#!/bin/bash
# Backup & Restore Module - Enhanced with Debug

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
    debug "backup_config_files called"
    log "Backing up configuration files..."
    
    local backup_dir="$BACKUP_DIR"
    local config_backup_dir="$backup_dir/config"
    debug "Target backup directory: $backup_dir"
    debug "Config backup directory: $config_backup_dir"
    
    # Use local backup if NAS unavailable
    if [ ! -d "$backup_dir" ]; then
        debug "Backup directory not accessible, checking NAS mount"
        if mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
            debug "NAS is mounted but backup dir doesn't exist"
        else
            backup_dir="/opt/dockge_backups_local"
            config_backup_dir="$backup_dir/config"
            warning "Using local backup: $backup_dir"
            debug "Switched to local backup directory"
        fi
    fi
    
    debug "Creating config backup directory: $config_backup_dir"
    mkdir -p "$config_backup_dir"
    
    local ts=$(timestamp)
    local config_backup_file="$config_backup_dir/config_backup_$ts.tar.gz"
    local temp_dir="/tmp/server-helper-config-backup-$$"
    debug "Timestamp: $ts"
    debug "Backup file will be: $config_backup_file"
    debug "Temporary directory: $temp_dir"
    
    # Create temporary directory structure
    debug "Creating temporary directory structure"
    mkdir -p "$temp_dir"
    
    local file_count=0
    
    # Backup individual config files
    debug "Backing up individual config files (${#CONFIG_FILES[@]} files to check)"
    for file in "${CONFIG_FILES[@]}"; do
        debug "Checking file: $file"
        if [ -f "$file" ]; then
            local dest_dir="$temp_dir$(dirname "$file")"
            debug "File exists, destination: $dest_dir"
            mkdir -p "$dest_dir"
            if sudo cp "$file" "$dest_dir/" 2>/dev/null; then
                debug "Backed up: $file"
                ((file_count++))
            else
                debug "Failed to backup: $file"
            fi
        else
            debug "File does not exist: $file"
        fi
    done
    debug "Backed up $file_count config files"
    
    # Backup config directories
    debug "Backing up config directories (${#CONFIG_DIRS[@]} directories to check)"
    for dir in "${CONFIG_DIRS[@]}"; do
        debug "Checking directory: $dir"
        if [ -d "$dir" ]; then
            local dest_dir="$temp_dir$(dirname "$dir")"
            debug "Directory exists, destination: $dest_dir"
            mkdir -p "$dest_dir"
            if sudo cp -r "$dir" "$dest_dir/" 2>/dev/null; then
                debug "Backed up directory: $dir"
                ((file_count++))
            else
                debug "Failed to backup directory: $dir"
            fi
        else
            debug "Directory does not exist: $dir"
        fi
    done
    
    # Backup NAS credentials
    debug "Looking for NAS credential files in /root"
    local cred_count=0
    sudo find /root -name ".nascreds_*" -type f 2>/dev/null | while read cred_file; do
        debug "Found credential file: $cred_file"
        local dest_dir="$temp_dir/root"
        mkdir -p "$dest_dir"
        if sudo cp "$cred_file" "$dest_dir/" 2>/dev/null; then
            debug "Backed up: $cred_file"
            ((cred_count++))
            ((file_count++))
        fi
    done
    debug "Backed up $cred_count credential files"
    
    # Create backup manifest
    debug "Creating backup manifest"
    cat > "$temp_dir/backup_manifest.txt" << EOF
Server Helper Configuration Backup
Created: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Files backed up: $file_count

Files included:
EOF
    
    find "$temp_dir" -type f ! -name "backup_manifest.txt" | sed "s|$temp_dir||" >> "$temp_dir/backup_manifest.txt"
    debug "Manifest created with file listing"
    
    # Create tarball
    debug "Creating tarball: $config_backup_file"
    if sudo tar -czf "$config_backup_file" -C "$temp_dir" . 2>/dev/null; then
        debug "Tarball created successfully"
    else
        error "Config backup failed"
        debug "Tarball creation failed"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup temp directory
    debug "Cleaning up temporary directory: $temp_dir"
    rm -rf "$temp_dir"
    
    local file_size=$(get_file_size "$config_backup_file")
    log "✓ Config backup created: $config_backup_file ($file_size, $file_count items)"
    debug "Config backup completed successfully"
    
    # Clean old config backups
    debug "Cleaning old config backups (retention: $BACKUP_RETENTION_DAYS days)"
    find "$config_backup_dir" -name "config_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local config_count=$(find "$config_backup_dir" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Config backups retained: $config_count"
    debug "Cleanup completed, $config_count backups remain"
    
    return 0
}

