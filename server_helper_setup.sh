#!/bin/bash

# Server Helper Setup Script for Ubuntu 24.04.3 LTS

set -e

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/server-helper.conf}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Load configuration from file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    warning "Configuration file not found: $CONFIG_FILE"
    log "Creating default configuration file..."
    cat > "$CONFIG_FILE" << 'EOF'
# Server Helper Configuration File
# Edit this file with your settings

# NAS Configuration (Multiple shares supported)
# Format: "IP:SHARE:MOUNT_POINT:USERNAME:PASSWORD"
# Separate multiple shares with semicolons
NAS_SHARES="192.168.1.100:share1:/mnt/nas1:user1:pass1;192.168.1.100:share2:/mnt/nas2:user1:pass1"

# Legacy single NAS config (kept for backward compatibility)
NAS_IP="192.168.1.100"
NAS_SHARE="share"
NAS_MOUNT_POINT="/mnt/nas"
NAS_USERNAME="your_username"
NAS_PASSWORD="your_password"

# Dockge Configuration
DOCKGE_PORT="5001"
DOCKGE_DATA_DIR="/opt/dockge"
BACKUP_DIR="$NAS_MOUNT_POINT/dockge_backups"
BACKUP_RETENTION_DAYS="30"

# NAS Mount Settings
NAS_MOUNT_REQUIRED="false"          # Set to "true" to fail setup if NAS doesn't mount
NAS_MOUNT_SKIP="false"              # Set to "true" to skip NAS mounting entirely

# System Configuration
NEW_HOSTNAME=""

# Uptime Kuma Push Monitor URLs (leave empty to disable)
UPTIME_KUMA_NAS_URL=""
UPTIME_KUMA_DOCKGE_URL=""
UPTIME_KUMA_SYSTEM_URL=""

# Disk Cleanup Settings
DISK_CLEANUP_THRESHOLD="80"
AUTO_CLEANUP_ENABLED="true"

# System Update Settings
AUTO_UPDATE_ENABLED="false"
UPDATE_CHECK_INTERVAL="24"
AUTO_REBOOT_ENABLED="false"
REBOOT_TIME="03:00"

# Security and Compliance Settings
SECURITY_CHECK_ENABLED="true"
SECURITY_CHECK_INTERVAL="12"
FAIL2BAN_ENABLED="false"
UFW_ENABLED="false"
SSH_HARDENING_ENABLED="false"
EOF
    chmod 600 "$CONFIG_FILE"
    error "Please edit $CONFIG_FILE with your settings and run again"
    exit 1
fi

# Set defaults if not in config
NAS_SHARES="${NAS_SHARES:-}"
NAS_IP="${NAS_IP:-192.168.1.100}"
NAS_SHARE="${NAS_SHARE:-share}"
NAS_MOUNT_POINT="${NAS_MOUNT_POINT:-/mnt/nas}"
NAS_USERNAME="${NAS_USERNAME:-your_username}"
NAS_PASSWORD="${NAS_PASSWORD:-your_password}"
DOCKGE_PORT="${DOCKGE_PORT:-5001}"
DOCKGE_DATA_DIR="${DOCKGE_DATA_DIR:-/opt/dockge}"
BACKUP_DIR="${BACKUP_DIR:-$NAS_MOUNT_POINT/dockge_backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
NAS_MOUNT_REQUIRED="${NAS_MOUNT_REQUIRED:-false}"
NAS_MOUNT_SKIP="${NAS_MOUNT_SKIP:-false}"
NEW_HOSTNAME="${NEW_HOSTNAME:-}"
UPTIME_KUMA_NAS_URL="${UPTIME_KUMA_NAS_URL:-}"
UPTIME_KUMA_DOCKGE_URL="${UPTIME_KUMA_DOCKGE_URL:-}"
UPTIME_KUMA_SYSTEM_URL="${UPTIME_KUMA_SYSTEM_URL:-}"
DISK_CLEANUP_THRESHOLD="${DISK_CLEANUP_THRESHOLD:-80}"
AUTO_CLEANUP_ENABLED="${AUTO_CLEANUP_ENABLED:-true}"
AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-false}"
UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-24}"
AUTO_REBOOT_ENABLED="${AUTO_REBOOT_ENABLED:-false}"
REBOOT_TIME="${REBOOT_TIME:-03:00}"
SECURITY_CHECK_ENABLED="${SECURITY_CHECK_ENABLED:-true}"
SECURITY_CHECK_INTERVAL="${SECURITY_CHECK_INTERVAL:-12}"
FAIL2BAN_ENABLED="${FAIL2BAN_ENABLED:-false}"
UFW_ENABLED="${UFW_ENABLED:-false}"
SSH_HARDENING_ENABLED="${SSH_HARDENING_ENABLED:-false}"

# Parse NAS shares into array
declare -a NAS_ARRAY
if [ -n "$NAS_SHARES" ]; then
    IFS=';' read -ra NAS_ARRAY <<< "$NAS_SHARES"
fi

