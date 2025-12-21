#!/bin/bash
# Security Module

setup_fail2ban() {
    command_exists fail2ban-client && { log "fail2ban installed"; return 0; }
    
    sudo apt-get install -y fail2ban
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
    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    log "✓ fail2ban configured"
}

setup_ufw() {
    command_exists ufw || sudo apt-get install -y ufw
    
    sudo ufw --force default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow $DOCKGE_PORT/tcp comment 'Dockge'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw --force enable
    log "✓ UFW configured"
}

harden_ssh() {
    local cfg="/etc/ssh/sshd_config"
    sudo cp "$cfg" "${cfg}.backup.$(timestamp)"
    
    sudo bash -c "cat >> $cfg << 'EOF'

# Security Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
EOF"
    sudo systemctl restart sshd
    log "✓ SSH hardened"
}

security_audit() {
    log "Security Audit:"
    local issues=0
    
    sudo grep -q "^PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null && warning "Root login enabled" && ((issues++)) || log "✓ Root login disabled"
    command_exists ufw && sudo ufw status | grep -q active && log "✓ UFW active" || { warning "UFW inactive"; ((issues++)); }
    command_exists fail2ban-client && systemctl is-active -q fail2ban && log "✓ fail2ban active" || { warning "fail2ban inactive"; ((issues++)); }
    
    log "Audit complete: $issues issues"
    return $issues
}

show_security_status() {
    security_audit
    command_exists fail2ban-client && sudo fail2ban-client status
    command_exists ufw && sudo ufw status verbose
}

apply_security_hardening() {
    confirm "Apply security hardening?" || return 1
    
    [ "$FAIL2BAN_ENABLED" = "true" ] && setup_fail2ban
    [ "$UFW_ENABLED" = "true" ] && setup_ufw
    [ "$SSH_HARDENING_ENABLED" = "true" ] && {
        confirm "Have SSH keys configured?" && harden_ssh || warning "Skipping SSH hardening"
    }
    
    dpkg -l | grep -q unattended-upgrades || {
        sudo apt-get install -y unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades
    }
    
    security_audit
}
