#!/bin/bash
# Backup & Restore Module - Enhanced with Config File Backup

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
    log "Backing up configuration files..."
    
    local backup_dir="$BACKUP_DIR"
    local config_backup_dir="$backup_dir/config"
    
    # Use local backup if NAS unavailable
    [ ! -d "$backup_dir" ] && {
        mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null || backup_dir="/opt/dockge_backups_local"
        config_backup_dir="$backup_dir/config"
        warning "Using local backup: $backup_dir"
    }
    
    mkdir -p "$config_backup_dir"
    
    local ts=$(timestamp)
    local config_backup_file="$config_backup_dir/config_backup_$ts.tar.gz"
    local temp_dir="/tmp/server-helper-config-backup-$$"
    
    # Create temporary directory structure
    mkdir -p "$temp_dir"
    
    local file_count=0
    
    # Backup individual config files
    for file in "${CONFIG_FILES[@]}"; do
        if [ -f "$file" ]; then
            local dest_dir="$temp_dir$(dirname "$file")"
            mkdir -p "$dest_dir"
            sudo cp "$file" "$dest_dir/" 2>/dev/null && {
                debug "Backed up: $file"
                ((file_count++))
            }
        fi
    done
    
    # Backup config directories
    for dir in "${CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local dest_dir="$temp_dir$(dirname "$dir")"
            mkdir -p "$dest_dir"
            sudo cp -r "$dir" "$dest_dir/" 2>/dev/null && {
                debug "Backed up directory: $dir"
                ((file_count++))
            }
        fi
    done
    
    # Backup NAS credentials
    sudo find /root -name ".nascreds_*" -type f 2>/dev/null | while read cred_file; do
        local dest_dir="$temp_dir/root"
        mkdir -p "$dest_dir"
        sudo cp "$cred_file" "$dest_dir/" 2>/dev/null && {
            debug "Backed up: $cred_file"
            ((file_count++))
        }
    done
    
    # Create backup manifest
    cat > "$temp_dir/backup_manifest.txt" << EOF
Server Helper Configuration Backup
Created: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Files backed up: $file_count

Files included:
EOF
    
    find "$temp_dir" -type f ! -name "backup_manifest.txt" | sed "s|$temp_dir||" >> "$temp_dir/backup_manifest.txt"
    
    # Create tarball
    sudo tar -czf "$config_backup_file" -C "$temp_dir" . 2>/dev/null || {
        error "Config backup failed"
        rm -rf "$temp_dir"
        return 1
    }
    
    # Cleanup temp directory
    rm -rf "$temp_dir"
    
    log "✓ Config backup created: $config_backup_file ($(get_file_size "$config_backup_file"), $file_count items)"
    
    # Clean old config backups
    find "$config_backup_dir" -name "config_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local config_count=$(find "$config_backup_dir" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Config backups retained: $config_count"
    
    return 0
}