# Function to mount a single NAS share
mount_single_nas() {
    local nas_ip="$1"
    local nas_share="$2"
    local mount_point="$3"
    local username="$4"
    local password="$5"
    
    log "Setting up NAS mount: //$nas_ip/$nas_share -> $mount_point"
    
    # Validate inputs
    if [ -z "$nas_ip" ] || [ -z "$nas_share" ] || [ -z "$mount_point" ]; then
        warning "Missing required NAS parameters - skipping this mount"
        return 1
    fi
    
    if [ ! -d "$mount_point" ]; then
        log "Creating mount point: $mount_point"
        sudo mkdir -p "$mount_point"
    fi
    
    if mountpoint -q "$mount_point"; then
        log "Already mounted at $mount_point"
        return 0
    fi
    
    # Create unique credentials file
    local creds_file="/root/.nascreds_$(echo $mount_point | tr '/' '_' | tr -d ' ')"
    
    # Escape special characters in password
    local escaped_password="${password//\\/\\\\}"
    escaped_password="${escaped_password//\$/\\\$}"
    
    sudo bash -c "cat > $creds_file << 'EOFCREDS'
username=$username
password=$escaped_password
EOFCREDS"
    sudo chmod 600 "$creds_file"
    
    log "Attempting to mount //$nas_ip/$nas_share to $mount_point"
    
    # Try mount with different SMB versions
    local mount_opts=""
    local mount_success=false
    
    # Try SMB 3.0
    if sudo mount -t cifs "//$nas_ip/$nas_share" "$mount_point" \
        -o "credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=3.0" 2>/dev/null; then
        log "✓ Mounted successfully with SMB 3.0"
        mount_opts="credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=3.0"
        mount_success=true
    # Try SMB 2.1
    elif sudo mount -t cifs "//$nas_ip/$nas_share" "$mount_point" \
        -o "credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=2.1" 2>/dev/null; then
        log "✓ Mounted successfully with SMB 2.1"
        mount_opts="credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=2.1"
        mount_success=true
    # Try SMB 1.0
    elif sudo mount -t cifs "//$nas_ip/$nas_share" "$mount_point" \
        -o "credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=1.0" 2>/dev/null; then
        warning "Mounted with SMB 1.0 (legacy, consider upgrading NAS)"
        mount_opts="credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,vers=1.0"
        mount_success=true
    # Try without version specification (auto-negotiate)
    elif sudo mount -t cifs "//$nas_ip/$nas_share" "$mount_point" \
        -o "credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775" 2>/dev/null; then
        log "✓ Mounted successfully (auto-negotiated SMB version)"
        mount_opts="credentials=$creds_file,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775"
        mount_success=true
    fi
    
    if [ "$mount_success" = false ]; then
        warning "Failed to mount //$nas_ip/$nas_share to $mount_point"
        warning "Checking kernel logs for details..."
        sudo dmesg | tail -5 | while read line; do
            warning "  $line"
        done
        warning "Common issues:"
        warning "  - Verify NAS IP is reachable: ping $nas_ip"
        warning "  - Check share name is correct"
        warning "  - Verify username/password"
        warning "  - Ensure SMB is enabled on NAS"
        return 1
    fi
    
    # Add to fstab if mounted successfully
    if ! grep -q "$mount_point" /etc/fstab 2>/dev/null; then
        log "Adding to /etc/fstab for auto-mount on boot"
        echo "//$nas_ip/$nas_share $mount_point cifs $mount_opts,_netdev,nofail 0 0" | sudo tee -a /etc/fstab > /dev/null
    fi
    
    log "✓ NAS mounted successfully: $mount_point"
    return 0
}

