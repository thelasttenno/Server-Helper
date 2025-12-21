#!/bin/bash

# NAS and Dockge Setup Script for Ubuntu 24.04.3 LTS
# This script mounts NAS, installs Docker/Dockge, and monitors both services

set -e

# Configuration file path
CONFIG_FILE="${CONFIG_FILE:-$(dirname "$0")/nas-dockge.conf}"

# Load configuration from file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    warning "Configuration file not found: $CONFIG_FILE"
    log "Creating default configuration file..."
    cat > "$CONFIG_FILE" << 'EOF'
# NAS and Dockge Configuration File
# Edit this file with your settings

# NAS Configuration
NAS_IP="192.168.1.100"              # Your NAS IP address
NAS_SHARE="share"                    # Your NAS share name
NAS_MOUNT_POINT="/mnt/nas"          # Local mount point
NAS_USERNAME="your_username"         # NAS username
NAS_PASSWORD="your_password"         # NAS password

# Dockge Configuration
DOCKGE_PORT="5001"                   # Dockge web interface port
DOCKGE_DATA_DIR="/opt/dockge"       # Dockge data directory
BACKUP_DIR="$NAS_MOUNT_POINT/dockge_backups"  # Backup location on NAS
BACKUP_RETENTION_DAYS="30"          # Keep backups for this many days

# System Configuration
NEW_HOSTNAME=""                      # Set hostname (leave empty to skip)

# Uptime Kuma Push Monitor URLs (leave empty to disable)
UPTIME_KUMA_NAS_URL=""              # Push URL for NAS monitoring
UPTIME_KUMA_DOCKGE_URL=""           # Push URL for Dockge monitoring
UPTIME_KUMA_SYSTEM_URL=""           # Push URL for overall system monitoring

# Disk Cleanup Settings
DISK_CLEANUP_THRESHOLD="80"         # Run cleanup when disk usage exceeds this percentage
AUTO_CLEANUP_ENABLED="true"         # Enable automatic cleanup during monitoring

# System Update Settings
AUTO_UPDATE_ENABLED="false"         # Enable automatic system updates during monitoring
UPDATE_CHECK_INTERVAL="24"          # Check for updates every X hours (24 = daily)
AUTO_REBOOT_ENABLED="false"         # Automatically reboot if kernel update requires it
REBOOT_TIME="03:00"                 # Time to schedule reboot (24hr format HH:MM)

# Security and Compliance Settings
SECURITY_CHECK_ENABLED="true"       # Enable security checks during monitoring
SECURITY_CHECK_INTERVAL="12"        # Check security every X hours (12 = twice daily)
FAIL2BAN_ENABLED="false"            # Install and configure fail2ban
UFW_ENABLED="false"                 # Enable UFW firewall with basic rules
SSH_HARDENING_ENABLED="false"       # Apply SSH security hardening
EOF
    chmod 600 "$CONFIG_FILE"
    error "Please edit $CONFIG_FILE with your settings and run again"
    exit 1
fi

# Configuration - EDIT THESE VALUES IN nas-dockge.conf FILE
# The values below are defaults if not set in config file
NAS_IP="${NAS_IP:-192.168.1.100}"
NAS_SHARE="${NAS_SHARE:-share}"
NAS_MOUNT_POINT="${NAS_MOUNT_POINT:-/mnt/nas}"
NAS_USERNAME="${NAS_USERNAME:-your_username}"
NAS_PASSWORD="${NAS_PASSWORD:-your_password}"
DOCKGE_PORT="${DOCKGE_PORT:-5001}"
DOCKGE_DATA_DIR="${DOCKGE_DATA_DIR:-/opt/dockge}"
BACKUP_DIR="${BACKUP_DIR:-$NAS_MOUNT_POINT/dockge_backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
NEW_HOSTNAME="${NEW_HOSTNAME:-}"

# Uptime Kuma Push Monitor URLs (leave empty to disable)
UPTIME_KUMA_NAS_URL="${UPTIME_KUMA_NAS_URL:-}"
UPTIME_KUMA_DOCKGE_URL="${UPTIME_KUMA_DOCKGE_URL:-}"
UPTIME_KUMA_SYSTEM_URL="${UPTIME_KUMA_SYSTEM_URL:-}"

# Disk Cleanup Settings
DISK_CLEANUP_THRESHOLD="${DISK_CLEANUP_THRESHOLD:-80}"
AUTO_CLEANUP_ENABLED="${AUTO_CLEANUP_ENABLED:-true}"

# System Update Settings
AUTO_UPDATE_ENABLED="${AUTO_UPDATE_ENABLED:-false}"
UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-24}"
AUTO_REBOOT_ENABLED="${AUTO_REBOOT_ENABLED:-false}"
REBOOT_TIME="${REBOOT_TIME:-03:00}"

# Security and Compliance Settings
SECURITY_CHECK_ENABLED="${SECURITY_CHECK_ENABLED:-true}"
SECURITY_CHECK_INTERVAL="${SECURITY_CHECK_INTERVAL:-12}"
FAIL2BAN_ENABLED="${FAIL2BAN_ENABLED:-false}"
UFW_ENABLED="${UFW_ENABLED:-false}"
SSH_HARDENING_ENABLED="${SSH_HARDENING_ENABLED:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to mount NAS
mount_nas() {
    log "Setting up NAS mount..."
    
    # Install cifs-utils if not present
    if ! dpkg -l | grep -q cifs-utils; then
        log "Installing cifs-utils..."
        sudo apt-get update
        sudo apt-get install -y cifs-utils
    fi
    
    # Create mount point if it doesn't exist
    if [ ! -d "$NAS_MOUNT_POINT" ]; then
        log "Creating mount point: $NAS_MOUNT_POINT"
        sudo mkdir -p "$NAS_MOUNT_POINT"
    fi
    
    # Check if already mounted
    if mountpoint -q "$NAS_MOUNT_POINT"; then
        log "NAS is already mounted at $NAS_MOUNT_POINT"
        return 0
    fi
    
    # Create credentials file
    CREDS_FILE="/root/.nascreds"
    sudo bash -c "cat > $CREDS_FILE << EOF
username=$NAS_USERNAME
password=$NAS_PASSWORD
EOF"
    sudo chmod 600 "$CREDS_FILE"
    
    # Mount the NAS
    log "Mounting NAS from //$NAS_IP/$NAS_SHARE to $NAS_MOUNT_POINT"
    sudo mount -t cifs "//$NAS_IP/$NAS_SHARE" "$NAS_MOUNT_POINT" \
        -o credentials="$CREDS_FILE",uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775
    
    # Add to fstab for persistence
    if ! grep -q "$NAS_MOUNT_POINT" /etc/fstab; then
        log "Adding NAS mount to /etc/fstab"
        echo "//$NAS_IP/$NAS_SHARE $NAS_MOUNT_POINT cifs credentials=$CREDS_FILE,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775,_netdev 0 0" | sudo tee -a /etc/fstab
    fi
    
    log "NAS mounted successfully"
}

