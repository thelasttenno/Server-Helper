#!/bin/bash
# NAS Management Module

mount_single_nas() {
    local ip="$1" share="$2" mount="$3" user="$4" pass="$5"
    
    debug "[mount_single_nas] IP: $ip, Share: $share, Mount: $mount"
    [ -z "$ip" ] && return 1
    
    sudo mkdir -p "$mount"
    if mountpoint -q "$mount"; then
        log "Already mounted: $mount"
        debug "[mount_single_nas] Mount point already active"
        return 0
    fi
    
    local creds="/root/.nascreds_$(echo $mount | tr '/' '_')"
    debug "[mount_single_nas] Creating credentials file: $creds"
    sudo bash -c "cat > $creds << EOF
username=$user
password=$pass
EOF"
    sudo chmod 600 "$creds"
    
    for vers in 3.0 2.1 1.0; do
        debug "[mount_single_nas] Attempting mount with SMB $vers"
        if sudo mount -t cifs "//$ip/$share" "$mount" -o "credentials=$creds,vers=$vers" 2>/dev/null; then
            log "✓ Mounted: $mount (SMB $vers)"
            grep -q "$mount" /etc/fstab || echo "//$ip/$share $mount cifs credentials=$creds,vers=$vers,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
            debug "[mount_single_nas] Mount successful with SMB $vers"
            return 0
        fi
    done
    
    warning "Failed to mount: $mount"
    debug "[mount_single_nas] All mount attempts failed"
    return 1
}

mount_nas() {
    debug "[mount_nas] Starting NAS mount process"
    [ "$NAS_MOUNT_SKIP" = "true" ] && { log "NAS mounting disabled"; return 0; }
    
    if ! command_exists mount.cifs; then
        debug "[mount_nas] Installing cifs-utils"
        sudo apt-get install -y cifs-utils
    fi
    
    local count=0 failed=0
    
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        debug "[mount_nas] Processing ${#NAS_ARRAY[@]} NAS share(s)"
        for cfg in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r ip share mount user pass <<< "$cfg"
            debug "[mount_nas] Processing share: //$ip/$share"
            mount_single_nas "$ip" "$share" "$mount" "$user" "$pass" && ((count++)) || ((failed++))
        done
    else
        debug "[mount_nas] Processing single NAS configuration"
        mount_single_nas "$NAS_IP" "$NAS_SHARE" "$NAS_MOUNT_POINT" "$NAS_USERNAME" "$NAS_PASSWORD" && ((count++)) || ((failed++))
    fi
    
    log "NAS mounts: $count success, $failed failed"
    debug "[mount_nas] Mount process complete"
    [ $count -eq 0 ] && [ "$NAS_MOUNT_REQUIRED" = "true" ] && return 1
    return 0
}

check_nas_heartbeat() {
    debug "[check_nas_heartbeat] Checking NAS connectivity"
    local status=0
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for cfg in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r _ _ mount _ _ <<< "$cfg"
            if ! mountpoint -q "$mount"; then
                debug "[check_nas_heartbeat] Mount point $mount is not mounted"
                status=1
            fi
        done
    else
        if ! mountpoint -q "$NAS_MOUNT_POINT"; then
            debug "[check_nas_heartbeat] Mount point $NAS_MOUNT_POINT is not mounted"
            status=1
        fi
    fi
    
    [ -n "$UPTIME_KUMA_NAS_URL" ] && {
        if [ $status -eq 0 ]; then
            debug "[check_nas_heartbeat] Sending up status to Uptime Kuma"
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=up" >/dev/null 2>&1
        else
            debug "[check_nas_heartbeat] Sending down status to Uptime Kuma"
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=down" >/dev/null 2>&1
        fi
    } || true
    
    debug "[check_nas_heartbeat] Heartbeat check complete, status: $status"
    return $status
}

list_nas_shares() {
    debug "[list_nas_shares] Listing NAS shares"
    log "NAS Shares:"
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for i in "${!NAS_ARRAY[@]}"; do
            IFS=':' read -r ip share mount _ _ <<< "${NAS_ARRAY[$i]}"
            mountpoint -q "$mount" 2>/dev/null && echo "$((i+1)). ✓ //$ip/$share -> $mount" || echo "$((i+1)). ✗ //$ip/$share -> $mount"
        done
    else
        mountpoint -q "$NAS_MOUNT_POINT" && echo "1. ✓ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT" || echo "1. ✗ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT"
    fi
}
