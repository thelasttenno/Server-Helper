#!/bin/bash
# Uninstall Module - Enhanced with Debug

uninstall_server_helper() {
    debug "uninstall_server_helper called"
    
    warning "╔════════════════════════════════════╗"
    warning "║  This will remove Server Helper    ║"
    warning "╚════════════════════════════════════╝"
    
    if ! confirm "Continue with uninstall?"; then
        debug "User cancelled uninstall"
        return 0
    fi
    
    debug "Checking for systemd service"
    if systemctl list-unit-files | grep -q server-helper; then
        debug "Service found"
        if confirm "Remove systemd service?"; then
            debug "User confirmed service removal"
            remove_systemd_service
        else
            debug "User declined service removal"
        fi
    else
        debug "Service not found"
    fi
    
    debug "Checking for NAS shares to unmount"
    if confirm "Unmount NAS shares?"; then
        debug "User confirmed NAS unmount"
        
        # Ensure NAS_ARRAY exists and is an array
        if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            debug "Unmounting ${#NAS_ARRAY[@]} NAS share(s)"
            for cfg in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r _ _ mount _ _ <<< "$cfg"
                debug "Checking mount: $mount"
                if mountpoint -q "$mount"; then
                    debug "Unmounting: $mount"
                    sudo umount "$mount"
                else
                    debug "Not mounted: $mount"
                fi
            done
        else
            debug "Unmounting single NAS share: $NAS_MOUNT_POINT"
            sudo umount "$NAS_MOUNT_POINT" 2>/dev/null || true
        fi
        
        debug "Creating backup of /etc/fstab"
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
        debug "Removed CIFS entries from fstab"
    else
        debug "User declined NAS unmount"
    fi
    
    debug "Checking for Dockge directory: $DOCKGE_DATA_DIR"
    if [ -d "$DOCKGE_DATA_DIR" ]; then
        debug "Dockge directory found"
        if confirm "Remove Dockge?"; then
            debug "User confirmed Dockge removal"
            cd "$DOCKGE_DATA_DIR"
            
            debug "Stopping Dockge containers"
            sudo docker compose down 2>/dev/null || true
            
            if confirm "Delete Dockge data?"; then
                debug "User confirmed data deletion"
                
                if confirm "Create final backup?"; then
                    debug "User requested final backup"
                    local final_backup="/root/dockge_final_$(timestamp).tar.gz"
                    debug "Creating final backup: $final_backup"
                    sudo tar -czf "$final_backup" "$DOCKGE_DATA_DIR"
                    log "Final backup created: $final_backup"
                else
                    debug "User declined final backup"
                fi
                
                debug "Removing Dockge directory: $DOCKGE_DATA_DIR"
                sudo rm -rf "$DOCKGE_DATA_DIR"
            else
                debug "User declined data deletion"
            fi
        else
            debug "User declined Dockge removal"
        fi
    else
        debug "Dockge directory not found"
    fi
    
    debug "Checking for Docker"
    if command_exists docker; then
        debug "Docker found"
        if confirm "Remove Docker?"; then
            debug "User confirmed Docker removal"
            
            read -p "Type 'yes' to confirm Docker removal: " docker_confirm
            debug "User entered: $docker_confirm"
            
            if [ "$docker_confirm" = "yes" ]; then
                debug "Stopping Docker service"
                sudo systemctl stop docker
                
                debug "Purging Docker packages"
                sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                
                if confirm "Remove Docker data?"; then
                    debug "User confirmed Docker data removal"
                    debug "Removing /var/lib/docker and /var/lib/containerd"
                    sudo rm -rf /var/lib/docker /var/lib/containerd
                else
                    debug "User declined Docker data removal"
                fi
            else
                debug "User did not confirm Docker removal"
            fi
        else
            debug "User declined Docker removal"
        fi
    else
        debug "Docker not installed"
    fi
    
    debug "Checking for config file: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        debug "Config file found"
        if confirm "Remove config?"; then
            debug "User confirmed config removal"
            sudo rm "$CONFIG_FILE"
        else
            debug "User declined config removal"
        fi
    else
        debug "Config file not found"
    fi
    
    debug "Removing NAS credential files"
    sudo rm -f /root/.nascreds* 2>/dev/null
    
    debug "Checking backup directory: $BACKUP_DIR"
    if [ -d "$BACKUP_DIR" ]; then
        debug "Backup directory found"
        if confirm "Remove backups?"; then
            debug "User confirmed backup removal"
            read -p "Type 'DELETE' to confirm: " conf
            debug "User entered: $conf"
            
            if [ "$conf" = "DELETE" ]; then
                debug "Removing backup directory: $BACKUP_DIR"
                sudo rm -rf "$BACKUP_DIR"
            else
                debug "User did not confirm backup deletion"
            fi
        else
            debug "User declined backup removal"
        fi
    else
        debug "Backup directory not found"
    fi
    
    debug "Checking for Server Helper script"
    if confirm "Remove Server Helper script?"; then
        debug "User confirmed script removal"
        local dir="$(dirname "$SCRIPT_DIR/server_helper_setup.sh")"
        debug "Script directory: $dir"
        
        if confirm "Remove entire directory $dir?"; then
            debug "User confirmed directory removal"
            cd /tmp
            sudo rm -rf "$dir"
        else
            debug "User declined directory removal, removing only script"
            sudo rm -f "$SCRIPT_DIR/server_helper_setup.sh"
        fi
    else
        debug "User declined script removal"
    fi
    
    log "═══════════════════════════════════════"
    log "      Uninstallation Complete"
    log "═══════════════════════════════════════"
    debug "uninstall_server_helper completed"
}