# Function to mount NAS (supports multiple shares)
mount_nas() {
    # Check if NAS mounting should be skipped
    if [ "$NAS_MOUNT_SKIP" = "true" ]; then
        log "NAS mounting is disabled (NAS_MOUNT_SKIP=true)"
        return 0
    fi
    
    log "Setting up NAS mounts..."
    
    if ! dpkg -l | grep -q cifs-utils; then
        log "Installing cifs-utils..."
        sudo apt-get update
        sudo apt-get install -y cifs-utils
    fi
    
    local mount_count=0
    local failed_count=0
    local total_count=0
    
    # Mount shares from NAS_SHARES if configured
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        total_count=${#NAS_ARRAY[@]}
        log "Attempting to mount $total_count NAS share(s)..."
        
        for nas_config in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r nas_ip nas_share mount_point username password <<< "$nas_config"
            
            if [ -z "$nas_ip" ] || [ -z "$nas_share" ] || [ -z "$mount_point" ]; then
                warning "Invalid NAS config format: $nas_config"
                warning "Expected format: IP:SHARE:MOUNT_POINT:USERNAME:PASSWORD"
                failed_count=$((failed_count + 1))
                continue
            fi
            
            if mount_single_nas "$nas_ip" "$nas_share" "$mount_point" "$username" "$password"; then
                mount_count=$((mount_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        done
    else
        # Fallback to legacy single NAS config
        total_count=1
        log "Using legacy single NAS configuration..."
        
        if mount_single_nas "$NAS_IP" "$NAS_SHARE" "$NAS_MOUNT_POINT" "$NAS_USERNAME" "$NAS_PASSWORD"; then
            mount_count=$((mount_count + 1))
        else
            failed_count=$((failed_count + 1))
        fi
    fi
    
    echo ""
    log "═══════════════════════════════════════════════════════"
    log "NAS Mount Summary: $mount_count/$total_count successful"
    log "═══════════════════════════════════════════════════════"
    
    if [ $failed_count -gt 0 ]; then
        warning "$failed_count NAS share(s) failed to mount"
        
        if [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
            error "NAS_MOUNT_REQUIRED is set to true, but some mounts failed"
            error "Setup cannot continue. Please fix NAS configuration and try again."
            return 1
        else
            warning "Continuing setup without all NAS shares mounted"
            warning "Backups to NAS will not work until NAS is mounted"
            warning "Set NAS_MOUNT_REQUIRED=true in config to make NAS mandatory"
        fi
    fi
    
    if [ $mount_count -eq 0 ]; then
        warning "No NAS shares were mounted successfully!"
        
        if [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
            error "Setup cannot continue without NAS (NAS_MOUNT_REQUIRED=true)"
            return 1
        else
            warning "Continuing setup without NAS storage"
            warning "Features requiring NAS (backups) will not work"
        fi
    fi
    
    return 0
}

# Function to set hostname
set_hostname() {
    local hostname="$1"
    
    if [ -z "$hostname" ]; then
        error "Hostname cannot be empty"
        return 1
    fi
    
    if ! echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
        error "Invalid hostname format"
        return 1
    fi
    
    local current_hostname=$(hostname)
    
    if [ "$current_hostname" == "$hostname" ]; then
        log "Hostname is already set to: $hostname"
        return 0
    fi
    
    log "Changing hostname from '$current_hostname' to '$hostname'..."
    sudo hostnamectl set-hostname "$hostname"
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
    
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$hostname" | sudo tee -a /etc/hosts
    fi
    
    log "Hostname changed successfully to: $hostname"
    return 0
}

# Function to install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed ($(docker --version))"
        return 0
    fi
    
    log "Installing Docker..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed successfully"
}

# Function to install Dockge
install_dockge() {
    log "Setting up Dockge..."
    sudo mkdir -p "$DOCKGE_DATA_DIR"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
    sudo bash -c "cat > $DOCKGE_DATA_DIR/docker-compose.yml << 'EOFDC'
version: '3.8'
services:
  dockge:
    image: louislam/dockge:1
    restart: unless-stopped
    ports:
      - '$DOCKGE_PORT:5001'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data
      - ./stacks:/opt/stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
EOFDC"
    
    log "Dockge configuration created"
}

# Function to start Dockge
start_dockge() {
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    log "Dockge started successfully on port $DOCKGE_PORT"
}

# Function to check NAS heartbeat (supports multiple shares)
check_nas_heartbeat() {
    local status=0
    local failed_mounts=""
    
    # Check all configured NAS shares
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for nas_config in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r nas_ip nas_share mount_point username password <<< "$nas_config"
            
            if [ -z "$mount_point" ]; then
                continue
            fi
            
            if ! mountpoint -q "$mount_point"; then
                error "NAS not mounted: $mount_point"
                failed_mounts="${failed_mounts}${mount_point},"
                status=1
            elif ! timeout 5 ls "$mount_point" > /dev/null 2>&1; then
                error "NAS not responding: $mount_point"
                failed_mounts="${failed_mounts}${mount_point},"
                status=1
            fi
        done
    else
        # Check legacy single NAS
        if ! mountpoint -q "$NAS_MOUNT_POINT"; then
            error "NAS is not mounted at $NAS_MOUNT_POINT"
            failed_mounts="$NAS_MOUNT_POINT"
            status=1
        elif ! timeout 5 ls "$NAS_MOUNT_POINT" > /dev/null 2>&1; then
            error "NAS mount point is not responding"
            failed_mounts="$NAS_MOUNT_POINT"
            status=1
        fi
    fi
    
    if [ -n "$UPTIME_KUMA_NAS_URL" ]; then
        if [ $status -eq 0 ]; then
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1 || true
        else
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=down&msg=Failed:${failed_mounts}" > /dev/null 2>&1 || true
        fi
    fi
    
    return $status
}

# Function to check Dockge heartbeat
check_dockge_heartbeat() {
    local status=0
    
    if ! sudo docker ps | grep -q dockge; then
        error "Dockge container is not running"
        status=1
    elif ! curl -sf http://localhost:$DOCKGE_PORT > /dev/null 2>&1; then
        error "Dockge is not responding on port $DOCKGE_PORT"
        status=1
    fi
    
    if [ -n "$UPTIME_KUMA_DOCKGE_URL" ]; then
        if [ $status -eq 0 ]; then
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1 || true
        else
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=down&msg=Dockge%20Error" > /dev/null 2>&1 || true
        fi
    fi
    
    return $status
}

# Function to backup Dockge
backup_dockge() {
    log "Starting Dockge backup..."
    
    # Check if primary backup location is available
    if ! mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null && ! [ -d "$BACKUP_DIR" ]; then
        warning "NAS is not mounted and backup directory doesn't exist"
        
        # Try to find any mounted NAS share
        local alt_backup_dir=""
        if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for nas_config in "${NAS_ARRAY[@]}"; do
                IFS=':' read -r nas_ip nas_share mount_point username password <<< "$nas_config"
                if mountpoint -q "$mount_point" 2>/dev/null; then
                    alt_backup_dir="$mount_point/dockge_backups"
                    warning "Using alternative backup location: $alt_backup_dir"
                    BACKUP_DIR="$alt_backup_dir"
                    break
                fi
            done
        fi
        
        if [ -z "$alt_backup_dir" ]; then
            # Fallback to local backup
            BACKUP_DIR="/opt/dockge_backups_local"
            warning "No NAS available - using local backup: $BACKUP_DIR"
            warning "Local backups will not survive server failures!"
        fi
    fi
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="dockge_backup_$TIMESTAMP.tar.gz"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log "Creating backup: $BACKUP_NAME"
    
    if sudo tar -czf "$BACKUP_PATH" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        log "✓ Backup created successfully: $BACKUP_PATH"
        BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
        find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete 2>/dev/null
        
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f 2>/dev/null | wc -l)
        log "Total backups retained: $BACKUP_COUNT"
        return 0
    else
        error "Failed to create backup"
        return 1
    fi
}

# Function to restore Dockge
restore_dockge() {
    log "Available backups:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || {
        error "No backups found in $BACKUP_DIR"
        return 1
    }
    
    echo ""
    read -p "Enter the backup filename to restore (or 'latest' for most recent): " BACKUP_FILE
    
    if [ "$BACKUP_FILE" == "latest" ]; then
        BACKUP_FILE=$(ls -t "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null | head -1)
        if [ -z "$BACKUP_FILE" ]; then
            error "No backups found"
            return 1
        fi
        log "Using latest backup: $(basename $BACKUP_FILE)"
    else
        BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    fi
    
    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: $BACKUP_FILE"
        return 1
    fi
    
    warning "This will overwrite current Dockge stacks and data!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Restore cancelled"
        return 1
    fi
    
    log "Stopping Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    EMERGENCY_BACKUP="$DOCKGE_DATA_DIR/emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating emergency backup of current state..."
    sudo tar -czf "$EMERGENCY_BACKUP" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || true
    
    log "Restoring from backup..."
    sudo rm -rf "$DOCKGE_DATA_DIR/stacks" "$DOCKGE_DATA_DIR/data"
    sudo tar -xzf "$BACKUP_FILE" -C "$DOCKGE_DATA_DIR"
    
    log "Starting Dockge..."
    sudo docker compose up -d
    
    log "Restore completed successfully!"
    log "Emergency backup saved to: $EMERGENCY_BACKUP"
    return 0
}

# Function to check disk usage
check_disk_usage() {
    local partition="${1:-/}"
    local usage=$(df -h "$partition" | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "$usage"
}

# Function to clean disk
clean_disk() {
    log "Starting disk cleanup..."
    
    local initial_usage=$(check_disk_usage)
    log "Current disk usage: ${initial_usage}%"
    
    log "Cleaning apt cache..."
    sudo apt-get clean
    sudo apt-get autoclean
    
    log "Removing old kernels..."
    sudo apt-get autoremove --purge -y
    
    log "Cleaning systemd journal logs (keeping last 7 days)..."
    sudo journalctl --vacuum-time=7d
    
    if command -v docker &> /dev/null; then
        log "Cleaning Docker system..."
        sudo docker container prune -f
        sudo docker image prune -f
        sudo docker volume prune -f
        sudo docker network prune -f
        sudo docker builder prune -f
    fi
    
    log "Cleaning temporary files..."
    sudo rm -rf /tmp/* 2>/dev/null || true
    sudo rm -rf /var/tmp/* 2>/dev/null || true
    
    log "Cleaning old log files..."
    sudo find /var/log -type f -name "*.log.*" -delete 2>/dev/null || true
    sudo find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
    
    local final_usage=$(check_disk_usage)
    local freed=$((initial_usage - final_usage))
    log "Disk cleanup completed!"
    log "Initial usage: ${initial_usage}%"
    log "Final usage: ${final_usage}%"
    log "Space freed: ${freed}%"
    
    return 0
}

# Function to show disk space
show_disk_space() {
    log "Disk Space Information:"
    echo ""
    df -h | grep -E '^/dev/|Filesystem'
    echo ""
    log "Largest directories in /:"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    echo ""
    if command -v docker &> /dev/null; then
        log "Docker disk usage:"
        sudo docker system df
    fi
}

# Function to check for updates
check_updates() {
    log "Checking for system updates..."
    sudo apt-get update -qq
    
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    
    if [ "$updates" -gt 0 ]; then
        warning "Found $updates available updates ($security_updates security updates)"
        return 0
    else
        log "System is up to date"
        return 1
    fi
}

# Function to update system
update_system() {
    log "Starting system update and upgrade..."
    
    local kernel_before=$(uname -r)
    
    log "Updating package lists..."
    sudo apt-get update
    
    log "Upgrading packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    log "Performing distribution upgrade..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    
    log "Cleaning up..."
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    local kernel_after=$(uname -r)
    
    log "System update completed successfully!"
    log "Kernel before: $kernel_before"
    log "Kernel after: $kernel_after"
    
    if [ -f /var/run/reboot-required ]; then
        warning "System reboot is required!"
        return 2
    fi
    
    return 0
}

# Function to perform full upgrade
full_upgrade() {
    log "Starting full system upgrade..."
    
    read -p "This will perform a full system upgrade. Continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Upgrade cancelled"
        return 1
    fi
    
    log "Creating backup of important configuration files..."
    sudo tar -czf "/root/config_backup_$(date +%Y%m%d_%H%M%S).tar.gz" \
        /etc/apt/sources.list* \
        /etc/fstab \
        /etc/hostname \
        /etc/hosts \
        "$DOCKGE_DATA_DIR/docker-compose.yml" 2>/dev/null || true
    
    update_system
    local result=$?
    
    if [ $result -eq 2 ]; then
        log "Reboot is required to complete the upgrade"
        read -p "Reboot now? (yes/no): " REBOOT_NOW
        
        if [ "$REBOOT_NOW" = "yes" ]; then
            log "Rebooting system in 10 seconds..."
            sleep 10
            sudo reboot
        else
            log "Please reboot the system manually when convenient"
        fi
    fi
    
    return 0
}

# Function to schedule reboot
schedule_reboot() {
    local reboot_time="$1"
    
    if [ -z "$reboot_time" ]; then
        reboot_time="$REBOOT_TIME"
    fi
    
    log "Scheduling system reboot for $reboot_time..."
    sudo shutdown -c 2>/dev/null || true
    sudo shutdown -r "$reboot_time" "Scheduled reboot for system updates"
    
    log "Reboot scheduled for $reboot_time"
    log "To cancel, run: sudo shutdown -c"
}

# Function to show update status
show_update_status() {
    log "System Update Status:"
    echo ""
    
    log "Current kernel: $(uname -r)"
    log "OS Version: $(lsb_release -d | cut -f2)"
    echo ""
    
    if [ -f /var/run/reboot-required ]; then
        warning "REBOOT REQUIRED!"
    else
        log "No reboot required"
    fi
    echo ""
    
    log "Checking for available updates..."
    sudo apt-get update -qq
    
    local total_updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
    
    if [ "$total_updates" -gt 0 ]; then
        warning "$total_updates updates available ($security_updates security updates)"
        echo ""
        log "Available updates:"
        apt list --upgradable 2>/dev/null | grep upgradable
    else
        log "System is fully up to date"
    fi
}

# Function to setup fail2ban
setup_fail2ban() {
    log "Setting up fail2ban..."
    
    if command -v fail2ban-client &> /dev/null; then
        log "fail2ban is already installed"
        return 0
    fi
    
    log "Installing fail2ban..."
    sudo apt-get update
    sudo apt-get install -y fail2ban
    
    log "Configuring fail2ban..."
    sudo bash -c 'cat > /etc/fail2ban/jail.local << EOFF2B
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 86400
EOFF2B'
    
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    
    log "fail2ban installed and configured"
}

# Function to setup UFW
setup_ufw() {
    log "Setting up UFW firewall..."
    
    if ! command -v ufw &> /dev/null; then
        log "Installing UFW..."
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    log "Configuring UFW rules..."
    sudo ufw --force default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow $DOCKGE_PORT/tcp comment 'Dockge'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw --force enable
    
    log "UFW firewall configured and enabled"
    sudo ufw status verbose
}

# Function to harden SSH
harden_ssh() {
    log "Applying SSH security hardening..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local backup_config="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    sudo cp "$ssh_config" "$backup_config"
    log "SSH config backed up to: $backup_config"
    
    log "Applying SSH hardening settings..."
    
    sudo bash -c "cat >> $ssh_config << 'EOFSSH'

# Security Hardening Applied $(date)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOFSSH"
    
    log "Restarting SSH service..."
    sudo systemctl restart sshd
    
    log "SSH hardening applied successfully"
    warning "Make sure you have SSH key authentication set up before logging out!"
}

# Function to perform security audit
security_audit() {
    log "Performing security audit..."
    echo ""
    
    local issues=0
    
    log "Checking SSH configuration..."
    if sudo grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "SSH root login is enabled"
        issues=$((issues + 1))
    else
        log "✓ SSH root login is disabled"
    fi
    
    if sudo grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "SSH password authentication is enabled"
        issues=$((issues + 1))
    else
        log "✓ SSH password authentication is disabled"
    fi
    
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            log "✓ UFW firewall is active"
        else
            warning "UFW firewall is installed but not active"
            issues=$((issues + 1))
        fi
    else
        warning "UFW firewall is not installed"
        issues=$((issues + 1))
    fi
    
    if command -v fail2ban-client &> /dev/null; then
        if sudo systemctl is-active --quiet fail2ban; then
            log "✓ fail2ban is active"
        else
            warning "fail2ban is installed but not running"
            issues=$((issues + 1))
        fi
    else
        warning "fail2ban is not installed"
        issues=$((issues + 1))
    fi
    
    if dpkg -l | grep -q unattended-upgrades; then
        log "✓ unattended-upgrades is installed"
    else
        warning "unattended-upgrades is not installed"
        issues=$((issues + 1))
    fi
    
    echo ""
    if [ $issues -eq 0 ]; then
        log "Security audit completed: No issues found!"
    else
        warning "Security audit completed: $issues potential issues found"
    fi
    
    return $issues
}

# Function to show security status
show_security_status() {
    log "Security Status Report"
    echo ""
    
    security_audit
    
    echo ""
    log "Security Services Status:"
    
    if command -v fail2ban-client &> /dev/null; then
        sudo fail2ban-client status
    fi
    
    echo ""
    if command -v ufw &> /dev/null; then
        sudo ufw status verbose
    fi
}

# Function to apply security hardening
apply_security_hardening() {
    log "Applying comprehensive security hardening..."
    echo ""
    
    read -p "This will apply security hardening to your system. Continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Security hardening cancelled"
        return 1
    fi
    
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        setup_fail2ban
    fi
    
    if [ "$UFW_ENABLED" = "true" ]; then
        setup_ufw
    fi
    
    if [ "$SSH_HARDENING_ENABLED" = "true" ]; then
        warning "SSH hardening will disable password authentication and root login"
        read -p "Do you have SSH key authentication set up? (yes/no): " SSH_KEYS
        
        if [ "$SSH_KEYS" = "yes" ]; then
            harden_ssh
        else
            error "Please set up SSH keys before hardening SSH configuration"
        fi
    fi
    
    if ! dpkg -l | grep -q unattended-upgrades; then
        log "Installing unattended-upgrades..."
        sudo apt-get update
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades
    fi
    
    log "Security hardening completed!"
    echo ""
    security_audit
}

# Function to create systemd service
create_systemd_service() {
    log "Creating systemd service for auto-start on boot..."
    
    # Get the absolute path of this script - multiple methods for compatibility
    local script_path=""
    
    # Method 1: Use BASH_SOURCE
    if [ -n "${BASH_SOURCE[0]}" ]; then
        script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    # Method 2: Use $0
    elif [ -n "$0" ]; then
        script_path="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    # Method 3: Search for the script
    else
        script_path=$(find /opt -name "server_helper_setup.sh" 2>/dev/null | head -1)
    fi
    
    # Validate script path
    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
        error "Cannot determine script path automatically"
        echo ""
        read -p "Enter the full path to this script (e.g., /opt/Server-Helper/server_helper_setup.sh): " script_path
        
        if [ ! -f "$script_path" ]; then
            error "File not found: $script_path"
            return 1
        fi
    fi
    
    log "Script path: $script_path"
    
    local service_name="server-helper"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log "Creating service file: $service_file"
    
    sudo bash -c "cat > $service_file << EOFSERV
[Unit]
Description=Server Helper Monitoring Service
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=root
ExecStart=$script_path monitor
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERV"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    
    log "Systemd service created and enabled successfully!"
    log "Service name: $service_name"
    echo ""
    log "Useful commands:"
    log "  Start:   sudo systemctl start $service_name"
    log "  Stop:    sudo systemctl stop $service_name"
    log "  Status:  sudo systemctl status $service_name"
    log "  Logs:    sudo journalctl -u $service_name -f"
    
    return 0
}

# Function to remove systemd service
remove_systemd_service() {
    local service_name="server-helper"
    
    log "Removing systemd service..."
    
    sudo systemctl stop "$service_name" 2>/dev/null || true
    sudo systemctl disable "$service_name" 2>/dev/null || true
    sudo rm "/etc/systemd/system/${service_name}.service" 2>/dev/null || true
    sudo systemctl daemon-reload
    
    log "Systemd service removed successfully!"
}

# Function to show service status
show_service_status() {
    local service_name="server-helper"
    
    log "Service Status:"
    echo ""
    
    if sudo systemctl list-unit-files | grep -q "$service_name"; then
        sudo systemctl status "$service_name" --no-pager
        echo ""
        log "Recent logs:"
        sudo journalctl -u "$service_name" -n 20 --no-pager
    else
        warning "Service is not installed"
        log "Run '$0 enable-autostart' to create the service"
    fi
}

# Function to start service
start_service_now() {
    local service_name="server-helper"
    
    if ! sudo systemctl list-unit-files | grep -q "$service_name"; then
        error "Service is not installed. Run '$0 enable-autostart' first"
        return 1
    fi
    
    log "Starting service..."
    sudo systemctl start "$service_name"
    sleep 2
    sudo systemctl status "$service_name" --no-pager
}

# Function to stop service
stop_service() {
    local service_name="server-helper"
    
    log "Stopping service..."
    sudo systemctl stop "$service_name"
    sudo systemctl status "$service_name" --no-pager
}

# Function to edit config
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log "Opening configuration file: $CONFIG_FILE"
    
    if command -v nano &> /dev/null; then
        sudo nano "$CONFIG_FILE"
    elif command -v vim &> /dev/null; then
        sudo vim "$CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        sudo vi "$CONFIG_FILE"
    else
        log "Please edit manually: $CONFIG_FILE"
    fi
}

# Function to show config
show_config() {
    log "Current Configuration:"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log "Configuration file: $CONFIG_FILE"
    echo ""
    
    cat "$CONFIG_FILE" | while IFS= read -r line; do
        if [[ $line =~ PASSWORD|_URL ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            echo "$key=\"***REDACTED***\""
        else
            echo "$line"
        fi
    done
}

# Function to validate config
validate_config() {
    log "Validating configuration..."
    local errors=0
    
    if [ "$NAS_USERNAME" = "your_username" ] || [ "$NAS_PASSWORD" = "your_password" ]; then
        error "NAS credentials are not configured"
        errors=$((errors + 1))
    fi
    
    if [ -z "$NAS_MOUNT_POINT" ]; then
        error "NAS_MOUNT_POINT is not set"
        errors=$((errors + 1))
    fi
    
    if [ $errors -eq 0 ]; then
        log "Configuration validation passed!"
        return 0
    else
        error "Configuration validation failed with $errors errors"
        return 1
    fi
}

# Function to monitor services
monitor_services() {
    log "Starting monitoring service (checking every 2 minutes)..."
    
    backup_dockge
    
    BACKUP_INTERVAL=180
    UPDATE_INTERVAL=$((UPDATE_CHECK_INTERVAL * 30))
    SECURITY_INTERVAL=$((SECURITY_CHECK_INTERVAL * 30))
    CHECK_COUNT=0
    UPDATE_COUNT=0
    SECURITY_COUNT=0
    
    while true; do
        sleep 120
        CHECK_COUNT=$((CHECK_COUNT + 1))
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        SECURITY_COUNT=$((SECURITY_COUNT + 1))
        
        NAS_OK=true
        DOCKGE_OK=true
        
        DISK_USAGE=$(check_disk_usage)
        if [ "$DISK_USAGE" -ge "$DISK_CLEANUP_THRESHOLD" ] && [ "$AUTO_CLEANUP_ENABLED" = "true" ]; then
            warning "Disk usage at ${DISK_USAGE}%"
            clean_disk
        fi
        
        if [ "$UPDATE_COUNT" -ge "$UPDATE_INTERVAL" ] && [ "$AUTO_UPDATE_ENABLED" = "true" ]; then
            log "Performing scheduled system update..."
            if check_updates; then
                update_system
                local update_result=$?
                
                if [ $update_result -eq 2 ] && [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
                    schedule_reboot "$REBOOT_TIME"
                fi
            fi
            UPDATE_COUNT=0
        fi
        
        if [ "$SECURITY_COUNT" -ge "$SECURITY_INTERVAL" ] && [ "$SECURITY_CHECK_ENABLED" = "true" ]; then
            log "Performing scheduled security audit..."
            security_audit
            SECURITY_COUNT=0
        fi
        
        if ! check_nas_heartbeat; then
            NAS_OK=false
            error "NAS heartbeat failed - attempting to remount..."
            
            # Unmount all NAS shares
            if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
                for nas_config in "${NAS_ARRAY[@]}"; do
                    IFS=':' read -r nas_ip nas_share mount_point username password <<< "$nas_config"
                    [ -n "$mount_point" ] && sudo umount -f "$mount_point" 2>/dev/null || true
                done
            else
                sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null || true
            fi
            
            # Attempt remount
            if mount_nas; then
                log "NAS remounted successfully"
                NAS_OK=true
            fi
        fi
        
        if ! check_dockge_heartbeat; then
            DOCKGE_OK=false
            error "Dockge heartbeat failed - attempting to restart..."
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
            sleep 10
            if check_dockge_heartbeat; then
                log "Dockge restarted successfully"
                DOCKGE_OK=true
            fi
        fi
        
        if [ -n "$UPTIME_KUMA_SYSTEM_URL" ]; then
            if [ "$NAS_OK" = true ] && [ "$DOCKGE_OK" = true ]; then
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=up&msg=OK" > /dev/null 2>&1 || true
            else
                local failed=""
                [ "$NAS_OK" = false ] && failed="NAS"
                [ "$DOCKGE_OK" = false ] && failed="${failed:+$failed,}Dockge"
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=down&msg=Failed:${failed}" > /dev/null 2>&1 || true
            fi
        fi
        
        if [ $CHECK_COUNT -ge $BACKUP_INTERVAL ]; then
            log "Performing scheduled backup..."
            backup_dockge
            CHECK_COUNT=0
        fi
        
        log "Heartbeat OK - Disk: ${DISK_USAGE}% | Backup: $((BACKUP_INTERVAL - CHECK_COUNT)) | Updates: $((UPDATE_INTERVAL - UPDATE_COUNT)) | Security: $((SECURITY_INTERVAL - SECURITY_COUNT))"
    done
}

# Main execution
main() {
    log "Starting Server Helper setup script..."
    
    if [ -n "$NEW_HOSTNAME" ]; then
        set_hostname "$NEW_HOSTNAME"
    fi
    
    # Attempt NAS mount (optional unless NAS_MOUNT_REQUIRED=true)
    if ! mount_nas; then
        if [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
            error "Setup failed: NAS mounting is required but failed"
            error "Fix NAS configuration or set NAS_MOUNT_REQUIRED=false"
            exit 1
        fi
    fi
    
    install_docker
    install_dockge
    start_dockge
    
    echo ""
    log "═══════════════════════════════════════════════════════"
    log "            Setup Complete!"
    log "═══════════════════════════════════════════════════════"
    log "Current hostname: $(hostname)"
    log "Dockge: http://localhost:$DOCKGE_PORT"
    
    # Display mounted NAS shares
    local mounted_count=0
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        log ""
        log "NAS Shares Status:"
        for nas_config in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r nas_ip nas_share mount_point username password <<< "$nas_config"
            if [ -n "$mount_point" ]; then
                if mountpoint -q "$mount_point" 2>/dev/null; then
                    log "  ✓ $mount_point (//$nas_ip/$nas_share) - MOUNTED"
                    mounted_count=$((mounted_count + 1))
                else
                    warning "  ✗ $mount_point (//$nas_ip/$nas_share) - NOT MOUNTED"
                fi
            fi
        done
    else
        if mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
            log "NAS: $NAS_MOUNT_POINT - MOUNTED"
            mounted_count=1
        else
            warning "NAS: $NAS_MOUNT_POINT - NOT MOUNTED"
        fi
    fi
    
    if [ $mounted_count -eq 0 ]; then
        echo ""
        warning "╔════════════════════════════════════════════════════╗"
        warning "║  No NAS shares mounted - backups will be local!    ║"
        warning "║  Fix NAS config and run: ./script.sh mount-nas     ║"
        warning "╚════════════════════════════════════════════════════╝"
    fi
    
    echo ""
    log "═══════════════════════════════════════════════════════"
    
    echo ""
    
    read -p "Enable auto-start on boot? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_systemd_service
        echo ""
        read -p "Start monitoring now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_service_now
        fi
    else
        read -p "Start monitoring now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            monitor_services
        fi
    fi
}

# Handle arguments
case "$1" in
    monitor) monitor_services ;;
    backup) backup_dockge ;;
    restore) restore_dockge ;;
    list-backups) ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups" ;;
    set-hostname) set_hostname "$2" ;;
    show-hostname) log "Hostname: $(hostname)" ;;
    clean-disk) clean_disk ;;
    disk-space) show_disk_space ;;
    update) update_system ;;
    full-upgrade) full_upgrade ;;
    check-updates) check_updates; show_update_status ;;
    update-status) show_update_status ;;
    schedule-reboot) schedule_reboot "${2:-$REBOOT_TIME}" ;;
    security-audit) security_audit ;;
    security-status) show_security_status ;;
    security-harden) apply_security_hardening ;;
    setup-fail2ban) setup_fail2ban ;;
    setup-ufw) setup_ufw ;;
    harden-ssh) harden_ssh ;;
    enable-autostart) create_systemd_service ;;
    disable-autostart) remove_systemd_service ;;
    service-status) show_service_status ;;
    start) start_service_now ;;
    stop) stop_service ;;
    restart) stop_service; sleep 2; start_service_now ;;
    logs) sudo journalctl -u server-helper -f ;;
    edit-config) edit_config ;;
    show-config) show_config ;;
    validate-config) validate_config ;;
    list-nas) 
        log "Configured NAS shares:"
        if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
            for i in "${!NAS_ARRAY[@]}"; do
                IFS=':' read -r nas_ip nas_share mount_point username password <<< "${NAS_ARRAY[$i]}"
                local status="not mounted"
                local symbol="✗"
                if mountpoint -q "$mount_point" 2>/dev/null; then
                    status="MOUNTED"
                    symbol="✓"
                fi
                echo "$((i+1)). $symbol //$nas_ip/$nas_share -> $mount_point ($status)"
            done
        else
            local status="not mounted"
            local symbol="✗"
            if mountpoint -q "$NAS_MOUNT_POINT" 2>/dev/null; then
                status="MOUNTED"
                symbol="✓"
            fi
            echo "1. $symbol //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT ($status)"
        fi
        ;;
    mount-nas)
        log "Attempting to mount all configured NAS shares..."
        mount_nas
        ;;
    *) main ;;
esac
