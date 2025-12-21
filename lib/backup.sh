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
    
    sudo tar -czf "$backup_file" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || { error "Backup failed"; return 1; }
    
    log "✓ Backup created: $backup_file ($(get_file_size "$backup_file"))"
    
    find "$backup_dir" -name "dockge_backup_*.tar.gz" -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
    log "Backups retained: $(find "$backup_dir" -name "dockge_backup_*.tar.gz" 2>/dev/null | wc -l)"
}

restore_dockge() {
    log "Available backups:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || { error "No backups found"; return 1; }
    
    read -p "Enter filename or 'latest': " file
    [ "$file" = "latest" ] && file=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
    [ -z "$file" ] || [ ! -f "$BACKUP_DIR/$file" ] && { error "File not found"; return 1; }
    
    confirm "Restore from backup? This will overwrite current data" || return 1
    
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    sudo tar -czf "emergency_backup_$(timestamp).tar.gz" stacks data 2>/dev/null
    sudo rm -rf stacks data
    sudo tar -xzf "$BACKUP_DIR/$file" -C "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    
    log "✓ Restore complete"
}

list_backups() {
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups found"
}
