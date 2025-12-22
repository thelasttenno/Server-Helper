#!/bin/bash
# Security Module

setup_fail2ban() {
    debug "[setup_fail2ban] Setting up fail2ban"
    if command_exists fail2ban-client; then
        log "fail2ban installed"
        return 0
    fi
    
    debug "[setup_fail2ban] Installing fail2ban package"
    sudo apt-get install -y fail2ban
    
    debug "[setup_fail2ban] Creating jail.local configuration"
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
    
    debug "[setup_fail2ban] Enabling and restarting fail2ban service"
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log "✓ fail2ban configured"
    debug "[setup_fail2ban] fail2ban setup complete"
}

setup_ufw() {
    debug "[setup_ufw] Setting up UFW firewall"
    if ! command_exists ufw; then
        debug "[setup_ufw] Installing ufw"
        sudo apt-get install -y ufw
    fi
    
    debug "[setup_ufw] Configuring UFW rules"
    sudo ufw --force default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow $DOCKGE_PORT/tcp comment 'Dockge'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw --force enable
    
    log "✓ UFW configured"
    debug "[setup_ufw] UFW setup complete"
}

harden_ssh() {
    debug "[harden_ssh] Hardening SSH configuration"
    local cfg="/etc/ssh/sshd_config"
    
    debug "[harden_ssh] Creating backup of sshd_config"
    sudo cp "$cfg" "${cfg}.backup.$(timestamp)"
    
    debug "[harden_ssh] Applying SSH hardening settings"
    sudo bash -c "cat >> $cfg << 'EOF'

# Security Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
EOF"
    
    debug "[harden_ssh] Restarting SSH service"
    sudo systemctl restart sshd
    log "✓ SSH hardened"
    debug "[harden_ssh] SSH hardening complete"
}

security_audit() {
    debug "[security_audit] Starting security audit"
    log "Security Audit:"
    local issues=0
    
    debug "[security_audit] Checking SSH root login"
    if sudo grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        warning "Root login enabled"
        ((issues++))
    else
        log "✓ Root login disabled"
    fi
    
    debug "[security_audit] Checking UFW status"
    if command_exists ufw && sudo ufw status | grep -q active; then
        log "✓ UFW active"
    else
        warning "UFW inactive"
        ((issues++))
    fi
    
    debug "[security_audit] Checking fail2ban status"
    if command_exists fail2ban-client && systemctl is-active -q fail2ban; then
        log "✓ fail2ban active"
    else
        warning "fail2ban inactive"
        ((issues++))
    fi
    
    log "Audit complete: $issues issues"
    debug "[security_audit] Security audit complete with $issues issue(s)"
    return $issues
}

show_security_status() {
    debug "[show_security_status] Displaying security status"
    security_audit
    
    if command_exists fail2ban-client; then
        debug "[show_security_status] Showing fail2ban status"
        sudo fail2ban-client status
    fi
    
    if command_exists ufw; then
        debug "[show_security_status] Showing UFW status"
        sudo ufw status verbose
    fi
}

apply_security_hardening() {
    debug "[apply_security_hardening] Starting security hardening"
    confirm "Apply security hardening?" || return 1
    
    if [ "$FAIL2BAN_ENABLED" = "true" ]; then
        debug "[apply_security_hardening] Setting up fail2ban"
        setup_fail2ban
    fi
    
    if [ "$UFW_ENABLED" = "true" ]; then
        debug "[apply_security_hardening] Setting up UFW"
        setup_ufw
    fi
    
    if [ "$SSH_HARDENING_ENABLED" = "true" ]; then
        if confirm "Have SSH keys configured?"; then
            debug "[apply_security_hardening] Hardening SSH"
            harden_ssh
        else
            warning "Skipping SSH hardening"
        fi
    fi
    
    if ! dpkg -l | grep -q unattended-upgrades; then
        debug "[apply_security_hardening] Installing unattended-upgrades"
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades
    fi
    
    security_audit
    debug "[apply_security_hardening] Security hardening complete"
}
