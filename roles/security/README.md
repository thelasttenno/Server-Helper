# Security Role

Comprehensive security hardening using community roles and custom configurations.

## Features

- **General Hardening**: geerlingguy.security role
- **Intrusion Prevention**: fail2ban (robertdebock.fail2ban)
- **Firewall**: UFW with service-specific rules (weareinteractive.ufw)
- **SSH Hardening**: Secure SSH configuration

## Requirements

Community roles (installed via requirements.yml):
- geerlingguy.security v3.2.0
- robertdebock.fail2ban v5.1.0
- weareinteractive.ufw v2.0.0

## Variables

```yaml
security:
  basic_hardening: true
  
  fail2ban:
    enabled: true
    bantime: 3600
    findtime: 600
    maxretry: 3
  
  ufw:
    enabled: true
    default_policy: deny
  
  ssh_hardening: true
```

## What Gets Hardened

### General (geerlingguy.security)
- Automatic security updates
- Firewall configuration
- System hardening parameters

### fail2ban
- SSH protection (3 attempts, 1 hour ban)
- Automatic ban for brute force
- Email notifications (optional)

### UFW Firewall
- Default deny incoming
- Allow SSH (port 22)
- Allow Dockge (port 5001)
- Allow Netdata (port 19999)
- Allow Uptime Kuma (port 3001)

### SSH Hardening
- Disable root login
- Disable password authentication
- Use public key only
- Stronger ciphers and MACs
- Log verbosely

## Usage

Included in `playbooks/setup.yml`.

Manual run:
```bash
ansible-playbook playbooks/setup.yml --tags security
```

Security audit playbook:
```bash
ansible-playbook playbooks/security.yml
```

## Verification

```bash
# Check fail2ban status
sudo fail2ban-client status

# Check UFW status
sudo ufw status verbose

# Check SSH configuration
sudo sshd -T | grep -E '(permitrootlogin|passwordauthentication)'
```

## Troubleshooting

**Locked out of SSH:**
- Ensure SSH keys are configured before enabling
- Use console access to revert: `sudo rm /etc/ssh/sshd_config.d/99-hardening.conf`

**fail2ban not starting:**
```bash
sudo fail2ban-client status
sudo journalctl -u fail2ban
```

**UFW blocking services:**
```bash
sudo ufw status numbered
sudo ufw delete <rule_number>
```
