#!/bin/bash
# Self-Update Module - Automated script updater

# GitHub repository details
REPO_URL="https://github.com/thelasttenno/Server-Helper.git"
REPO_RAW_URL="https://raw.githubusercontent.com/thelasttenno/Server-Helper/main"
INSTALL_DIR="/opt/Server-Helper"

# Check for updates
check_for_script_updates() {
    debug "[check_for_script_updates] Checking for Server Helper updates"

    log ""
    log "═══════════════════════════════════════════════════════"
    log "         Checking for Server Helper Updates"
    log "═══════════════════════════════════════════════════════"
    log ""

    # Get current version
    local current_version=$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "0.0.0")
    log "Current version: $current_version"

    # Check if git is available
    if ! command_exists git; then
        warning "Git is not installed. Installing git..."
        execute_with_spinner "Installing git" "sudo apt-get update && sudo apt-get install -y git"
    fi

    # Try to fetch latest version from GitHub
    log "Fetching latest version information..."
    local latest_version=$(curl -fsS "$REPO_RAW_URL/VERSION" 2>/dev/null || echo "")

    if [ -z "$latest_version" ]; then
        warning "Could not fetch latest version from GitHub"
        log "Repository: $REPO_URL"
        return 1
    fi

    log "Latest version: $latest_version"

    # Compare versions
    if [ "$current_version" = "$latest_version" ]; then
        log "✓ You are running the latest version"
        debug "[check_for_script_updates] Already up to date"
        return 0
    else
        log ""
        warning "New version available: $latest_version"
        log "Your version: $current_version"
        log ""

        # Show what's new if available
        log "Fetching changelog..."
        local changelog=$(curl -fsS "$REPO_RAW_URL/CHANGELOG.md" 2>/dev/null | head -50)
        if [ -n "$changelog" ]; then
            echo "$changelog" | grep -A 20 "## Version $latest_version" || true
        fi

        log ""
        debug "[check_for_script_updates] Update available"
        return 2
    fi
}

# Perform self-update
self_update() {
    debug "[self_update] Starting self-update process"

    require_root

    log ""
    log "═══════════════════════════════════════════════════════"
    log "         Server Helper Self-Update"
    log "═══════════════════════════════════════════════════════"
    log ""

    # Check for updates first
    check_for_script_updates
    local check_result=$?

    if [ $check_result -eq 0 ]; then
        log "Already running latest version. No update needed."
        return 0
    elif [ $check_result -eq 1 ]; then
        error "Could not check for updates"
        return 1
    fi

    # Confirm update
    log ""
    if ! confirm "Do you want to update Server Helper now?"; then
        log "Update cancelled by user"
        debug "[self_update] Update cancelled"
        return 0
    fi

    log ""
    log "Starting update process..."
    log ""

    # Create backup of current installation
    log "Step 1/5: Creating backup..."
    local backup_dir="/root/server-helper-backup-$(timestamp)"
    execute_with_spinner "Backing up current installation" "sudo cp -r $INSTALL_DIR $backup_dir"
    log "✓ Backup created: $backup_dir"

    # Backup configuration
    log ""
    log "Step 2/5: Backing up configuration..."
    if [ -f "$INSTALL_DIR/server-helper.conf" ]; then
        sudo cp "$INSTALL_DIR/server-helper.conf" "$backup_dir/server-helper.conf"
        log "✓ Configuration backed up"
    else
        log "No configuration file found"
    fi

    # Download latest version
    log ""
    log "Step 3/5: Downloading latest version..."
    local temp_dir="/tmp/server-helper-update-$$"
    execute_with_spinner "Cloning repository" "git clone --depth 1 $REPO_URL $temp_dir"

    if [ ! -d "$temp_dir" ]; then
        error "Failed to download update"
        log "Backup available at: $backup_dir"
        return 1
    fi

    log "✓ Latest version downloaded"

    # Stop service if running
    log ""
    log "Step 4/5: Preparing for update..."
    if systemctl is-active --quiet server-helper 2>/dev/null; then
        log "Stopping server-helper service..."
        sudo systemctl stop server-helper
        local service_was_running=true
    else
        local service_was_running=false
    fi

    # Update files
    log ""
    log "Step 5/5: Installing update..."

    # Copy new files
    execute_with_spinner "Updating scripts" "sudo cp -r $temp_dir/* $INSTALL_DIR/"

    # Restore configuration
    if [ -f "$backup_dir/server-helper.conf" ]; then
        sudo cp "$backup_dir/server-helper.conf" "$INSTALL_DIR/server-helper.conf"
        log "✓ Configuration restored"
    fi

    # Ensure correct permissions
    sudo chmod +x "$INSTALL_DIR/server_helper_setup.sh"
    sudo chmod +x "$INSTALL_DIR/lib/"*.sh
    sudo chmod 600 "$INSTALL_DIR/server-helper.conf" 2>/dev/null || true

    # Cleanup temp directory
    rm -rf "$temp_dir"

    log ""
    log "═══════════════════════════════════════════════════════"
    log "         Update Complete!"
    log "═══════════════════════════════════════════════════════"

    # Show new version
    local new_version=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null)
    log ""
    log "Updated to version: $new_version"
    log "Backup available at: $backup_dir"

    # Restart service if it was running
    if [ "$service_was_running" = true ]; then
        log ""
        if confirm "Restart server-helper service?"; then
            sudo systemctl start server-helper
            log "✓ Service restarted"
        else
            warning "Remember to restart the service manually:"
            log "  sudo systemctl start server-helper"
        fi
    fi

    log ""
    log "Update completed successfully!"
    log "Run 'sudo ./server_helper_setup.sh version' to see new version"

    debug "[self_update] Update completed successfully"
    return 0
}

