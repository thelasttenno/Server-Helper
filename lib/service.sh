#!/bin/bash
# Systemd Service Management Module - Enhanced with Debug

create_systemd_service() {
    debug "create_systemd_service called"
    
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    debug "Detected script path: $script_path"
    
    if [ ! -f "$script_path" ]; then
        debug "Script path not found, trying: $SCRIPT_DIR/server_helper_setup.sh"
        script_path="$SCRIPT_DIR/server_helper_setup.sh"
    fi
    debug "Final script path: $script_path"
    
    if [ ! -x "$script_path" ]; then
        debug "Script is not executable, making it executable"
        sudo chmod +x "$script_path"
    fi
    
    log "Creating systemd service..."
    debug "Service file: /etc/systemd/system/server-helper.service"
    
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
    debug "Service file created"
    
    debug "Reloading systemd daemon"
    sudo systemctl daemon-reload
    
    debug "Enabling server-helper service"
    sudo systemctl enable server-helper
    
    log "✓ Service created and enabled"
    debug "create_systemd_service completed"
}

remove_systemd_service() {
    debug "remove_systemd_service called"
    log "Removing systemd service..."
    
    debug "Stopping server-helper service"
    sudo systemctl stop server-helper 2>/dev/null || true
    
    debug "Disabling server-helper service"
    sudo systemctl disable server-helper 2>/dev/null || true
    
    debug "Removing service file"
    sudo rm /etc/systemd/system/server-helper.service 2>/dev/null || true
    
    debug "Reloading systemd daemon"
    sudo systemctl daemon-reload
    
    log "✓ Service removed"
    debug "remove_systemd_service completed"
}

show_service_status() {
    debug "show_service_status called"
    
    debug "Checking if service exists"
    if systemctl list-unit-files | grep -q server-helper; then
        debug "Service exists, showing status"
        sudo systemctl status server-helper --no-pager
        echo ""
        
        log "Recent logs:"
        debug "Fetching last 20 log entries"
        sudo journalctl -u server-helper -n 20 --no-pager
    else
        warning "Service not installed"
        debug "Service not found in systemd"
    fi
    
    debug "show_service_status completed"
}

start_service_now() {
    debug "start_service_now called"
    
    debug "Checking if service is installed"
    if ! systemctl list-unit-files | grep -q server-helper; then
        error "Service not installed"
        debug "Service not found, cannot start"
        return 1
    fi
    
    debug "Starting server-helper service"
    sudo systemctl start server-helper
    
    debug "Waiting 2 seconds for service to start"
    sleep 2
    
    debug "Showing service status"
    sudo systemctl status server-helper --no-pager
    
    debug "start_service_now completed"
}

stop_service() {
    debug "stop_service called"
    
    debug "Stopping server-helper service"
    sudo systemctl stop server-helper
    
    debug "Showing service status"
    sudo systemctl status server-helper --no-pager
    
    debug "stop_service completed"
}

restart_service() {
    debug "restart_service called"
    
    debug "Stopping service"
    stop_service
    
    debug "Waiting 2 seconds"
    sleep 2
    
    debug "Starting service"
    start_service_now
    
    debug "restart_service completed"
}

show_logs() {
    debug "show_logs called"
    log "Showing live logs (Ctrl+C to exit)..."
    debug "Starting journalctl follow for server-helper"
    sudo journalctl -u server-helper -f
}

