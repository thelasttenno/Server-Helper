#!/bin/bash
# Systemd Service Management Module

create_systemd_service() {
    debug "[create_systemd_service] Creating systemd service"
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    [ ! -f "$script_path" ] && script_path="$SCRIPT_DIR/server_helper_setup.sh"
    
    debug "[create_systemd_service] Script path: $script_path"
    [ ! -x "$script_path" ] && sudo chmod +x "$script_path"
    
    log "Creating systemd service..."
    debug "[create_systemd_service] Writing service file"
    sudo bash -c "cat > /etc/systemd/system/server-helper.service << EOF
[Unit]
Description=Server Helper Monitoring Service v0.2.2
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
    
    debug "[create_systemd_service] Reloading systemd daemon"
    sudo systemctl daemon-reload
    sudo systemctl enable server-helper
    log "✓ Service created and enabled"
    debug "[create_systemd_service] Service creation complete"
}

remove_systemd_service() {
    debug "[remove_systemd_service] Removing systemd service"
    log "Removing systemd service..."
    
    debug "[remove_systemd_service] Stopping service"
    sudo systemctl stop server-helper 2>/dev/null || true
    
    debug "[remove_systemd_service] Disabling service"
    sudo systemctl disable server-helper 2>/dev/null || true
    
    debug "[remove_systemd_service] Removing service file"
    sudo rm /etc/systemd/system/server-helper.service 2>/dev/null || true
    
    debug "[remove_systemd_service] Reloading systemd daemon"
    sudo systemctl daemon-reload
    log "✓ Service removed"
    debug "[remove_systemd_service] Service removal complete"
}

show_service_status() {
    debug "[show_service_status] Displaying service status"
    if systemctl list-unit-files | grep -q server-helper; then
        sudo systemctl status server-helper --no-pager
        echo ""
        log "Recent logs:"
        sudo journalctl -u server-helper -n 20 --no-pager
    else
        warning "Service not installed"
    fi
}

start_service_now() {
    debug "[start_service_now] Starting service"
    if ! systemctl list-unit-files | grep -q server-helper; then
        error "Service not installed"
        return 1
    fi
    
    sudo systemctl start server-helper
    sleep 2
    sudo systemctl status server-helper --no-pager
    debug "[start_service_now] Service started"
}

stop_service() {
    debug "[stop_service] Stopping service"
    sudo systemctl stop server-helper
    sudo systemctl status server-helper --no-pager
    debug "[stop_service] Service stopped"
}

restart_service() {
    debug "[restart_service] Restarting service"
    stop_service
    sleep 2
    start_service_now
    debug "[restart_service] Service restarted"
}

show_logs() {
    debug "[show_logs] Showing live logs"
    log "Showing live logs (Ctrl+C to exit)..."
    sudo journalctl -u server-helper -f
}

# Monitoring service
monitor_services() {
    debug "[monitor_services] Starting monitoring service"
    log "Starting monitoring (2-min intervals)..."
    
    backup_dockge
    
    local BACKUP_INT=180
    local UPDATE_INT=$((UPDATE_CHECK_INTERVAL * 30))
    local SEC_INT=$((SECURITY_CHECK_INTERVAL * 30))
    local bc=0 uc=0 sc=0
    
    debug "[monitor_services] Backup interval: $BACKUP_INT cycles"
    debug "[monitor_services] Update interval: $UPDATE_INT cycles"
    debug "[monitor_services] Security interval: $SEC_INT cycles"
    
    while true; do
        sleep 120
        ((bc++)); ((uc++)); ((sc++))
        debug "[monitor_services] Cycle: Backup=$bc, Update=$uc, Security=$sc"
        
        local disk=$(check_disk_usage)
        debug "[monitor_services] Disk usage: $disk%"
        
        if [ "$disk" -ge "$DISK_CLEANUP_THRESHOLD" ] && [ "$AUTO_CLEANUP_ENABLED" = "true" ]; then
            debug "[monitor_services] Disk threshold exceeded, running cleanup"
            clean_disk
        fi
        
        if [ $uc -ge $UPDATE_INT ] && [ "$AUTO_UPDATE_ENABLED" = "true" ]; then
            debug "[monitor_services] Running update check"
            if check_updates; then
                update_system
                if [ $? -eq 2 ] && [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
                    debug "[monitor_services] Scheduling reboot"
                    schedule_reboot "$REBOOT_TIME"
                fi
            fi
            uc=0
        fi
        
        if [ $sc -ge $SEC_INT ] && [ "$SECURITY_CHECK_ENABLED" = "true" ]; then
            debug "[monitor_services] Running security audit"
            security_audit
            sc=0
        fi
        
        if ! check_nas_heartbeat; then
            error "NAS failed"
            debug "[monitor_services] Attempting NAS remount"
            mount_nas || true
        fi
        
        if ! check_dockge_heartbeat; then
            error "Dockge failed"
            debug "[monitor_services] Restarting Dockge"
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
        fi
        
        if [ $bc -ge $BACKUP_INT ]; then
            debug "[monitor_services] Running backup"
            backup_dockge
            bc=0
        fi
        
        log "✓ Heartbeat | Disk:${disk}% | Backup:$((BACKUP_INT-bc)) | Updates:$((UPDATE_INT-uc)) | Security:$((SEC_INT-sc))"
    done
}