backup_dockge() {
    debug "backup_dockge called"
    log "Starting backup..."
    
    local backup_dir="$BACKUP_DIR"
    debug "Checking backup directory: $backup_dir"
    
    if [ ! -d "$backup_dir" ]; then
        debug "Backup directory not accessible"
        if mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
            debug "NAS mounted but backup dir missing"
        else
            backup_dir="/opt/dockge_backups_local"
            warning "Using local backup: $backup_dir"
            debug "Switched to local backup: $backup_dir"
        fi
    fi
    
    debug "Creating backup directory: $backup_dir"
    mkdir -p "$backup_dir"
    
    local ts=$(timestamp)
    local backup_file="$backup_dir/dockge_backup_$ts.tar.gz"
    debug "Backup file: $backup_file"
    debug "Timestamp: $ts"
    
    # Backup Dockge data
    debug "Creating Dockge backup from: $DOCKGE_DATA_DIR"
    debug "Including: stacks/ and data/"
    if sudo tar -czf "$backup_file" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        local file_size=$(get_file_size "$backup_file")
        log "✓ Dockge backup created: $backup_file ($file_size)"
        debug "Dockge backup created successfully"
    else
        error "Dockge backup failed"
        debug "Tar command failed for Dockge backup"
        return 1
    fi
    
    # Automatically backup configuration files
    debug "Automatically backing up configuration files"
    backup_config_files
    
    # Clean old Dockge backups
    debug "Cleaning old Dockge backups (retention: $BACKUP_RETENTION_DAYS days)"
    find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local dockge_count=$(find "$backup_dir" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Dockge backups retained: $dockge_count"
    debug "Cleanup completed, $dockge_count Dockge backups remain"
}

restore_config_files() {
    debug "restore_config_files called"
    log "Available config backups:"
    local config_backup_dir="$BACKUP_DIR/config"
    debug "Looking in: $config_backup_dir"
    
    if ls -lh "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null; then
        debug "Found config backups"
    else
        error "No config backups found"
        debug "No config backup files found in $config_backup_dir"
        return 1
    fi
    
    read -p "Enter filename or 'latest': " file
    debug "User input: $file"
    
    if [ "$file" = "latest" ]; then
        file=$(ls -t "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null | head -1)
        debug "Selected latest file: $file"
    fi
    
    if [ -z "$file" ]; then
        file="$config_backup_dir/$file"
        debug "Constructed full path: $file"
    elif [ ! -f "$file" ]; then
        if [ -f "$config_backup_dir/$file" ]; then
            file="$config_backup_dir/$file"
            debug "Found file in config backup dir: $file"
        else
            error "File not found"
            debug "File not found: $file"
            return 1
        fi
    fi
    
    if [ ! -f "$file" ]; then
        error "File not found: $file"
        debug "Final check failed, file does not exist"
        return 1
    fi
    
    debug "Selected backup file: $file"
    
    # Show manifest
    log "Backup contents:"
    debug "Extracting and displaying manifest"
    if sudo tar -tzf "$file" backup_manifest.txt 2>/dev/null; then
        sudo tar -xzOf "$file" backup_manifest.txt
    fi
    echo ""
    
    if ! confirm "Restore from this config backup? This will overwrite current configuration files"; then
        debug "User declined restore operation"
        return 1
    fi
    
    # Create emergency backup
    local emergency_backup="/root/emergency_config_backup_$(timestamp).tar.gz"
    log "Creating emergency backup..."
    debug "Emergency backup location: $emergency_backup"
    
    local temp_dir="/tmp/server-helper-emergency-$$"
    debug "Creating temp directory: $temp_dir"
    mkdir -p "$temp_dir"
    
    debug "Backing up current config files for emergency restore"
    for cfg_file in "${CONFIG_FILES[@]}"; do
        if [ -f "$cfg_file" ]; then
            debug "Backing up: $cfg_file"
            local dest_dir="$temp_dir$(dirname "$cfg_file")"
            mkdir -p "$dest_dir"
            sudo cp "$cfg_file" "$dest_dir/" 2>/dev/null
        fi
    done
    
    debug "Creating emergency backup tarball"
    sudo tar -czf "$emergency_backup" -C "$temp_dir" . 2>/dev/null
    rm -rf "$temp_dir"
    log "Emergency backup created: $emergency_backup"
    
    # Restore configuration files
    log "Restoring configuration files..."
    debug "Extracting backup to root: $file"
    if sudo tar -xzf "$file" -C / 2>/dev/null; then
        log "✓ Configuration restore complete"
        debug "Restore completed successfully"
    else
        error "Restore failed"
        debug "Tar extraction failed"
        return 1
    fi
    
    warning "Please review restored files and reboot if necessary"
    
    # Show what was restored
    log "Restored files:"
    debug "Listing restored files"
    sudo tar -tzf "$file" | grep -v "/$" | head -20
    
    debug "restore_config_files completed"
    return 0
}

restore_dockge() {
    debug "restore_dockge called"
    log "Available Dockge backups:"
    debug "Backup directory: $BACKUP_DIR"
    
    if ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null; then
        debug "Found Dockge backups"
    else
        error "No Dockge backups found"
        debug "No Dockge backup files found"
        return 1
    fi
    
    read -p "Enter filename or 'latest': " file
    debug "User input: $file"
    
    if [ "$file" = "latest" ]; then
        file=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
        debug "Selected latest: $file"
    else
        if [ -z "$file" ] || [ ! -f "$BACKUP_DIR/$file" ]; then
            error "File not found"
            debug "File not found: $BACKUP_DIR/$file"
            return 1
        fi
        file="$BACKUP_DIR/$file"
    fi
    
    debug "Selected backup file: $file"
    
    if ! confirm "Restore from backup? This will overwrite current Dockge data"; then
        debug "User declined restore"
        return 1
    fi
    
    debug "Stopping Dockge"
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Create emergency backup
    local emergency_file="emergency_dockge_backup_$(timestamp).tar.gz"
    log "Creating emergency backup..."
    debug "Emergency backup: $emergency_file"
    sudo tar -czf "$emergency_file" stacks data 2>/dev/null
    
    # Restore
    debug "Removing current stacks and data"
    sudo rm -rf stacks data
    
    debug "Extracting backup: $file"
    sudo tar -xzf "$file" -C "$DOCKGE_DATA_DIR"
    
    debug "Starting Dockge"
    sudo docker compose up -d
    
    log "✓ Dockge restore complete"
    debug "restore_dockge completed"
}

list_backups() {
    debug "list_backups called"
    
    log "=== Dockge Backups ==="
    debug "Listing Dockge backups from: $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No Dockge backups found"
    
    echo ""
    log "=== Configuration Backups ==="
    debug "Listing config backups from: $BACKUP_DIR/config"
    ls -lh "$BACKUP_DIR/config"/config_backup_*.tar.gz 2>/dev/null || echo "No config backups found"
    
    echo ""
    log "=== Backup Statistics ==="
    debug "Calculating backup statistics"
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local dockge_count=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    local config_count=$(find "$BACKUP_DIR/config" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    
    echo "Total backup size: ${total_size:-0}"
    echo "Dockge backups: $dockge_count"
    echo "Config backups: $config_count"
    echo "Retention period: $BACKUP_RETENTION_DAYS days"
    
    debug "Total size: $total_size, Dockge: $dockge_count, Config: $config_count"
    debug "list_backups completed"
}

backup_all() {
    debug "backup_all called"
    log "Starting complete backup (Dockge + Config)..."
    backup_dockge
    # config is already called within backup_dockge
    log "✓ Complete backup finished"
    debug "backup_all completed"
}

show_backup_manifest() {
    local backup_file="$1"
    debug "show_backup_manifest called with: $backup_file"
    
    if [ -z "$backup_file" ]; then
        read -p "Enter backup file path: " backup_file
        debug "User entered: $backup_file"
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "File not found: $backup_file"
        debug "Backup file does not exist"
        return 1
    fi
    
    log "Backup manifest for: $(basename "$backup_file")"
    echo "================================"
    debug "Displaying manifest from: $backup_file"
    
    if [[ "$backup_file" == *"config_backup"* ]]; then
        debug "Config backup detected, extracting manifest"
        if sudo tar -xzOf "$backup_file" backup_manifest.txt 2>/dev/null; then
            debug "Manifest displayed successfully"
        else
            error "No manifest found in backup"
            debug "No manifest file found, showing contents instead"
            log "Backup contents:"
            sudo tar -tzf "$backup_file" | head -50
        fi
    else
        debug "Dockge backup detected, showing file listing"
        log "Backup contents:"
        sudo tar -tzf "$backup_file" | head -50
        echo "..."
        local file_count=$(sudo tar -tzf "$backup_file" | wc -l)
        log "Total files: $file_count"
        debug "Total files in backup: $file_count"
    fi
    
    debug "show_backup_manifest completed"
}
