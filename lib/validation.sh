#!/bin/bash
# Validation Module

validate_ip() {
    [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
    IFS='.' read -ra ADDR <<< "$1"
    for i in "${ADDR[@]}"; do
        [ "$i" -gt 255 ] && return 1
    done
    return 0
}

validate_port() {
    [[ $1 =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

validate_hostname() {
    echo "$1" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'
}

validate_config() {
    log "Validating configuration..."
    local errors=0
    
    [ "$NAS_USERNAME" = "your_username" ] && [ "$NAS_MOUNT_SKIP" != "true" ] && {
        error "NAS credentials not configured"
        ((errors++))
    }
    
    validate_port "$DOCKGE_PORT" || { error "Invalid port: $DOCKGE_PORT"; ((errors++)); }
    
    [ $errors -eq 0 ] && { log "✓ Validation passed"; return 0; } || { error "$errors errors found"; return 1; }
}