# Auto-update check (for scheduled runs)
auto_update_check() {
    debug "[auto_update_check] Performing auto-update check"

    # Only check if enabled in config
    if [ "${AUTO_UPDATE_CHECK:-false}" != "true" ]; then
        debug "[auto_update_check] Auto-update check disabled"
        return 0
    fi

    log "Checking for Server Helper updates..."

    check_for_script_updates
    local result=$?

    if [ $result -eq 2 ]; then
        log ""
        warning "A new version of Server Helper is available!"
        log "Run: sudo ./server_helper_setup.sh self-update"

        # Send notification if Uptime Kuma URL is configured
        if [ -n "$UPTIME_KUMA_UPDATE_URL" ]; then
            curl -fsS -m 10 "${UPTIME_KUMA_UPDATE_URL}?status=update-available&msg=new-version" >/dev/null 2>&1 || true
        fi
    fi

    debug "[auto_update_check] Auto-update check complete"
}

# Rollback to previous version
rollback_update() {
    debug "[rollback_update] Starting rollback process"

    require_root

    log ""
    log "═══════════════════════════════════════════════════════"
    log "         Server Helper Rollback"
    log "═══════════════════════════════════════════════════════"
    log ""

    # Find latest backup
    local latest_backup=$(sudo find /root -maxdepth 1 -type d -name "server-helper-backup-*" 2>/dev/null | sort -r | head -1)

    if [ -z "$latest_backup" ]; then
        error "No backup found to rollback to"
        return 1
    fi

    log "Found backup: $latest_backup"

    # Get backup version
    local backup_version=$(cat "$latest_backup/VERSION" 2>/dev/null || echo "unknown")
    log "Backup version: $backup_version"

    log ""
    if ! confirm "Rollback to this version?"; then
        log "Rollback cancelled"
        return 0
    fi

    log ""
    log "Rolling back..."

    # Stop service if running
    if systemctl is-active --quiet server-helper 2>/dev/null; then
        log "Stopping server-helper service..."
        sudo systemctl stop server-helper
        local service_was_running=true
    else
        local service_was_running=false
    fi

    # Restore from backup
    execute_with_spinner "Restoring from backup" "sudo cp -r $latest_backup/* $INSTALL_DIR/"

    # Ensure correct permissions
    sudo chmod +x "$INSTALL_DIR/server_helper_setup.sh"
    sudo chmod +x "$INSTALL_DIR/lib/"*.sh
    sudo chmod 600 "$INSTALL_DIR/server-helper.conf" 2>/dev/null || true

    # Restart service if it was running
    if [ "$service_was_running" = true ]; then
        sudo systemctl start server-helper
        log "✓ Service restarted"
    fi

    log ""
    log "✓ Rollback complete"
    log "Current version: $(cat $INSTALL_DIR/VERSION 2>/dev/null)"

    debug "[rollback_update] Rollback completed successfully"
}

# Show update changelog
show_update_changelog() {
    debug "[show_update_changelog] Fetching changelog"

    log "Fetching latest changelog..."

    local changelog=$(curl -fsS "$REPO_RAW_URL/CHANGELOG.md" 2>/dev/null)

    if [ -n "$changelog" ]; then
        echo "$changelog" | less
    else
        error "Could not fetch changelog"
        log "Visit: https://github.com/thelasttenno/Server-Helper/blob/main/CHANGELOG.md"
    fi

    debug "[show_update_changelog] Changelog displayed"
}
