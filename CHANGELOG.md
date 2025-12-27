# Server Helper Changelog

## Version 1.0.0 - Complete Rewrite: Ansible Edition (2025-12-23)

### 🎉 Major Release - Complete Architectural Overhaul

This is a **complete rewrite** from bash scripts to Ansible playbooks. This is a **breaking change** requiring migration from v0.3.0.

---

### 🌟 New Architecture

**Technology Stack:**
- **Infrastructure as Code**: Ansible playbooks (declarative, idempotent)
- **Monitoring**: Netdata (metrics) + Uptime Kuma (alerting)
- **Container Management**: Dockge (web UI for docker-compose stacks)
- **Backups**: Restic (encrypted, deduplicated, incremental)
- **Security**: Lynis (automated auditing) + fail2ban + UFW
- **Automation**: ansible-pull (self-updating) + systemd timers

**Deployment Model:**
- All services deployed as Docker containers via Dockge stacks
- One stack per service in `/opt/dockge/stacks/`
- Systemd timers for recurring tasks (backups, security scans)
- Web-based management (no more CLI menu)

---

### ✨ New Features

#### Monitoring & Alerting

- **Netdata Integration**: 
  - Real-time system and container metrics
  - Pre-configured alarms for CPU, RAM, disk
  - Push alerts to Uptime Kuma via webhooks
  - Netdata Cloud integration (optional)

- **Uptime Kuma Integration**:
  - Hybrid monitoring (pull + push)
  - Pull: Monitors service HTTP endpoints every 60s
  - Push: Receives critical alerts from Netdata/Restic/Lynis
  - Multiple notification channels (Email, Discord, Telegram, etc.)

- **Docker Network Isolation**:
  - `monitoring` network for observability stack
  - `proxy` network for reverse proxy (optional)

#### Backup System

- **Restic Backups**:
  - Encrypted, compressed, deduplicated
  - Incremental backups (space-efficient)
  - Multiple destinations (any combination):
    - NAS (CIFS/SMB)
    - AWS S3
    - Backblaze B2
    - Local storage
  - Flexible retention policies:
    - Daily, weekly, monthly, yearly
  - Heartbeat notifications to Uptime Kuma

- **Systemd Timer**:
  - Scheduled backups via systemd (not cron)
  - Configurable schedule
  - Logs to journald

#### Security

- **Lynis Integration**:
  - Automated weekly security audits
  - Systemd timer for scheduling
  - Reports to `/var/log/lynis/`
  - Optional Uptime Kuma notifications

- **Automated Hardening**:
  - fail2ban (intrusion prevention)
  - UFW firewall (default deny)
  - SSH hardening (disable password auth, root login)
  - Unattended security updates (optional)

#### Container Management

- **Dockge Web UI**:
  - Visual stack management
  - Compose file editor
  - Container logs viewer
  - Stack health monitoring

- **All Services in Stacks**:
  ```
  /opt/dockge/stacks/
  ├── netdata/
  ├── uptime-kuma/
  ├── watchtower/ (optional)
  └── reverse-proxy/ (optional)
  ```

#### Optional Services

- **Watchtower**: Automatic container updates
  - Configurable schedule
  - Monitor-only mode
  - Notifications via Shoutrrr

- **Traefik Reverse Proxy**:
  - Automatic Let's Encrypt certificates
  - HTTP → HTTPS redirection
  - Dashboard UI
  - Docker integration

- **Nginx Proxy Manager**:
  - Alternative to Traefik
  - Web-based configuration
  - Let's Encrypt integration

#### Self-Update

- **ansible-pull Integration**:
  - Pulls latest playbook from GitHub
  - Runs setup playbook automatically
  - Systemd timer (daily at 5 AM default)
  - Idempotent (safe to re-run)
  - Logs to `/var/log/ansible-pull.log`

---

### 🔄 Migration from v0.3.0

**Breaking Changes:**
- Complete rewrite - no upgrade path, requires fresh setup
- Configuration format changed: bash → YAML
- CLI menu removed → Web UIs
- Bash commands → Ansible playbooks
- Tar backups → Restic backups

**Migration Path:**
1. Export v0.3.0 configuration
2. Map to Ansible variables
3. Run new Ansible setup
4. Migrate custom stacks
5. Remove old installation

**See**: [MIGRATION.md](MIGRATION.md) for detailed guide

---

### 📦 What's Included

#### Ansible Playbooks

- `playbooks/setup.yml` - Main setup playbook
- `playbooks/backup.yml` - Manual backup trigger
- `playbooks/security.yml` - Security audit
- `playbooks/update.yml` - Self-update (via ansible-pull)

#### Ansible Roles

- `common` - Base system setup
- `security` - Security hardening
- `nas` - NAS share mounting
- `dockge` - Container management
- `netdata` - Metrics monitoring
- `uptime-kuma` - Uptime monitoring
- `restic` - Backup system
- `lynis` - Security auditing
- `reverse-proxy` - Traefik/Nginx (optional)
- `watchtower` - Auto-updates (optional)
- `self-update` - ansible-pull setup

#### Community Roles

- `geerlingguy.docker` - Docker installation
- `geerlingguy.security` - Security baseline
- `geerlingguy.pip` - Python pip
- `weareinteractive.ufw` - UFW firewall
- `robertdebock.fail2ban` - fail2ban IPS

