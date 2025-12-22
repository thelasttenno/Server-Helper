#!/bin/bash
# Core Library - Essential utility functions

# Execute command with dry-run support
execute() {
    local cmd="$1"
    debug "[execute] Command: $cmd"
    
    if [ "$DRY_RUN" = "true" ]; then
        log "[DRY-RUN] Would execute: $cmd"
        return 0
    else
        debug "Executing: $cmd"
        eval "$cmd"
        local exit_code=$?
        debug "[execute] Exit code: $exit_code"
        return $exit_code
    fi
}

# Check if running as root
require_root() {
    debug "[require_root] Checking root privileges (EUID: $EUID)"
    if [ "$EUID" -ne 0 ]; then
        error "This operation requires root privileges"
        error "Please run with sudo"
        exit 1
    fi
    debug "[require_root] Root privileges confirmed"
}

# Check if command exists
command_exists() {
    local cmd="$1"
    debug "[command_exists] Checking for command: $cmd"
    if command -v "$cmd" &> /dev/null; then
        debug "[command_exists] Command found: $cmd"
        return 0
    else
        debug "[command_exists] Command not found: $cmd"
        return 1
    fi
}

# Check if service is running
service_running() {
    local service="$1"
    debug "[service_running] Checking service: $service"
    if systemctl is-active --quiet "$service"; then
        debug "[service_running] Service $service is active"
        return 0
    else
        debug "[service_running] Service $service is not active"
        return 1
    fi
}

# Check if port is in use
port_in_use() {
    local port="$1"
    debug "[port_in_use] Checking port: $port"
    if ss -tulpn | grep -q ":$port "; then
        debug "[port_in_use] Port $port is in use"
        return 0
    else
        debug "[port_in_use] Port $port is available"
        return 1
    fi
}

# Wait for condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local interval="${3:-2}"
    local elapsed=0
    
    debug "[wait_for] Condition: $condition, Timeout: ${timeout}s, Interval: ${interval}s"
    
    while [ $elapsed -lt $timeout ]; do
        debug "[wait_for] Elapsed: ${elapsed}s"
        if eval "$condition"; then
            debug "[wait_for] Condition met after ${elapsed}s"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    debug "[wait_for] Timeout reached after ${elapsed}s"
    return 1
}

# Retry command with backoff
retry() {
    local max_attempts="$1"
    shift
    local cmd="$@"
    local attempt=1
    
    debug "[retry] Command: $cmd, Max attempts: $max_attempts"
    
    while [ $attempt -le $max_attempts ]; do
        debug "[retry] Attempt $attempt/$max_attempts"
        if eval "$cmd"; then
            debug "[retry] Command succeeded on attempt $attempt"
            return 0
        fi
        
        warning "Attempt $attempt/$max_attempts failed, retrying..."
        sleep $((attempt * 2))
        attempt=$((attempt + 1))
    done
    
    error "Command failed after $max_attempts attempts"
    debug "[retry] All attempts exhausted"
    return 1
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    debug "[confirm] Prompt: $prompt, Default: $default"
    
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
    
    local result=$?
    debug "[confirm] User response: ${REPLY:-default}, Result: $result"
    return $result
}

# Progress indicator
show_progress() {
    local msg="$1"
    debug "[show_progress] Starting: $msg"
    echo -n "$msg"
    
    while kill -0 $! 2>/dev/null; do
        echo -n "."
        sleep 1
    done
    
    echo " Done"
    debug "[show_progress] Completed: $msg"
}

# Get yes/no input
get_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    debug "[get_yes_no] Prompt: $prompt, Default: $default"
    
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
    
    debug "[safe_copy] Source: $src, Dest: $dest, Backup: $backup"
    
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
    debug "[safe_copy] Copy completed successfully"
}

# Create directory safely
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    
    debug "[safe_mkdir] Directory: $dir, Mode: $mode"
    
    if [ ! -d "$dir" ]; then
        debug "Creating directory: $dir (mode: $mode)"
        sudo mkdir -p "$dir"
        sudo chmod "$mode" "$dir"
        debug "[safe_mkdir] Directory created successfully"
    else
        debug "[safe_mkdir] Directory already exists"
    fi
}

# Remove directory safely
safe_rmdir() {
    local dir="$1"
    local force="${2:-false}"
    
    debug "[safe_rmdir] Directory: $dir, Force: $force"
    
    if [ ! -d "$dir" ]; then
        debug "Directory doesn't exist: $dir"
        return 0
    fi
    
    if [ "$force" = "true" ]; then
        sudo rm -rf "$dir"
        debug "[safe_rmdir] Directory removed (forced)"
    else
        if confirm "Remove directory $dir?"; then
            sudo rm -rf "$dir"
            debug "[safe_rmdir] Directory removed (user confirmed)"
        else
            debug "[safe_rmdir] Directory removal cancelled by user"
        fi
    fi
}

# Get file size in human readable format
get_file_size() {
    local file="$1"
    debug "[get_file_size] File: $file"
    
    if [ -f "$file" ]; then
        local size=$(du -h "$file" | cut -f1)
        debug "[get_file_size] Size: $size"
        echo "$size"
    else
        debug "[get_file_size] File not found"
        echo "0"
    fi
}

# Check disk space
check_disk_space() {
    local path="${1:-/}"
    local threshold="${2:-90}"
    
    debug "[check_disk_space] Path: $path, Threshold: $threshold%"
    
    local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    debug "[check_disk_space] Current usage: $usage%"
    
    if [ "$usage" -ge "$threshold" ]; then
        warning "Disk usage at $usage% (threshold: $threshold%)"
        return 1
    fi
    
    return 0
}

# Timestamp function
timestamp() {
    local ts=$(date '+%Y%m%d_%H%M%S')
    debug "[timestamp] Generated: $ts"
    echo "$ts"
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    debug "[format_bytes] Input: $bytes bytes"
    
    while [ $bytes -ge 1024 ] && [ $unit -lt 4 ]; do
        bytes=$((bytes / 1024))
        unit=$((unit + 1))
    done
    
    local result="${bytes}${units[$unit]}"
    debug "[format_bytes] Output: $result"
    echo "$result"
}
