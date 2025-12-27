# Server Helper v1.0.0 - Ansible Edition

**Complete rewrite using Ansible + Docker + Modern Monitoring Stack**

A declarative, idempotent server management solution for Ubuntu 24.04 LTS with automated monitoring, backups, and security hardening.

---

## 🌟 What's New in v1.0.0

**Complete architectural overhaul** from bash scripts to Ansible playbooks:

- ✅ **Declarative Configuration**: Define desired state, let Ansible handle the rest
- ✅ **Idempotent Operations**: Run playbooks multiple times safely
- ✅ **Community Roles**: Uses trusted Ansible Galaxy roles
- ✅ **Modern Stack**: Netdata, Uptime Kuma, Restic, Lynis
- ✅ **Web UIs**: All management via web interfaces
- ✅ **Flexible Backups**: NAS, S3, B2, local storage (any combination)
- ✅ **Auto-Update**: Self-updating via ansible-pull
- ✅ **Hybrid Monitoring**: Pull + Push alerting for comprehensive coverage

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Server Helper v1.0.0                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Netdata    │  │ Uptime Kuma  │  │   Dockge     │     │
│  │  (Metrics)   │  │  (Alerting)  │  │  (Stacks)    │     │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘     │
│         │                  │                                │
│         │ Push alerts      │ Pull monitoring                │
│         └──────────────────┘                                │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Restic     │  │    Lynis     │  │  Watchtower  │     │
│  │  (Backups)   │  │  (Security)  │  │  (Updates)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                              │
│  ┌──────────────────────────────────────────────────┐      │
│  │  Optional: Traefik/Nginx Proxy Manager          │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Core Services (All in Dockge stacks):

- **Netdata**: System and container metrics (~100MB RAM)
- **Uptime Kuma**: Uptime monitoring and alerting (~50MB RAM)
- **Dockge**: Docker compose stack manager (~50MB RAM)
- **Restic**: Encrypted, deduplicated backups (via systemd timer)
- **Lynis**: Security auditing (via systemd timer)
- **Watchtower**: Auto-update containers (optional)
- **Traefik/Nginx**: Reverse proxy (optional)

**Total RAM**: ~200-250MB + containers

---

## 📦 Quick Start

### Prerequisites

```bash
# Ubuntu 24.04 LTS server
# Ansible control node (can be same server)
# Python 3.8+
# SSH access with sudo privileges
```

### 1. Install Ansible (on control node)

```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install -y ansible python3-pip git

# Verify installation
ansible --version
```

### 2. Clone Repository

```bash
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
git checkout v1.0.0
```

### 3. Install Requirements

```bash
# Install community roles
ansible-galaxy install -r requirements.yml

# Install Python dependencies
pip3 install -r requirements.txt
```

### 4. Configure Inventory

```bash
# Edit inventory
cp inventory/hosts.example.yml inventory/hosts.yml
nano inventory/hosts.yml

# Add your server(s):
all:
  hosts:
    server01:
      ansible_host: 192.168.1.100
      ansible_user: ubuntu
      ansible_become: yes
```

### 5. Configure Variables

```bash
# Copy example config
cp group_vars/all.example.yml group_vars/all.yml

# Edit with your settings (use mapping from Step 2)
nano group_vars/all.yml

# Key settings to configure:
# - hostname
# - nas (if used)
# - restic (backup destinations)
# - netdata (monitoring)
# - uptime_kuma (alerting)
# - security (firewall, fail2ban, ssh)
```

### 6. Setup Ansible Vault (Secure Secrets)

```bash
# Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Create encrypted vault file
ansible-vault create group_vars/vault.yml

# Add your secrets (see group_vars/vault.example.yml for template):
# - NAS passwords
# - Restic backup passwords
# - Cloud credentials (AWS, B2)
# - SMTP passwords
# - API keys

# Reference vault variables in all.yml:
# nas:
#   username: "{{ vault_nas_credentials[0].username }}"
#   password: "{{ vault_nas_credentials[0].password }}"

# See VAULT_GUIDE.md for complete documentation
```

### 7. Run Setup Playbook

```bash
# Dry run first (check mode)
ansible-playbook playbooks/setup.yml --check

# Run actual setup
ansible-playbook playbooks/setup.yml

# With verbose output
ansible-playbook playbooks/setup.yml -v
```

### 7. Access Services

After setup completes:

```bash
# Dockge: http://your-server:5001
# Netdata: http://your-server:19999
# Uptime Kuma: http://your-server:3001

# Initial Uptime Kuma setup
# - Visit http://your-server:3001
# - Create admin account
# - Configure monitors (done via playbook on subsequent runs)
```

---

## 🔐 Ansible Vault - Secure Secrets Management