# Monitoring service
monitor_services() {
    debug "monitor_services called"
    log "Starting monitoring (2-min intervals)..."
    debug "Monitor configuration:"
    debug "  - BACKUP_INTERVAL: 180 (6 hours)"
    debug "  - UPDATE_CHECK_INTERVAL: $UPDATE_CHECK_INTERVAL"
    debug "  - SECURITY_CHECK_INTERVAL: $SECURITY_CHECK_INTERVAL"
    debug "  - AUTO_CLEANUP_ENABLED: $AUTO_CLEANUP_ENABLED"
    debug "  - AUTO_UPDATE_ENABLED: $AUTO_UPDATE_ENABLED"
    debug "  - AUTO_REBOOT_ENABLED: $AUTO_REBOOT_ENABLED"
    debug "  - SECURITY_CHECK_ENABLED: $SECURITY_CHECK_ENABLED"
    
    debug "Creating initial backup"
    backup_dockge
    
    local BACKUP_INT=180
    local UPDATE_INT=$((UPDATE_CHECK_INTERVAL * 30))
    local SEC_INT=$((SECURITY_CHECK_INTERVAL * 30))
    local bc=0 uc=0 sc=0
    
    debug "Calculated intervals:"
    debug "  - Backup: $BACKUP_INT cycles (6 hours)"
    debug "  - Update: $UPDATE_INT cycles"
    debug "  - Security: $SEC_INT cycles"
    
    debug "Entering monitoring loop"
    while true; do
        debug "Monitoring cycle: bc=$bc, uc=$uc, sc=$sc"
        sleep 120
        ((bc++)); ((uc++)); ((sc++))
        
        debug "Checking disk usage"
        local disk=$(check_disk_usage)
        debug "Current disk usage: $disk%"
        
        if [ "$disk" -ge "$DISK_CLEANUP_THRESHOLD" ]; then
            debug "Disk usage ($disk%) >= threshold ($DISK_CLEANUP_THRESHOLD%)"
            if [ "$AUTO_CLEANUP_ENABLED" = "true" ]; then
                debug "AUTO_CLEANUP_ENABLED=true, running cleanup"
                clean_disk
            else
                debug "AUTO_CLEANUP_ENABLED=false, skipping cleanup"
                warning "Disk usage at $disk% but auto-cleanup disabled"
            fi
        fi
        
        if [ $uc -ge $UPDATE_INT ]; then
            debug "Update check interval reached ($uc >= $UPDATE_INT)"
            if [ "$AUTO_UPDATE_ENABLED" = "true" ]; then
                debug "AUTO_UPDATE_ENABLED=true, checking for updates"
                if check_updates; then
                    debug "Updates available, running update_system"
                    update_system
                    local update_result=$?
                    debug "update_system returned: $update_result"
                    
                    if [ $update_result -eq 2 ] && [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
                        debug "Reboot required and AUTO_REBOOT_ENABLED=true"
                        schedule_reboot "$REBOOT_TIME"
                    fi
                else
                    debug "No updates available"
                fi
            else
                debug "AUTO_UPDATE_ENABLED=false, skipping update check"
            fi
            uc=0
        fi
        
        if [ $sc -ge $SEC_INT ]; then
            debug "Security check interval reached ($sc >= $SEC_INT)"
            if [ "$SECURITY_CHECK_ENABLED" = "true" ]; then
                debug "SECURITY_CHECK_ENABLED=true, running security audit"
                security_audit
            else
                debug "SECURITY_CHECK_ENABLED=false, skipping security audit"
            fi
            sc=0
        fi
        
        debug "Checking NAS heartbeat"
        if check_nas_heartbeat; then
            debug "NAS heartbeat OK"
        else
            error "NAS failed"
            debug "NAS heartbeat failed, attempting remount"
            mount_nas || true
        fi
        
        debug "Checking Dockge heartbeat"
        if check_dockge_heartbeat; then
            debug "Dockge heartbeat OK"
        else
            error "Dockge failed"
            debug "Dockge heartbeat failed, attempting restart"
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
        fi
        
        if [ $bc -ge $BACKUP_INT ]; then
            debug "Backup interval reached ($bc >= $BACKUP_INT)"
            backup_dockge
            bc=0
        fi
        
        log "✓ Heartbeat | Disk:${disk}% | Backup:$((BACKUP_INT-bc)) | Updates:$((UPDATE_INT-uc)) | Security:$((SEC_INT-sc))"
        debug "Cycle complete, next cycle in 120 seconds"
    done
}
