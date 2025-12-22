#!/bin/bash
# Validation Module

validate_ip() {
    local ip="$1"
    debug "[validate_ip] Validating IP: $ip"
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ]; then
                debug "[validate_ip] Octet $i exceeds 255"
                return 1
            fi
        done
        debug "[validate_ip] IP is valid"
        return 0
    else
        debug "[validate_ip] IP format invalid"
        return 1
    fi
}

validate_port() {
    local port="$1"
    debug "[validate_port] Validating port: $port"
    
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        debug "[validate_port] Port is valid"
        return 0
    else
        debug "[validate_port] Port is invalid"
        return 1
    fi
}

validate_hostname() {
    local hostname="$1"
    debug "[validate_hostname] Validating hostname: $hostname"
    
    if echo "$hostname" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
        debug "[validate_hostname] Hostname is valid"
        return 0
    else
        debug "[validate_hostname] Hostname is invalid"
        return 1
    fi
}

validate_config() {
    debug "[validate_config] Starting configuration validation"
    log "Validating configuration..."
    local errors=0
    
    [ "$NAS_USERNAME" = "your_username" ] && [ "$NAS_MOUNT_SKIP" != "true" ] && {
        error "NAS credentials not configured"
        ((errors++))
    }
    
    validate_port "$DOCKGE_PORT" || { error "Invalid port: $DOCKGE_PORT"; ((errors++)); }
    
    debug "[validate_config] Validation complete with $errors error(s)"
    [ $errors -eq 0 ] && { log "✓ Validation passed"; return 0; } || { error "$errors errors found"; return 1; }
}
