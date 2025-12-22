#!/bin/bash
# Core Library - Essential utility functions - Enhanced with Debug

# Execute command with dry-run support
execute() {
    local cmd="$1"
    debug "execute called with command: $cmd"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would execute: $cmd"
        debug "DRY_RUN mode active, command not executed"
        return 0
    else
        debug "Executing command: $cmd"
        eval "$cmd"
        local result=$?
        debug "Command returned: $result"
        return $result
    fi
}

# Check if running as root
require_root() {
    debug "require_root called"
    debug "EUID: $EUID"
    
    if [ "$EUID" -ne 0 ]; then
        error "This operation requires root privileges"
        error "Please run with sudo"
        debug "User is not root, exiting"
        exit 1
    fi
    
    debug "Root check passed"
}

# Check if command exists
command_exists() {
    local cmd="$1"
    debug "command_exists called for: $cmd"
    
    if command -v "$cmd" &> /dev/null; then
        debug "Command exists: $cmd"
        return 0
    else
        debug "Command does not exist: $cmd"
        return 1
    fi
}

# Check if service is running
service_running() {
    local service="$1"
    debug "service_running called for: $service"
    
    if systemctl is-active --quiet "$service"; then
        debug "Service is running: $service"
        return 0
    else
        debug "Service is not running: $service"
        return 1
    fi
}

# Check if port is in use
port_in_use() {
    local port="$1"
    debug "port_in_use called for port: $port"
    
    if ss -tulpn | grep -q ":$port "; then
        debug "Port is in use: $port"
        return 0
    else
        debug "Port is not in use: $port"
        return 1
    fi
}

# Wait for condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    local elapsed=0
    
    debug "wait_for called"
    debug "  Condition: $condition"
    debug "  Timeout: $timeout seconds"
    debug "  Interval: $interval seconds"
    
    while [ $elapsed -lt $timeout ]; do
        debug "Checking condition (elapsed: $elapsed/$timeout)"
        if eval "$condition"; then
            debug "Condition met after $elapsed seconds"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    debug "Timeout reached after $timeout seconds"
    return 1
}

# Retry command with backoff
retry() {
    local max_attempts="$1"
    shift
    local cmd="$@"
    local attempt=1
    
    debug "retry called"
    debug "  Max attempts: $max_attempts"
    debug "  Command: $cmd"
    
    while [ $attempt -le $max_attempts ]; do
        debug "Attempt $attempt/$max_attempts"
        if eval "$cmd"; then
            debug "Command succeeded on attempt $attempt"
            return 0
        fi
        
        warning "Attempt $attempt/$max_attempts failed, retrying..."
        local wait_time=$((attempt * 2))
        debug "Waiting $wait_time seconds before retry"
        sleep $wait_time
        attempt=$((attempt + 1))
    done
    
    error "Command failed after $max_attempts attempts"
    debug "All retry attempts exhausted"
    return 1
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    debug "confirm called"
    debug "  Prompt: $prompt"
    debug "  Default: $default"
    
    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " -n 1 -r
    else
        read -p "$prompt [y/N]: " -n 1 -r
    fi
    
    echo
    debug "User reply: ${REPLY:-<enter>}"
    
    if [ "$default" = "y" ]; then
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            debug "User confirmed (default yes)"
            return 0
        else
            debug "User declined"
            return 1
        fi
    else
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            debug "User confirmed"
            return 0
        else
            debug "User declined (default no)"
            return 1
        fi
    fi
}

# Progress indicator
show_progress() {
    local msg="$1"
    debug "show_progress called with message: $msg"
    echo -n "$msg"
    
    debug "Waiting for background process $!"
    while kill -0 $! 2>/dev/null; do
        echo -n "."
        sleep 1
    done
    
    echo " Done"
    debug "Progress complete"
}

# Get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    debug "get_yes_no called"
    debug "  Prompt: $prompt"
    debug "  Default: $default"
    
    while true; do
        if confirm "$prompt" "$default"; then
            debug "Returning yes (0)"
            return 0
        else
            debug "Returning no (1)"
            return 1
        fi
    done
}

# Safe file operations
safe_copy() {
    local src="$1"
    local dest="$2"
    local backup="${3:-true}"
    
    debug "safe_copy called"
    debug "  Source: $src"
    debug "  Destination: $dest"
    debug "  Backup: $backup"
    
    if [ ! -f "$src" ]; then
        error "Source file not found: $src"
        debug "Source file does not exist"
        return 1
    fi
    
    if [ -f "$dest" ] && [ "$backup" = "true" ]; then
        local backup_file="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
        debug "Backing up existing file to: $backup_file"
        sudo cp "$dest" "$backup_file"
    fi
    
    debug "Copying $src to $dest"
    sudo cp "$src" "$dest"
    debug "Copy completed"
}

# Create directory safely
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    
    debug "safe_mkdir called"
    debug "  Directory: $dir"
    debug "  Mode: $mode"
    
    if [ ! -d "$dir" ]; then
        debug "Directory does not exist, creating"
        sudo mkdir -p "$dir"
        sudo chmod "$mode" "$dir"
        debug "Directory created with mode $mode"
    else
        debug "Directory already exists"
    fi
}

# Remove directory safely
safe_rmdir() {
    local dir="$1"
    local force="${2:-false}"
    
    debug "safe_rmdir called"
    debug "  Directory: $dir"
    debug "  Force: $force"
    
    if [ ! -d "$dir" ]; then
        debug "Directory doesn't exist: $dir"
        return 0
    fi
    
    if [ "$force" = "true" ]; then
        debug "Force mode, removing without confirmation"
        sudo rm -rf "$dir"
    else
        if confirm "Remove directory $dir?"; then
            debug "User confirmed removal"
            sudo rm -rf "$dir"
        else
            debug "User declined removal"
        fi
    fi
}

# Get file size in human readable format
get_file_size() {
    local file="$1"
    debug "get_file_size called for: $file"
    
    if [ -f "$file" ]; then
        local size=$(du -h "$file" | cut -f1)
        debug "File size: $size"
        echo "$size"
    else
        debug "File does not exist"
        echo "0"
    fi
}

# Check disk space
check_disk_space() {
    local path="${1:-/}"
    local threshold="${2:-90}"
    
    debug "check_disk_space called"
    debug "  Path: $path"
    debug "  Threshold: $threshold%"
    
    local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    debug "Current usage: $usage%"
    
    if [ "$usage" -ge "$threshold" ]; then
        warning "Disk usage at $usage% (threshold: $threshold%)"
        debug "Usage exceeds threshold"
        return 1
    fi
    
    debug "Usage within threshold"
    return 0
}

# Timestamp function
timestamp() {
    local ts=$(date '+%Y%m%d_%H%M%S')
    debug "timestamp generated: $ts"
    echo "$ts"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    debug "format_bytes called with: $bytes"
    
    while [ $bytes -ge 1024 ] && [ $unit -lt 4 ]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done
    
    local result="${bytes}${units[$unit]}"
    debug "Formatted result: $result"
    echo "$result"
}
