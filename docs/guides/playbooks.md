## Playbook Guide: Control Node vs Target Node Architecture

## Overview

Server Helper uses a **control/target architecture** with separate playbooks for different deployment scenarios:

- **Control Node**: Your laptop/desktop that runs centralized monitoring for ALL servers
- **Target Nodes**: The Ubuntu servers you're configuring with Docker, services, etc.

## Playbook Structure

```
playbooks/
├── setup-targets.yml    # Configure target servers (recommended)
├── setup-control.yml    # Install centralized monitoring on control node
├── setup.yml            # Legacy all-in-one playbook
├── bootstrap.yml        # Initial target node preparation
├── backup.yml           # Run backups on targets
├── security.yml         # Security hardening on targets
└── update.yml           # System updates on targets
```

## Service Distribution

### Control Node Services

**Playbook**: `playbooks/setup-control.yml`

| Service | Purpose | Port | Why Control Node? |
|---------|---------|------|-------------------|
| **Uptime Kuma** | Centralized uptime monitoring | 3001 | Monitor ALL servers from one dashboard |
| **Netdata Parent** (optional) | Metrics aggregation | 19999 | Aggregate metrics from all targets |

**Install with**:
```bash
ansible-playbook playbooks/setup-control.yml
```

### Target Node Services

**Playbook**: `playbooks/setup-targets.yml`

| Service | Purpose | Port | Why Target Nodes? |
|---------|---------|------|-------------------|
| **Docker** | Container runtime | - | Required for containers |
| **Dockge** | Container stack management | 5001 | Per-server management |
| **Netdata** | System metrics | 19999 | Per-server monitoring |
| **Restic** | Encrypted backups | - | Per-server backups |
| **fail2ban** | Intrusion prevention | - | Per-server security |
| **UFW** | Firewall | - | Per-server firewall |
| **SSH Hardening** | SSH security | 22 | Per-server SSH |
| **Lynis** | Security auditing | - | Per-server audits |

**Install with**:
```bash
ansible-playbook playbooks/setup-targets.yml
```

## Deployment Scenarios

### Scenario 1: Multi-Server Deployment (Recommended)

**Best for**: Managing 2+ servers from a central location

```bash
# 1. Setup control node (install Ansible, clone repo)
./setup.sh

# 2. Configure target servers
ansible-playbook playbooks/setup-targets.yml

# 3. Install centralized monitoring on control node
ansible-playbook playbooks/setup-control.yml
```

**Result**:
```
Control Node (Your Laptop)
├── Centralized Uptime Kuma → monitors all targets
└── Ansible → manages all targets

Target Servers (3 servers)
├── Server 1: Docker, Dockge, Netdata, Restic, Security
├── Server 2: Docker, Dockge, Netdata, Restic, Security
└── Server 3: Docker, Dockge, Netdata, Restic, Security
```

**Access**:
- Uptime Kuma (centralized): `http://localhost:3001`
- Server 1 Dockge: `http://192.168.1.100:5001`
- Server 1 Netdata: `http://192.168.1.100:19999`
- Server 2 Dockge: `http://192.168.1.101:5001`
- ...

### Scenario 2: Single Server Deployment

**Best for**: One server with all services local

```bash
# 1. Clone repo on server
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# 2. Run all-in-one playbook
ansible-playbook playbooks/setup.yml
```

**Result**:
```
Single Server
├── Docker, Dockge, Netdata, Uptime Kuma
├── Restic, fail2ban, UFW, Lynis
└── Everything runs locally
```

**Access**:
- Dockge: `http://192.168.1.100:5001`
- Netdata: `http://192.168.1.100:19999`
- Uptime Kuma: `http://192.168.1.100:3001` (monitors only this server)

### Scenario 3: Hybrid (Some servers, some standalone)

**Best for**: Mix of centrally managed and standalone servers

```bash
# For centrally managed servers:
ansible-playbook playbooks/setup-targets.yml --limit production

# For standalone servers:
ansible-playbook playbooks/setup.yml --limit standalone-server

# Control node:
ansible-playbook playbooks/setup-control.yml
```

## Detailed Playbook Documentation

