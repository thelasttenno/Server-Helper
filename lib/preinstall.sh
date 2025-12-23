#!/bin/bash
# Pre-Installation Check Module - Detects and handles existing installations

detect_existing_service() {
    debug "detect_existing_service() - Checking for existing systemd service"
    
    if systemctl list-unit-files | grep -q "server-helper.service"; then
        log "Found existing systemd service: server-helper.service"
        
        if systemctl is-active --quiet server-helper; then
            warning "Service is currently RUNNING"
            return 0
        else
            warning "Service exists but is STOPPED"
            return 0
        fi
    fi
    
    debug "detect_existing_service() - No existing service found"
    return 1
}

detect_existing_mounts() {
    debug "detect_existing_mounts() - Checking for existing NAS mounts"
    local found=0
    
    # Check for CIFS mounts in /etc/fstab
    if grep -q "cifs.*_netdev" /etc/fstab 2>/dev/null; then
        warning "Found CIFS mount entries in /etc/fstab"
        grep "cifs.*_netdev" /etc/fstab | while read line; do
            log "  - $line"
        done
        found=1
    fi
    
    # Check for currently mounted shares
    if mount | grep -q "type cifs"; then
        warning "Found currently mounted CIFS shares:"
        mount | grep "type cifs" | while read line; do
            log "  - $line"
        done
        found=1
    fi
    
    # Check for NAS credential files
    if sudo find /root -name ".nascreds_*" -type f 2>/dev/null | grep -q .; then
        warning "Found existing NAS credential files:"
        sudo find /root -name ".nascreds_*" -type f 2>/dev/null | while read file; do
            log "  - $file"
        done
        found=1
    fi
    
    debug "detect_existing_mounts() - Mount detection result: $found"
    return $found
}

