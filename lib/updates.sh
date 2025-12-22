#!/bin/bash
# System Updates Module - Enhanced with Debug

check_updates() {
    debug "check_updates called"
    debug "Running apt-get update"
    sudo apt-get update -qq
    
    debug "Checking for upgradable packages"
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    debug "Found $updates upgradable package(s)"
    
    if [ $updates -gt 0 ]; then
        warning "$updates updates available"
        debug "Returning 0 (updates available)"
        return 0
    else
        log "System up to date"
        debug "Returning 1 (no updates)"
        return 1
    fi
}

update_system() {
    debug "update_system called"
    log "Updating system..."
    
    local kb=$(uname -r)
    debug "Kernel before update: $kb"
    
    debug "Running apt-get update"
    sudo apt-get update
    
    debug "Running apt-get upgrade (non-interactive)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    debug "Running apt-get dist-upgrade (non-interactive)"
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    
    debug "Running apt-get autoremove"
    sudo apt-get autoremove -y
    
    local ka=$(uname -r)
    debug "Kernel after update: $ka"
    log "✓ Update complete (kernel: $kb -> $ka)"
    
    if [ -f /var/run/reboot-required ]; then
        warning "Reboot required"
        debug "/var/run/reboot-required exists, returning 2"
        return 2
    fi
    
    debug "No reboot required, returning 0"
    return 0
}

full_upgrade() {
    debug "full_upgrade called"
    
    if ! confirm "Perform full system upgrade?"; then
        debug "User declined full upgrade"
        return 1
    fi
    
    debug "Creating config backup before upgrade"
    local backup_file="/root/config_backup_$(timestamp).tar.gz"
    debug "Backup file: $backup_file"
    
    sudo tar -czf "$backup_file" /etc/apt/sources.list* /etc/fstab /etc/hostname /etc/hosts 2>/dev/null
    debug "Config backup created: $backup_file"
    
    debug "Running update_system"
    update_system
    local result=$?
    debug "update_system returned: $result"
    
    if [ $result -eq 2 ]; then
        debug "Reboot required after upgrade"
        if [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
            debug "AUTO_REBOOT_ENABLED=true, scheduling reboot"
            schedule_reboot "$REBOOT_TIME"
        elif confirm "Reboot now?"; then
            debug "User confirmed reboot"
            log "Rebooting in 10s..."
            sleep 10
            sudo reboot
        else
            debug "User declined reboot"
        fi
    fi
    
    debug "full_upgrade completed"
}

schedule_reboot() {
    local time="${1:-$REBOOT_TIME}"
    debug "schedule_reboot called with time: $time"
    
    debug "Cancelling any existing shutdown schedules"
    sudo shutdown -c 2>/dev/null || true
    
    debug "Scheduling reboot for: $time"
    sudo shutdown -r "$time" "Scheduled reboot"
    
    log "✓ Reboot scheduled for $time"
    debug "Reboot scheduled successfully"
}

show_update_status() {
    debug "show_update_status called"
    log "Update Status:"
    
    local kernel=$(uname -r)
    debug "Current kernel: $kernel"
    echo "Kernel: $kernel"
    
    local os=$(lsb_release -d | cut -f2)
    debug "OS: $os"
    echo "OS: $os"
    
    if [ -f /var/run/reboot-required ]; then
        warning "REBOOT REQUIRED"
        debug "/var/run/reboot-required exists"
        
        if [ -f /var/run/reboot-required.pkgs ]; then
            debug "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs | while read pkg; do
                debug "  - $pkg"
            done
        fi
    else
        log "No reboot needed"
        debug "No reboot required"
    fi
    
    debug "Checking for available updates"
    if check_updates; then
        debug "Updates are available, listing them"
        apt list --upgradable 2>/dev/null | grep upgradable
    fi
    
    debug "show_update_status completed"
}