#### Docker Compose Stacks

- Dockge (container management)
- Netdata (monitoring)
- Uptime Kuma (alerting)
- Watchtower (auto-updates, optional)
- Traefik (reverse proxy, optional)

#### Configuration

- Declarative YAML configuration
- Inventory-based multi-host support
- Group variables for global settings
- Host variables for per-server customization

---

### 🎯 Key Improvements

#### Developer Experience

- **Idempotent**: Re-run playbooks safely
- **Version Control**: Infrastructure as code in Git
- **Modular**: Easy to add/remove components
- **Testable**: Check mode for dry runs
- **Documented**: Comprehensive README + migration guide

#### Operations

- **Web UIs**: All management via browser
- **Automated**: Systemd timers for recurring tasks
- **Monitored**: Real-time metrics and alerts
- **Secure**: Automated hardening and audits
- **Flexible**: Choose services à la carte

#### Reliability

- **Container Restart Policies**: Auto-recovery
- **Health Checks**: Uptime Kuma monitors
- **Backup Verification**: Restic check command
- **Log Rotation**: Automatic cleanup
- **Resource Limits**: Prevent runaway containers

---

### 📊 System Requirements

**Minimum:**
- Ubuntu 24.04 LTS
- 2 GB RAM
- 20 GB disk space
- 1 CPU core
- Ansible 2.15+ (on control node)

**Recommended:**
- 4 GB RAM
- 50 GB disk space
- 2 CPU cores
- Ansible 2.16+

**Resource Usage:**
- Netdata: ~100-150 MB RAM
- Uptime Kuma: ~50-80 MB RAM
- Dockge: ~50 MB RAM
- Docker: ~100 MB RAM
- **Total**: ~300-400 MB RAM + containers

---

### 🔧 Configuration Highlights

**Flexible NAS Support:**
```yaml
nas:
  shares:
    - ip: "192.168.1.100"
      share: "backup"
      mount: "/mnt/nas/backup"
    - ip: "192.168.1.100"
      share: "media"
      mount: "/mnt/nas/media"
```

**Multiple Backup Destinations:**
```yaml
restic:
  destinations:
    nas:
      enabled: true
    s3:
      enabled: true
    local:
      enabled: true
```

**Hybrid Monitoring:**
```yaml
# Uptime Kuma monitors (pull)
monitors:
  - name: "Netdata Health"
    type: "http"
    url: "http://localhost:19999/api/v1/info"

# Netdata alarms push to Uptime Kuma
netdata:
  alarms:
    cpu_critical: 95
    uptime_kuma_urls:
      cpu: "http://localhost:3001/api/push/CPU123"
```

---

### 📝 Usage Examples

#### Initial Setup
```bash
ansible-playbook playbooks/setup.yml
```

#### Run Backup
```bash
ansible-playbook playbooks/backup.yml
```

#### Security Audit
```bash
ansible-playbook playbooks/security.yml
```

#### Update Configuration
```bash
nano group_vars/all.yml
ansible-playbook playbooks/setup.yml
```

---

### 🐛 Known Issues

None at release. This is a fresh rewrite with no legacy code.

---

### 🔮 Future Roadmap

**v1.1.0 (Minor):**
- Additional backup destinations (SFTP, Dropbox)
- Grafana integration for dashboards
- Prometheus metrics collection
- Email notification templates

**v1.2.0 (Minor):**
- Multi-host deployment support
- High availability configurations
- Database backup support (MySQL, PostgreSQL)
- Application-specific stacks (WordPress, Ghost, etc.)

**v2.0.0 (Major):**
- Kubernetes support (Helm charts)
- GitOps workflow (ArgoCD)
- Multi-cloud deployment (AWS, GCP, Azure)
- Enterprise features

---

### 🙏 Credits

**Community Roles:**
- Jeff Geerling (geerlingguy) - Docker, Security, Pip roles
- WeAreInteractive - UFW role
- Robert de Bock - fail2ban role

**Technology Stack:**
- Ansible (Red Hat)
- Docker (Docker Inc.)
- Netdata (Netdata Inc.)
- Uptime Kuma (Louis Lam)
- Dockge (Louis Lam)
- Restic (Restic Authors)
- Lynis (CISOfy)

---

## Version 0.3.0 - Self-Update & Loading Indicators (2025-12-22)

### New Features
- Self-updater system with GitHub integration
- Loading indicators (spinners, progress bars)
- Auto-update checking in monitoring loop
- Rollback capability
- Enhanced menu (43 options)

**See**: Previous CHANGELOG for full v0.3.0 details

---

## Version 0.2.x - Enhanced Features (2025-12-22)

### v0.2.3
- Pre-installation detection
- Emergency NAS unmount
- Installation management commands

### v0.2.2
- Enhanced debug mode
- Comprehensive logging

### v0.2.1
- Configuration file backup
- Enhanced backup manifests

### v0.2.0
- Modular architecture
- Library system

---

## Version 0.1.x - Initial Releases

Initial bash-based implementation.

---

**Note**: For migration from v0.3.0 to v1.0.0, see [MIGRATION.md](MIGRATION.md)