# Function to set hostname
set_hostname() {
    local hostname="$1"
    
    if [ -z "$hostname" ]; then
        error "Hostname cannot be empty"
        return 1
    fi
    
    # Validate hostname format
    if ! echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?

# Function to install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed ($(docker --version))"
        return 0
    fi
    
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update and install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed successfully"
}

# Function to install Dockge
install_dockge() {
    log "Setting up Dockge..."
    
    # Create Dockge directories
    sudo mkdir -p "$DOCKGE_DATA_DIR"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
    # Create docker-compose.yml for Dockge
    sudo bash -c "cat > $DOCKGE_DATA_DIR/docker-compose.yml << 'EOF'
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
EOF"
    
    log "Dockge configuration created"
}

# Function to start Dockge
start_dockge() {
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    log "Dockge started successfully on port $DOCKGE_PORT"
}

# Function to check NAS heartbeat
check_nas_heartbeat() {
    local status=0
    
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted at $NAS_MOUNT_POINT"
        status=1
    elif ! timeout 5 ls "$NAS_MOUNT_POINT" > /dev/null 2>&1; then
        error "NAS mount point is not responding"
        status=1
    fi
    
    # Send heartbeat to Uptime Kuma if configured
    if [ -n "$UPTIME_KUMA_NAS_URL" ]; then
        if [ $status -eq 0 ]; then
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1 || true
        else
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=down&msg=NAS%20Error" > /dev/null 2>&1 || true
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
    
    # Send heartbeat to Uptime Kuma if configured
    if [ -n "$UPTIME_KUMA_DOCKGE_URL" ]; then
        if [ $status -eq 0 ]; then
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=up&msg=OK&ping=" > /dev/null 2>&1 || true
        else
            curl -fsS -m 10 "${UPTIME_KUMA_DOCKGE_URL}?status=down&msg=Dockge%20Error" > /dev/null 2>&1 || true
        fi
    fi
    
    return $status
}

# Function to backup Dockge stacks to NAS
backup_dockge() {
    log "Starting Dockge backup..."
    
    # Check if NAS is mounted
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted. Cannot perform backup."
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Create timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="dockge_backup_$TIMESTAMP.tar.gz"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log "Creating backup: $BACKUP_NAME"
    
    # Backup stacks and data directories
    if sudo tar -czf "$BACKUP_PATH" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        log "Backup created successfully: $BACKUP_PATH"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        # Clean up old backups
        log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
        find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
        
        # Count remaining backups
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f | wc -l)
        log "Total backups retained: $BACKUP_COUNT"
        
        return 0
    else
        error "Failed to create backup"
        return 1
    fi
}

