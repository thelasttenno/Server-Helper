#!/bin/bash
# Configuration Management Module

create_default_config() {
    debug "[create_default_config] Creating default configuration file"
    cat > "$CONFIG_FILE" << 'EOF'
# Server Helper Configuration
# Version 0.2.2

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
    debug "[create_default_config] Configuration file created at: $CONFIG_FILE"
}

load_config() {
    debug "[load_config] Loading configuration from: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        debug "[load_config] Configuration loaded successfully"
        debug "[load_config] DEBUG mode: $DEBUG"
    else
        warning "Config not found, creating: $CONFIG_FILE"
        create_default_config
        error "Please edit $CONFIG_FILE and run again"
        exit 1
    fi
}

set_defaults() {
    debug "[set_defaults] Setting default values"
    NAS_SHARES="${NAS_SHARES:-}"
    NAS_IP="${NAS_IP:-192.168.1.100}"
    DOCKGE_PORT="${DOCKGE_PORT:-5001}"
    DOCKGE_DATA_DIR="${DOCKGE_DATA_DIR:-/opt/dockge}"
    NAS_MOUNT_REQUIRED="${NAS_MOUNT_REQUIRED:-false}"
    BACKUP_ADDITIONAL_DIRS="${BACKUP_ADDITIONAL_DIRS:-}"
    DEBUG="${DEBUG:-false}"
    
    debug "[set_defaults] NAS_IP: $NAS_IP"
    debug "[set_defaults] DOCKGE_PORT: $DOCKGE_PORT"
    debug "[set_defaults] DOCKGE_DATA_DIR: $DOCKGE_DATA_DIR"
}

parse_nas_shares() {
    debug "[parse_nas_shares] Parsing NAS shares configuration"
    # Declare as global array first to prevent unbound variable errors
    declare -g -a NAS_ARRAY=()
    if [ -n "$NAS_SHARES" ]; then
        IFS=';' read -ra NAS_ARRAY <<< "$NAS_SHARES"
        debug "[parse_nas_shares] Found ${#NAS_ARRAY[@]} NAS share(s)"
    else
        debug "[parse_nas_shares] No NAS_SHARES defined, using single share config"
    fi
}

parse_backup_dirs() {
    debug "[parse_backup_dirs] Parsing backup directories"
    # Parse additional backup directories into array
    declare -g -a BACKUP_DIRS_ARRAY=()
    if [ -n "$BACKUP_ADDITIONAL_DIRS" ]; then
        IFS=';' read -ra BACKUP_DIRS_ARRAY <<< "$BACKUP_ADDITIONAL_DIRS"
        debug "[parse_backup_dirs] Found ${#BACKUP_DIRS_ARRAY[@]} additional backup directory(ies)"
    else
        debug "[parse_backup_dirs] No additional backup directories configured"
    fi
}

edit_config() {
    debug "[edit_config] Opening configuration file for editing"
    [ ! -f "$CONFIG_FILE" ] && { error "Config not found"; return 1; }
    command_exists nano && sudo nano "$CONFIG_FILE" || sudo vi "$CONFIG_FILE"
    debug "[edit_config] Configuration editing completed"
}

show_config() {
    debug "[show_config] Displaying configuration (passwords masked)"
    [ ! -f "$CONFIG_FILE" ] && { error "Config not found"; return 1; }
    log "Configuration: $CONFIG_FILE"
    cat "$CONFIG_FILE" | while read line; do
        [[ $line =~ PASSWORD|_URL ]] && echo "$(echo "$line" | cut -d'=' -f1)=\"***\"" || echo "$line"
    done
}
