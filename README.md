# Server Helper v1.0.0 - Ansible Edition

**Complete rewrite using Ansible + Docker + Modern Monitoring Stack**

A declarative, idempotent server management solution for Ubuntu 24.04 LTS with automated monitoring, backups, and security hardening.

> **🚀 New: Command Node Architecture**
> Manage multiple servers from your laptop/desktop! See [docs/guides/command-node.md](docs/guides/command-node.md) for the new multi-node setup guide.

---

## 🎯 What This Does

Server Helper automatically configures and manages your Ubuntu servers with a complete production-ready stack:

**In Plain English:**

- **Monitoring**: Watch your server's CPU, RAM, disk space, and uptime in real-time dashboards
- **Alerting**: Get notified (email, Discord, Telegram) when something goes wrong
- **Backups**: Encrypted, automatic backups to NAS, AWS S3, or Backblaze B2
- **Security**: Firewall, SSH hardening, intrusion prevention, and weekly security scans
- **Container Management**: Easy web interface to manage Docker containers
- **Self-Updating**: Servers automatically update themselves from your Git repository
- **Multi-Server Support**: Manage multiple physical servers with independent or shared configurations

**The Result:**

You get a professional server setup in minutes instead of hours, with everything configured using battle-tested best practices. Whether you're managing one server or dozens, everything is controlled from a single configuration file.

**Before Server Helper:**

```text
Manual SSH → Install Docker → Configure firewall → Setup backups →
Install monitoring → Configure alerts → Setup security → Repeat for each server
⏱️ Time: 2-4 hours per server
```

**After Server Helper:**

```text
Edit config file → Run one command → Have coffee
⏱️ Time: 5-10 minutes per server (mostly automated)
```

### Quick Check vs Full Install

| Approach          | Best For                      | Time      | What You Get                                         |
|-------------------|-------------------------------|-----------|------------------------------------------------------|
| **Quick Check**   | Testing, single server, learning | 5-10 min  | Basic monitoring + security on one server            |
| **Full Install**  | Production, multiple servers  | 15-30 min | Complete stack on multiple servers + centralized monitoring |

**Quick Check:** Run [setup.sh](setup.sh) and follow prompts for a single server

