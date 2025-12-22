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

emergency_unmount_nas() {
    debug "[emergency_unmount_nas] Starting emergency unmount procedure"
    local mount_point="${1:-$NAS_MOUNT_POINT}"

    log ""
    log "═══════════════════════════════════════════════════════"
    log "         Emergency NAS Unmount Procedure"
    log "═══════════════════════════════════════════════════════"
    log ""
    log "Target: $mount_point"

    # Check if mount point exists
    if [ ! -d "$mount_point" ]; then
        error "Mount point does not exist: $mount_point"
        return 1
    fi

    # Check if actually mounted
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        log "✓ $mount_point is not mounted"
        log "Cleaning up fstab anyway..."
        sudo sed -i.backup '/cifs.*_netdev/d' /etc/fstab 2>/dev/null || true
        log "✓ Done"
        return 0
    fi

    # Change to safe directory
    debug "[emergency_unmount_nas] Changing to safe directory"
    cd /tmp || cd /

    # Show what's using the mount
    log ""
    warning "Checking for processes using $mount_point..."
    if command_exists lsof; then
        local procs=$(sudo lsof "$mount_point" 2>/dev/null | tail -n +2)
        if [ -n "$procs" ]; then
            warning "Processes found:"
            echo "$procs"
            echo ""
            if confirm "Kill these processes?"; then
                log "Killing processes..."
                sudo fuser -km "$mount_point" 2>/dev/null || true
                sleep 2
                log "✓ Processes killed"
            else
                warning "Unmount may fail with active processes"
            fi
        else
            log "✓ No processes found"
        fi
    else
        warning "lsof not available, skipping process check"
        log "Installing lsof is recommended: sudo apt-get install lsof"
    fi

    # Try unmount methods
    log ""
    warning "Attempting to unmount $mount_point..."
    log ""

    local success=false

    # Method 1: Normal unmount
    debug "[emergency_unmount_nas] Method 1: Normal unmount"
    if sudo umount "$mount_point" 2>/dev/null; then
        log "✓ Method 1: Normal unmount - Success"
        success=true
    else
        warning "✗ Method 1: Normal unmount - Failed"

        # Method 2: Lazy unmount
        debug "[emergency_unmount_nas] Method 2: Lazy unmount"
        if sudo umount -l "$mount_point" 2>/dev/null; then
            log "✓ Method 2: Lazy unmount (-l) - Success"
            success=true
        else
            warning "✗ Method 2: Lazy unmount - Failed"

            # Method 3: Force unmount
            debug "[emergency_unmount_nas] Method 3: Force unmount"
            if sudo umount -f "$mount_point" 2>/dev/null; then
                log "✓ Method 3: Force unmount (-f) - Success"
                success=true
            else
                warning "✗ Method 3: Force unmount - Failed"

                # Method 4: Force + Lazy
                debug "[emergency_unmount_nas] Method 4: Force + Lazy"
                if sudo umount -fl "$mount_point" 2>/dev/null; then
                    log "✓ Method 4: Force + Lazy (-fl) - Success"
                    success=true
                else
                    error "✗ Method 4: Force + Lazy - Failed"
                fi
            fi
        fi
    fi

    log ""

    # Check result
    if [ "$success" = true ]; then
        log "═══════════════════════════════════════════════════════"
        log "         Unmount Successful!"
        log "═══════════════════════════════════════════════════════"

        # Clean up fstab
        log ""
        log "Cleaning up /etc/fstab..."
        sudo cp /etc/fstab "/etc/fstab.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sudo sed -i '/cifs.*_netdev/d' /etc/fstab 2>/dev/null || true
        log "✓ Removed CIFS entries from fstab"

        # Remove credential files
        log ""
        log "Removing NAS credential files..."
        sudo find /root -name ".nascreds*" -type f -delete 2>/dev/null || true
        log "✓ Credential files removed"

        log ""
        log "✓ Complete! NAS fully unmounted and cleaned up."
        debug "[emergency_unmount_nas] Emergency unmount completed successfully"
        return 0
    else
        error "═══════════════════════════════════════════════════════"
        error "         All Unmount Methods Failed"
        error "═══════════════════════════════════════════════════════"
        log ""
        warning "Remaining processes:"
        sudo lsof "$mount_point" 2>/dev/null || log "Unable to check (lsof not available)"
        log ""
        warning "Recommendations:"
        log "1. Manually kill remaining processes:"
        log "   sudo lsof $mount_point"
        log "   sudo kill -9 <PID>"
        log ""
        log "2. Stop Docker if running:"
        log "   cd /opt/dockge && sudo docker compose down"
        log "   sudo systemctl stop docker"
        log ""
        log "3. Stop server-helper service:"
        log "   sudo systemctl stop server-helper"
        log ""
        log "4. Try this command again"
        log ""
        log "5. Last resort - reboot:"
        log "   sudo reboot"
        log ""
        debug "[emergency_unmount_nas] Emergency unmount failed"
        return 1
    fi
}
