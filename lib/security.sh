#!/bin/bash
# Security Module - Enhanced with Debug

setup_fail2ban() {
    debug "setup_fail2ban called"
    
    if command_exists fail2ban-client; then
        log "fail2ban installed"
        debug "fail2ban already installed"
        return 0
    fi
    
    debug "Installing fail2ban"
    sudo apt-get install -y fail2ban
    
    debug "Creating /etc/fail2ban/jail.local"
    sudo bash -c 'cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
maxretry = 3
bantime = 86400
EOF'
    debug "jail.local created with SSH protection"
    
    debug "Enabling fail2ban service"
    sudo systemctl enable fail2ban
    
    debug "Restarting fail2ban service"
    sudo systemctl restart fail2ban
    
    log "✓ fail2ban configured"
    debug "fail2ban setup completed"
}

setup_ufw() {
    debug "setup_ufw called"
    
    if ! command_exists ufw; then
        debug "UFW not installed, installing"
        sudo apt-get install -y ufw
    else
        debug "UFW already installed"
    fi
    
    debug "Configuring UFW default policies"
    sudo ufw --force default deny incoming
    sudo ufw default allow outgoing
    
    debug "Allowing SSH"
    sudo ufw allow ssh
    
    debug "Allowing Dockge port: $DOCKGE_PORT"
    sudo ufw allow $DOCKGE_PORT/tcp comment 'Dockge'
    
    debug "Allowing HTTP (port 80)"
    sudo ufw allow 80/tcp comment 'HTTP'
    
    debug "Allowing HTTPS (port 443)"
    sudo ufw allow 443/tcp comment 'HTTPS'
    
    debug "Enabling UFW"
    sudo ufw --force enable
    
    log "✓ UFW configured"
    debug "UFW setup completed"
}

harden_ssh() {
    debug "harden_ssh called"
    local cfg="/etc/ssh/sshd_config"
    debug "SSH config file: $cfg"
    
    debug "Creating backup of sshd_config"
    local backup="${cfg}.backup.$(timestamp)"
    sudo cp "$cfg" "$backup"
    debug "Backup created: $backup"
    
    debug "Appending hardening rules to $cfg"
    sudo bash -c "cat >> $cfg << 'EOF'

# Security Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
EOF"
    debug "Hardening rules appended"
    
    debug "Restarting SSH service"
    sudo systemctl restart sshd
    
    log "✓ SSH hardened"
    debug "SSH hardening completed"
}

security_audit() {
    debug "security_audit called"
    log "Security Audit:"
    local issues=0
    
    debug "Checking SSH root login setting"
    if sudo grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "Root login enabled"
        debug "Root login is enabled (security issue)"
        ((issues++))
    else
        log "✓ Root login disabled"
        debug "Root login disabled (good)"
    fi
    
    debug "Checking UFW status"
    if command_exists ufw; then
        if sudo ufw status | grep -q active; then
            log "✓ UFW active"
            debug "UFW is active (good)"
        else
            warning "UFW inactive"
            debug "UFW is inactive (security issue)"
            ((issues++))
        fi
    else
        warning "UFW not installed"
        debug "UFW not installed (security issue)"
        ((issues++))
    fi
    
    debug "Checking fail2ban status"
    if command_exists fail2ban-client; then
        if systemctl is-active -q fail2ban; then
            log "✓ fail2ban active"
            debug "fail2ban is active (good)"
        else
            warning "fail2ban inactive"
            debug "fail2ban is inactive (security issue)"
            ((issues++))
        fi
    else
        warning "fail2ban not installed"
        debug "fail2ban not installed (security issue)"
        ((issues++))
    fi
    
    log "Audit complete: $issues issues"
    debug "Security audit completed with $issues issue(s)"
    return $issues
}

show_security_status() {
    debug "show_security_status called"
    
    debug "Running security audit"
    security_audit
    
    if command_exists fail2ban-client; then
        debug "Showing fail2ban status"
        sudo fail2ban-client status
    else
        debug "fail2ban not installed, skipping status"
    fi
    
    if command_exists ufw; then
        debug "Showing UFW status"
        sudo ufw status verbose
    else
        debug "UFW not installed, skipping status"
    fi
    
    debug "show_security_status completed"
}

apply_security_hardening() {
    debug "apply_security_hardening called"
    
    if ! confirm "Apply security hardening?"; then
        debug "User declined security hardening"
        return 1
    fi
    
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        debug "FAIL2BAN_ENABLED=true, setting up fail2ban"
        setup_fail2ban
    else
        debug "FAIL2BAN_ENABLED=false, skipping fail2ban"
    fi
    
    if [ "$UFW_ENABLED" = "true" ]; then
        debug "UFW_ENABLED=true, setting up UFW"
        setup_ufw
    else
        debug "UFW_ENABLED=false, skipping UFW"
    fi
    
    if [ "$SSH_HARDENING_ENABLED" = "true" ]; then
        debug "SSH_HARDENING_ENABLED=true, checking SSH keys"
        if confirm "Have SSH keys configured?"; then
            debug "User confirmed SSH keys, hardening SSH"
            harden_ssh
        else
            warning "Skipping SSH hardening"
            debug "User does not have SSH keys, skipping SSH hardening"
        fi
    else
        debug "SSH_HARDENING_ENABLED=false, skipping SSH hardening"
    fi
    
    debug "Checking for unattended-upgrades"
    if dpkg -l | grep -q unattended-upgrades; then
        debug "unattended-upgrades already installed"
    else
        debug "Installing unattended-upgrades"
        sudo apt-get install -y unattended-upgrades
        debug "Configuring unattended-upgrades"
        sudo dpkg-reconfigure -plow unattended-upgrades
    fi
    
    debug "Running final security audit"
    security_audit
    debug "apply_security_hardening completed"
}
