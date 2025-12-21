#!/bin/bash
# Disk Management Module

check_disk_usage() {
    df -h "${1:-/}" | awk 'NR==2 {print $5}' | sed 's/%//'
}

clean_disk() {
    log "Cleaning disk..."
    local initial=$(check_disk_usage)
    
    sudo apt-get clean
    sudo apt-get autoclean
    sudo apt-get autoremove --purge -y
    sudo journalctl --vacuum-time=7d
    
    command_exists docker && {
        sudo docker container prune -f
        sudo docker image prune -f
        sudo docker volume prune -f
        sudo docker network prune -f
        sudo docker builder prune -f
    }
    
    sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    sudo find /var/log -name "*.log.*" -delete 2>/dev/null || true
    
    local final=$(check_disk_usage)
    log "✓ Cleaned: ${initial}% -> ${final}% (freed $((initial - final))%)"
}

show_disk_space() {
    log "Disk Space:"
    df -h | grep -E '^/dev/|Filesystem'
    echo ""
    log "Top 10 directories:"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    command_exists docker && { echo ""; sudo docker system df; }
}