Server Helper uses **Ansible Vault** to encrypt sensitive data (passwords, API keys, credentials). This allows you to safely commit encrypted secrets to Git.

### Quick Setup

```bash
# 1. Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# 2. Create encrypted vault file
ansible-vault create group_vars/vault.yml

# 3. Add your secrets in the editor that opens
# See group_vars/vault.example.yml for template

# 4. Reference vault variables in group_vars/all.yml
# Example:
#   nas:
#     username: "{{ vault_nas_credentials[0].username }}"
#     password: "{{ vault_nas_credentials[0].password }}"
```

### Common Vault Commands

```bash
# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# View encrypted file
ansible-vault view group_vars/vault.yml

# Change vault password
ansible-vault rekey group_vars/vault.yml

# Run playbook (uses .vault_password automatically)
ansible-playbook playbooks/setup.yml
```

### What to Store in Vault

**Always encrypt:**
- 🔑 NAS passwords
- 🔑 Restic backup passwords
- 🔑 AWS/S3/B2 credentials
- 🔑 SMTP passwords
- 🔑 API keys and tokens
- 🔑 SSL certificates and private keys
- 🔑 Admin account passwords

**Safe to keep in plain text:**
- ✅ Hostnames
- ✅ Port numbers
- ✅ File paths
- ✅ Feature flags
- ✅ Public URLs

### Security Best Practices

- ✅ **Keep .vault_password secret**: Never commit to Git
- ✅ **Strong passwords**: Use 32+ character random passwords
- ✅ **Secure sharing**: Share vault password via password manager
- ✅ **Regular rotation**: Change vault password periodically
- ✅ **Unique secrets**: Don't reuse passwords across services

### Documentation

- **Comprehensive Guide**: [VAULT_GUIDE.md](VAULT_GUIDE.md)
- **Quick Reference**: [VAULT_QUICK_REFERENCE.md](VAULT_QUICK_REFERENCE.md)
- **Example Vault**: [group_vars/vault.example.yml](group_vars/vault.example.yml)

---

## 🔧 Configuration

### Main Configuration File: `group_vars/all.yml`

```yaml
# System Configuration
hostname: "server-01"
timezone: "America/New_York"

# NAS Configuration (optional)
nas:
  enabled: true
  shares:
    - ip: "192.168.1.100"
      share: "backup"
      mount: "/mnt/nas/backup"
      username: "nasuser"
      password: "naspass"
    - ip: "192.168.1.100"
      share: "media"
      mount: "/mnt/nas/media"
      username: "nasuser"
      password: "naspass"

# Backup Configuration (flexible - any combination)
restic:
  enabled: true
  schedule: "0 2 * * *"  # 2 AM daily
  retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6
  
  # Backup destinations (enable any/all)
  destinations:
    nas:
      enabled: true
      path: "/mnt/nas/backup/restic"
      password: "restic-repo-password"
    
    s3:
      enabled: false
      bucket: "my-backups"
      endpoint: "s3.amazonaws.com"
      access_key: "AWS_ACCESS_KEY"
      secret_key: "AWS_SECRET_KEY"
      password: "restic-repo-password"
    
    b2:
      enabled: false
      bucket: "my-backups"
      account_id: "B2_ACCOUNT_ID"
      account_key: "B2_ACCOUNT_KEY"
      password: "restic-repo-password"
    
    local:
      enabled: true
      path: "/opt/backups/restic"
      password: "restic-repo-password"
  
  # What to backup
  backup_paths:
    - /opt/dockge/stacks
    - /opt/dockge/data
    - /etc
    - /home

# Monitoring Configuration
netdata:
  enabled: true
  port: 19999
  claim_token: ""  # Optional: Netdata Cloud claim token
  
uptime_kuma:
  enabled: true
  port: 3001
  # Monitors configured after initial setup

# Container Management
dockge:
  enabled: true
  port: 5001
  stacks_dir: "/opt/dockge/stacks"
  data_dir: "/opt/dockge/data"

# Security Configuration
security:
  fail2ban_enabled: true
  ufw_enabled: true
  ufw_allowed_ports:
    - 22    # SSH
    - 5001  # Dockge
    - 19999 # Netdata
    - 3001  # Uptime Kuma
  
  ssh_hardening: true
  ssh_port: 22
  ssh_password_authentication: false
  ssh_permit_root_login: false
  
  lynis_enabled: true
  lynis_schedule: "0 3 * * 0"  # 3 AM every Sunday

# Optional Services
watchtower:
  enabled: false
  schedule: "0 4 * * *"  # 4 AM daily

reverse_proxy:
  enabled: false
  type: "traefik"  # or "nginx"
  domain: "example.com"
  email: "admin@example.com"  # For Let's Encrypt

# Self-Update Configuration
self_update:
  enabled: true
  schedule: "0 5 * * *"  # 5 AM daily
  git_repo: "https://github.com/thelasttenno/Server-Helper.git"
  branch: "main"
  version: "v1.0.0"
```

