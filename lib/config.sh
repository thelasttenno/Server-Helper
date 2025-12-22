#!/bin/bash
# Configuration Management Module

create_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Server Helper Configuration

# NAS Configuration
NAS_SHARES=""
NAS_IP="192.168.1.100"
NAS_SHARE="share"
NAS_MOUNT_POINT="/mnt/nas"
NAS_USERNAME="your_username"
NAS_PASSWORD="your_password"
NAS_MOUNT_REQUIRED="false"
NAS_MOUNT_SKIP="false"

# Dockge Configuration
DOCKGE_PORT="5001"
DOCKGE_DATA_DIR="/opt/dockge"

# Backup Configuration
BACKUP_DIR="$NAS_MOUNT_POINT/dockge_backups"
BACKUP_RETENTION_DAYS="30"
BACKUP_ADDITIONAL_DIRS="/opt/stacks"  # Semicolon-separated list of additional directories to backup

# System Configuration
NEW_HOSTNAME=""
DISK_CLEANUP_THRESHOLD="80"
AUTO_CLEANUP_ENABLED="true"

# Update Management
AUTO_UPDATE_ENABLED="false"
UPDATE_CHECK_INTERVAL="24"
AUTO_REBOOT_ENABLED="false"
REBOOT_TIME="03:00"

# Security Configuration
SECURITY_CHECK_ENABLED="true"
SECURITY_CHECK_INTERVAL="12"
FAIL2BAN_ENABLED="false"
UFW_ENABLED="false"
SSH_HARDENING_ENABLED="false"

# Uptime Kuma Integration
UPTIME_KUMA_NAS_URL=""
UPTIME_KUMA_DOCKGE_URL=""
UPTIME_KUMA_SYSTEM_URL=""

# Debug
DEBUG="false"
EOF
    chmod 600 "$CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        warning "Config not found, creating: $CONFIG_FILE"
        create_default_config
        error "Please edit $CONFIG_FILE and run again"
        exit 1
    fi
}

set_defaults() {
    NAS_SHARES="${NAS_SHARES:-}"
    NAS_IP="${NAS_IP:-192.168.1.100}"
    DOCKGE_PORT="${DOCKGE_PORT:-5001}"
    DOCKGE_DATA_DIR="${DOCKGE_DATA_DIR:-/opt/dockge}"
    NAS_MOUNT_REQUIRED="${NAS_MOUNT_REQUIRED:-false}"
    BACKUP_ADDITIONAL_DIRS="${BACKUP_ADDITIONAL_DIRS:-}"
    DEBUG="${DEBUG:-false}"
}

parse_nas_shares() {
    # Declare as global array first to prevent unbound variable errors
    declare -g -a NAS_ARRAY=()
    if [ -n "$NAS_SHARES" ]; then
        IFS=';' read -ra NAS_ARRAY <<< "$NAS_SHARES"
    fi
}

parse_backup_dirs() {
    # Parse additional backup directories into array
    declare -g -a BACKUP_DIRS_ARRAY=()
    if [ -n "$BACKUP_ADDITIONAL_DIRS" ]; then
        IFS=';' read -ra BACKUP_DIRS_ARRAY <<< "$BACKUP_ADDITIONAL_DIRS"
    fi
}

edit_config() {
    [ ! -f "$CONFIG_FILE" ] && { error "Config not found"; return 1; }
    command_exists nano && sudo nano "$CONFIG_FILE" || sudo vi "$CONFIG_FILE"
}

show_config() {
    [ ! -f "$CONFIG_FILE" ] && { error "Config not found"; return 1; }
    log "Configuration: $CONFIG_FILE"
    cat "$CONFIG_FILE" | while read line; do
        [[ $line =~ PASSWORD|_URL ]] && echo "$(echo "$line" | cut -d'=' -f1)=\"***\"" || echo "$line"
    done
}