### playbooks/setup-targets.yml

**Purpose**: Configure target servers with essential services (no Uptime Kuma)

**Usage**:
```bash
# Configure all target servers
ansible-playbook playbooks/setup-targets.yml

# Configure specific server
ansible-playbook playbooks/setup-targets.yml --limit server-01

# Configure a group
ansible-playbook playbooks/setup-targets.yml --limit production

# Dry run (check mode)
ansible-playbook playbooks/setup-targets.yml --check

# Skip certain services
ansible-playbook playbooks/setup-targets.yml --skip-tags backups

# Only install specific services
ansible-playbook playbooks/setup-targets.yml --tags docker,dockge
```

**What it does**:
1. Updates system packages
2. Installs Docker & Docker Compose
3. Configures storage (LVM, NAS mounts)
4. Creates system users
5. Installs Dockge for container management
6. Installs Netdata for metrics
7. Configures Restic backups
8. Hardens security (fail2ban, UFW, SSH)
9. Schedules Lynis security scans

**What it DOESN'T do**:
- ❌ Install Uptime Kuma (use setup-control.yml instead)
- ❌ Install Ansible (not needed on targets)

**Tags**:
- `common`, `base` - Base system setup
- `docker`, `setup` - Docker installation
- `security`, `firewall`, `ssh` - Security hardening
- `dockge`, `containers` - Container management
- `monitoring`, `netdata` - Metrics collection
- `backups`, `restic` - Backup configuration
- `nas`, `storage` - Storage configuration

---

### playbooks/setup-control.yml

**Purpose**: Install centralized monitoring on control node

**Usage**:
```bash
# Install control node services
ansible-playbook playbooks/setup-control.yml

# Install with specific config
ansible-playbook playbooks/setup-control.yml -e "control_uptime_kuma_port=3002"
```

**What it does**:
1. Installs Docker on control node (if not present)
2. Deploys centralized Uptime Kuma
3. Creates monitoring configuration template
4. Displays URLs for all target servers

**What it DOESN'T do**:
- ❌ Configure target servers
- ❌ Install services on targets

**Configuration**:
```yaml
# In group_vars/all.yml
control_node_install_dir: /opt/control-node
control_uptime_kuma_enabled: true
control_uptime_kuma_port: 3001
uptime_kuma_version: "1"
```

**After installation**:
1. Access Uptime Kuma: `http://localhost:3001`
2. Complete initial setup (create admin account)
3. Add monitors for each target server:
   - **HTTP Monitor**: Netdata health check
   - **HTTP Monitor**: Dockge web UI
   - **Ping Monitor**: Server availability
   - **Port Monitor**: SSH connectivity

---

### playbooks/setup.yml (Legacy)

**Purpose**: All-in-one playbook for single server or per-server Uptime Kuma

**Usage**:
```bash
# Install everything on target servers
ansible-playbook playbooks/setup.yml
```

**What it does**:
- Everything from `setup-targets.yml`
- PLUS: Installs Uptime Kuma on EACH target server

**Use this when**:
- You have only one server
- You want Uptime Kuma on each server (not centralized)
- You're migrating from an older setup

**Don't use this when**:
- You have multiple servers (use setup-targets.yml + setup-control.yml)
- You want centralized monitoring

---

### playbooks/bootstrap.yml

**Purpose**: Prepare fresh target nodes for Ansible management

**Usage**:
```bash
# Bootstrap all new servers
ansible-playbook playbooks/bootstrap.yml --ask-become-pass

# Bootstrap specific server
ansible-playbook playbooks/bootstrap.yml --limit new-server -K
```

**What it does**:
1. Installs Python 3 (required for Ansible)
2. Updates system packages
3. Installs SSH server
4. Creates admin user with sudo
5. Adds SSH keys from control node
6. Basic SSH security (disable root, disable passwords)

**When to use**:
- Fresh Ubuntu installation
- New server added to inventory
- Target doesn't have Python 3

**Alternative**: Use `bootstrap-target.sh` script on each target manually

---

### playbooks/backup.yml

**Purpose**: Manually trigger backups on target servers