---

## 📚 Common Operations

### Run Full Setup

```bash
ansible-playbook playbooks/setup.yml
```

### Update System (self-update)

```bash
ansible-playbook playbooks/update.yml

# Or let systemd timer do it automatically
sudo systemctl status ansible-pull.timer
```

### Run Backup Manually

```bash
ansible-playbook playbooks/backup.yml

# Or trigger via systemd
sudo systemctl start restic-backup.service
```

### Security Audit

```bash
ansible-playbook playbooks/security.yml

# Or trigger Lynis manually
sudo systemctl start lynis-scan.service
```

### Check Service Status

```bash
# All services
ansible all -m shell -a "systemctl status docker dockge netdata uptime-kuma"

# Specific service
ansible all -m shell -a "docker ps"
```

### View Logs

```bash
# Ansible playbook logs
tail -f /var/log/ansible-pull.log

# Restic backup logs
sudo journalctl -u restic-backup -f

# Lynis scan logs
sudo journalctl -u lynis-scan -f
```

---

## 🔄 Monitoring & Alerting

### Hybrid Monitoring Setup

#### Pull Monitoring (Uptime Kuma → Services)

Uptime Kuma checks these endpoints every 60 seconds:

```yaml
Monitors:
  - name: "Netdata Health"
    type: HTTP
    url: "http://localhost:19999/api/v1/info"
    interval: 60
  
  - name: "Dockge Health"
    type: HTTP
    url: "http://localhost:5001"
    interval: 60
  
  - name: "Docker Daemon"
    type: HTTP
    url: "http://localhost:2375/_ping"  # If Docker API enabled
    interval: 60
```

#### Push Monitoring (Services → Uptime Kuma)

Services send alerts to Uptime Kuma:

```yaml
Netdata Alarms:
  - CPU > 95% → POST http://uptime-kuma:3001/api/push/CPU123
  - RAM > 95% → POST http://uptime-kuma:3001/api/push/RAM123
  - Disk > 90% → POST http://uptime-kuma:3001/api/push/DISK123

Restic Backup:
  - Success → POST http://uptime-kuma:3001/api/push/BACKUP123?status=up
  - Failure → POST http://uptime-kuma:3001/api/push/BACKUP123?status=down

Lynis Scan:
  - Complete → POST http://uptime-kuma:3001/api/push/LYNIS123?status=up&msg=score-XX
```

### Configure Notifications

In Uptime Kuma UI:

1. Go to **Settings** → **Notifications**
2. Add notification endpoints:
   - Email (SMTP)
   - Discord webhook
   - Telegram bot
   - Slack webhook
   - Many more...

---

## 💾 Backup & Restore

### Backup Destinations

Configure any combination in `group_vars/all.yml`:

```yaml
restic:
  destinations:
    nas:
      enabled: true        # ✅ Backup to NAS
    s3:
      enabled: true        # ✅ Backup to AWS S3
    local:
      enabled: true        # ✅ Backup to local disk
    b2:
      enabled: false       # ❌ Disabled
```

### Manual Backup

```bash
# Run backup playbook
ansible-playbook playbooks/backup.yml

# Or trigger systemd service
sudo systemctl start restic-backup.service
```

### Restore from Backup

```bash
# List snapshots
sudo restic -r /mnt/nas/backup/restic snapshots

# Restore specific snapshot
sudo restic -r /mnt/nas/backup/restic restore <snapshot-id> --target /tmp/restore

# Restore latest
sudo restic -r /mnt/nas/backup/restic restore latest --target /tmp/restore
```

### Backup Schedule

Configured via systemd timer (default: daily at 2 AM):

```bash
# Check timer status
sudo systemctl status restic-backup.timer

# View next run time
sudo systemctl list-timers restic-backup.timer

# Modify schedule
sudo nano /etc/systemd/system/restic-backup.timer
sudo systemctl daemon-reload
sudo systemctl restart restic-backup.timer
```

---

## 🔒 Security

### Security Features

- **fail2ban**: Protects against brute force attacks
- **UFW**: Firewall with default deny policy
- **SSH Hardening**: Disables password auth, root login
- **Lynis**: Weekly security audits
- **Automatic Updates**: Watchtower for containers (optional)

### Run Security Audit

```bash
# Via Ansible
ansible-playbook playbooks/security.yml

# Via systemd (runs weekly by default)
sudo systemctl start lynis-scan.service

# View report
sudo cat /var/log/lynis/report.dat
```

### Security Audit Schedule

```bash
# Default: Sunday at 3 AM
sudo systemctl status lynis-scan.timer

# Change schedule
sudo nano /etc/systemd/system/lynis-scan.timer
sudo systemctl daemon-reload
```

