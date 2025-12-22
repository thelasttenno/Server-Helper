#!/bin/bash
# Uninstall Module

uninstall_server_helper() {
    warning "╔════════════════════════════════════╗"
    warning "║  This will remove Server Helper    ║"
    warning "╚════════════════════════════════════╝"
    
    confirm "Continue with uninstall?" || return 0
    
    # 1. Stop systemd service first
    systemctl list-unit-files | grep -q server-helper && {
        confirm "Remove systemd service?" && remove_systemd_service
    }
    
    # 2. REMOVE BACKUPS BEFORE UNMOUNTING NAS (CRITICAL!)
    # Set default if not set, and handle both NAS and local backup locations
    local backup_dir="${BACKUP_DIR}"
    [ -z "$backup_dir" ] && backup_dir="${NAS_MOUNT_POINT}/dockge_backups"
    [ -z "$backup_dir" ] || [ "$backup_dir" = "/dockge_backups" ] && backup_dir="/opt/dockge_backups_local"
    
    if [ -d "$backup_dir" ]; then
        log "Found backup directory: $backup_dir"
        confirm "Remove backups in $backup_dir?" && {
            read -p "Type 'DELETE' to confirm: " conf
            if [ "$conf" = "DELETE" ]; then
                sudo rm -rf "$backup_dir"
                log "✓ Backups removed"
            else
                log "Backup removal cancelled"
            fi
        }
    else
        log "No backup directory found at: $backup_dir"
        # Check for alternative backup location
        if [ -d "/opt/dockge_backups_local" ]; then
            log "Found local backup directory: /opt/dockge_backups_local"
            confirm "Remove local backups?" && {
                read -p "Type 'DELETE' to confirm: " conf
                if [ "$conf" = "DELETE" ]; then
                    sudo rm -rf "/opt/dockge_backups_local"
                    log "✓ Local backups removed"
                else
                    log "Backup removal cancelled"
                fi
            }
        fi
    fi
    
    # 3. NOW unmount NAS (after backups are removed)
    confirm "Unmount NAS shares?" && {
        # Ensure NAS_ARRAY exists and is an array
        if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for cfg in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r _ _ mount _ _ <<< "$cfg"
                mountpoint -q "$mount" && sudo umount "$mount"
            done
        else
            mountpoint -q "$NAS_MOUNT_POINT" && sudo umount "$NAS_MOUNT_POINT" 2>/dev/null || true
        fi
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
    }
    
    # 4. Remove Dockge
    [ -d "$DOCKGE_DATA_DIR" ] && confirm "Remove Dockge?" && {
        cd "$DOCKGE_DATA_DIR"
        sudo docker compose down 2>/dev/null || true
        confirm "Delete Dockge data?" && {
            confirm "Create final backup?" && sudo tar -czf "/root/dockge_final_$(timestamp).tar.gz" "$DOCKGE_DATA_DIR"
            sudo rm -rf "$DOCKGE_DATA_DIR"
        }
    }
    
    # 5. Remove Docker
    command_exists docker && confirm "Remove Docker?" && {
        confirm "Type 'yes' to confirm Docker removal: " && [ "$REPLY" = "yes" ] && {
            sudo systemctl stop docker
            sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            confirm "Remove Docker data?" && sudo rm -rf /var/lib/docker /var/lib/containerd
        }
    }
    
    # 6. Remove config file
    [ -f "$CONFIG_FILE" ] && confirm "Remove config?" && sudo rm "$CONFIG_FILE"
    
    # 7. Remove NAS credentials
    sudo rm -f /root/.nascreds* 2>/dev/null
    
    # 8. Remove script itself
    confirm "Remove Server Helper script?" && {
        local dir="$(dirname "$SCRIPT_DIR/server_helper_setup.sh")"
        confirm "Remove entire directory $dir?" && { cd /tmp; sudo rm -rf "$dir"; } || sudo rm -f "$SCRIPT_DIR/server_helper_setup.sh"
    }
    
    log "═══════════════════════════════════════"
    log "      Uninstallation Complete"
    log "═══════════════════════════════════════"
}
