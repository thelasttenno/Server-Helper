#!/bin/bash
# System Updates Module

check_updates() {
    debug "[check_updates] Checking for available updates"
    sudo apt-get update -qq
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    debug "[check_updates] Found $updates available update(s)"
    [ $updates -gt 0 ] && { warning "$updates updates available"; return 0; } || { log "System up to date"; return 1; }
}

update_system() {
    debug "[update_system] Starting system update"
    log "Updating system..."
    local kb=$(uname -r)
    debug "[update_system] Current kernel: $kb"
    
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    sudo apt-get autoremove -y
    
    local ka=$(uname -r)
    debug "[update_system] New kernel: $ka"
    log "✓ Update complete (kernel: $kb -> $ka)"
    
    if [ -f /var/run/reboot-required ]; then
        warning "Reboot required"
        debug "[update_system] Reboot flag detected"
        return 2
    fi
    
    debug "[update_system] System update complete"
    return 0
}

full_upgrade() {
    debug "[full_upgrade] Starting full system upgrade"
    confirm "Perform full system upgrade?" || return 1
    
    debug "[full_upgrade] Creating configuration backup"
    sudo tar -czf "/root/config_backup_$(timestamp).tar.gz" /etc/apt/sources.list* /etc/fstab /etc/hostname /etc/hosts 2>/dev/null
    
    update_system
    local update_status=$?
    
    if [ $update_status -eq 2 ]; then
        if confirm "Reboot now?"; then
            log "Rebooting in 10s..."
            debug "[full_upgrade] Reboot scheduled"
            sleep 10
            sudo reboot
        fi
    fi
    
    debug "[full_upgrade] Full upgrade complete"
}

schedule_reboot() {
    local time="${1:-$REBOOT_TIME}"
    debug "[schedule_reboot] Scheduling reboot for: $time"
    
    sudo shutdown -c 2>/dev/null || true
    sudo shutdown -r "$time" "Scheduled reboot"
    log "✓ Reboot scheduled for $time"
    debug "[schedule_reboot] Reboot scheduled successfully"
}

show_update_status() {
    debug "[show_update_status] Displaying update status"
    log "Update Status:"
    echo "Kernel: $(uname -r)"
    echo "OS: $(lsb_release -d | cut -f2)"
    
    if [ -f /var/run/reboot-required ]; then
        warning "REBOOT REQUIRED"
        debug "[show_update_status] Reboot required flag present"
    else
        log "No reboot needed"
    fi
    
    check_updates && apt list --upgradable 2>/dev/null | grep upgradable
}
