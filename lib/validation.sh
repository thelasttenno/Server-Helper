#!/bin/bash
# Validation Module - Enhanced with Debug

validate_ip() {
    debug "validate_ip called with: $1"
    
    if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        debug "IP format valid, checking octets"
    else
        debug "IP format invalid: $1"
        return 1
    fi
    
    IFS='.' read -ra ADDR <<< "$1"
    for i in "${ADDR[@]}"; do
        debug "Checking octet: $i"
        if [ "$i" -gt 255 ]; then
            debug "Octet $i exceeds 255"
            return 1
        fi
    done
    
    debug "IP validation passed: $1"
    return 0
}

validate_port() {
    debug "validate_port called with: $1"
    
    if [[ $1 =~ ^[0-9]+$ ]]; then
        debug "Port is numeric: $1"
    else
        debug "Port is not numeric: $1"
        return 1
    fi
    
    if [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; then
        debug "Port is in valid range: $1"
        return 0
    else
        debug "Port out of range (1-65535): $1"
        return 1
    fi
}

validate_hostname() {
    debug "validate_hostname called with: $1"
    
    if echo "$1" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
        debug "Hostname validation passed: $1"
        return 0
    else
        debug "Hostname validation failed: $1"
        return 1
    fi
}

validate_config() {
    debug "validate_config called"
    log "Validating configuration..."
    local errors=0
    
    debug "Checking NAS credentials"
    if [ "$NAS_USERNAME" = "your_username" ] && [ "$NAS_MOUNT_SKIP" != "true" ]; then
        error "NAS credentials not configured"
        debug "NAS_USERNAME is still default value and NAS_MOUNT_SKIP=$NAS_MOUNT_SKIP"
        ((errors++))
    else
        debug "NAS credentials check passed (username=$NAS_USERNAME, skip=$NAS_MOUNT_SKIP)"
    fi
    
    debug "Validating DOCKGE_PORT: $DOCKGE_PORT"
    if validate_port "$DOCKGE_PORT"; then
        debug "DOCKGE_PORT validation passed"
    else
        error "Invalid port: $DOCKGE_PORT"
        ((errors++))
    fi
    
    debug "Validation complete with $errors error(s)"
    if [ $errors -eq 0 ]; then
        log "✓ Validation passed"
        return 0
    else
        error "$errors errors found"
        return 1
    fi
}