detect_existing_dockge() {
    debug "detect_existing_dockge() - Checking for existing Dockge installation"
    local found=0
    
    # Check for Dockge directory
    if [ -d "/opt/dockge" ]; then
        warning "Found existing Dockge directory: /opt/dockge"
        
        # Check if Dockge container is running
        if sudo docker ps 2>/dev/null | grep -q dockge; then
            warning "Dockge container is RUNNING"
            found=1
        elif sudo docker ps -a 2>/dev/null | grep -q dockge; then
            warning "Dockge container exists but is STOPPED"
            found=1
        fi
        
        # Check directory contents
        if [ -d "/opt/dockge/stacks" ] || [ -d "/opt/dockge/data" ]; then
            local stack_count=$(find /opt/dockge/stacks -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            if [ $stack_count -gt 0 ]; then
                warning "Found $stack_count stack(s) in /opt/dockge/stacks"
            fi
        fi
        
        found=1
    fi
    
    debug "detect_existing_dockge() - Dockge detection result: $found"
    return $found
}

detect_existing_docker() {
    debug "detect_existing_docker() - Checking for existing Docker installation"
    
    if command_exists docker; then
        local docker_version=$(docker --version 2>/dev/null)
        warning "Found existing Docker installation: $docker_version"
        
        # Check for running containers
        local running_containers=$(sudo docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
        if [ $running_containers -gt 0 ]; then
            warning "Found $running_containers running container(s)"
            sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | head -10
        fi
        
        return 0
    fi
    
    debug "detect_existing_docker() - No Docker installation found"
    return 1
}

detect_existing_config() {
    debug "detect_existing_config() - Checking for existing configuration"
    
    if [ -f "/opt/Server-Helper/server-helper.conf" ]; then
        warning "Found existing configuration file: /opt/Server-Helper/server-helper.conf"
        log "Last modified: $(stat -c %y /opt/Server-Helper/server-helper.conf 2>/dev/null | cut -d. -f1)"
        return 0
    fi
    
    debug "detect_existing_config() - No configuration file found"
    return 1
}

detect_existing_backups() {
    debug "detect_existing_backups() - Checking for existing backups"
    local found=0
    
    # Check local backup directory
    if [ -d "/opt/dockge_backups_local" ]; then
        local backup_count=$(find /opt/dockge_backups_local -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
        if [ $backup_count -gt 0 ]; then
            warning "Found $backup_count local backup(s) in /opt/dockge_backups_local"
            found=1
        fi
    fi
    
    # Check if NAS mount point exists and has backups
    if [ -d "/mnt/nas/dockge_backups" ]; then
        local nas_backup_count=$(find /mnt/nas/dockge_backups -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
        if [ $nas_backup_count -gt 0 ]; then
            warning "Found $nas_backup_count backup(s) on NAS"
            found=1
        fi
    fi
    
    debug "detect_existing_backups() - Backup detection result: $found"
    return $found
}

show_installation_summary() {
    log ""
    log "═══════════════════════════════════════════════════════"
    log "         EXISTING INSTALLATION DETECTED"
    log "═══════════════════════════════════════════════════════"
    log ""
    
    local has_service; detect_existing_service >/dev/null 2>&1; has_service=$?
    local has_mounts; detect_existing_mounts >/dev/null 2>&1; has_mounts=$?
    local has_dockge; detect_existing_dockge >/dev/null 2>&1; has_dockge=$?
    local has_docker; detect_existing_docker >/dev/null 2>&1; has_docker=$?
    local has_config; detect_existing_config >/dev/null 2>&1; has_config=$?
    local has_backups; detect_existing_backups >/dev/null 2>&1; has_backups=$?
    
    log ""
    log "Installation Component Status:"
    [ "$has_service" -eq 0 ] && log "  ✓ Systemd Service" || log "  ✗ Systemd Service"
    [ "$has_mounts" -eq 0 ] && log "  ✓ NAS Mounts" || log "  ✗ NAS Mounts"
    [ "$has_dockge" -eq 0 ] && log "  ✓ Dockge" || log "  ✗ Dockge"
    [ "$has_docker" -eq 0 ] && log "  ✓ Docker" || log "  ✗ Docker"
    [ "$has_config" -eq 0 ] && log "  ✓ Configuration File" || log "  ✗ Configuration File"
    [ "$has_backups" -eq 0 ] && log "  ✓ Existing Backups" || log "  ✗ Existing Backups"
    log ""
    log "═══════════════════════════════════════════════════════"
}

cleanup_existing_service() {
    debug "cleanup_existing_service() - Removing existing systemd service"
    
    log "Stopping and removing systemd service..."
    sudo systemctl stop server-helper 2>/dev/null || true
    sudo systemctl disable server-helper 2>/dev/null || true
    sudo rm /etc/systemd/system/server-helper.service 2>/dev/null || true
    sudo systemctl daemon-reload
    
    log "✓ Service removed"
}

cleanup_existing_mounts() {
    debug "cleanup_existing_mounts() - Unmounting and cleaning up NAS mounts"
    
    log "Unmounting CIFS shares..."
    
    # Unmount all CIFS mounts
    mount | grep "type cifs" | awk '{print $3}' | while read mount_point; do
        log "Unmounting: $mount_point"
        sudo umount -f "$mount_point" 2>/dev/null || sudo umount -l "$mount_point" 2>/dev/null || true
    done
    
    # Backup and clean fstab
    if grep -q "cifs.*_netdev" /etc/fstab 2>/dev/null; then
        log "Backing up /etc/fstab..."
        sudo cp /etc/fstab "/etc/fstab.backup.$(timestamp)"
        sudo sed -i.bak '/cifs.*_netdev/d' /etc/fstab
    fi
    
    # Remove credential files
    sudo find /root -name ".nascreds_*" -type f -delete 2>/dev/null || true
    
    log "✓ NAS mounts cleaned up"
}

cleanup_existing_dockge() {
    debug "cleanup_existing_dockge() - Removing existing Dockge installation"
    
    log "Stopping Dockge containers..."
    
    if [ -d "/opt/dockge" ]; then
        cd /opt/dockge
        sudo docker compose down 2>/dev/null || true
        cd -
    fi
    
    # Remove Dockge containers
    sudo docker rm -f $(sudo docker ps -a -q --filter "name=dockge") 2>/dev/null || true
    
    if confirm "Delete Dockge data directory (/opt/dockge)? This will remove all stacks!"; then
        if confirm "Create backup before deletion?"; then
            local backup_file="/root/dockge_preinstall_backup_$(timestamp).tar.gz"
            log "Creating backup: $backup_file"
            sudo tar -czf "$backup_file" -C /opt dockge 2>/dev/null || true
            log "✓ Backup created: $backup_file"
        fi
        
        log "Removing /opt/dockge..."
        sudo rm -rf /opt/dockge
        log "✓ Dockge directory removed"
    else
        warning "Keeping existing Dockge data directory"
    fi
}

cleanup_existing_docker() {
    debug "cleanup_existing_docker() - Checking Docker removal"
    
    warning "═══════════════════════════════════════════════════════"
    warning "         DOCKER REMOVAL CONFIRMATION"
    warning "═══════════════════════════════════════════════════════"
    warning ""
    warning "This will remove Docker and ALL containers, images, and volumes!"
    warning "This action is DESTRUCTIVE and cannot be easily undone."
    warning ""
    
    if ! confirm "Do you want to remove Docker completely?"; then
        log "Keeping existing Docker installation"
        return 0
    fi
    
    if ! confirm "Type 'REMOVE-DOCKER' to confirm (case sensitive)"; then
        log "Docker removal cancelled"
        return 0
    fi
    
    read -p "Confirmation text: " confirm_text
    if [ "$confirm_text" != "REMOVE-DOCKER" ]; then
        error "Confirmation text did not match. Docker removal cancelled."
        return 1
    fi
    
    log "Removing Docker..."
    sudo systemctl stop docker 2>/dev/null || true
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || true
    
    if confirm "Remove ALL Docker data (/var/lib/docker)?"; then
        sudo rm -rf /var/lib/docker /var/lib/containerd
        log "✓ Docker data removed"
    fi
    
    log "✓ Docker removed"
}

pre_installation_check() {
    debug "pre_installation_check() - Starting pre-installation check"
    
    log ""
    log "═══════════════════════════════════════════════════════"
    log "         PRE-INSTALLATION CHECK"
    log "═══════════════════════════════════════════════════════"
    log ""
    log "Checking for existing Server Helper installation..."
    log ""
    
    local existing_found=0
    
    # Run all detection functions
    detect_existing_service && existing_found=1
    detect_existing_mounts && existing_found=1
    detect_existing_dockge && existing_found=1
    detect_existing_docker && existing_found=1
    detect_existing_config && existing_found=1
    detect_existing_backups && existing_found=1
    
    if [ $existing_found -eq 0 ]; then
        log "✓ No existing installation detected"
        log "Proceeding with fresh installation..."
        debug "pre_installation_check() - No existing installation found"
        return 0
    fi
    
    # Show summary and prompt for action
    show_installation_summary
    
    log ""
    log "What would you like to do?"
    log ""
    log "1) Continue with existing installation (skip setup)"
    log "2) Remove and reinstall (clean slate)"
    log "3) Selective cleanup (choose components)"
    log "4) Cancel and exit"
    log ""
    
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            log "Continuing with existing installation..."
            debug "pre_installation_check() - User chose to keep existing installation"
            return 0
            ;;
        2)
            warning "═══════════════════════════════════════════════════════"
            warning "         COMPLETE REMOVAL SELECTED"
            warning "═══════════════════════════════════════════════════════"
            
            if ! confirm "This will remove ALL components. Continue?"; then
                log "Cancelled by user"
                exit 0
            fi
            
            debug "pre_installation_check() - User chose complete removal"
            
            detect_existing_service && cleanup_existing_service
            detect_existing_dockge && cleanup_existing_dockge
            detect_existing_mounts && cleanup_existing_mounts
            detect_existing_docker && cleanup_existing_docker
            
            log ""
            log "✓ Complete cleanup finished"
            log "Proceeding with fresh installation..."
            return 0
            ;;
        3)
            debug "pre_installation_check() - User chose selective cleanup"
            
            detect_existing_service && {
                confirm "Remove systemd service?" && cleanup_existing_service
            }
            
            detect_existing_dockge && {
                confirm "Remove Dockge installation?" && cleanup_existing_dockge
            }
            
            detect_existing_mounts && {
                confirm "Cleanup NAS mounts?" && cleanup_existing_mounts
            }
            
            detect_existing_docker && {
                confirm "Remove Docker?" && cleanup_existing_docker
            }
            
            log ""
            log "✓ Selective cleanup finished"
            log "Proceeding with installation..."
            return 0
            ;;
        4)
            log "Installation cancelled by user"
            debug "pre_installation_check() - User cancelled installation"
            exit 0
            ;;
        *)
            error "Invalid choice"
            debug "pre_installation_check() - Invalid user choice: $choice"
            exit 1
            ;;
    esac
}
