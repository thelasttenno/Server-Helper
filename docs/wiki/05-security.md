# Security Guide

Comprehensive security documentation for Server Helper.

## Table of Contents

1. [Security Overview](#security-overview)
2. [SSH Hardening](#ssh-hardening)
3. [Firewall Configuration](#firewall-configuration)
4. [Intrusion Prevention](#intrusion-prevention)
5. [Secrets Management](#secrets-management)
6. [Certificate Management](#certificate-management)
7. [Identity & Access](#identity--access)
8. [Security Auditing](#security-auditing)
9. [Best Practices](#best-practices)

---

## Security Overview

Server Helper implements defense-in-depth with multiple security layers:

```
┌─────────────────────────────────────────────────┐
│  Layer 5: Monitoring & Auditing                │
│  - Lynis security scans                        │
│  - fail2ban alerts                             │
│  - Uptime Kuma health checks                   │
├─────────────────────────────────────────────────┤
│  Layer 4: Encryption                           │
│  - TLS for all web traffic                     │
│  - Internal PKI (Step-CA)                      │
│  - Ansible Vault for secrets                   │
├─────────────────────────────────────────────────┤
│  Layer 3: Authorization                        │
│  - RBAC via Authentik groups                   │
│  - sudo restrictions                           │
│  - Docker group membership                     │
├─────────────────────────────────────────────────┤
│  Layer 2: Authentication                       │
│  - SSH key-only authentication                 │
│  - Authentik SSO                               │
│  - fail2ban brute-force protection             │
├─────────────────────────────────────────────────┤
│  Layer 1: Network                              │
│  - UFW firewall (deny by default)              │
│  - Docker Socket Proxy                         │
│  - Traefik TLS termination                     │
└─────────────────────────────────────────────────┘
```

---

## SSH Hardening

### Configuration

SSH is hardened using a drop-in configuration file at `/etc/ssh/sshd_config.d/99-server-helper.conf`.

**Settings Applied:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `PermitRootLogin` | no | Prevent root SSH access |
| `PasswordAuthentication` | no | Force key-based auth |
| `PubkeyAuthentication` | yes | Enable key auth |
| `MaxAuthTries` | 3 | Limit auth attempts |
| `X11Forwarding` | no | Disable X11 |
| `AllowAgentForwarding` | no | Disable agent forwarding |
| `AllowTcpForwarding` | no | Disable TCP forwarding |
| `PermitEmptyPasswords` | no | No empty passwords |
| `ChallengeResponseAuthentication` | no | Disable challenge-response |

### Key Management

```bash
# Generate ED25519 key (recommended)
ssh-keygen -t ed25519 -C "server-helper-$(date +%Y%m%d)"

# Copy to target
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@target

# Verify key-only access works before disabling passwords
ssh user@target
```

### Customization

```yaml
# group_vars/all.yml
target_security:
  ssh_hardening:
    enabled: true
    permit_root_login: false
    password_authentication: false
    pubkey_authentication: true
    max_auth_tries: 3
```

---

## Firewall Configuration

### UFW Rules

Default policy is deny-all with explicit allows:

```
Default incoming: DENY
Default outgoing: ALLOW
```

**Automatic Rules:**

| Port | Protocol | Service |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (Traefik) |
| 443 | TCP | HTTPS (Traefik) |
| 53 | TCP/UDP | DNS (Pi-hole) |

**Target-Specific Rules:**

| Port | Protocol | From | Service |
|------|----------|------|---------|
| 2375 | TCP | Control IP only | Docker Socket Proxy |

### Adding Custom Rules

```yaml
# group_vars/all.yml or host_vars/server.yml
security_ufw_extra_rules:
  - { rule: allow, port: "8080", proto: tcp, comment: "Custom app" }
  - { rule: allow, port: "3306", proto: tcp, from_ip: "192.168.1.0/24", comment: "MySQL from LAN" }
```

### Checking Status

```bash
# On any node
sudo ufw status verbose
sudo ufw status numbered
```

---

## Intrusion Prevention

### fail2ban Configuration

fail2ban protects against brute-force attacks:

**SSH Jail Settings:**

| Setting | Value | Description |
|---------|-------|-------------|
| `maxretry` | 3 | Failed attempts before ban |
| `bantime` | 86400 | Ban duration (24 hours) |
| `findtime` | 600 | Time window for failures |

### Checking Bans

```bash
# View banned IPs
sudo fail2ban-client status sshd

# Unban an IP
sudo fail2ban-client set sshd unbanip 1.2.3.4

# View all jails
sudo fail2ban-client status
```

### Customization

```yaml
# group_vars/all.yml
target_security:
  fail2ban:
    enabled: true
    sshd_maxretry: 3
    sshd_bantime: 86400  # 24 hours
```

---

## Secrets Management

### Ansible Vault

All secrets are stored in `group_vars/vault.yml` and encrypted with Ansible Vault.

**Setup:**

```bash
# Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Encrypt vault file
ansible-vault encrypt group_vars/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# View without editing
ansible-vault view group_vars/vault.yml
```

**Best Practices:**

1. Never commit `.vault_password` to git
2. Use strong, unique passwords for each secret
3. Rotate secrets periodically
4. Use `ansible-vault rekey` when changing vault password

### Secret Rotation

```bash
# Rotate vault password
ansible-vault rekey group_vars/vault.yml

# Generate new secrets
openssl rand -hex 32  # For API keys
openssl rand -base64 32  # For passwords
uuidgen  # For UUIDs
```

---

## Certificate Management

### Step-CA (Internal PKI)

Step-CA provides automatic certificate management for internal services.

**Root CA Location:** `/opt/stacks/step-ca/certs/root_ca.crt`

### Installing Root CA

**On Linux targets (automatic):**
The `site.yml` playbook automatically distributes the root CA.

**Manual installation:**

```bash
# Download root CA
curl -k https://step-ca.example.com:9000/root -o /tmp/root_ca.crt

# Install (Debian/Ubuntu)
sudo cp /tmp/root_ca.crt /usr/local/share/ca-certificates/step-ca-root.crt
sudo update-ca-certificates

# Install (RHEL/CentOS)
sudo cp /tmp/root_ca.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust
```

### Requesting Certificates

```bash
# Install step CLI
wget https://dl.smallstep.com/cli/docs-cli-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb

# Bootstrap CLI
step ca bootstrap --ca-url https://step-ca.example.com:9000 \
  --fingerprint $(step certificate fingerprint /path/to/root_ca.crt)

# Request certificate
step ca certificate myservice.example.com server.crt server.key
```

### Traefik Integration

Traefik can use Step-CA for automatic internal certificates:

```yaml
# roles/traefik/defaults/main.yml
traefik_step_ca_enabled: true
traefik_step_ca_endpoint: "https://step-ca:9000"
```

---

## Identity & Access

### Authentik SSO

Authentik provides centralized authentication for all services.

**Setup:**
1. Access https://auth.example.com
2. Login with bootstrap credentials
3. Change admin password immediately
4. Create OAuth2 providers for each service

**Group-Based Access:**

| Group | Grafana Role | Description |
|-------|--------------|-------------|
| Grafana Admins | Admin | Full access |
| Grafana Editors | Editor | Create/edit dashboards |
| (default) | Viewer | Read-only |

### Service Integration

**Grafana OAuth:**

```yaml
# group_vars/all.yml
grafana_oauth_enabled: true
grafana_oauth_client_id: "{{ vault_grafana_oauth_client_id }}"
grafana_oauth_client_secret: "{{ vault_grafana_oauth_client_secret }}"
```

---

## Security Auditing

### Lynis Scans

Lynis performs weekly security audits.

**Schedule:** Sundays at 3 AM (configurable)

**Reports:** `/var/log/lynis/`

### Manual Scan

```bash
# Run Lynis manually
sudo lynis audit system

# View report
sudo cat /var/log/lynis/report.dat
```

### Customization

```yaml
# group_vars/all.yml
target_security:
  lynis:
    enabled: true
    schedule: "0 3 * * 0"  # Weekly Sunday 3 AM
```

---

## Best Practices

### Do's

1. **Use strong, unique passwords** for all services
2. **Rotate secrets** at least annually
3. **Keep systems updated** using `ansible-playbook playbooks/update.yml`
4. **Review Lynis reports** regularly
5. **Monitor fail2ban** for attack patterns
6. **Use Authentik SSO** for all services
7. **Backup vault.yml** securely (encrypted)

### Don'ts

1. **Never** commit `.vault_password` to git
2. **Never** use password authentication for SSH
3. **Never** expose Docker socket directly
4. **Never** disable the firewall
5. **Never** skip security updates
6. **Never** use default passwords in production

### Security Checklist

```
[ ] SSH key authentication only
[ ] UFW firewall enabled
[ ] fail2ban running
[ ] Lynis auditing enabled
[ ] Vault encrypted
[ ] .vault_password in .gitignore
[ ] Root CA installed on clients
[ ] Authentik configured
[ ] All services behind Traefik
[ ] Backups encrypted and tested
```

---

## Incident Response

### If Compromised

1. **Isolate** affected systems (disable network)
2. **Preserve** evidence (don't reboot)
3. **Rotate** all secrets immediately
4. **Review** logs in Loki/Grafana
5. **Check** fail2ban for suspicious IPs
6. **Restore** from known-good backup
7. **Report** incident as appropriate

### Log Locations

| Service | Location |
|---------|----------|
| System | `/var/log/syslog`, `/var/log/auth.log` |
| fail2ban | `/var/log/fail2ban.log` |
| Lynis | `/var/log/lynis/` |
| Docker | `docker logs <container>` |
| Centralized | Grafana → Explore → Loki |

---

## Next Steps

- [Troubleshooting](06-troubleshooting.md) - Common issues and solutions
