#!/bin/bash
# Backup & Restore Module - Enhanced with Config File Backup and Debug Support

# Configuration files to backup
declare -a CONFIG_FILES=(
    "/etc/fstab"
    "/etc/hosts"
    "/etc/hostname"
    "/etc/ssh/sshd_config"
    "/etc/fail2ban/jail.local"
    "/etc/ufw/ufw.conf"
    "/etc/systemd/system/server-helper.service"
    "$CONFIG_FILE"
)

# Additional directories to backup
declare -a CONFIG_DIRS=(
    "/etc/docker"
    "/etc/apt/sources.list.d"
)

backup_config_files() {
    debug "backup_config_files() - Starting configuration backup"
    log "Backing up configuration files..."
    
    local backup_dir="$BACKUP_DIR"
    local config_backup_dir="$backup_dir/config"
    
    # Use local backup if NAS unavailable
    if [ ! -d "$backup_dir" ]; then
        if ! mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
            backup_dir="/opt/dockge_backups_local"
            config_backup_dir="$backup_dir/config"
            warning "NAS unavailable, using local backup: $backup_dir"
            debug "backup_config_files() - Switched to local backup directory"
        fi
    fi
    
    debug "backup_config_files() - Creating backup directory: $config_backup_dir"
    mkdir -p "$config_backup_dir"
    
    local ts=$(timestamp)
    local config_backup_file="$config_backup_dir/config_backup_$ts.tar.gz"
    local temp_dir="/tmp/server-helper-config-backup-$$"
    
    debug "backup_config_files() - Temp directory: $temp_dir"
    debug "backup_config_files() - Backup file: $config_backup_file"
    
    # Create temporary directory structure
    mkdir -p "$temp_dir"
    
    local file_count=0
    
    # Backup individual config files
    debug "backup_config_files() - Backing up individual config files"
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$file" ]; then
            local dest_dir="$temp_dir$(dirname "$file")"
            mkdir -p "$dest_dir"
            if sudo cp "$file" "$dest_dir/" 2>/dev/null; then
                debug "Backed up: $file"
                ((file_count++))
            else
                debug "Failed to backup: $file"
            fi
        else
            debug "File not found (skipping): $file"
        fi
    done
    
    # Backup config directories
    debug "backup_config_files() - Backing up config directories"
    for dir in "${CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local dest_dir="$temp_dir$(dirname "$dir")"
            mkdir -p "$dest_dir"
            if sudo cp -r "$dir" "$dest_dir/" 2>/dev/null; then
                debug "Backed up directory: $dir"
                ((file_count++))
            else
                debug "Failed to backup directory: $dir"
            fi
        else
            debug "Directory not found (skipping): $dir"
        fi
    done
    
    # Backup NAS credentials
    debug "backup_config_files() - Backing up NAS credentials"
    sudo find /root -name ".nascreds_*" -type f 2>/dev/null | while read cred_file; do
        local dest_dir="$temp_dir/root"
        mkdir -p "$dest_dir"
        if sudo cp "$cred_file" "$dest_dir/" 2>/dev/null; then
            debug "Backed up: $cred_file"
            ((file_count++))
        fi
    done
    
    # Create backup manifest
    debug "backup_config_files() - Creating backup manifest"
    cat > "$temp_dir/backup_manifest.txt" << EOF
Server Helper Configuration Backup
Created: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
OS: $(lsb_release -d | cut -f2)
Files backed up: $file_count

Files included:
EOF
    
    find "$temp_dir" -type f ! -name "backup_manifest.txt" | sed "s|$temp_dir||" >> "$temp_dir/backup_manifest.txt"
    
    # Create tarball
    debug "backup_config_files() - Creating tarball"
    if sudo tar -czf "$config_backup_file" -C "$temp_dir" . 2>/dev/null; then
        debug "backup_config_files() - Tarball created successfully"
    else
        error "Config backup failed"
        rm -rf "$temp_dir"
        debug "backup_config_files() - Tarball creation failed"
        return 1
    fi
    
    # Cleanup temp directory
    debug "backup_config_files() - Cleaning up temp directory"
    rm -rf "$temp_dir"
    
    local file_size=$(get_file_size "$config_backup_file")
    log "✓ Config backup created: $config_backup_file ($file_size, $file_count items)"
    
    # Clean old config backups
    debug "backup_config_files() - Cleaning old backups (retention: $BACKUP_RETENTION_DAYS days)"
    find "$config_backup_dir" -name "config_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local config_count=$(find "$config_backup_dir" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Config backups retained: $config_count"
    
    debug "backup_config_files() - Completed successfully"
    return 0
}

