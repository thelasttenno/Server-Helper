#!/bin/bash
# NAS Management Module - Enhanced with Debug

mount_single_nas() {
    local ip="$1" share="$2" mount="$3" user="$4" pass="$5"
    
    debug "mount_single_nas called"
    debug "Parameters: IP=$ip, Share=$share, Mount=$mount, User=$user"
    
    if [ -z "$ip" ]; then
        debug "IP is empty, returning failure"
        return 1
    fi
    
    debug "Creating mount directory: $mount"
    sudo mkdir -p "$mount"
    
    debug "Checking if already mounted: $mount"
    if mountpoint -q "$mount"; then
        log "Already mounted: $mount"
        debug "Mount point already active"
        return 0
    fi
    
    local creds="/root/.nascreds_$(echo $mount | tr '/' '_')"
    debug "Creating credentials file: $creds"
    sudo bash -c "cat > $creds << EOF
username=$user
password=$pass
EOF"
    sudo chmod 600 "$creds"
    debug "Credentials file created with mode 600"
    
    debug "Attempting to mount with multiple SMB versions"
    for vers in 3.0 2.1 1.0; do
        debug "Trying SMB version: $vers"
        if sudo mount -t cifs "//$ip/$share" "$mount" -o "credentials=$creds,vers=$vers" 2>/dev/null; then
            log "✓ Mounted: $mount (SMB $vers)"
            debug "Mount successful with SMB $vers"
            
            debug "Checking if mount is in /etc/fstab"
            if grep -q "$mount" /etc/fstab; then
                debug "Mount already in fstab"
            else
                debug "Adding mount to /etc/fstab"
                echo "//$ip/$share $mount cifs credentials=$creds,vers=$vers,_netdev,nofail 0 0" | sudo tee -a /etc/fstab
                debug "Added to fstab: //$ip/$share $mount"
            fi
            return 0
        else
            debug "SMB $vers failed, trying next version"
        fi
    done
    
    warning "Failed to mount: $mount"
    debug "All SMB versions failed for mount: $mount"
    return 1
}

mount_nas() {
    debug "mount_nas called"
    debug "NAS_MOUNT_SKIP: $NAS_MOUNT_SKIP"
    
    if [ "$NAS_MOUNT_SKIP" = "true" ]; then
        log "NAS mounting disabled"
        debug "Skipping NAS mount (NAS_MOUNT_SKIP=true)"
        return 0
    fi
    
    debug "Checking for cifs-utils"
    if command_exists mount.cifs; then
        debug "cifs-utils already installed"
    else
        debug "Installing cifs-utils"
        sudo apt-get install -y cifs-utils
        debug "cifs-utils installation completed"
    fi
    
    local count=0 failed=0
    
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        debug "Using NAS_ARRAY with ${#NAS_ARRAY[@]} share(s)"
        for cfg in "${NAS_ARRAY[@]}"; do
            debug "Processing NAS config: $cfg"
            IFS=':' read -r ip share mount user pass <<< "$cfg"
            debug "Parsed: IP=$ip, Share=$share, Mount=$mount"
            if mount_single_nas "$ip" "$share" "$mount" "$user" "$pass"; then
                ((count++))
                debug "Mount succeeded, count=$count"
            else
                ((failed++))
                debug "Mount failed, failed=$failed"
            fi
        done
    else
        debug "Using single NAS configuration"
        debug "NAS_IP=$NAS_IP, NAS_SHARE=$NAS_SHARE, NAS_MOUNT_POINT=$NAS_MOUNT_POINT"
        if mount_single_nas "$NAS_IP" "$NAS_SHARE" "$NAS_MOUNT_POINT" "$NAS_USERNAME" "$NAS_PASSWORD"; then
            ((count++))
            debug "Single mount succeeded"
        else
            ((failed++))
            debug "Single mount failed"
        fi
    fi
    
    log "NAS mounts: $count success, $failed failed"
    debug "Final mount stats: success=$count, failed=$failed"
    
    if [ $count -eq 0 ] && [ "$NAS_MOUNT_REQUIRED" = "true" ]; then
        debug "No successful mounts and NAS_MOUNT_REQUIRED=true, returning failure"
        return 1
    fi
    
    debug "mount_nas completed successfully"
    return 0
}

check_nas_heartbeat() {
    debug "check_nas_heartbeat called"
    local status=0
    
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        debug "Checking ${#NAS_ARRAY[@]} NAS mount(s)"
        for cfg in "${NAS_ARRAY[@]}"; do
            IFS=':' read -r _ _ mount _ _ <<< "$cfg"
            debug "Checking mount point: $mount"
            if mountpoint -q "$mount"; then
                debug "Mount point active: $mount"
            else
                debug "Mount point inactive: $mount"
                status=1
            fi
        done
    else
        debug "Checking single NAS mount: $NAS_MOUNT_POINT"
        if mountpoint -q "$NAS_MOUNT_POINT"; then
            debug "Mount point active: $NAS_MOUNT_POINT"
        else
            debug "Mount point inactive: $NAS_MOUNT_POINT"
            status=1
        fi
    fi
    
    if [ -n "$UPTIME_KUMA_NAS_URL" ]; then
        debug "Sending heartbeat to Uptime Kuma: $UPTIME_KUMA_NAS_URL"
        if [ $status -eq 0 ]; then
            debug "Sending 'up' status"
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=up" >/dev/null 2>&1
        else
            debug "Sending 'down' status"
            curl -fsS -m 10 "${UPTIME_KUMA_NAS_URL}?status=down" >/dev/null 2>&1
        fi
    else
        debug "No UPTIME_KUMA_NAS_URL configured, skipping heartbeat"
    fi
    
    debug "check_nas_heartbeat returning status: $status"
    return $status
}

list_nas_shares() {
    debug "list_nas_shares called"
    log "NAS Shares:"
    
    # Ensure NAS_ARRAY exists and is an array
    if [ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]; then
        debug "Listing ${#NAS_ARRAY[@]} NAS share(s) from array"
        for i in "${!NAS_ARRAY[@]}"; do
            IFS=':' read -r ip share mount _ _ <<< "${NAS_ARRAY[$i]}"
            debug "Checking share $((i+1)): //$ip/$share -> $mount"
            if mountpoint -q "$mount" 2>/dev/null; then
                echo "$((i+1)). ✓ //$ip/$share -> $mount"
                debug "Share $((i+1)) is mounted"
            else
                echo "$((i+1)). ✗ //$ip/$share -> $mount"
                debug "Share $((i+1)) is not mounted"
            fi
        done
    else
        debug "Listing single NAS share: //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT"
        if mountpoint -q "$NAS_MOUNT_POINT"; then
            echo "1. ✓ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT"
            debug "Single share is mounted"
        else
            echo "1. ✗ //$NAS_IP/$NAS_SHARE -> $NAS_MOUNT_POINT"
            debug "Single share is not mounted"
        fi
    fi
    
    debug "list_nas_shares completed"
}
