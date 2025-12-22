#!/bin/bash
# Uninstall Module - Fixed NAS Unmount

uninstall_server_helper() {
    warning "╔════════════════════════════════════╗"
    warning "║  This will remove Server Helper    ║"
    warning "╚════════════════════════════════════╝"
    
    confirm "Continue with uninstall?" || return 0
    
    systemctl list-unit-files | grep -q server-helper && {
        confirm "Remove systemd service?" && remove_systemd_service
    }

    [ -d "$BACKUP_DIR" ] && confirm "Remove backups?" && {
        read -p "Type 'DELETE' to confirm: " conf
        [ "$conf" = "DELETE" ] && sudo rm -rf "$BACKUP_DIR"
    }
    
    confirm "Unmount NAS shares?" && {
        # Change to safe directory to avoid "device is busy" errors
        cd /tmp
        
        # Ensure NAS_ARRAY exists and is an array
        if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for cfg in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r _ _ mount _ _ <<< "$cfg"
                if mountpoint -q "$mount" 2>/dev/null; then
                    log "Unmounting: $mount"
                    
                    # Check for processes using the mount
                    if command_exists lsof; then
                        local procs=$(sudo lsof "$mount" 2>/dev/null | tail -n +2)
                        if [ -n "$procs" ]; then
                            warning "Processes using $mount:"
                            echo "$procs"
                            confirm "Kill processes and force unmount?" || continue
                            sudo fuser -km "$mount" 2>/dev/null || true
                            sleep 2  # Give processes time to die
                        fi
                    fi
                    
                    # Try normal unmount first
                    if sudo umount "$mount" 2>/dev/null; then
                        log "✓ Unmounted: $mount"
                    else
                        # Try lazy unmount
                        warning "Normal unmount failed, trying lazy unmount..."
                        if sudo umount -l "$mount" 2>/dev/null; then
                            log "✓ Lazy unmounted: $mount"
                        else
                            # Try force unmount as last resort
                            warning "Lazy unmount failed, trying force unmount..."
                            if sudo umount -f "$mount" 2>/dev/null; then
                                log "✓ Force unmounted: $mount"
                            else
                                error "Failed to unmount: $mount"
                                warning "You may need to reboot to fully unmount"
                            fi
                        fi
                    fi
                fi
            done
        else
            if mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
                log "Unmounting: $NAS_MOUNT_POINT"
                
                # Check for processes using the mount
                if command_exists lsof; then
                    local procs=$(sudo lsof "$NAS_MOUNT_POINT" 2>/dev/null | tail -n +2)
                    if [ -n "$procs" ]; then
                        warning "Processes using $NAS_MOUNT_POINT:"
                        echo "$procs"
                        confirm "Kill processes and force unmount?" || return 0
                        sudo fuser -km "$NAS_MOUNT_POINT" 2>/dev/null || true
                        sleep 2  # Give processes time to die
                    fi
                fi
                
                # Try normal unmount first
                if sudo umount "$NAS_MOUNT_POINT" 2>/dev/null; then
                    log "✓ Unmounted: $NAS_MOUNT_POINT"
                elif sudo umount -l "$NAS_MOUNT_POINT" 2>/dev/null; then
                    log "✓ Lazy unmounted: $NAS_MOUNT_POINT"
                elif sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null; then
                    log "✓ Force unmounted: $NAS_MOUNT_POINT"
                else
                    error "Failed to unmount: $NAS_MOUNT_POINT"
                    warning "You may need to reboot to fully unmount"
                fi
            fi
        fi
        
        # Remove from fstab
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
        log "✓ Removed NAS entries from /etc/fstab"
    }
    
    [ -d "$DOCKGE_DATA_DIR" ] && confirm "Remove Dockge?" && {
        cd "$DOCKGE_DATA_DIR"
        sudo docker compose down 2>/dev/null || true
        confirm "Delete Dockge data?" && {
            confirm "Create final backup?" && sudo tar -czf "/root/dockge_final_$(timestamp).tar.gz" "$DOCKGE_DATA_DIR"
            sudo rm -rf "$DOCKGE_DATA_DIR"
        }
    }
    
    command_exists docker && confirm "Remove Docker?" && {
        confirm "Type 'yes' to confirm Docker removal: " && [ "$REPLY" = "yes" ] && {
            sudo systemctl stop docker
            sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            confirm "Remove Docker data?" && sudo rm -rf /var/lib/docker /var/lib/containerd
        }
    }
    
    [ -f "$CONFIG_FILE" ] && confirm "Remove config?" && sudo rm "$CONFIG_FILE"
    
    sudo rm -f /root/.nascreds* 2>/dev/null
    
    confirm "Remove Server Helper script?" && {
        local dir="$(dirname "$SCRIPT_DIR/server_helper_setup.sh")"
        confirm "Remove entire directory $dir?" && { cd /tmp; sudo rm -rf "$dir"; } || sudo rm -f "$SCRIPT_DIR/server_helper_setup.sh"
    }
    
    log "═══════════════════════════════════════"
    log "      Uninstallation Complete"
    log "═══════════════════════════════════════"
}