**Usage**:
```bash
# Run backups on all servers
ansible-playbook playbooks/backup.yml

# Backup specific server
ansible-playbook playbooks/backup.yml --limit server-01

# Backup specific group
ansible-playbook playbooks/backup.yml --limit production
```

**What it does**:
- Runs Restic backup for configured paths
- Prunes old backups according to retention policy
- Sends status to Uptime Kuma (push monitor)

---

### playbooks/security.yml

**Purpose**: Run security hardening and audits

**Usage**:
```bash
# Harden all servers
ansible-playbook playbooks/security.yml

# Specific server
ansible-playbook playbooks/security.yml --limit server-01
```

**What it does**:
- Runs Lynis security audit
- Updates fail2ban rules
- Reviews firewall configuration
- Checks SSH hardening

---

### playbooks/update.yml

**Purpose**: ansible-pull self-update mechanism

**Usage**:
```bash
# This runs automatically via systemd timer on target nodes
# Or manually:
ansible-playbook playbooks/update.yml
```

**What it does**:
- Pulls latest playbook changes from Git
- Re-runs configuration (idempotent)
- Updates system packages
- Logs to `/var/log/ansible-pull.log`

---

## Common Workflows

### Initial Setup (Multi-Server)

```bash
# 1. On control node
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
./setup.sh

# Script will:
# - Install Ansible on control node
# - Prompt for target IPs
# - Create inventory
# - Bootstrap targets (optional)
# - Run setup-targets.yml
# - Offer to run setup-control.yml
```

### Adding a New Server

```bash
# 1. Bootstrap the new server
ansible-playbook playbooks/bootstrap.yml --limit new-server -K

# 2. Add to inventory (inventory/hosts.yml)
# new-server:
#   ansible_host: 192.168.1.104
#   ansible_user: ansible

# 3. Configure the server
ansible-playbook playbooks/setup-targets.yml --limit new-server

# 4. Add monitors in Uptime Kuma on control node
```

### Updating Configuration

```bash
# 1. Edit group_vars/all.yml or host_vars/

# 2. Re-run playbook (idempotent)
ansible-playbook playbooks/setup-targets.yml

# Or update just one service
ansible-playbook playbooks/setup-targets.yml --tags security
```

### Monitoring Setup

```bash
# 1. Ensure targets are configured
ansible-playbook playbooks/setup-targets.yml

# 2. Install centralized monitoring
ansible-playbook playbooks/setup-control.yml

# 3. Access Uptime Kuma
# http://localhost:3001

# 4. Add monitors for each target:
# - Name: Server-01 Netdata
#   Type: HTTP
#   URL: http://192.168.1.100:19999/api/v1/info
#   Interval: 60s

# - Name: Server-01 Dockge
#   Type: HTTP
#   URL: http://192.168.1.100:5001
#   Interval: 60s

# - Name: Server-01 SSH
#   Type: Port
#   Host: 192.168.1.100
#   Port: 22
#   Interval: 60s
```

### Backup Testing

```bash
# Run manual backup
ansible-playbook playbooks/backup.yml --limit server-01

# Check backup status
ansible server-01 -m shell -a "restic -r /path/to/repo snapshots"

# Restore file
ansible server-01 -m shell -a "restic -r /path/to/repo restore latest --target /restore"
```

## Variables and Configuration

### Control Node Variables

```yaml
# group_vars/all.yml
control_node_install_dir: /opt/control-node
control_uptime_kuma_enabled: true
control_uptime_kuma_port: 3001
uptime_kuma_version: "1"
```

### Target Node Variables

```yaml
# group_vars/all.yml

# Monitoring (Netdata only on targets)
monitoring:
  netdata:
    enabled: true
    port: 19999
    claim_token: ""  # Optional: Netdata Cloud

# Container Management (per target)
dockge:
  enabled: true
  port: 5001
  stacks_dir: /opt/dockge/stacks

# Backups (per target)
backups:
  enabled: true

restic:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  destinations:
    nas:
      enabled: true
      path: /mnt/nas/backups/restic

# Security (per target)
security:
  fail2ban_enabled: true
  ufw_enabled: true
  ssh_hardening: true
  ssh_port: 22
  lynis_enabled: true
```