**Full Install:** See [Getting Started](#-getting-started-step-by-step-guide) below for multi-server setup

---

## 🌟 What's New in v1.0.0

**Complete architectural overhaul** from bash scripts to Ansible playbooks:

- ✅ **Command Node Architecture**: Manage multiple servers from a central location
- ✅ **Declarative Configuration**: Define desired state, let Ansible handle the rest
- ✅ **Idempotent Operations**: Run playbooks multiple times safely
- ✅ **Multi-Node Support**: Configure dozens of servers with minimal effort
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
│  │  Optional: Traefik Reverse Proxy                │      │
│  │  Optional: Authentik (SSO & Identity)           │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Core Services (All in Dockge stacks):

- **Netdata**: System and container metrics (~100MB RAM)
- **Uptime Kuma**: Uptime monitoring and alerting (~50MB RAM)
- **Dockge**: Docker compose stack manager (~50MB RAM)
- **Loki + Promtail**: Centralized log aggregation (~150MB RAM)
- **Grafana**: Log visualization and dashboards (~200MB RAM)
- **Restic**: Encrypted, deduplicated backups (via systemd timer)
- **Lynis**: Security auditing (via systemd timer)
- **Semaphore UI**: Web-based Ansible automation & playbook execution (~100MB RAM) (optional)
- **Pi-hole + Unbound**: DNS & ad-blocking (~150MB RAM) (optional)
- **Watchtower**: Auto-update containers (optional)
- **Traefik**: Reverse proxy (optional)
- **Authentik**: Identity provider & SSO (optional)

**Total RAM**: ~550-800MB + containers (depending on enabled services)

---

## 🚀 Getting Started: Step-by-Step Guide

### Prerequisites

**Command Node (Your Laptop/Desktop):**

- Any OS: Windows (WSL), macOS, or Linux
- Python 3.8+
- SSH access to your target servers

**Target Servers:**

- Ubuntu 24.04 LTS (recommended) or Ubuntu 22.04
- SSH server running
- At least 2GB RAM (4GB+ recommended)
- User account with sudo privileges

### Step 1: Choose Your Installation Method

| Method | Best For | Difficulty |
|--------|----------|------------|
| **Automated Setup** | Most users, quick start | Easy ⭐ |
| **Manual Setup** | Custom configs, advanced users | Medium ⭐⭐⭐ |

### Step 2A: Automated Setup (Recommended)

Perfect for getting started quickly with sensible defaults:

```bash
# 1. Clone on your command node (laptop/desktop)
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# 2. Run interactive setup
./setup.sh
```

**The script will guide you through:**

1. Installing Ansible on your command node
2. Entering target server IPs and credentials
3. Bootstrapping target servers (creating Ansible user, SSH keys)
4. Configuring services (monitoring, backups, security)
5. Deploying everything automatically

**What you'll be asked:**

- Target server IP addresses
- SSH credentials (username/password or key)
- Backup preferences (NAS, S3, B2, local)
- Monitoring preferences (Netdata, Uptime Kuma)

📖 **Detailed Guide**: [docs/guides/setup-script.md](docs/guides/setup-script.md)

---

### Step 2B: Manual Setup (Advanced)

**For custom configurations or existing Ansible setups:**

#### 1. Install Ansible (on command node)

```bash
# On Ubuntu/Debian
sudo apt update
sudo apt install -y ansible python3-pip git

# Verify installation
ansible --version
```

#### 2. Clone Repository

```bash
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
git checkout v1.0.0
```

#### 3. Install Requirements

```bash
# Install community roles
ansible-galaxy install -r requirements.yml

# Install Python dependencies (if requirements.txt exists)
pip3 install -r requirements.txt
```

#### 4. Configure Inventory

This is the most important step. The inventory defines which servers you want to manage.

**Option A: Interactive Script (Recommended)**

```bash
# Add servers interactively with guided prompts
./scripts/add-server.sh

# Add multiple servers in batch mode
./scripts/add-server.sh --batch
```

The interactive script will:
- Guide you through all server details with prompts
- Validate IP addresses, hostnames, and ports
- Test SSH connectivity before adding
- Automatically backup your inventory before changes
- Add servers to appropriate groups

**Option B: Manual Configuration**

```bash
# Copy the example inventory
cp inventory/hosts.example.yml inventory/hosts.yml

# Edit with your server details
nano inventory/hosts.yml
```

**Example inventory for 3 servers:**

```yaml
all:
  hosts:
    webserver:
      ansible_host: 192.168.1.100
      ansible_user: ansible
      hostname: web-prod-01

    database:
      ansible_host: 192.168.1.101
      ansible_user: ansible
      hostname: db-prod-01

    monitoring:
      ansible_host: 192.168.1.102
      ansible_user: ansible
      hostname: monitor-01

  children:
    production:
      hosts:
        webserver:
        database:
```

📋 See [inventory/hosts.example.yml](inventory/hosts.example.yml) for a fully commented template with all options.

#### 5. Configure Variables

```bash
# Copy example config
cp group_vars/all.example.yml group_vars/all.yml

# Edit with your settings
nano group_vars/all.yml
```

**Key settings to configure:**

- `hostname`: Server hostname
- `nas`: NAS mount configuration (optional)
- `backups`: Backup destinations (NAS, S3, B2, local)
- `monitoring`: Netdata and Uptime Kuma settings
- `security`: Firewall, fail2ban, SSH hardening

#### 6. Setup Ansible Vault (Secure Secrets)

```bash
# Create vault password file
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Create encrypted vault file
ansible-vault create group_vars/vault.yml

# Add your secrets (see group_vars/vault.example.yml for template)
```

**What to store in vault:**

- NAS passwords
- Restic backup passwords
- Cloud credentials (AWS, B2)
- SMTP passwords
- API keys

📖 **Complete guides:**

- [docs/guides/vault.md](docs/guides/vault.md) - Comprehensive vault guide
- [docs/reference/vault-commands.md](docs/reference/vault-commands.md) - Quick reference

**🔧 Vault Helper Scripts:**

Server Helper includes convenient wrapper scripts for vault operations:

```bash
# All-in-one vault management tool
./scripts/vault.sh init                    # Initialize vault setup
./scripts/vault.sh status                  # Show vault status
./scripts/vault.sh create <file>           # Create new encrypted file
./scripts/vault.sh edit <file>             # Edit encrypted file (recommended)
./scripts/vault.sh view <file>             # View encrypted file (read-only)
./scripts/vault.sh validate                # Validate all vault files
./scripts/vault.sh backup <file>           # Create backup
./scripts/vault.sh rekey <file|--all>      # Change vault password

# Individual helper scripts (called by vault.sh)
./scripts/vault-edit.sh group_vars/vault.yml      # Edit vault file
./scripts/vault-view.sh group_vars/vault.yml      # View vault file
./scripts/vault-encrypt.sh <file>                 # Encrypt plain text file
./scripts/vault-decrypt.sh <file>                 # Decrypt (use with caution!)
./scripts/vault-rekey.sh <file|--all>             # Rotate vault password
```

**Quick start with helper scripts:**

```bash
# Initialize vault (creates password file and vault.yml)
./scripts/vault.sh init

# Edit vault to add secrets
./scripts/vault.sh edit group_vars/vault.yml

# Check vault status
./scripts/vault.sh status

# Validate vault can be decrypted
./scripts/vault.sh validate
```

#### 7. Bootstrap Target Servers (First Time Only)

If your target servers don't have the Ansible user set up yet:

```bash
# Bootstrap creates the ansible user and configures SSH
ansible-playbook playbooks/bootstrap.yml -K
```

#### 8. Run Setup Playbook

```bash
# Dry run first (check mode)
ansible-playbook playbooks/setup-targets.yml --check

# Run actual setup on all servers
ansible-playbook playbooks/setup-targets.yml

# Or run on specific servers
ansible-playbook playbooks/setup-targets.yml --limit webserver

# With verbose output
ansible-playbook playbooks/setup-targets.yml -v
```

#### 9. Setup Control Node (Optional but Recommended)

Install centralized monitoring on your command node:

```bash
ansible-playbook playbooks/setup-control.yml
```

This installs:

- **Uptime Kuma**: Monitor all target servers from one place
- **Scanopy**: Security scanning for containers
- **PruneMate**: Automated Docker cleanup

#### 10. Access Services

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

### Understanding the Playbooks

Each playbook does something specific. Here's what they do in plain English:

| Playbook | What It Does | When to Use |
|----------|--------------|-------------|
| **bootstrap.yml** | Prepares a fresh server for Ansible (creates user, sets up SSH) | First time only, on brand new servers |
| **setup-targets.yml** | Installs everything on your target servers (Docker, monitoring, backups, security) | Initial setup and updates |
| **setup-control.yml** | Installs centralized monitoring on your laptop/desktop | Once, on your command node |
| **backup.yml** | Runs backups immediately (normally automated) | Manual backup runs |
| **update.yml** | Updates server configuration from Git (self-update) | Normally runs automatically |
| **security.yml** | Runs security audit with Lynis | Manual security checks |

**Typical workflow:**

1. **First time**: Run `bootstrap.yml` → `setup-targets.yml` → `setup-control.yml`
2. **Add new server**: Run `bootstrap.yml` → `setup-targets.yml` on new server only
3. **Update config**: Edit `group_vars/all.yml` → Run `setup-targets.yml`
4. **Emergency backup**: Run `backup.yml`

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

- **Comprehensive Guide**: [docs/guides/vault.md](docs/guides/vault.md)
- **Quick Reference**: [docs/reference/vault-commands.md](docs/reference/vault-commands.md)
- **Example Vault**: [group_vars/vault.example.yml](group_vars/vault.example.yml)

---

## 📚 Documentation

Complete documentation is available in the [docs/](docs/) directory:

### Getting Started

- **[Quick Start Installation](docs/guides/setup-script.md)** - Step-by-step setup guide
- **[Command Node Architecture](docs/guides/command-node.md)** - Multi-server management
- **[Multi-Server Setup](docs/MULTI_SERVER_SETUP.md)** - Managing multiple physical servers
- **[Running Playbooks](docs/guides/playbooks.md)** - Playbook usage guide

### Configuration & Security

- **[Ansible Vault Guide](docs/guides/vault.md)** - Complete secrets management guide
- **[Vault Quick Reference](docs/reference/vault-commands.md)** - Common commands cheat sheet

### Testing & Quality Assurance

- **[Testing Quick Start](docs/testing-quickstart.md)** - Get started with testing in 5 minutes
- **[Complete Testing Guide](docs/testing.md)** - Comprehensive Molecule + Testinfra documentation
- **CI/CD Pipeline** - Automated testing via GitHub Actions

### Development

- **[Contributing Guide](docs/development/contributing.md)** - Git workflow with Vault
- **[Implementation Details](docs/development/implementation.md)** - Architecture notes

### Additional Resources

- **[Migration Guide](MIGRATION.md)** - Upgrading from v0.x to v1.0.0
- **[Changelog](CHANGELOG.md)** - Version history
- **[Archive](docs/archive/)** - Historical documentation

📖 **[Browse All Documentation](docs/)**

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

authentik:
  enabled: false
  http_port: 9000
  https_port: 9443

semaphore:
  enabled: false
  port: 3000
  database:
    dialect: postgres  # postgres, mysql, or bolt (sqlite)
  admin:
    username: admin
    email: admin@example.com

# Self-Update Configuration
self_update:
  enabled: true
  schedule: "0 5 * * *"  # 5 AM daily
  git_repo: "https://github.com/thelasttenno/Server-Helper.git"
  branch: "main"
  version: "v1.0.0"
```

---

## 🛠️ Deployment Scripts

Server Helper includes convenient scripts and a Makefile to simplify common operations and reduce repetitive work.

### Available Scripts

| Script | Purpose | Quick Start |
|--------|---------|-------------|
| **setup.sh** | Interactive setup wizard | `./setup.sh` |
| **bootstrap-target.sh** | Prepare new target servers | `sudo ./bootstrap-target.sh` |
| **upgrade.sh** | Upgrade Docker images & restart services | `./upgrade.sh` |
| **scripts/open-ui.sh** | Open web UIs in browser | `./scripts/open-ui.sh` |
| **Makefile** | Common operation shortcuts | `make help` |

### Quick Commands (via Makefile)

```bash
# Setup & deployment
make setup                          # Interactive setup
make deploy                         # Deploy to all servers
make deploy-host HOST=server-01     # Deploy to specific server

# Operations
make update                         # Update from Git
make upgrade                        # Upgrade Docker images
make backup                         # Run backups
make security                       # Security audit

# UI & Monitoring
make ui                             # List service URLs
make ui-all                         # Open all UIs in browser
make status                         # Check service status

# Testing
make test                           # Run all tests
make lint                           # Run linting

# Vault management
make vault-edit                     # Edit secrets
make vault-view                     # View secrets
```

### upgrade.sh Examples

```bash
# Upgrade all services on all servers
./upgrade.sh

# Upgrade specific service
./upgrade.sh --service netdata

# Upgrade specific host
./upgrade.sh --host server-01

# Dry run (preview changes)
./upgrade.sh --dry-run

# Pull images without restarting
./upgrade.sh --pull-only
```

### UI Launcher Examples

```bash
# List all service URLs
./scripts/open-ui.sh

# Open Dockge
./scripts/open-ui.sh dockge

# Open Netdata on specific server
./scripts/open-ui.sh netdata server-01

# Open all UIs
./scripts/open-ui.sh all
```

**📖 Complete Guide:** [docs/scripts-guide.md](docs/scripts-guide.md)
**🎯 Quick Reference:** [SCRIPTS_QUICKREF.md](SCRIPTS_QUICKREF.md)

---

## 📚 Common Operations

### Run Full Setup

```bash
# Using Makefile (recommended)
make deploy

# Or using ansible-playbook directly
ansible-playbook playbooks/setup-targets.yml
```

### Update System (self-update)

```bash
# Using Makefile
make update

# Or using ansible-playbook
ansible-playbook playbooks/update.yml

# Or let systemd timer do it automatically
sudo systemctl status ansible-pull.timer
```

### Run Backup Manually

```bash
# Using Makefile
make backup

# Or using ansible-playbook
ansible-playbook playbooks/backup.yml

# Or trigger via systemd
sudo systemctl start restic-backup.service
```

### Security Audit

```bash
# Using Makefile
make security

# Or using ansible-playbook
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

## 🔐 Certificate Management

Server Helper provides **hybrid certificate management** for maximum security and privacy:

- **Public domains** (mealie.example.com) → Let's Encrypt via DNS-01 challenge
- **Internal domains** (grafana.internal) → Smallstep CA (self-hosted)

### Quick Setup

```yaml
# group_vars/all.yml
reverse_proxy:
  enabled: true
  type: "traefik"
  domain: "example.com"

certificates:
  public:
    enabled: true
    challenge: "dns-01"
    dns_provider: "cloudflare"
    domains:
      - "example.com"
      - "*.example.com"

step_ca:
  enabled: true
  port: 9000
```

### Privacy-First Design

- **Cloudflare DNS-only mode**: Traffic goes directly to your server (not proxied)
- **Self-hosted internal CA**: 100% private, no external dependencies
- **Automatic renewal**: Certificates renew automatically

### Service Routing

```yaml
# group_vars/all.yml
services:
  mealie:
    enabled: true
    public: true                    # Uses Let's Encrypt
    domain: "mealie.example.com"
    port: 9925

  grafana:
    enabled: true
    public: false                   # Uses Smallstep CA
    port: 3000
    # Accessible at: grafana.internal
```

### Client Certificate Installation

After deploying Smallstep CA, install the root certificate on client devices:

```bash
# Automatic installation
curl -sSL https://your-server:9000/install-root-ca.sh | bash

# Manual Linux
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt
sudo cp step-ca-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**Documentation:**

- [Certificate Management Guide](docs/guides/certificates.md)
- [Cloudflare Privacy Guide](docs/guides/cloudflare-privacy.md)
- [Smallstep CA Guide](docs/guides/smallstep-ca.md)
- [Traefik Guide](docs/guides/traefik.md)

---

## 🌐 DNS & Service Discovery (Pi-hole + Unbound)

### Overview

Server Helper includes an optional DNS stack with Pi-hole and Unbound that provides:

- **Internal DNS**: Access services via clean names like `grafana.internal` or `netdata.internal`
- **Ad Blocking**: Network-wide ad blocking for all devices
- **Privacy**: Recursive DNS with Unbound (no external DNS queries)
- **Auto-Discovery**: Services automatically registered to DNS via Ansible

### Quick Setup

```yaml
# In group_vars/all.yml
dns:
  enabled: true
  private_domain: internal  # Services accessible as service.internal

  pihole:
    port: 8080  # Web UI
    theme: default-dark

  unbound:
    forward_zone: false  # true for faster lookups, false for privacy
```

### Auto-Discovered Services

When enabled, DNS automatically registers:
- `dockge.internal` → Dockge UI
- `grafana.internal` → Grafana dashboards
- `netdata.internal` → Netdata metrics
- `uptime-kuma.internal` → Uptime Kuma
- `pihole.internal` → Pi-hole admin
- `{{ hostname }}.internal` → Server itself

### Custom DNS Records

Add custom entries in `group_vars/all.yml`:

```yaml
dns:
  custom_records:
    - domain: nas.internal
      ip: 192.168.1.100
    - domain: router.internal
      ip: 192.168.1.1

  database_services:
    - name: postgres
      ip: 192.168.1.50
    - name: mysql
      ip: 192.168.1.51

  application_services:
    - name: webapp
      ip: 192.168.1.100
```

### Access Pi-hole

```bash
# Pi-hole Web UI
http://your-server:8080/admin

# Login with password from vault
ansible-vault view group_vars/vault.yml | grep pihole_password
```

### Configure Client Devices

**Option 1: Network-wide (Router)**
1. Log into your router
2. Set DNS to your server's IP: `192.168.1.x`
3. All devices now use Pi-hole

**Option 2: Per-Device**
- **Windows**: Network Settings → DNS → Manual → Primary DNS: `192.168.1.x`
- **macOS**: Network Preferences → DNS → Add: `192.168.1.x`
- **Linux**: Edit `/etc/resolv.conf` → `nameserver 192.168.1.x`
- **iOS/Android**: Wi-Fi Settings → Configure DNS → Manual → `192.168.1.x`

### Monitoring Integration

DNS integrates with your existing monitoring:

**Grafana Dashboard:**
```bash
# Pi-hole metrics automatically exported to Prometheus
# Import Pi-hole dashboard: https://grafana.com/grafana/dashboards/10176
```

**Uptime Kuma Monitors:**
- Pi-hole Health: `http://your-server:8080/admin/`
- DNS Resolution: DNS check for `google.com`
- Internal DNS: DNS check for `grafana.internal`

**Netdata:**
- Monitors Pi-hole query performance
- Tracks blocked queries
- DNS response times

### Features

| Feature | Description |
|---------|-------------|
| **Ad Blocking** | Block ads, trackers, malware domains network-wide |
| **Internal DNS** | Clean service names instead of `http://192.168.1.50:3000` |
| **Privacy** | Recursive DNS with Unbound (no Google/Cloudflare tracking) |
| **DNSSEC** | DNS security validation |
| **Caching** | Faster DNS responses |
| **Query Logging** | See all DNS queries in Pi-hole UI |
| **Whitelist/Blacklist** | Customize blocking rules |
| **Dark Theme** | Easy on the eyes |

### Advanced Configuration

**Enable DNS-over-TLS forwarding:**
```yaml
dns:
  unbound:
    forward_zone: true  # Use upstream DNS instead of recursive
    forward_tls: true   # Encrypted DNS queries
    forward_servers:
      - 1.1.1.1  # Cloudflare
      - 9.9.9.9  # Quad9
```

**Custom upstream DNS:**
```yaml
dns:
  unbound:
    forward_servers:
      - 208.67.222.222  # OpenDNS
      - 208.67.220.220
```

**Add private domains:**
```yaml
dns:
  additional_private_domains:
    - home.arpa
    - lan
    - localdomain
```

### Troubleshooting

**DNS not resolving:**
```bash
# Check if Pi-hole is running
docker ps | grep pihole

# Test DNS resolution
dig @localhost google.com
dig @localhost grafana.internal

# Check Pi-hole logs
docker logs pihole
docker logs unbound
```

**Pi-hole UI not accessible:**
```bash
# Check firewall
sudo ufw status | grep 8080

# Check if port is in use
sudo netstat -tlnp | grep 8080
```

**Services not auto-registering:**
```bash
# Check custom DNS list
cat /opt/dockge/stacks/dns/pihole/custom.list

# Restart Pi-hole to reload
docker restart pihole
```

---

## 🤖 Semaphore UI - Ansible Automation Web Interface

Semaphore UI provides a modern web-based interface for running Ansible playbooks, managing inventories, and scheduling automated tasks. It's perfect for teams who want a user-friendly way to execute Server Helper playbooks without SSH or command-line access.

### What is Semaphore?

Semaphore is an open-source alternative to Ansible Tower/AWX with a focus on simplicity. It provides:

- **Web-based Playbook Execution**: Run any Ansible playbook from your browser
- **Real-time Logs**: Watch playbook execution with live output
- **Scheduled Tasks**: Cron-like scheduling for automated runs
- **Access Control**: Multi-user support with role-based permissions
- **Task History**: Complete audit trail of all playbook runs
- **Inventory Management**: Visual inventory editor
- **Secret Management**: Secure storage for SSH keys and passwords
- **Notifications**: Telegram, Slack, and email alerts

### Enable Semaphore

In [group_vars/all.yml](group_vars/all.yml):

```yaml
semaphore:
  enabled: true
  port: 3000  # Or any available port

  # Database options
  database:
    dialect: postgres  # Recommended: postgres, mysql, or bolt (sqlite)
    host: semaphore-db
    port: 5432
    name: semaphore
    user: semaphore

  # Admin credentials (change password on first login!)
  admin:
    username: admin
    email: admin@example.com

  # Optional: Enable notifications
  telegram:
    enabled: true
    token: "{{ vault_semaphore_telegram_token }}"
    chat: "{{ vault_semaphore_telegram_chat }}"

  slack:
    enabled: true
    url: "{{ vault_semaphore_slack_webhook }}"
```

In [group_vars/vault.yml](group_vars/vault.yml):

```yaml
# Generate with: openssl rand -base64 32
vault_semaphore_db_password: "strong-database-password"
vault_semaphore_admin_password: "change-on-first-login"

# CRITICAL: Generate once and NEVER change (encrypts stored credentials)
vault_semaphore_access_key_encryption: "permanent-encryption-key-32-bytes"

# Optional notification secrets
vault_semaphore_telegram_token: "bot_token_from_botfather"
vault_semaphore_telegram_chat: "chat_id"
vault_semaphore_slack_webhook: "https://hooks.slack.com/services/..."
```

### Deploy Semaphore

```bash
# Deploy to all servers
ansible-playbook playbooks/setup-targets.yml --tags semaphore

# Deploy to specific server
ansible-playbook playbooks/setup-targets.yml --tags semaphore --limit server-01

# Using Makefile
make deploy-semaphore
```

### Access Semaphore UI

After deployment:

1. Navigate to `http://<server-ip>:3000`
2. Login with admin credentials from vault
3. **IMPORTANT**: Change the default password immediately!
4. A setup guide is generated at `/root/semaphore-setup-guide.md`

### Initial Setup

Follow these steps in the Semaphore UI:

#### 1. Create a Project

- Click "New Project"
- Name: e.g., "Server Management"
- Save

#### 2. Add SSH Key (Key Store)

- Navigate to "Key Store" → "New Key"
- Type: SSH Key
- Name: "Ansible SSH Key"
- Paste your private SSH key
- Save

#### 3. Add Inventory

- Go to "Inventory" → "New Inventory"
- Type: Static or File
- Content: Your inventory file or paste inventory YAML

Example static inventory:
```yaml
all:
  hosts:
    server01:
      ansible_host: 192.168.1.100
      ansible_user: ansible
```

#### 4. Add Repository

For local playbooks (recommended):

- URL: `file:///opt/semaphore/playbooks`
- Branch: (leave empty)
- Access Key: None

For Git repository:

- URL: `https://github.com/thelasttenno/Server-Helper.git`
- Branch: `main`
- Access Key: Select your SSH key (if private repo)

#### 5. Create Task Template

- Navigate to "Task Templates" → "New Template"
- Name: "Update Servers"
- Playbook: `playbooks/update.yml`
- Inventory: Select your inventory
- Repository: Select your repository
- Environment: (optional) Add variables
- Vault Password: Add if using encrypted vault

#### 6. Run Your First Task

- Go to "Tasks" → "New Task"
- Select template
- Click "Run"
- Watch real-time logs!

### Using Server Helper Playbooks

Copy your Server Helper playbooks to Semaphore's directory:

```bash
# On the target server
sudo cp -r /path/to/Server-Helper/* /opt/semaphore/playbooks/

# Or mount during deployment (recommended)
# In docker-compose.yml, add volume:
# - /opt/Server-Helper:/playbooks:ro
```

Example templates to create:

| Template Name | Playbook | Description |
| --- | --- | --- |
| **Setup Targets** | `playbooks/setup-targets.yml` | Full server setup |
| **Update System** | `playbooks/update.yml` | System updates |
| **Run Backups** | `playbooks/backup.yml` | Manual backup |
| **Security Audit** | `playbooks/security.yml` | Lynis scan |
| **Deploy Monitoring** | `playbooks/setup-targets.yml --tags monitoring` | Install monitoring only |

### Database Options

**PostgreSQL (Recommended for Production):**

- Best performance and reliability
- Supports concurrent access
- Required for multi-user teams

**MySQL:**

- Alternative to PostgreSQL
- Good performance
- Widely supported

**Bolt/SQLite (Development Only):**

- Single-file database
- No separate container needed
- Limited to single-user access
- Not recommended for production

Change database in [group_vars/all.yml](group_vars/all.yml):

```yaml
semaphore:
  database:
    dialect: bolt  # For development/testing
```

### Scheduled Tasks

Create cron-like schedules in Semaphore:

1. Create a Task Template (e.g., "Daily Backup")
2. In template settings, enable "Schedule"
3. Set cron expression: `0 2 * * *` (2 AM daily)
4. Save

Example schedules:

- **Daily backups**: `0 2 * * *`
- **Weekly updates**: `0 3 * * 0` (Sunday 3 AM)
- **Hourly health check**: `0 * * * *`

### Notifications

Configure in [group_vars/all.yml](group_vars/all.yml):

**Telegram:**
```yaml
semaphore:
  telegram:
    enabled: true
    token: "{{ vault_semaphore_telegram_token }}"
    chat: "{{ vault_semaphore_telegram_chat }}"
```

**Slack:**
```yaml
semaphore:
  slack:
    enabled: true
    url: "{{ vault_semaphore_slack_webhook }}"
```

**Email:**
```yaml
semaphore:
  email:
    enabled: true
    sender: semaphore@example.com
    host: smtp.gmail.com
    port: 587
    username: semaphore@example.com
    password: "{{ vault_semaphore_smtp_password }}"
```

### Semaphore Security Best Practices

1. **Change Default Password**: Immediately after first login
2. **Use Strong Encryption Key**: Never change `vault_semaphore_access_key_encryption` after initial setup
3. **Limit Network Access**: Use firewall rules to restrict Semaphore port
4. **Enable HTTPS**: Use reverse proxy (Traefik) with SSL
5. **Regular Backups**: Backup Semaphore database regularly
6. **LDAP/SSO**: Integrate with Authentik or LDAP for enterprise auth

### Monitoring Semaphore with Uptime Kuma

Add Semaphore to Uptime Kuma:

```yaml
uptime_kuma:
  monitors:
    - name: "Semaphore Health"
      type: "http"
      url: "http://localhost:3000/api/ping"
      interval: 60
```

### Useful Commands

```bash
# View Semaphore logs
docker logs -f semaphore

# View database logs (PostgreSQL)
docker logs -f semaphore-db

# Restart Semaphore
cd /opt/semaphore
docker compose restart semaphore

# Access PostgreSQL database
docker exec -it semaphore-db psql -U semaphore -d semaphore

# Backup Semaphore database
docker exec semaphore-db pg_dump -U semaphore semaphore > semaphore-backup.sql

# Restore Semaphore database
cat semaphore-backup.sql | docker exec -i semaphore-db psql -U semaphore -d semaphore
```

### Semaphore Troubleshooting

**Cannot access Semaphore UI:**
```bash
# Check if container is running
docker ps | grep semaphore

# Check logs
docker logs semaphore

# Verify port is not blocked
sudo ufw status | grep 3000
```

**Database connection errors:**
```bash
# Check database container
docker ps | grep semaphore-db

# Check database health
docker inspect semaphore-db | grep Health

# Check database logs
docker logs semaphore-db
```

**Task execution fails:**

- Verify SSH key is correct in Key Store
- Check inventory is accessible
- Verify playbook paths are correct
- Review task logs in Semaphore UI
- Ensure Ansible vault password is configured (if using encrypted secrets)

### Advanced: LDAP Authentication

Integrate with enterprise LDAP/Active Directory:

```yaml
semaphore:
  ldap:
    enabled: true
    server: ldap://ldap.example.com:389
    binddn: "cn=admin,dc=example,dc=com"
    password: "{{ vault_semaphore_ldap_password }}"
    searchdn: "ou=users,dc=example,dc=com"
```

Users can then login with their LDAP credentials instead of local accounts.

### Resources

- **Official Documentation**: <https://docs.ansible-semaphore.com/>
- **GitHub Repository**: <https://github.com/ansible-semaphore/semaphore>
- **Community Support**: <https://github.com/ansible-semaphore/semaphore/discussions>
- **Setup Guide**: `/root/semaphore-setup-guide.md` (generated on deployment)

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

## 🧪 Testing

Server-Helper includes comprehensive automated testing using **Molecule** and **Testinfra** to catch configuration bugs before deployment.

### Quick Start

```bash
# Install test dependencies
pip install -r requirements-test.txt

# Test all roles
make test

# Test specific role
make test-role ROLE=common

# Run linting
make lint
```

### What Gets Tested

- ✅ **Service Deployment**: Containers start successfully
- ✅ **Configuration**: Files created with correct permissions
- ✅ **Network**: Ports listening correctly
- ✅ **Dependencies**: Required packages installed
- ✅ **Integration**: Services communicate properly

### Available Tests

| Role | What's Tested | Run With |
| ------ | --------------- | ---------- |
| **common** | System setup, packages, directories | `cd roles/common && molecule test` |
| **security** | fail2ban, SSH hardening, firewall | `cd roles/security && molecule test` |
| **dockge** | Docker service, Dockge container | `cd roles/dockge && molecule test` |
| **netdata** | Monitoring stack, health checks | `cd roles/netdata && molecule test` |

### CI/CD Testing

Tests run automatically on:

- Every push to `main` or `develop`
- Every pull request
- Can be triggered manually

View results: [GitHub Actions](.github/workflows/molecule-tests.yml)

### Documentation

- **[Quick Start Guide](docs/testing-quickstart.md)** - 5-minute setup
- **[Complete Testing Guide](docs/testing.md)** - Detailed documentation

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