backup_dockge() {
    debug "backup_dockge() - Starting Dockge backup"
    log "Starting backup..."
    
    local backup_dir="$BACKUP_DIR"
    if [ ! -d "$backup_dir" ]; then
        if ! mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
            backup_dir="/opt/dockge_backups_local"
            warning "NAS unavailable, using local backup: $backup_dir"
            debug "backup_dockge() - Switched to local backup directory"
        fi
    fi
    
    debug "backup_dockge() - Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir"
    
    local ts=$(timestamp)
    local backup_file="$backup_dir/dockge_backup_$ts.tar.gz"
    
    debug "backup_dockge() - Backup file: $backup_file"
    debug "backup_dockge() - Source directory: $DOCKGE_DATA_DIR"
    
    # Backup Dockge data
    debug "backup_dockge() - Creating Dockge tarball"
    if sudo tar -czf "$backup_file" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        local file_size=$(get_file_size "$backup_file")
        log "✓ Dockge backup created: $backup_file ($file_size)"
        debug "backup_dockge() - Dockge backup successful"
    else
        error "Dockge backup failed"
        debug "backup_dockge() - Dockge backup failed"
        return 1
    fi
    
    # Automatically backup configuration files
    debug "backup_dockge() - Triggering automatic config backup"
    backup_config_files
    
    # Clean old Dockge backups
    debug "backup_dockge() - Cleaning old backups (retention: $BACKUP_RETENTION_DAYS days)"
    find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local dockge_count=$(find "$backup_dir" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Dockge backups retained: $dockge_count"
    
    debug "backup_dockge() - Completed successfully"
}

restore_config_files() {
    debug "restore_config_files() - Starting configuration restore"
    log "Available config backups:"
    local config_backup_dir="$BACKUP_DIR/config"
    
    debug "restore_config_files() - Backup directory: $config_backup_dir"
    
    ls -lh "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null || { 
        error "No config backups found"
        debug "restore_config_files() - No backups found"
        return 1
    }
    
    read -p "Enter filename or 'latest': " file
    debug "restore_config_files() - User input: $file"
    
    if [ "$file" = "latest" ]; then
        file=$(ls -t "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null | head -1)
        debug "restore_config_files() - Selected latest: $file"
    fi
    
    if [ -z "$file" ]; then
        file="$config_backup_dir/$file"
    elif [ ! -f "$file" ]; then
        [ -f "$config_backup_dir/$file" ] && file="$config_backup_dir/$file" || {
            error "File not found"
            debug "restore_config_files() - File not found: $file"
            return 1
        }
    fi
    
    [ ! -f "$file" ] && { 
        error "File not found: $file"
        debug "restore_config_files() - File validation failed"
        return 1
    }
    
    # Show manifest
    log "Backup contents:"
    debug "restore_config_files() - Displaying manifest"
    sudo tar -tzf "$file" backup_manifest.txt 2>/dev/null && sudo tar -xzOf "$file" backup_manifest.txt || true
    echo ""
    
    if ! confirm "Restore from this config backup? This will overwrite current configuration files"; then
        log "Restore cancelled"
        debug "restore_config_files() - User cancelled restore"
        return 1
    fi
    
    # Create emergency backup
    local emergency_backup="/root/emergency_config_backup_$(timestamp).tar.gz"
    log "Creating emergency backup..."
    debug "restore_config_files() - Emergency backup: $emergency_backup"
    
    local temp_dir="/tmp/server-helper-emergency-$$"
    mkdir -p "$temp_dir"
    
    for cfg_file in "${CONFIG_FILES[@]}"; do
        if [ -f "$cfg_file" ]; then
            local dest_dir="$temp_dir$(dirname "$cfg_file")"
            mkdir -p "$dest_dir"
            sudo cp "$cfg_file" "$dest_dir/" 2>/dev/null
            debug "restore_config_files() - Backed up to emergency: $cfg_file"
        fi
    done
    
    sudo tar -czf "$emergency_backup" -C "$temp_dir" . 2>/dev/null
    rm -rf "$temp_dir"
    log "Emergency backup created: $emergency_backup"
    
    # Restore configuration files
    log "Restoring configuration files..."
    debug "restore_config_files() - Extracting backup to /"
    if sudo tar -xzf "$file" -C / 2>/dev/null; then
        log "✓ Configuration restore complete"
        debug "restore_config_files() - Restore successful"
    else
        error "Restore failed"
        debug "restore_config_files() - Restore failed"
        return 1
    fi
    
    warning "Please review restored files and reboot if necessary"
    
    # Show what was restored
    log "Restored files:"
    sudo tar -tzf "$file" | grep -v "/$" | head -20
    
    debug "restore_config_files() - Completed"
    return 0
}

restore_dockge() {
    debug "restore_dockge() - Starting Dockge restore"
    log "Available Dockge backups:"
    
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || { 
        error "No Dockge backups found"
        debug "restore_dockge() - No backups found"
        return 1
    }
    
    read -p "Enter filename or 'latest': " file
    debug "restore_dockge() - User input: $file"
    
    if [ "$file" = "latest" ]; then
        file=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
        debug "restore_dockge() - Selected latest: $file"
    else
        [ -z "$file" ] || [ ! -f "$BACKUP_DIR/$file" ] && { 
            error "File not found"
            debug "restore_dockge() - File not found: $file"
            return 1
        }
        file="$BACKUP_DIR/$file"
    fi
    
    if ! confirm "Restore from backup? This will overwrite current Dockge data"; then
        log "Restore cancelled"
        debug "restore_dockge() - User cancelled restore"
        return 1
    fi
    
    debug "restore_dockge() - Stopping Dockge"
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Create emergency backup
    local emergency_backup="emergency_dockge_backup_$(timestamp).tar.gz"
    debug "restore_dockge() - Creating emergency backup: $emergency_backup"
    sudo tar -czf "$emergency_backup" stacks data 2>/dev/null
    log "Emergency backup created: $emergency_backup"
    
    # Restore
    debug "restore_dockge() - Removing old data"
    sudo rm -rf stacks data
    
    debug "restore_dockge() - Extracting backup"
    sudo tar -xzf "$file" -C "$DOCKGE_DATA_DIR"
    
    debug "restore_dockge() - Starting Dockge"
    sudo docker compose up -d
    
    log "✓ Dockge restore complete"
    debug "restore_dockge() - Completed successfully"
}

list_backups() {
    debug "list_backups() - Listing all backups"
    
    log "=== Dockge Backups ==="
    if ls "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null; then
        ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null
    else
        echo "No Dockge backups found"
    fi
    
    echo ""
    log "=== Configuration Backups ==="
    if ls "$BACKUP_DIR/config"/config_backup_*.tar.gz 2>/dev/null; then
        ls -lh "$BACKUP_DIR/config"/config_backup_*.tar.gz 2>/dev/null
    else
        echo "No config backups found"
    fi
    
    echo ""
    log "=== Backup Statistics ==="
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local dockge_count=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    local config_count=$(find "$BACKUP_DIR/config" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    
    echo "Total backup size: ${total_size:-0}"
    echo "Dockge backups: $dockge_count"
    echo "Config backups: $config_count"
    echo "Retention period: $BACKUP_RETENTION_DAYS days"
    
    debug "list_backups() - Completed"
}

# Backup both Dockge and config files
backup_all() {
    debug "backup_all() - Starting complete backup"
    log "Starting complete backup (Dockge + Config)..."
    backup_dockge
    # config is already called within backup_dockge
    log "✓ Complete backup finished"
    debug "backup_all() - Completed"
}

# Export manifest from a backup
show_backup_manifest() {
    local backup_file="$1"
    
    debug "show_backup_manifest() - File: $backup_file"
    
    if [ -z "$backup_file" ]; then
        read -p "Enter backup file path: " backup_file
        debug "show_backup_manifest() - User provided: $backup_file"
    fi
    
    [ ! -f "$backup_file" ] && { 
        error "File not found: $backup_file"
        debug "show_backup_manifest() - File not found"
        return 1
    }
    
    log "Backup manifest for: $(basename "$backup_file")"
    echo "================================"
    
    if [[ "$backup_file" == *"config_backup"* ]]; then
        debug "show_backup_manifest() - Config backup detected"
        sudo tar -xzOf "$backup_file" backup_manifest.txt 2>/dev/null || {
            error "No manifest found in backup"
            log "Backup contents:"
            sudo tar -tzf "$backup_file" | head -50
        }
    else
        debug "show_backup_manifest() - Dockge backup detected"
        log "Backup contents:"
        sudo tar -tzf "$backup_file" | head -50
        echo "..."
        log "Total files: $(sudo tar -tzf "$backup_file" | wc -l)"
    fi
    
    debug "show_backup_manifest() - Completed"
}