## Comparison Table

| Feature | setup-targets.yml | setup-control.yml | setup.yml (legacy) |
|---------|-------------------|-------------------|-------------------|
| **Target** | Remote servers | Control node (localhost) | Remote servers |
| **Docker** | ✅ Installed | ✅ Installed | ✅ Installed |
| **Dockge** | ✅ Per-server | ❌ Not needed | ✅ Per-server |
| **Netdata** | ✅ Per-server | ⚠️ Optional (parent) | ✅ Per-server |
| **Uptime Kuma** | ❌ Not installed | ✅ Centralized | ✅ Per-server |
| **Restic** | ✅ Per-server | ❌ Not needed | ✅ Per-server |
| **Security** | ✅ Per-server | ❌ Not needed | ✅ Per-server |
| **Use Case** | Multi-server (recommended) | Centralized monitoring | Single server |

## Best Practices

### 1. Use Control/Target Split for Multi-Server

✅ **Do**:
```bash
ansible-playbook playbooks/setup-targets.yml
ansible-playbook playbooks/setup-control.yml
```

❌ **Don't**:
```bash
ansible-playbook playbooks/setup.yml  # Installs Uptime Kuma on every target
```

### 2. Tag Usage for Selective Updates

```bash
# Update only security settings
ansible-playbook playbooks/setup-targets.yml --tags security

# Update only monitoring
ansible-playbook playbooks/setup-targets.yml --tags monitoring

# Skip backups during setup
ansible-playbook playbooks/setup-targets.yml --skip-tags backups
```

### 3. Group Targeting

```yaml
# inventory/hosts.yml
all:
  children:
    production:
      hosts:
        server-01:
        server-02:
    development:
      hosts:
        dev-01:
```

```bash
# Update only production
ansible-playbook playbooks/setup-targets.yml --limit production

# Update only dev
ansible-playbook playbooks/setup-targets.yml --limit development
```

### 4. Idempotent Re-Runs

All playbooks are idempotent - safe to run multiple times:

```bash
# Update configuration
vim group_vars/all.yml

# Re-run (only changes what's needed)
ansible-playbook playbooks/setup-targets.yml
```

## Troubleshooting

### Control Node Services Not Accessible

**Problem**: Can't access Uptime Kuma on control node

**Solution**:
```bash
# Check if container is running
docker ps | grep uptime-kuma

# Check logs
docker logs uptime-kuma-control

# Restart container
docker restart uptime-kuma-control

# Re-run playbook
ansible-playbook playbooks/setup-control.yml
```

### Target Services Missing

**Problem**: Netdata not installed on target

**Solution**:
```bash
# Re-run with specific tags
ansible-playbook playbooks/setup-targets.yml --tags monitoring --limit server-01

# Check if role ran
ansible-playbook playbooks/setup-targets.yml --limit server-01 -vv
```

### Playbook Selection Confusion

**Question**: Which playbook should I use?

**Answer**:
- **Multiple servers**: `setup-targets.yml` + `setup-control.yml`
- **Single server**: `setup.yml`
- **New server**: `bootstrap.yml` first, then `setup-targets.yml`
- **Manual backup**: `backup.yml`
- **Security audit**: `security.yml`

## Summary

For the **recommended multi-server setup**:

1. **Bootstrap targets** (once):
   ```bash
   ansible-playbook playbooks/bootstrap.yml -K
   ```

2. **Configure targets**:
   ```bash
   ansible-playbook playbooks/setup-targets.yml
   ```

3. **Setup control node**:
   ```bash
   ansible-playbook playbooks/setup-control.yml
   ```

4. **Access services**:
   - Centralized Uptime Kuma: `http://localhost:3001`
   - Server 1 Dockge: `http://192.168.1.100:5001`
   - Server 1 Netdata: `http://192.168.1.100:19999`

5. **Ongoing management**:
   ```bash
   ansible-playbook playbooks/backup.yml          # Backups
   ansible-playbook playbooks/security.yml        # Security
   ansible-playbook playbooks/setup-targets.yml   # Updates
   ```

Enjoy streamlined multi-server management! 🚀
