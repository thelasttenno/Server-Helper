#!/bin/bash
# Uninstall Module

uninstall_server_helper() {
    warning "╔════════════════════════════════════╗"
    warning "║  This will remove Server Helper    ║"
    warning "╚════════════════════════════════════╝"
    
    confirm "Continue with uninstall?" || return 0
    
    systemctl list-unit-files | grep -q server-helper && {
        confirm "Remove systemd service?" && remove_systemd_service
    }
    
    confirm "Unmount NAS shares?" && {
        if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for cfg in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r _ _ mount _ _ <<< "$cfg"
                mountpoint -q "$mount" && sudo umount "$mount"
            done
        else
            sudo umount "$NAS_MOUNT_POINT" 2>/dev/null || true
        fi
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
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
    
    [ -d "$BACKUP_DIR" ] && confirm "Remove backups?" && {
        read -p "Type 'DELETE' to confirm: " conf
        [ "$conf" = "DELETE" ] && sudo rm -rf "$BACKUP_DIR"
    }
    
    confirm "Remove Server Helper script?" && {
        local dir="$(dirname "$SCRIPT_DIR/server_helper_setup.sh")"
        confirm "Remove entire directory $dir?" && { cd /tmp; sudo rm -rf "$dir"; } || sudo rm -f "$SCRIPT_DIR/server_helper_setup.sh"
    }
    
    log "═══════════════════════════════════════"
    log "      Uninstallation Complete"
    log "═══════════════════════════════════════"
}