---

## 🔄 Self-Update

### Automatic Updates (ansible-pull)

The system self-updates daily via ansible-pull:

```bash
# Check self-update timer
sudo systemctl status ansible-pull.timer

# View last update
sudo journalctl -u ansible-pull -n 50

# Manual update
sudo systemctl start ansible-pull.service
```

### How It Works

```yaml
Systemd Timer:
  Schedule: Daily at 5 AM
  Command: ansible-pull -U https://github.com/thelasttenno/Server-Helper.git
  Playbook: playbooks/setup.yml
  Result: System updates to latest configuration
```

### Disable Self-Update

```yaml
# In group_vars/all.yml
self_update:
  enabled: false
```

---

## 🐛 Troubleshooting

### Playbook Fails

```bash
# Run with verbose output
ansible-playbook playbooks/setup.yml -vvv

# Check specific task
ansible-playbook playbooks/setup.yml --start-at-task="Install Docker"

# Dry run (check mode)
ansible-playbook playbooks/setup.yml --check
```

### Service Not Starting

```bash
# Check Docker containers
docker ps -a

# Check systemd services
sudo systemctl status restic-backup
sudo systemctl status lynis-scan

# View logs
sudo journalctl -xe
```

### Backup Failures

```bash
# Check Restic repository
sudo restic -r /mnt/nas/backup/restic check

# View backup logs
sudo journalctl -u restic-backup -f

# Test backup manually
sudo restic -r /mnt/nas/backup/restic backup /opt/dockge
```

### NAS Mount Issues

```bash
# Check mounts
mount | grep cifs

# Test mount manually
sudo mount -t cifs //192.168.1.100/backup /mnt/nas/backup -o username=user,password=pass

# Check NAS connectivity
ping 192.168.1.100
```

---

## 📖 Migration from v0.3.0

See **[MIGRATION.md](MIGRATION.md)** for detailed migration guide from bash version.

**Quick summary:**
1. Export current configuration
2. Map to Ansible variables
3. Run new playbook
4. Verify services
5. Disable old bash system

---

## 📁 Directory Structure

```
/opt/
├── dockge/
│   ├── docker-compose.yml
│   ├── data/
│   └── stacks/
│       ├── netdata/
│       │   └── docker-compose.yml
│       ├── uptime-kuma/
│       │   └── docker-compose.yml
│       ├── watchtower/  (optional)
│       │   └── docker-compose.yml
│       └── reverse-proxy/  (optional)
│           └── docker-compose.yml
├── backups/
│   └── restic/  (if local backup enabled)
└── ansible/
    └── Server-Helper/  (playbook repository)

/mnt/
└── nas/
    └── backup/
        └── restic/  (if NAS backup enabled)

/var/log/
├── ansible-pull.log
├── restic-backup.log
└── lynis/
    └── report.dat

/etc/systemd/system/
├── restic-backup.service
├── restic-backup.timer
├── lynis-scan.service
├── lynis-scan.timer
├── ansible-pull.service
└── ansible-pull.timer
```

---

## 🎯 Feature Comparison

| Feature | v0.3.0 (Bash) | v1.0.0 (Ansible) |
|---------|---------------|------------------|
| **Configuration** | Bash config file | YAML variables |
| **Idempotency** | ❌ Manual | ✅ Automatic |
| **Interface** | CLI menu | Web UIs |
| **Monitoring** | Basic heartbeats | Netdata + Uptime Kuma |
| **Backups** | Tar archives | Restic (encrypted, deduplicated) |
| **Security** | Manual scripts | Lynis + automated hardening |
| **Updates** | Git pull | ansible-pull |
| **Modularity** | Bash functions | Ansible roles |
| **Community Support** | ❌ | ✅ Galaxy roles |
| **Extensibility** | Manual editing | Add roles/tasks |

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## 📝 License

GNU General Public License v3.0

---

## 🆘 Support

- **Issues**: https://github.com/thelasttenno/Server-Helper/issues
- **Discussions**: https://github.com/thelasttenno/Server-Helper/discussions
- **Documentation**: https://github.com/thelasttenno/Server-Helper/wiki

---

## ✨ Credits

Uses these excellent community roles:
- [geerlingguy.docker](https://github.com/geerlingguy/ansible-role-docker)
- [geerlingguy.security](https://github.com/geerlingguy/ansible-role-security)
- [geerlingguy.pip](https://github.com/geerlingguy/ansible-role-pip)

Built with:
- [Netdata](https://www.netdata.cloud/)
- [Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Dockge](https://github.com/louislam/dockge)
- [Restic](https://restic.net/)
- [Lynis](https://cisofy.com/lynis/)

---

**Made with ❤️ for Ubuntu 24.04 LTS**
