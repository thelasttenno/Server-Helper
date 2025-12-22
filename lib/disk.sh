#!/bin/bash
# Disk Management Module - Enhanced with Debug

check_disk_usage() {
    local path="${1:-/}"
    debug "check_disk_usage called for: $path"
    
    local usage=$(df -h "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    debug "Disk usage for $path: $usage%"
    
    echo "$usage"
}

clean_disk() {
    debug "clean_disk called"
    log "Cleaning disk..."
    local initial=$(check_disk_usage)
    debug "Initial disk usage: $initial%"
    
    debug "Running apt-get clean"
    sudo apt-get clean
    
    debug "Running apt-get autoclean"
    sudo apt-get autoclean
    
    debug "Running apt-get autoremove"
    sudo apt-get autoremove --purge -y
    
    debug "Vacuuming journal logs (keeping 7 days)"
    sudo journalctl --vacuum-time=7d
    
    if command_exists docker; then
        debug "Docker found, running cleanup"
        
        debug "Pruning Docker containers"
        sudo docker container prune -f
        
        debug "Pruning Docker images"
        sudo docker image prune -f
        
        debug "Pruning Docker volumes"
        sudo docker volume prune -f
        
        debug "Pruning Docker networks"
        sudo docker network prune -f
        
        debug "Pruning Docker build cache"
        sudo docker builder prune -f
    else
        debug "Docker not installed, skipping Docker cleanup"
    fi
    
    debug "Cleaning /tmp and /var/tmp"
    sudo rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
    
    debug "Removing old log files"
    sudo find /var/log -name "*.log.*" -delete 2>/dev/null || true
    
    local final=$(check_disk_usage)
    debug "Final disk usage: $final%"
    local freed=$((initial - final))
    log "✓ Cleaned: ${initial}% -> ${final}% (freed ${freed}%)"
    debug "Disk cleanup completed, freed ${freed}%"
}

show_disk_space() {
    debug "show_disk_space called"
    log "Disk Space:"
    
    debug "Showing filesystem usage"
    df -h | grep -E '^/dev/|Filesystem'
    
    echo ""
    log "Top 10 directories:"
    debug "Finding top 10 largest directories in /"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    
    if command_exists docker; then
        echo ""
        debug "Showing Docker disk usage"
        sudo docker system df
    else
        debug "Docker not installed, skipping Docker disk usage"
    fi
    
    debug "show_disk_space completed"
}