# Function to restore Dockge from backup
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
    
    # Confirm restoration
    warning "This will overwrite current Dockge stacks and data!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Restore cancelled"
        return 1
    fi
    
    # Stop Dockge
    log "Stopping Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Backup current state just in case
    EMERGENCY_BACKUP="$DOCKGE_DATA_DIR/emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating emergency backup of current state..."
    sudo tar -czf "$EMERGENCY_BACKUP" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || true
    
    # Restore from backup
    log "Restoring from backup..."
    sudo rm -rf "$DOCKGE_DATA_DIR/stacks" "$DOCKGE_DATA_DIR/data"
    sudo tar -xzf "$BACKUP_FILE" -C "$DOCKGE_DATA_DIR"
    
    # Restart Dockge
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
    
    local cleaned=false
    
    # Clean apt cache
    log "Cleaning apt cache..."
    sudo apt-get clean
    sudo apt-get autoclean
    cleaned=true
    
    # Remove old kernels (keep current and one previous)
    log "Removing old kernels..."
    sudo apt-get autoremove --purge -y
    cleaned=true
    
    # Clean systemd journal logs (keep last 7 days)
    log "Cleaning systemd journal logs (keeping last 7 days)..."
    sudo journalctl --vacuum-time=7d
    cleaned=true
    
    # Clean Docker system
    if command -v docker &> /dev/null; then
        log "Cleaning Docker system (removing unused containers, images, and volumes)..."
        
        # Remove stopped containers
        stopped_containers=$(sudo docker ps -aq -f status=exited 2>/dev/null | wc -l)
        if [ "$stopped_containers" -gt 0 ]; then
            log "Removing $stopped_containers stopped containers..."
            sudo docker container prune -f
        fi
        
        # Remove dangling images
        dangling_images=$(sudo docker images -f "dangling=true" -q 2>/dev/null | wc -l)
        if [ "$dangling_images" -gt 0 ]; then
            log "Removing $dangling_images dangling images..."
            sudo docker image prune -f
        fi
        
        # Remove unused volumes
        log "Removing unused Docker volumes..."
        sudo docker volume prune -f
        
        # Remove unused networks
        log "Removing unused Docker networks..."
        sudo docker network prune -f
        
        # Remove build cache
        log "Removing Docker build cache..."
        sudo docker builder prune -f
        
        cleaned=true
    fi
    
    # Clean thumbnail cache
    if [ -d "$HOME/.cache/thumbnails" ]; then
        log "Cleaning thumbnail cache..."
        rm -rf "$HOME/.cache/thumbnails/*"
        cleaned=true
    fi
    
    # Clean temporary files
    log "Cleaning temporary files..."
    sudo rm -rf /tmp/*
    sudo rm -rf /var/tmp/*
    cleaned=true
    
    # Clean old log files
    log "Cleaning old log files..."
    sudo find /var/log -type f -name "*.log.*" -delete
    sudo find /var/log -type f -name "*.gz" -delete
    cleaned=true
    
    if [ "$cleaned" = true ]; then
        local final_usage=$(check_disk_usage)
        local freed=$((initial_usage - final_usage))
        log "Disk cleanup completed!"
        log "Initial usage: ${initial_usage}%"
        log "Final usage: ${final_usage}%"
        log "Space freed: ${freed}%"
    else
        log "No cleanup performed"
    fi
    
    return 0
}

# Function to show disk space information
show_disk_space() {
    log "Disk Space Information:"
    echo ""
    df -h | grep -E '^/dev/|Filesystem'
    echo ""
    log "Largest directories in /:"
    sudo du -h --max-depth=1 / 2>/dev/null | sort -hr | head -10
    echo ""
    log "Docker disk usage:"
    if command -v docker &> /dev/null; then
        sudo docker system df
    else
        echo "Docker not installed"
    fi
}

# Function to check for system updates
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

# Function to perform system update
update_system() {
    log "Starting system update and upgrade..."
    
    local kernel_before=$(uname -r)
    
    # Update package lists
    log "Updating package lists..."
    sudo apt-get update
    
    # Show what will be upgraded
    log "Packages to be upgraded:"
    apt list --upgradable 2>/dev/null | grep upgradable
    echo ""
    
    # Perform upgrade
    log "Upgrading packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    
    # Perform dist-upgrade for kernel and major updates
    log "Performing distribution upgrade..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
    
    # Clean up
    log "Cleaning up..."
    sudo apt-get autoremove -y
    sudo apt-get autoclean
    
    local kernel_after=$(uname -r)
    
    log "System update completed successfully!"
    log "Kernel before: $kernel_before"
    log "Kernel after: $kernel_after"
    
    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        warning "System reboot is required!"
        
        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs
        fi
        
        return 2  # Return code 2 means reboot required
    fi
    
    return 0
}

# Function to perform full system upgrade
full_upgrade() {
    log "Starting full system upgrade..."
    
    read -p "This will perform a full system upgrade. Continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Upgrade cancelled"
        return 1
    fi
    
    # Backup important configs before major upgrade
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
    
    # Cancel any existing reboot
    sudo shutdown -c 2>/dev/null || true
    
    # Schedule new reboot
    sudo shutdown -r "$reboot_time" "Scheduled reboot for system updates"
    
    log "Reboot scheduled for $reboot_time"
    log "To cancel, run: sudo shutdown -c"
}

# Function to show system update status
show_update_status() {
    log "System Update Status:"
    echo ""
    
    log "Current kernel: $(uname -r)"
    log "OS Version: $(lsb_release -d | cut -f2)"
    echo ""
    
    if [ -f /var/run/reboot-required ]; then
        warning "REBOOT REQUIRED!"
        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requiring reboot:"
            cat /var/run/reboot-required.pkgs
        fi
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

# Function to install and configure fail2ban
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
    sudo bash -c 'cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 86400
EOF'
    
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    
    log "fail2ban installed and configured"
}

# Function to setup UFW firewall
setup_ufw() {
    log "Setting up UFW firewall..."
    
    if command -v ufw &> /dev/null; then
        log "UFW is already installed"
    else
        log "Installing UFW..."
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    log "Configuring UFW rules..."
    
    # Default policies
    sudo ufw --force default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH (important!)
    sudo ufw allow ssh
    
    # Allow Dockge
    sudo ufw allow $DOCKGE_PORT/tcp comment 'Dockge'
    
    # Allow common services
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    
    # Enable UFW
    sudo ufw --force enable
    
    log "UFW firewall configured and enabled"
    sudo ufw status verbose
}

# Function to harden SSH configuration
harden_ssh() {
    log "Applying SSH security hardening..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local backup_config="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup original config
    sudo cp "$ssh_config" "$backup_config"
    log "SSH config backed up to: $backup_config"
    
    # Apply hardening settings
    log "Applying SSH hardening settings..."
    
    sudo bash -c "cat >> $ssh_config << 'EOF'

# Security Hardening Applied $(date)
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
Protocol 2
EOF"
    
    # Restart SSH service
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
    
    # Check for root login
    log "Checking SSH configuration..."
    if sudo grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "SSH root login is enabled"
        issues=$((issues + 1))
    else
        log "✓ SSH root login is disabled"
    fi
    
    # Check password authentication
    if sudo grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "SSH password authentication is enabled"
        issues=$((issues + 1))
    else
        log "✓ SSH password authentication is disabled"
    fi
    
    # Check firewall
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
    
    # Check fail2ban
    if command -v fail2ban-client &> /dev/null; then
        if sudo systemctl is-active --quiet fail2ban; then
            log "✓ fail2ban is active"
            local banned=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')
            log "  Currently banned IPs: ${banned:-0}"
        else
            warning "fail2ban is installed but not running"
            issues=$((issues + 1))
        fi
    else
        warning "fail2ban is not installed"
        issues=$((issues + 1))
    fi
    
    # Check for world-writable files
    log "Checking for world-writable files in sensitive directories..."
    local writable=$(sudo find /etc /usr/bin /usr/sbin -type f -perm -002 2>/dev/null | wc -l)
    if [ "$writable" -gt 0 ]; then
        warning "Found $writable world-writable files in sensitive directories"
        issues=$((issues + 1))
    else
        log "✓ No world-writable files in sensitive directories"
    fi
    
    # Check for users with empty passwords
    log "Checking for users with empty passwords..."
    local empty_pass=$(sudo awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [ "$empty_pass" -gt 0 ]; then
        warning "Found $empty_pass users with empty passwords"
        issues=$((issues + 1))
    else
        log "✓ No users with empty passwords"
    fi
    
    # Check unattended-upgrades
    if dpkg -l | grep -q unattended-upgrades; then
        log "✓ unattended-upgrades is installed"
    else
        warning "unattended-upgrades is not installed (automatic security updates disabled)"
        issues=$((issues + 1))
    fi
    
    # Check for listening services
    log "Checking for listening network services..."
    echo ""
    log "Listening services:"
    sudo ss -tulpn | grep LISTEN
    echo ""
    
    # Check Docker security
    if command -v docker &> /dev/null; then
        log "Checking Docker security..."
        
        # Check Docker socket permissions
        if [ -S /var/run/docker.sock ]; then
            local socket_perms=$(stat -c %a /var/run/docker.sock)
            if [ "$socket_perms" != "660" ]; then
                warning "Docker socket has unusual permissions: $socket_perms"
                issues=$((issues + 1))
            else
                log "✓ Docker socket permissions are correct"
            fi
        fi
        
        # Check for containers running as root
        local root_containers=$(sudo docker ps --format '{{.ID}}' | xargs -I {} sudo docker inspect {} --format '{{.Config.User}}' | grep -c '^

# Function to run monitoring loop
monitor_services() {
    log "Starting monitoring service (checking every 2 minutes)..."
    log "Press Ctrl+C to stop monitoring"
    
    # Perform initial backup
    backup_dockge
    
    # Track backup timing (backup every 6 hours = 180 checks at 2 min intervals)
    BACKUP_INTERVAL=180
    # Track update timing (default 24 hours = 720 checks at 2 min intervals)
    UPDATE_INTERVAL=$((UPDATE_CHECK_INTERVAL * 30))
    # Track security check timing (default 12 hours = 360 checks at 2 min intervals)
    SECURITY_INTERVAL=$((SECURITY_CHECK_INTERVAL * 30))
    CHECK_COUNT=0
    UPDATE_COUNT=0
    SECURITY_COUNT=0
    
    while true; do
        sleep 120  # 2 minutes
        CHECK_COUNT=$((CHECK_COUNT + 1))
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        SECURITY_COUNT=$((SECURITY_COUNT + 1))
        
        NAS_OK=true
        DOCKGE_OK=true
        
        # Check disk usage
        DISK_USAGE=$(check_disk_usage)
        if [ "$DISK_USAGE" -ge "$DISK_CLEANUP_THRESHOLD" ] && [ "$AUTO_CLEANUP_ENABLED" = "true" ]; then
            warning "Disk usage at ${DISK_USAGE}% (threshold: ${DISK_CLEANUP_THRESHOLD}%)"
            log "Running automatic cleanup..."
            clean_disk
        fi
        
        # Check for system updates
        if [ "$UPDATE_COUNT" -ge "$UPDATE_INTERVAL" ] && [ "$AUTO_UPDATE_ENABLED" = "true" ]; then
            log "Performing scheduled system update check..."
            if check_updates; then
                log "Installing system updates..."
                update_system
                local update_result=$?
                
                if [ $update_result -eq 2 ]; then
                    warning "System reboot required after updates"
                    if [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
                        schedule_reboot "$REBOOT_TIME"
                    else
                        log "Automatic reboot is disabled. Please reboot manually."
                    fi
                fi
            fi
            UPDATE_COUNT=0
        fi
        
        # Perform security checks
        if [ "$SECURITY_COUNT" -ge "$SECURITY_INTERVAL" ] && [ "$SECURITY_CHECK_ENABLED" = "true" ]; then
            log "Performing scheduled security audit..."
            security_audit
            SECURITY_COUNT=0
        fi
        
        # Check NAS
        if ! check_nas_heartbeat; then
            NAS_OK=false
            error "NAS heartbeat failed - attempting to remount..."
            sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null || true
            if mount_nas; then
                log "NAS remounted successfully"
                NAS_OK=true
            else
                error "Failed to remount NAS"
            fi
        fi
        
        # Check Dockge
        if ! check_dockge_heartbeat; then
            DOCKGE_OK=false
            error "Dockge heartbeat failed - attempting to restart..."
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
            sleep 10
            if check_dockge_heartbeat; then
                log "Dockge restarted successfully"
                DOCKGE_OK=true
            else
                error "Failed to restart Dockge"
            fi
        fi
        
        # Send overall system status to Uptime Kuma
        if [ -n "$UPTIME_KUMA_SYSTEM_URL" ]; then
            if [ "$NAS_OK" = true ] && [ "$DOCKGE_OK" = true ]; then
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=up&msg=All%20Services%20OK&ping=" > /dev/null 2>&1 || true
            else
                local failed_services=""
                [ "$NAS_OK" = false ] && failed_services="NAS"
                [ "$DOCKGE_OK" = false ] && failed_services="${failed_services:+$failed_services,}Dockge"
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=down&msg=Failed:${failed_services}" > /dev/null 2>&1 || true
            fi
        fi
        
        # Perform backup every 6 hours
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
    log "Starting NAS and Dockge setup script..."
    
    # Check if running as root for some operations
    if [ "$EUID" -ne 0 ]; then
        log "This script requires sudo privileges for certain operations"
    fi
    
    # Set hostname if configured
    if [ -n "$NEW_HOSTNAME" ]; then
        set_hostname "$NEW_HOSTNAME"
    fi
    
    # Mount NAS
    mount_nas
    
    # Install Docker if needed
    install_docker
    
    # Install/Setup Dockge
    install_dockge
    
    # Start Dockge
    start_dockge
    
    log "Setup complete!"
    log "Current hostname: $(hostname)"
    log "Dockge is available at: http://localhost:$DOCKGE_PORT"
    log "NAS is mounted at: $NAS_MOUNT_POINT"
    echo ""
    
    # Ask about auto-start on boot
    read -p "Do you want to enable auto-start on boot? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_systemd_service
        echo ""
        read -p "Start the monitoring service now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            start_service_now
        fi
    else
        # Ask user if they want to start monitoring manually
        read -p "Do you want to start the monitoring service now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            monitor_services
        else
            log "You can run this script again with 'monitor' argument to start monitoring"
            log "Or enable auto-start with: $0 enable-autostart"
        fi
    fi
}

# Handle arguments
if [ "$1" == "monitor" ]; then
    monitor_services
elif [ "$1" == "backup" ]; then
    backup_dockge
elif [ "$1" == "restore" ]; then
    restore_dockge
elif [ "$1" == "list-backups" ]; then
    log "Available backups in $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups found"
elif [ "$1" == "set-hostname" ]; then
    if [ -z "$2" ]; then
        error "Usage: $0 set-hostname <new_hostname>"
        exit 1
    fi
    set_hostname "$2"
elif [ "$1" == "show-hostname" ]; then
    log "Current hostname: $(hostname)"
    log "Fully qualified domain name: $(hostname -f)"
elif [ "$1" == "clean-disk" ]; then
    clean_disk
elif [ "$1" == "disk-space" ]; then
    show_disk_space
elif [ "$1" == "update" ]; then
    update_system
elif [ "$1" == "full-upgrade" ]; then
    full_upgrade
elif [ "$1" == "check-updates" ]; then
    check_updates
    show_update_status
elif [ "$1" == "update-status" ]; then
    show_update_status
elif [ "$1" == "schedule-reboot" ]; then
    if [ -n "$2" ]; then
        schedule_reboot "$2"
    else
        schedule_reboot
    fi
elif [ "$1" == "security-audit" ]; then
    security_audit
elif [ "$1" == "security-status" ]; then
    show_security_status
elif [ "$1" == "security-harden" ]; then
    apply_security_hardening
elif [ "$1" == "setup-fail2ban" ]; then
    setup_fail2ban
elif [ "$1" == "setup-ufw" ]; then
    setup_ufw
elif [ "$1" == "harden-ssh" ]; then
    harden_ssh
elif [ "$1" == "enable-autostart" ]; then
    create_systemd_service
elif [ "$1" == "disable-autostart" ]; then
    remove_systemd_service
elif [ "$1" == "service-status" ]; then
    show_service_status
elif [ "$1" == "start" ]; then
    start_service_now
elif [ "$1" == "stop" ]; then
    stop_service
elif [ "$1" == "restart" ]; then
    stop_service
    sleep 2
    start_service_now
elif [ "$1" == "logs" ]; then
    log "Showing service logs (Ctrl+C to exit)..."
    sudo journalctl -u nas-dockge-monitor -f
elif [ "$1" == "edit-config" ]; then
    edit_config
elif [ "$1" == "show-config" ]; then
    show_config
elif [ "$1" == "validate-config" ]; then
    validate_config
else
    main
fi; then
        error "Invalid hostname format. Use only letters, numbers, and hyphens. Must start and end with alphanumeric."
        return 1
    fi
    
    local current_hostname=$(hostname)
    
    if [ "$current_hostname" == "$hostname" ]; then
        log "Hostname is already set to: $hostname"
        return 0
    fi
    
    log "Changing hostname from '$current_hostname' to '$hostname'..."
    
    # Set the hostname
    sudo hostnamectl set-hostname "$hostname"
    
    # Update /etc/hosts
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
    
    # Add entry if it doesn't exist
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$hostname" | sudo tee -a /etc/hosts
    fi
    
    log "Hostname changed successfully to: $hostname"
    log "New hostname will be fully active after reboot"
    
    return 0
}

# Function to install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed ($(docker --version))"
        return 0
    fi
    
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update and install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed successfully"
}

# Function to install Dockge
install_dockge() {
    log "Setting up Dockge..."
    
    # Create Dockge directories
    sudo mkdir -p "$DOCKGE_DATA_DIR"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
    # Create docker-compose.yml for Dockge
    sudo bash -c "cat > $DOCKGE_DATA_DIR/docker-compose.yml << 'EOF'
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
EOF"
    
    log "Dockge configuration created"
}

# Function to start Dockge
start_dockge() {
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    log "Dockge started successfully on port $DOCKGE_PORT"
}

# Function to check NAS heartbeat
check_nas_heartbeat() {
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted at $NAS_MOUNT_POINT"
        return 1
    fi
    
    if ! timeout 5 ls "$NAS_MOUNT_POINT" > /dev/null 2>&1; then
        error "NAS mount point is not responding"
        return 1
    fi
    
    return 0
}

# Function to check Dockge heartbeat
check_dockge_heartbeat() {
    if ! sudo docker ps | grep -q dockge; then
        error "Dockge container is not running"
        return 1
    fi
    
    if ! curl -sf http://localhost:$DOCKGE_PORT > /dev/null 2>&1; then
        error "Dockge is not responding on port $DOCKGE_PORT"
        return 1
    fi
    
    return 0
}

# Function to backup Dockge stacks to NAS
backup_dockge() {
    log "Starting Dockge backup..."
    
    # Check if NAS is mounted
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted. Cannot perform backup."
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Create timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="dockge_backup_$TIMESTAMP.tar.gz"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log "Creating backup: $BACKUP_NAME"
    
    # Backup stacks and data directories
    if sudo tar -czf "$BACKUP_PATH" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        log "Backup created successfully: $BACKUP_PATH"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        # Clean up old backups
        log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
        find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
        
        # Count remaining backups
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f | wc -l)
        log "Total backups retained: $BACKUP_COUNT"
        
        return 0
    else
        error "Failed to create backup"
        return 1
    fi
}

# Function to restore Dockge from backup
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
    
    # Confirm restoration
    warning "This will overwrite current Dockge stacks and data!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Restore cancelled"
        return 1
    fi
    
    # Stop Dockge
    log "Stopping Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Backup current state just in case
    EMERGENCY_BACKUP="$DOCKGE_DATA_DIR/emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating emergency backup of current state..."
    sudo tar -czf "$EMERGENCY_BACKUP" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || true
    
    # Restore from backup
    log "Restoring from backup..."
    sudo rm -rf "$DOCKGE_DATA_DIR/stacks" "$DOCKGE_DATA_DIR/data"
    sudo tar -xzf "$BACKUP_FILE" -C "$DOCKGE_DATA_DIR"
    
    # Restart Dockge
    log "Starting Dockge..."
    sudo docker compose up -d
    
    log "Restore completed successfully!"
    log "Emergency backup saved to: $EMERGENCY_BACKUP"
    return 0
}

# Function to run monitoring loop
monitor_services() {
    log "Starting monitoring service (checking every 2 minutes)..."
    log "Press Ctrl+C to stop monitoring"
    
    # Perform initial backup
    backup_dockge
    
    # Track backup timing (backup every 6 hours = 180 checks at 2 min intervals)
    BACKUP_INTERVAL=180
    CHECK_COUNT=0
    
    while true; do
        sleep 120  # 2 minutes
        CHECK_COUNT=$((CHECK_COUNT + 1))
        
        # Check NAS
        if ! check_nas_heartbeat; then
            error "NAS heartbeat failed - attempting to remount..."
            sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null || true
            if mount_nas; then
                log "NAS remounted successfully"
            else
                error "Failed to remount NAS"
            fi
        fi
        
        # Check Dockge
        if ! check_dockge_heartbeat; then
            error "Dockge heartbeat failed - attempting to restart..."
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
            sleep 10
            if check_dockge_heartbeat; then
                log "Dockge restarted successfully"
            else
                error "Failed to restart Dockge"
            fi
        fi
        
        # Perform backup every 6 hours
        if [ $CHECK_COUNT -ge $BACKUP_INTERVAL ]; then
            log "Performing scheduled backup..."
            backup_dockge
            CHECK_COUNT=0
        fi
        
        log "Heartbeat check complete - All services OK (Next backup in $((BACKUP_INTERVAL - CHECK_COUNT)) checks)"
    done
}

# Main execution
main() {
    log "Starting NAS and Dockge setup script..."
    
    # Check if running as root for some operations
    if [ "$EUID" -ne 0 ]; then
        log "This script requires sudo privileges for certain operations"
    fi
    
    # Mount NAS
    mount_nas
    
    # Install Docker if needed
    install_docker
    
    # Install/Setup Dockge
    install_dockge
    
    # Start Dockge
    start_dockge
    
    log "Setup complete!"
    log "Dockge is available at: http://localhost:$DOCKGE_PORT"
    log "NAS is mounted at: $NAS_MOUNT_POINT"
    echo ""
    
    # Ask user if they want to start monitoring
    read -p "Do you want to start the monitoring service now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_services
    else
        log "You can run this script again with 'monitor' argument to start monitoring"
        log "Example: $0 monitor"
    fi
}

# Handle arguments
if [ "$1" == "monitor" ]; then
    monitor_services
elif [ "$1" == "backup" ]; then
    backup_dockge
elif [ "$1" == "restore" ]; then
    restore_dockge
elif [ "$1" == "list-backups" ]; then
    log "Available backups in $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups found"
else
    main
fi)
        if [ "$root_containers" -gt 0 ]; then
            warning "$root_containers containers are running as root"
            issues=$((issues + 1))
        else
            log "✓ No containers running as root"
        fi
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

# Function to apply all security hardening
apply_security_hardening() {
    log "Applying comprehensive security hardening..."
    echo ""
    
    read -p "This will apply security hardening to your system. Continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Security hardening cancelled"
        return 1
    fi
    
    # Install and configure fail2ban
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        setup_fail2ban
    fi
    
    # Setup UFW firewall
    if [ "$UFW_ENABLED" = "true" ]; then
        setup_ufw
    fi
    
    # Harden SSH
    if [ "$SSH_HARDENING_ENABLED" = "true" ]; then
        warning "SSH hardening will disable password authentication and root login"
        read -p "Do you have SSH key authentication set up? (yes/no): " SSH_KEYS
        
        if [ "$SSH_KEYS" = "yes" ]; then
            harden_ssh
        else
            error "Please set up SSH keys before hardening SSH configuration"
            log "You can add your public key to ~/.ssh/authorized_keys"
        fi
    fi
    
    # Install unattended-upgrades for automatic security updates
    if ! dpkg -l | grep -q unattended-upgrades; then
        log "Installing unattended-upgrades for automatic security updates..."
        sudo apt-get update
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades
    fi
    
    log "Security hardening completed!"
    echo ""
    
    # Run security audit
    security_audit
}

# Function to create systemd service for auto-start on boot
create_systemd_service() {
    log "Creating systemd service for auto-start on boot..."
    
    # Get the absolute path of this script
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    if [ ! -f "$script_path" ]; then
        error "Cannot determine script path"
        return 1
    fi
    
    log "Script path: $script_path"
    
    # Create systemd service file
    local service_name="nas-dockge-monitor"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log "Creating service file: $service_file"
    
    sudo bash -c "cat > $service_file << EOF
[Unit]
Description=NAS and Dockge Monitoring Service
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

# Security settings
NoNewPrivileges=false
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF"
    
    # Reload systemd daemon
    log "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    # Enable the service
    log "Enabling service to start on boot..."
    sudo systemctl enable "$service_name"
    
    log "Systemd service created and enabled successfully!"
    log "Service name: $service_name"
    echo ""
    log "Useful commands:"
    log "  Start service:   sudo systemctl start $service_name"
    log "  Stop service:    sudo systemctl stop $service_name"
    log "  Restart service: sudo systemctl restart $service_name"
    log "  View status:     sudo systemctl status $service_name"
    log "  View logs:       sudo journalctl -u $service_name -f"
    log "  Disable boot:    sudo systemctl disable $service_name"
    
    return 0
}

# Function to remove systemd service
remove_systemd_service() {
    local service_name="nas-dockge-monitor"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    log "Removing systemd service..."
    
    # Stop the service if running
    if sudo systemctl is-active --quiet "$service_name"; then
        log "Stopping service..."
        sudo systemctl stop "$service_name"
    fi
    
    # Disable the service
    if sudo systemctl is-enabled --quiet "$service_name"; then
        log "Disabling service..."
        sudo systemctl disable "$service_name"
    fi
    
    # Remove service file
    if [ -f "$service_file" ]; then
        log "Removing service file..."
        sudo rm "$service_file"
    fi
    
    # Reload systemd daemon
    sudo systemctl daemon-reload
    
    log "Systemd service removed successfully!"
}

# Function to show service status
show_service_status() {
    local service_name="nas-dockge-monitor"
    
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

# Function to start service now
start_service_now() {
    local service_name="nas-dockge-monitor"
    
    if ! sudo systemctl list-unit-files | grep -q "$service_name"; then
        error "Service is not installed. Run '$0 enable-autostart' first"
        return 1
    fi
    
    log "Starting service..."
    sudo systemctl start "$service_name"
    
    sleep 2
    
    log "Service started. Checking status..."
    sudo systemctl status "$service_name" --no-pager
}

# Function to stop service
stop_service() {
    local service_name="nas-dockge-monitor"
    
    if ! sudo systemctl list-unit-files | grep -q "$service_name"; then
        error "Service is not installed"
        return 1
    fi
    
    log "Stopping service..."
    sudo systemctl stop "$service_name"
    
    log "Service stopped"
    sudo systemctl status "$service_name" --no-pager
}

# Function to edit configuration file
edit_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log "Opening configuration file: $CONFIG_FILE"
    
    # Try to use the best available editor
    if command -v nano &> /dev/null; then
        sudo nano "$CONFIG_FILE"
    elif command -v vim &> /dev/null; then
        sudo vim "$CONFIG_FILE"
    elif command -v vi &> /dev/null; then
        sudo vi "$CONFIG_FILE"
    else
        log "Configuration file location: $CONFIG_FILE"
        log "Please edit it manually with your preferred editor"
    fi
}

# Function to show current configuration
show_config() {
    log "Current Configuration:"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log "Configuration file: $CONFIG_FILE"
    echo ""
    
    # Show configuration with sensitive values masked
    cat "$CONFIG_FILE" | while IFS= read -r line; do
        # Mask passwords and sensitive URLs
        if [[ $line =~ PASSWORD|_URL ]]; then
            key=$(echo "$line" | cut -d'=' -f1)
            echo "$key=\"***REDACTED***\""
        else
            echo "$line"
        fi
    done
}

# Function to validate configuration
validate_config() {
    log "Validating configuration..."
    local errors=0
    
    if [ "$NAS_USERNAME" = "your_username" ] || [ "$NAS_PASSWORD" = "your_password" ]; then
        error "NAS credentials are not configured"
        errors=$((errors + 1))
    fi
    
    if [ "$NAS_IP" = "192.168.1.100" ]; then
        warning "NAS IP is using default value - please verify"
    fi
    
    if [ -z "$NAS_MOUNT_POINT" ]; then
        error "NAS_MOUNT_POINT is not set"
        errors=$((errors + 1))
    fi
    
    if [ -z "$DOCKGE_DATA_DIR" ]; then
        error "DOCKGE_DATA_DIR is not set"
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

# Function to run monitoring loop
monitor_services() {
    log "Starting monitoring service (checking every 2 minutes)..."
    log "Press Ctrl+C to stop monitoring"
    
    # Perform initial backup
    backup_dockge
    
    # Track backup timing (backup every 6 hours = 180 checks at 2 min intervals)
    BACKUP_INTERVAL=180
    # Track update timing (default 24 hours = 720 checks at 2 min intervals)
    UPDATE_INTERVAL=$((UPDATE_CHECK_INTERVAL * 30))
    CHECK_COUNT=0
    UPDATE_COUNT=0
    
    while true; do
        sleep 120  # 2 minutes
        CHECK_COUNT=$((CHECK_COUNT + 1))
        UPDATE_COUNT=$((UPDATE_COUNT + 1))
        
        NAS_OK=true
        DOCKGE_OK=true
        
        # Check disk usage
        DISK_USAGE=$(check_disk_usage)
        if [ "$DISK_USAGE" -ge "$DISK_CLEANUP_THRESHOLD" ] && [ "$AUTO_CLEANUP_ENABLED" = "true" ]; then
            warning "Disk usage at ${DISK_USAGE}% (threshold: ${DISK_CLEANUP_THRESHOLD}%)"
            log "Running automatic cleanup..."
            clean_disk
        fi
        
        # Check for system updates
        if [ "$UPDATE_COUNT" -ge "$UPDATE_INTERVAL" ] && [ "$AUTO_UPDATE_ENABLED" = "true" ]; then
            log "Performing scheduled system update check..."
            if check_updates; then
                log "Installing system updates..."
                update_system
                local update_result=$?
                
                if [ $update_result -eq 2 ]; then
                    warning "System reboot required after updates"
                    if [ "$AUTO_REBOOT_ENABLED" = "true" ]; then
                        schedule_reboot "$REBOOT_TIME"
                    else
                        log "Automatic reboot is disabled. Please reboot manually."
                    fi
                fi
            fi
            UPDATE_COUNT=0
        fi
        
        # Check NAS
        if ! check_nas_heartbeat; then
            NAS_OK=false
            error "NAS heartbeat failed - attempting to remount..."
            sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null || true
            if mount_nas; then
                log "NAS remounted successfully"
                NAS_OK=true
            else
                error "Failed to remount NAS"
            fi
        fi
        
        # Check Dockge
        if ! check_dockge_heartbeat; then
            DOCKGE_OK=false
            error "Dockge heartbeat failed - attempting to restart..."
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
            sleep 10
            if check_dockge_heartbeat; then
                log "Dockge restarted successfully"
                DOCKGE_OK=true
            else
                error "Failed to restart Dockge"
            fi
        fi
        
        # Send overall system status to Uptime Kuma
        if [ -n "$UPTIME_KUMA_SYSTEM_URL" ]; then
            if [ "$NAS_OK" = true ] && [ "$DOCKGE_OK" = true ]; then
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=up&msg=All%20Services%20OK&ping=" > /dev/null 2>&1 || true
            else
                local failed_services=""
                [ "$NAS_OK" = false ] && failed_services="NAS"
                [ "$DOCKGE_OK" = false ] && failed_services="${failed_services:+$failed_services,}Dockge"
                curl -fsS -m 10 "${UPTIME_KUMA_SYSTEM_URL}?status=down&msg=Failed:${failed_services}" > /dev/null 2>&1 || true
            fi
        fi
        
        # Perform backup every 6 hours
        if [ $CHECK_COUNT -ge $BACKUP_INTERVAL ]; then
            log "Performing scheduled backup..."
            backup_dockge
            CHECK_COUNT=0
        fi
        
        log "Heartbeat OK - Disk: ${DISK_USAGE}% | Backup: $((BACKUP_INTERVAL - CHECK_COUNT)) | Updates: $((UPDATE_INTERVAL - UPDATE_COUNT))"
    done
}

# Main execution
main() {
    log "Starting NAS and Dockge setup script..."
    
    # Check if running as root for some operations
    if [ "$EUID" -ne 0 ]; then
        log "This script requires sudo privileges for certain operations"
    fi
    
    # Set hostname if configured
    if [ -n "$NEW_HOSTNAME" ]; then
        set_hostname "$NEW_HOSTNAME"
    fi
    
    # Mount NAS
    mount_nas
    
    # Install Docker if needed
    install_docker
    
    # Install/Setup Dockge
    install_dockge
    
    # Start Dockge
    start_dockge
    
    log "Setup complete!"
    log "Current hostname: $(hostname)"
    log "Dockge is available at: http://localhost:$DOCKGE_PORT"
    log "NAS is mounted at: $NAS_MOUNT_POINT"
    echo ""
    
    # Ask user if they want to start monitoring
    read -p "Do you want to start the monitoring service now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_services
    else
        log "You can run this script again with 'monitor' argument to start monitoring"
        log "Example: $0 monitor"
    fi
}

# Handle arguments
if [ "$1" == "monitor" ]; then
    monitor_services
elif [ "$1" == "backup" ]; then
    backup_dockge
elif [ "$1" == "restore" ]; then
    restore_dockge
elif [ "$1" == "list-backups" ]; then
    log "Available backups in $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups found"
elif [ "$1" == "set-hostname" ]; then
    if [ -z "$2" ]; then
        error "Usage: $0 set-hostname <new_hostname>"
        exit 1
    fi
    set_hostname "$2"
elif [ "$1" == "show-hostname" ]; then
    log "Current hostname: $(hostname)"
    log "Fully qualified domain name: $(hostname -f)"
elif [ "$1" == "clean-disk" ]; then
    clean_disk
elif [ "$1" == "disk-space" ]; then
    show_disk_space
elif [ "$1" == "update" ]; then
    update_system
elif [ "$1" == "full-upgrade" ]; then
    full_upgrade
elif [ "$1" == "check-updates" ]; then
    check_updates
    show_update_status
elif [ "$1" == "update-status" ]; then
    show_update_status
elif [ "$1" == "schedule-reboot" ]; then
    if [ -n "$2" ]; then
        schedule_reboot "$2"
    else
        schedule_reboot
    fi
else
    main
fi; then
        error "Invalid hostname format. Use only letters, numbers, and hyphens. Must start and end with alphanumeric."
        return 1
    fi
    
    local current_hostname=$(hostname)
    
    if [ "$current_hostname" == "$hostname" ]; then
        log "Hostname is already set to: $hostname"
        return 0
    fi
    
    log "Changing hostname from '$current_hostname' to '$hostname'..."
    
    # Set the hostname
    sudo hostnamectl set-hostname "$hostname"
    
    # Update /etc/hosts
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$hostname/g" /etc/hosts
    
    # Add entry if it doesn't exist
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$hostname" | sudo tee -a /etc/hosts
    fi
    
    log "Hostname changed successfully to: $hostname"
    log "New hostname will be fully active after reboot"
    
    return 0
}

# Function to install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed ($(docker --version))"
        return 0
    fi
    
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update and install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed successfully"
}

# Function to install Dockge
install_dockge() {
    log "Setting up Dockge..."
    
    # Create Dockge directories
    sudo mkdir -p "$DOCKGE_DATA_DIR"
    sudo mkdir -p "$DOCKGE_DATA_DIR/stacks"
    
    # Create docker-compose.yml for Dockge
    sudo bash -c "cat > $DOCKGE_DATA_DIR/docker-compose.yml << 'EOF'
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
EOF"
    
    log "Dockge configuration created"
}

# Function to start Dockge
start_dockge() {
    log "Starting Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose up -d
    log "Dockge started successfully on port $DOCKGE_PORT"
}

# Function to check NAS heartbeat
check_nas_heartbeat() {
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted at $NAS_MOUNT_POINT"
        return 1
    fi
    
    if ! timeout 5 ls "$NAS_MOUNT_POINT" > /dev/null 2>&1; then
        error "NAS mount point is not responding"
        return 1
    fi
    
    return 0
}

# Function to check Dockge heartbeat
check_dockge_heartbeat() {
    if ! sudo docker ps | grep -q dockge; then
        error "Dockge container is not running"
        return 1
    fi
    
    if ! curl -sf http://localhost:$DOCKGE_PORT > /dev/null 2>&1; then
        error "Dockge is not responding on port $DOCKGE_PORT"
        return 1
    fi
    
    return 0
}

# Function to backup Dockge stacks to NAS
backup_dockge() {
    log "Starting Dockge backup..."
    
    # Check if NAS is mounted
    if ! mountpoint -q "$NAS_MOUNT_POINT"; then
        error "NAS is not mounted. Cannot perform backup."
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Create timestamped backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="dockge_backup_$TIMESTAMP.tar.gz"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
    
    log "Creating backup: $BACKUP_NAME"
    
    # Backup stacks and data directories
    if sudo tar -czf "$BACKUP_PATH" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null; then
        log "Backup created successfully: $BACKUP_PATH"
        
        # Get backup size
        BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
        log "Backup size: $BACKUP_SIZE"
        
        # Clean up old backups
        log "Cleaning up backups older than $BACKUP_RETENTION_DAYS days..."
        find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f -mtime +$BACKUP_RETENTION_DAYS -delete
        
        # Count remaining backups
        BACKUP_COUNT=$(find "$BACKUP_DIR" -name "dockge_backup_*.tar.gz" -type f | wc -l)
        log "Total backups retained: $BACKUP_COUNT"
        
        return 0
    else
        error "Failed to create backup"
        return 1
    fi
}

# Function to restore Dockge from backup
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
    
    # Confirm restoration
    warning "This will overwrite current Dockge stacks and data!"
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        log "Restore cancelled"
        return 1
    fi
    
    # Stop Dockge
    log "Stopping Dockge..."
    cd "$DOCKGE_DATA_DIR"
    sudo docker compose down
    
    # Backup current state just in case
    EMERGENCY_BACKUP="$DOCKGE_DATA_DIR/emergency_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    log "Creating emergency backup of current state..."
    sudo tar -czf "$EMERGENCY_BACKUP" -C "$DOCKGE_DATA_DIR" stacks data 2>/dev/null || true
    
    # Restore from backup
    log "Restoring from backup..."
    sudo rm -rf "$DOCKGE_DATA_DIR/stacks" "$DOCKGE_DATA_DIR/data"
    sudo tar -xzf "$BACKUP_FILE" -C "$DOCKGE_DATA_DIR"
    
    # Restart Dockge
    log "Starting Dockge..."
    sudo docker compose up -d
    
    log "Restore completed successfully!"
    log "Emergency backup saved to: $EMERGENCY_BACKUP"
    return 0
}

# Function to run monitoring loop
monitor_services() {
    log "Starting monitoring service (checking every 2 minutes)..."
    log "Press Ctrl+C to stop monitoring"
    
    # Perform initial backup
    backup_dockge
    
    # Track backup timing (backup every 6 hours = 180 checks at 2 min intervals)
    BACKUP_INTERVAL=180
    CHECK_COUNT=0
    
    while true; do
        sleep 120  # 2 minutes
        CHECK_COUNT=$((CHECK_COUNT + 1))
        
        # Check NAS
        if ! check_nas_heartbeat; then
            error "NAS heartbeat failed - attempting to remount..."
            sudo umount -f "$NAS_MOUNT_POINT" 2>/dev/null || true
            if mount_nas; then
                log "NAS remounted successfully"
            else
                error "Failed to remount NAS"
            fi
        fi
        
        # Check Dockge
        if ! check_dockge_heartbeat; then
            error "Dockge heartbeat failed - attempting to restart..."
            cd "$DOCKGE_DATA_DIR"
            sudo docker compose restart
            sleep 10
            if check_dockge_heartbeat; then
                log "Dockge restarted successfully"
            else
                error "Failed to restart Dockge"
            fi
        fi
        
        # Perform backup every 6 hours
        if [ $CHECK_COUNT -ge $BACKUP_INTERVAL ]; then
            log "Performing scheduled backup..."
            backup_dockge
            CHECK_COUNT=0
        fi
        
        log "Heartbeat check complete - All services OK (Next backup in $((BACKUP_INTERVAL - CHECK_COUNT)) checks)"
    done
}

# Main execution
main() {
    log "Starting NAS and Dockge setup script..."
    
    # Check if running as root for some operations
    if [ "$EUID" -ne 0 ]; then
        log "This script requires sudo privileges for certain operations"
    fi
    
    # Mount NAS
    mount_nas
    
    # Install Docker if needed
    install_docker
    
    # Install/Setup Dockge
    install_dockge
    
    # Start Dockge
    start_dockge
    
    log "Setup complete!"
    log "Dockge is available at: http://localhost:$DOCKGE_PORT"
    log "NAS is mounted at: $NAS_MOUNT_POINT"
    echo ""
    
    # Ask user if they want to start monitoring
    read -p "Do you want to start the monitoring service now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        monitor_services
    else
        log "You can run this script again with 'monitor' argument to start monitoring"
        log "Example: $0 monitor"
    fi
}

# Handle arguments
if [ "$1" == "monitor" ]; then
    monitor_services
elif [ "$1" == "backup" ]; then
    backup_dockge
elif [ "$1" == "restore" ]; then
    restore_dockge
elif [ "$1" == "list-backups" ]; then
    log "Available backups in $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR"/dockge_backup_*.tar.gz 2>/dev/null || echo "No backups found"
else
    main
fi