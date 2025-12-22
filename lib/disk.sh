#!/bin/bash
# Disk Management Module

check_disk_usage() {
    local path="${1:-/}"
    debug "[check_disk_usage] Checking disk usage for: $path"
    local usage=$(df -h "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    debug "[check_disk_usage] Current usage: $usage%"
    echo "$usage"
}

clean_disk() {
    debug "[clean_disk] Starting disk cleanup"
    log "Cleaning disk..."
    local initial=$(check_disk_usage)
    debug "[clean_disk] Initial disk usage: $initial%"
    
    debug "[clean_disk] Running apt cleanup"
    sudo apt-get clean
    sudo apt-get autoclean
    sudo apt-get autoremove --purge -y
    
    debug "[clean_disk] Vacuuming journal logs"
    sudo journalctl --vacuum-time=7d
    
    if command_exists docker; then
        debug "[clean_disk] Running Docker cleanup"
        sudo docker container prune -f
        sudo docker image prune -f
        sudo docker volume prune -f
        sudo docker network prune -f
        sudo docker builder prune -f
    fi
    
    debug "[clean_disk] Removing temporary files"
    sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    sudo find /var/log -name "*.log.*" -delete 2>/dev/null || true
    
    local final=$(check_disk_usage)
    debug "[clean_disk] Final disk usage: $final%"
    log "✓ Cleaned: ${initial}% -> ${final}% (freed $((initial - final))%)"
}

show_disk_space() {
    debug "[show_disk_space] Displaying disk space information"
    log "Disk Space:"
    df -h | grep -E '^/dev/|Filesystem'
    echo ""
    log "Top 10 directories:"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    
    if command_exists docker; then
        echo ""
        debug "[show_disk_space] Showing Docker system disk usage"
        sudo docker system df
    fi
}
