#!/bin/bash
# System Updates Module

check_updates() {
    sudo apt-get update -qq
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    [ $updates -gt 0 ] && { warning "$updates updates available"; return 0; } || { log "System up to date"; return 1; }
}

update_system() {
    log "Updating system..."
    local kb=$(uname -r)
    
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    sudo apt-get autoremove -y
    
    local ka=$(uname -r)
    log "✓ Update complete (kernel: $kb -> $ka)"
    
    [ -f /var/run/reboot-required ] && { warning "Reboot required"; return 2; }
    return 0
}

full_upgrade() {
    confirm "Perform full system upgrade?" || return 1
    
    sudo tar -czf "/root/config_backup_$(timestamp).tar.gz" /etc/apt/sources.list* /etc/fstab /etc/hostname /etc/hosts 2>/dev/null
    
    update_system
    [ $? -eq 2 ] && confirm "Reboot now?" && { log "Rebooting in 10s..."; sleep 10; sudo reboot; }
}

schedule_reboot() {
    local time="${1:-$REBOOT_TIME}"
    sudo shutdown -c 2>/dev/null || true
    sudo shutdown -r "$time" "Scheduled reboot"
    log "✓ Reboot scheduled for $time"
}

show_update_status() {
    log "Update Status:"
    echo "Kernel: $(uname -r)"
    echo "OS: $(lsb_release -d | cut -f2)"
    [ -f /var/run/reboot-required ] && warning "REBOOT REQUIRED" || log "No reboot needed"
    check_updates && apt list --upgradable 2>/dev/null | grep upgradable
}
