#!/bin/bash
# Uninstall Module

uninstall_server_helper() {
    debug "[uninstall_server_helper] Starting uninstallation process"
    warning "╔════════════════════════════════════╗"
    warning "║  This will remove Server Helper    ║"
    warning "╚════════════════════════════════════╝"
    
    confirm "Continue with uninstall?" || return 0
    
    if systemctl list-unit-files | grep -q server-helper; then
        if confirm "Remove systemd service?"; then
            debug "[uninstall_server_helper] Removing systemd service"
            remove_systemd_service
        fi
    fi
    
    if confirm "Unmount NAS shares?"; then
        debug "[uninstall_server_helper] Unmounting NAS shares"
        # Ensure NAS_ARRAY exists and is an array
        if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for cfg in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r _ _ mount _ _ <<< "$cfg"
                if mountpoint -q "$mount"; then
                    debug "[uninstall_server_helper] Unmounting: $mount"
                    sudo umount "$mount"
                fi
            done
        else
            sudo umount "$NAS_MOUNT_POINT" 2>/dev/null || true
        fi
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab
    fi
    
    if [ -d "$DOCKGE_DATA_DIR" ] && confirm "Remove Dockge?"; then
        debug "[uninstall_server_helper] Removing Dockge"
        cd "$DOCKGE_DATA_DIR"
        sudo docker compose down 2>/dev/null || true
        
        if confirm "Delete Dockge data?"; then
            if confirm "Create final backup?"; then
                debug "[uninstall_server_helper] Creating final backup"
                sudo tar -czf "/root/dockge_final_$(timestamp).tar.gz" "$DOCKGE_DATA_DIR"
            fi
            debug "[uninstall_server_helper] Deleting Dockge data"
            sudo rm -rf "$DOCKGE_DATA_DIR"
        fi
    fi
    
    if command_exists docker && confirm "Remove Docker?"; then
        if confirm "Type 'yes' to confirm Docker removal: " && [ "$REPLY" = "yes" ]; then
            debug "[uninstall_server_helper] Removing Docker"
            sudo systemctl stop docker
            sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            
            if confirm "Remove Docker data?"; then
                debug "[uninstall_server_helper] Removing Docker data"
                sudo rm -rf /var/lib/docker /var/lib/containerd
            fi
        fi
    fi
    
    if [ -f "$CONFIG_FILE" ] && confirm "Remove config?"; then
        debug "[uninstall_server_helper] Removing config file"
        sudo rm "$CONFIG_FILE"
    fi
    
    debug "[uninstall_server_helper] Removing NAS credentials"
    sudo rm -f /root/.nascreds* 2>/dev/null
    
    if [ -d "$BACKUP_DIR" ] && confirm "Remove backups?"; then
        read -p "Type 'DELETE' to confirm: " conf
        if [ "$conf" = "DELETE" ]; then
            debug "[uninstall_server_helper] Removing backups"
            sudo rm -rf "$BACKUP_DIR"
        fi
    fi
    
    if confirm "Remove Server Helper script?"; then
        local dir="$(dirname "$SCRIPT_DIR/server_helper_setup.sh")"
        if confirm "Remove entire directory $dir?"; then
            debug "[uninstall_server_helper] Removing entire directory"
            cd /tmp
            sudo rm -rf "$dir"
        else
            debug "[uninstall_server_helper] Removing script only"
            sudo rm -f "$SCRIPT_DIR/server_helper_setup.sh"
        fi
    fi
    
    log "═══════════════════════════════════════"
    log "      Uninstallation Complete"
    log "═══════════════════════════════════════"
    debug "[uninstall_server_helper] Uninstallation process complete"
}