backup_dockge() {
    log "Starting backup..."
    
    local backup_dir="$BACKUP_DIR"
    [ ! -d "$backup_dir" ] && {
        mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null || backup_dir="/opt/dockge_backups_local"
        warning "Using local backup: $backup_dir"
    }
    
    mkdir -p "$backup_dir"
    
    local ts=$(timestamp)
    local backup_file="$backup_dir/dockge_backup_$ts.tar.gz"
    
    # Backup Dockge data
    sudo tar -czf "$backup_file" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || { 
        error "Dockge backup failed"
        return 1
    }
    
    log "✓ Dockge backup created: $backup_file ($(get_file_size "$backup_file"))"
    
    # Automatically backup configuration files
    backup_config_files
    
    # Clean old Dockge backups
    find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    local dockge_count=$(find "$backup_dir" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    log "Dockge backups retained: $dockge_count"
}

restore_config_files() {
    log "Available config backups:"
    local config_backup_dir="$BACKUP_DIR/config"
    
    ls -lh "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null || { 
        error "No config backups found"
        return 1
    }
    
    read -p "Enter filename or 'latest': " file
    [ "$file" = "latest" ] && file=$(ls -t "$config_backup_dir"/config_backup_*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$file" ]; then
        file="$config_backup_dir/$file"
    elif [ ! -f "$file" ]; then
        [ -f "$config_backup_dir/$file" ] && file="$config_backup_dir/$file" || {
            error "File not found"
            return 1
        }
    fi
    
    [ ! -f "$file" ] && { error "File not found: $file"; return 1; }
    
    # Show manifest
    log "Backup contents:"
    sudo tar -tzf "$file" backup_manifest.txt 2>/dev/null && sudo tar -xzOf "$file" backup_manifest.txt || true
    echo ""
    
    confirm "Restore from this config backup? This will overwrite current configuration files" || return 1
    
    # Create emergency backup
    local emergency_backup="/root/emergency_config_backup_$(timestamp).tar.gz"
    log "Creating emergency backup..."
    
    local temp_dir="/tmp/server-helper-emergency-$$"
    mkdir -p "$temp_dir"
    
    for cfg_file in "${CONFIG_FILES[@]}"; do
        [ -f "$cfg_file" ] && {
            local dest_dir="$temp_dir$(dirname "$cfg_file")"
            mkdir -p "$dest_dir"
            sudo cp "$cfg_file" "$dest_dir/" 2>/dev/null
        }
    done
    
    sudo tar -czf "$emergency_backup" -C "$temp_dir" . 2>/dev/null
    rm -rf "$temp_dir"
    log "Emergency backup created: $emergency_backup"
    
    # Restore configuration files
    log "Restoring configuration files..."
    sudo tar -xzf "$file" -C / 2>/dev/null || {
        error "Restore failed"
        return 1
    }
    
    log "✓ Configuration restore complete"
    warning "Please review restored files and reboot if necessary"
    
    # Show what was restored
    log "Restored files:"
    sudo tar -tzf "$file" | grep -v "/$" | head -20
    
    return 0
}

restore_dockge() {
    log "Available Dockge backups:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || { 
        error "No Dockge backups found"
        return 1
    }
    
    read -p "Enter filename or 'latest': " file
    [ "$file" = "latest" ] && file=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
    [ -z "$file" ] || [ ! -f "$BACKUP_DIR/$file" ] && { 
        error "File not found"
        return 1
    }
    
    confirm "Restore from backup? This will overwrite current Dockge data" || return 1
    
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Create emergency backup
    sudo tar -czf "emergency_dockge_backup_$(timestamp).tar.gz" stacks data 2>/dev/null
    
    # Restore
    sudo rm -rf stacks data
    sudo tar -xzf "$BACKUP_DIR/$file" -C "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    
    log "✓ Dockge restore complete"
}

list_backups() {
    log "=== Dockge Backups ==="
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No Dockge backups found"
    
    echo ""
    log "=== Configuration Backups ==="
    ls -lh "$BACKUP_DIR/config"/config_backup_*.tar.gz 2>/dev/null || echo "No config backups found"
    
    echo ""
    log "=== Backup Statistics ==="
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    local dockge_count=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)
    local config_count=$(find "$BACKUP_DIR/config" -name "config_backup_*.tar.gz" 2>/dev/null | wc -l)
    
    echo "Total backup size: ${total_size:-0}"
    echo "Dockge backups: $dockge_count"
    echo "Config backups: $config_count"
    echo "Retention period: $BACKUP_RETENTION_DAYS days"
}

# Backup both Dockge and config files
backup_all() {
    log "Starting complete backup (Dockge + Config)..."
    backup_dockge
    # config is already called within backup_dockge
    log "✓ Complete backup finished"
}

# Export manifest from a backup
show_backup_manifest() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        read -p "Enter backup file path: " backup_file
    fi
    
    [ ! -f "$backup_file" ] && { error "File not found: $backup_file"; return 1; }
    
    log "Backup manifest for: $(basename "$backup_file")"
    echo "================================"
    
    if [[ "$backup_file" == *"config_backup"* ]]; then
        sudo tar -xzOf "$backup_file" backup_manifest.txt 2>/dev/null || {
            error "No manifest found in backup"
            log "Backup contents:"
            sudo tar -tzf "$backup_file" | head -50
        }
    else
        log "Backup contents:"
        sudo tar -tzf "$backup_file" | head -50
        echo "..."
        log "Total files: $(sudo tar -tzf "$backup_file" | wc -l)"
    fi
}
