#!/bin/bash
# Core Library - Essential utility functions

# Execute command with dry-run support
execute() {
    local cmd="$1"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would execute: $cmd"
        return 0
    else
        debug "Executing: $cmd"
        eval "$cmd"
    fi
}

# Check if running as root
require_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This operation requires root privileges"
        error "Please run with sudo"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if service is running
service_running() {
    systemctl is-active --quiet "$1"
}

# Check if port is in use
port_in_use() {
    ss -tulpn | grep -q ":$1 "
}

# Wait for condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Retry command with backoff
retry() {
    local max_attempts="$1"
    shift
    local cmd="$@"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        warning "Attempt $attempt/$max_attempts failed, retrying..."
        sleep $((attempt * 2))
        attempt=$((attempt + 1))
    done
    
    error "Command failed after $max_attempts attempts"
    return 1
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " -n 1 -r
    else
        read -p "$prompt [y/N]: " -n 1 -r
    fi
    
    echo
    
    if [ "$default" = "y" ]; then
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# Progress indicator
show_progress() {
    local msg="$1"
    echo -n "$msg"
    
    while kill -0 $! 2>/dev/null; do
        echo -n "."
        sleep 1
    done
    
    echo " Done"
}

# Get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        if confirm "$prompt" "$default"; then
            return 0
        else
            return 1
        fi
    done
}

# Safe file operations
safe_copy() {
    local src="$1"
    local dest="$2"
    local backup="${3:-true}"
    
    if [ ! -f "$src" ]; then
        error "Source file not found: $src"
        return 1
    fi
    
    if [ -f "$dest" ] && [ "$backup" = "true" ]; then
        local backup_file="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
        debug "Backing up $dest to $backup_file"
        sudo cp "$dest" "$backup_file"
    fi
    
    sudo cp "$src" "$dest"
}

# Create directory safely
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    
    if [ ! -d "$dir" ]; then
        debug "Creating directory: $dir (mode: $mode)"
        sudo mkdir -p "$dir"
        sudo chmod "$mode" "$dir"
    fi
}

# Remove directory safely
safe_rmdir() {
    local dir="$1"
    local force="${2:-false}"
    
    if [ ! -d "$dir" ]; then
        debug "Directory doesn't exist: $dir"
        return 0
    fi
    
    if [ "$force" = "true" ]; then
        sudo rm -rf "$dir"
    else
        if confirm "Remove directory $dir?"; then
            sudo rm -rf "$dir"
        fi
    fi
}

# Get file size in human readable format
get_file_size() {
    if [ -f "$1" ]; then
        du -h "$1" | cut -f1
    else
        echo "0"
    fi
}

# Check disk space
check_disk_space() {
    local path="${1:-/}"
    local threshold="${2:-90}"
    
    local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -ge "$threshold" ]; then
        warning "Disk usage at $usage% (threshold: $threshold%)"
        return 1
    fi
    
    return 0
}

# Timestamp function
timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $bytes -ge 1024 ] && [ $unit -lt 4 ]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done
    
    echo "${bytes}${units[$unit]}"
}
