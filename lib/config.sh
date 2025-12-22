#!/bin/bash
# Configuration Management Module - Enhanced with Debug

create_default_config() {
    debug "create_default_config called"
    debug "Creating default config at: $CONFIG_FILE"
    
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
    debug "Default config created with permissions 600"
}

load_config() {
    debug "load_config called"
    debug "Looking for config file: $CONFIG_FILE"
    
    if [ -f "$CONFIG_FILE" ]; then
        debug "Config file found, sourcing it"
        source "$CONFIG_FILE"
        debug "Config file sourced successfully"
        debug "DEBUG value from config: $DEBUG"
    else
        warning "Config not found, creating: $CONFIG_FILE"
        debug "Config file does not exist, creating default"
        create_default_config
        error "Please edit $CONFIG_FILE and run again"
        exit 1
    fi
}

set_defaults() {
    debug "set_defaults called"
    debug "Setting default values for unset variables"
    
    NAS_SHARES="${NAS_SHARES:-}"
    debug "NAS_SHARES: ${NAS_SHARES:-<empty>}"
    
    NAS_IP="${NAS_IP:-192.168.1.100}"
    debug "NAS_IP: $NAS_IP"
    
    DOCKGE_PORT="${DOCKGE_PORT:-5001}"
    debug "DOCKGE_PORT: $DOCKGE_PORT"
    
    DOCKGE_DATA_DIR="${DOCKGE_DATA_DIR:-/opt/dockge}"
    debug "DOCKGE_DATA_DIR: $DOCKGE_DATA_DIR"
    
    NAS_MOUNT_REQUIRED="${NAS_MOUNT_REQUIRED:-false}"
    debug "NAS_MOUNT_REQUIRED: $NAS_MOUNT_REQUIRED"
    
    BACKUP_ADDITIONAL_DIRS="${BACKUP_ADDITIONAL_DIRS:-}"
    debug "BACKUP_ADDITIONAL_DIRS: ${BACKUP_ADDITIONAL_DIRS:-<empty>}"
    
    DEBUG="${DEBUG:-false}"
    debug "DEBUG: $DEBUG"
    
    debug "Defaults set successfully"
}

parse_nas_shares() {
    debug "parse_nas_shares called"
    debug "NAS_SHARES value: ${NAS_SHARES:-<empty>}"
    
    # Declare as global array first to prevent unbound variable errors
    declare -g -a NAS_ARRAY=()
    
    if [ -n "$NAS_SHARES" ]; then
        debug "Parsing NAS_SHARES into array"
        IFS=';' read -ra NAS_ARRAY <<< "$NAS_SHARES"
        debug "Parsed ${#NAS_ARRAY[@]} NAS share(s)"
        
        for i in "${!NAS_ARRAY[@]}"; do
            debug "NAS_ARRAY[$i]: ${NAS_ARRAY[$i]}"
        done
    else
        debug "NAS_SHARES is empty, using single share config"
        debug "Single share - IP: $NAS_IP, Share: $NAS_SHARE, Mount: $NAS_MOUNT_POINT"
    fi
}

parse_backup_dirs() {
    debug "parse_backup_dirs called"
    debug "BACKUP_ADDITIONAL_DIRS value: ${BACKUP_ADDITIONAL_DIRS:-<empty>}"
    
    # Parse additional backup directories into array
    declare -g -a BACKUP_DIRS_ARRAY=()
    
    if [ -n "$BACKUP_ADDITIONAL_DIRS" ]; then
        debug "Parsing BACKUP_ADDITIONAL_DIRS into array"
        IFS=';' read -ra BACKUP_DIRS_ARRAY <<< "$BACKUP_ADDITIONAL_DIRS"
        debug "Parsed ${#BACKUP_DIRS_ARRAY[@]} additional backup directory(ies)"
        
        for i in "${!BACKUP_DIRS_ARRAY[@]}"; do
            debug "BACKUP_DIRS_ARRAY[$i]: ${BACKUP_DIRS_ARRAY[$i]}"
        done
    else
        debug "BACKUP_ADDITIONAL_DIRS is empty, no additional directories to backup"
    fi
}

edit_config() {
    debug "edit_config called"
    debug "Checking if config exists: $CONFIG_FILE"
    
    [ ! -f "$CONFIG_FILE" ] && { 
        error "Config not found"
        debug "Config file does not exist: $CONFIG_FILE"
        return 1
    }
    
    debug "Config file found, determining editor"
    if command_exists nano; then
        debug "Using nano editor"
        sudo nano "$CONFIG_FILE"
    else
        debug "Nano not found, using vi editor"
        sudo vi "$CONFIG_FILE"
    fi
    
    debug "Config editing completed"
}

show_config() {
    debug "show_config called"
    debug "Checking if config exists: $CONFIG_FILE"
    
    [ ! -f "$CONFIG_FILE" ] && { 
        error "Config not found"
        debug "Config file does not exist: $CONFIG_FILE"
        return 1
    }
    
    log "Configuration: $CONFIG_FILE"
    debug "Displaying config with masked passwords"
    
    cat "$CONFIG_FILE" | while read line; do
        if [[ $line =~ PASSWORD|_URL ]]; then
            masked_line="$(echo "$line" | cut -d'=' -f1)=\"***\""
            echo "$masked_line"
            debug "Masked line: $masked_line"
        else
            echo "$line"
        fi
    done
    
    debug "Config display completed"
}
