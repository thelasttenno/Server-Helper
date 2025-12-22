#!/bin/bash
# Backup & Restore Module

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
    
    # Create temporary directory for backup staging
    local temp_backup="/tmp/backup_staging_$$"
    mkdir -p "$temp_backup"
    
    # Backup Dockge data and stacks
    log "Backing up Dockge directories..."
    if [ -d "$DOCKGE_DATA_DIR/stacks" ]; then
        sudo cp -a "$DOCKGE_DATA_DIR/stacks" "$temp_backup/" 2>/dev/null || true
        log "  ✓ $DOCKGE_DATA_DIR/stacks"
    fi
    if [ -d "$DOCKGE_DATA_DIR/data" ]; then
        sudo cp -a "$DOCKGE_DATA_DIR/data" "$temp_backup/" 2>/dev/null || true
        log "  ✓ $DOCKGE_DATA_DIR/data"
    fi
    
    # Backup additional directories if configured
    if [ -n "${BACKUP_DIRS_ARRAY+x}" ] && [ ${#BACKUP_DIRS_ARRAY[@]} -gt 0 ]; then
        log "Backing up additional directories..."
        for dir in "${BACKUP_DIRS_ARRAY[@]}"; do
            if [ -d "$dir" ]; then
                # Create safe directory name by replacing / with _
                local safe_name="additional_$(echo "$dir" | sed 's|^/||' | tr '/' '_')"
                sudo cp -a "$dir" "$temp_backup/$safe_name" 2>/dev/null || true
                log "  ✓ $dir -> $safe_name"
            else
                warning "  ✗ $dir (not found, skipping)"
            fi
        done
    fi
    
    # Create archive from staging directory
    log "Creating archive..."
    sudo tar -czf "$backup_file" -C "$temp_backup" . 2>/dev/null || { 
        sudo rm -rf "$temp_backup"
        error "Backup failed"
        return 1
    }
    
    # Cleanup staging directory
    sudo rm -rf "$temp_backup"
    
    log "✓ Backup created: $backup_file ($(get_file_size "$backup_file"))"
    
    # Clean old backups
    local old_count=$(find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS 2>/dev/null | wc -l)
    if [ "$old_count" -gt 0 ]; then
        find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
        log "Cleaned $old_count old backup(s)"
    fi
    
    log "Backups retained: $(find "$backup_dir" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)"
}

restore_dockge() {
    log "Available backups:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || { error "No backups found"; return 1; }
    
    echo ""
    read -p "Enter filename or 'latest': " file
    [ "$file" = "latest" ] && file=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
    
    # Handle both full path and just filename
    if [ ! -f "$file" ]; then
        file="$BACKUP_DIR/$file"
    fi
    
    [ -z "$file" ] || [ ! -f "$file" ] && { error "File not found: $file"; return 1; }
    
    log "Selected backup: $file"
    
    # Show what's in the backup
    log "Backup contents:"
    sudo tar -tzf "$file" | grep -E '^[^/]+/$' | sed 's|/$||' | while read item; do
        echo "  - $item"
    done
    
    echo ""
    confirm "Restore from this backup? This will overwrite current data" || return 1
    
    # Create emergency backup
    log "Creating emergency backup..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down 2>/dev/null || true
    local emergency_file="emergency_backup_$(timestamp).tar.gz"
    sudo tar -czf "$emergency_file" stacks data 2>/dev/null || true
    [ -f "$emergency_file" ] && log "Emergency backup: $DOCKGE_DATA_DIR/$emergency_file"
    
    # Extract to temporary location first
    local temp_restore="/tmp/restore_staging_$$"
    mkdir -p "$temp_restore"
    
    log "Extracting backup..."
    sudo tar -xzf "$file" -C "$temp_restore"
    
    # Restore Dockge directories
    log "Restoring Dockge directories..."
    if [ -d "$temp_restore/stacks" ]; then
        sudo rm -rf "$DOCKGE_DATA_DIR/stacks"
        sudo mv "$temp_restore/stacks" "$DOCKGE_DATA_DIR/"
        log "  ✓ Restored: $DOCKGE_DATA_DIR/stacks"
    fi
    
    if [ -d "$temp_restore/data" ]; then
        sudo rm -rf "$DOCKGE_DATA_DIR/data"
        sudo mv "$temp_restore/data" "$DOCKGE_DATA_DIR/"
        log "  ✓ Restored: $DOCKGE_DATA_DIR/data"
    fi
    
    # Restore additional directories if they were in backup
    log "Checking for additional directories in backup..."
    for item in "$temp_restore"/additional_*; do
        [ -d "$item" ] || continue
        
        local base_name=$(basename "$item")
        # Convert safe name back to original path
        local original_path="/$(echo "$base_name" | sed 's/^additional_//' | tr '_' '/')"
        
        echo ""
        log "Found: $base_name -> $original_path"
        confirm "Restore $original_path?" && {
            sudo rm -rf "$original_path"
            sudo mkdir -p "$(dirname "$original_path")"
            sudo mv "$item" "$original_path"
            log "  ✓ Restored: $original_path"
        }
    done
    
    # Cleanup
    sudo rm -rf "$temp_restore"
    
    # Restart Dockge
    log "Restarting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    
    log "✓ Restore complete"
}

list_backups() {
    local backup_dir="$BACKUP_DIR"
    [ ! -d "$backup_dir" ] && backup_dir="/opt/dockge_backups_local"
    
    log "Backups in: $backup_dir"
    
    if ls "$backup_dir"/dockge_backup_*.tar.gz 1> /dev/null 2>&1; then
        echo ""
        ls -lh "$backup_dir"/dockge_backup_*.tar.gz 2>/dev/null
        echo ""
        
        # Show what's in the latest backup
        local latest=$(ls -t "$backup_dir"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            log "Latest backup contents:"
            sudo tar -tzf "$latest" | grep -E '^[^/]+/$' | sed 's|/$||' | while read item; do
                echo "  - $item"
            done
        fi
    else
        echo "No backups found"
    fi
}
