#!/bin/bash
# Systemd Service Management Module

create_systemd_service() {
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    [ ! -f "$script_path" ] && script_path="$SCRIPT_DIR/server_helper_setup.sh"
    
    [ ! -x "$script_path" ] && sudo chmod +x "$script_path"
    
    log "Creating systemd service..."
    sudo bash -c "cat > /etc/systemd/system/server-helper.service << EOF
[Unit]
Description=Server Helper Monitoring Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$(dirname "$script_path")
ExecStart=/bin/bash $script_path monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=\"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"

[Install]
WantedBy=multi-user.target
EOF"
    
    sudo systemctl daemon-reload
    sudo systemctl enable server-helper
    log "✓ Service created and enabled"
}

remove_systemd_service() {
    log "Removing systemd service..."
    sudo systemctl stop server-helper 2>/dev/null || true
    sudo systemctl disable server-helper 2>/dev/null || true
    sudo rm /etc/systemd/system/server-helper.service 2>/dev/null || true
    sudo systemctl daemon-reload
    log "✓ Service removed"
}

show_service_status() {
    systemctl list-unit-files | grep -q server-helper && {
        sudo systemctl status server-helper --no-pager
        echo ""
        log "Recent logs:"
        sudo journalctl -u server-helper -n 20 --no-pager
    } || warning "Service not installed"
}

start_service_now() {
    systemctl list-unit-files | grep -q server-helper || { error "Service not installed"; return 1; }
    sudo systemctl start server-helper
    sleep 2
    sudo systemctl status server-helper --no-pager
}

stop_service() {
    sudo systemctl stop server-helper
    sudo systemctl status server-helper --no-pager
}

restart_service() {
    stop_service
    sleep 2
    start_service_now
}

show_logs() {
    log "Showing live logs (Ctrl+C to exit)..."
    sudo journalctl -u server-helper -f
}

# Monitoring service
monitor_services() {
    log "Starting monitoring (2-min intervals)..."
    
    backup_dockge
    
    local BACKUP_INT=180
    local UPDATE_INT=$((UPDATE_CHECK_INTERVAL * 30))
    local SEC_INT=$((SECURITY_CHECK_INTERVAL * 30))
    local bc=0 uc=0 sc=0
    
    while true; do
        sleep 120
        ((bc++)); ((uc++)); ((sc++))
        
        local disk=$(check_disk_usage)
        [ "$disk" -ge "$DISK_CLEANUP_THRESHOLD" ] && [ "$AUTO_CLEANUP_ENABLED" = "true" ] && clean_disk
        
        [ $uc -ge $UPDATE_INT ] && [ "$AUTO_UPDATE_ENABLED" = "true" ] && {
            check_updates && {
                update_system
                [ $? -eq 2 ] && [ "$AUTO_REBOOT_ENABLED" = "true" ] && schedule_reboot "$REBOOT_TIME"
            }
            uc=0
        }
        
        [ $sc -ge $SEC_INT ] && [ "$SECURITY_CHECK_ENABLED" = "true" ] && { security_audit; sc=0; }
        
        check_nas_heartbeat || { error "NAS failed"; mount_nas || true; }
        check_dockge_heartbeat || { error "Dockge failed"; cd "$DOCKGE_DATA_DIR"; sudo docker compose restart; }
        
        [ $bc -ge $BACKUP_INT ] && { backup_dockge; bc=0; }
        
        log "✓ Heartbeat | Disk:${disk}% | Backup:$((BACKUP_INT-bc)) | Updates:$((UPDATE_INT-uc)) | Security:$((SEC_INT-sc))"
    done
}
