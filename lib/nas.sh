#!/bin/bash
# NAS Management Module

mount_single_nas() {
    local ip="$1" share="$2" mount="$3" user="$4" pass="$5"
    
    [ -z "$ip" ] && return 1
    sudo mkdir -p "$mount"
    mountpoint -q "$mount" && { log "Already mounted: $mount"; return 0; }
    
    local creds="/root/.nascreds_$(echo $mount | tr '/' '_')"
    sudo bash -c "cat > $creds << EOF
username=$user
password=$pass
EOF"
    sudo chmod 600 "$creds"
    
    for vers in 3.0 2.1 1.0; do
        if sudo mount -t cifs "//$ip/$share" "$mount" -o "credentials=$creds,vers=$vers" 2>/dev/null; then
            log "✓ Mounted: $mount (SMB $vers)"
            grep -q "$mount" /etc/fstab || echo "//$ip/$share $mount cifs credentials=$creds,vers=$vers,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
            return 0
        fi
    done
    
    warning "Failed to mount: $mount"
    return 1
}

mount_nas() {
    [ "$NAS_MOUNT_SKIP" = "true" ] && { log "NAS mounting disabled"; return 0; }
    
    command_exists mount.cifs || sudo apt-get install -y cifs-utils
    
    local count=0 failed=0
    
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for cfg in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r ip share mount user pass <<< "$cfg"
            mount_single_nas "$ip" "$share" "$mount" "$user" "$pass" && ((count++)) || ((failed++))
        done
    else
        mount_single_nas "$NAS_IP" "$NAS_SHARE" "$NAS_MOUNT_POINT" "$NAS_USERNAME" "$NAS_PASSWORD" && ((count++)) || ((failed++))
    fi
    
    log "NAS mounts: $count success, $failed failed"
    [ $count -eq 0 ] && [ "$NAS_MOUNT_REQUIRED" = "true" ] && return 1
    return 0
}

check_nas_heartbeat() {
    local status=0
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for cfg in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r _ _ mount _ _ <<< "$cfg"
            mountpoint -q "$mount" || status=1
        done
    else
        mountpoint -q "$NAS_MOUNT_POINT" || status=1
    fi
    
    [ -n "$UPTIME_KUMA_NAS_URL" ] && {
        [ $status -eq 0 ] && curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=up" >/dev/null 2>&1 || \
        curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=down" >/dev/null 2>&1
    } || true
    
    return $status
}

list_nas_shares() {
    log "NAS Shares:"
    if [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        for i in "${!NAS_ARRAY[@]}"; do
            IFS=':' read -r ip share mount _ _ <<< "${NAS_ARRAY[$i]}"
            mountpoint -q "$mount" 2>/dev/null && echo "$((i+1)). ✓ //$ip/$share -> $mount" || echo "$((i+1)). ✗ //$ip/$share -> $mount"
        done
    else
        mountpoint -q "$NAS_MOUNT_POINT" && echo "1. ✓ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT" || echo "1. ✗ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT"
    fi
}
