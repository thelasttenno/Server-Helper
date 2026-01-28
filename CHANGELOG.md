# Server Helper Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## How to Update This Changelog

When contributing, please add your changes under the "Unreleased" section in the appropriate category:

- **Added** - New features
- **Changed** - Changes in existing functionality
- **Deprecated** - Soon-to-be removed features
- **Removed** - Removed features
- **Fixed** - Bug fixes
- **Security** - Security fixes

Example:

```markdown
## Unreleased

### Added
- New backup destination support for SFTP

### Fixed
- Netdata health check timeout issue
```

## Unreleased

### Added

- **Certificate Management (Hybrid: Let's Encrypt + Smallstep CA)**:
  - Complete hybrid certificate management for public and internal domains
  - **Public domains**: Let's Encrypt via DNS-01 challenge (auto-renewed, browser-trusted)
  - **Internal domains**: Smallstep CA (self-hosted, fully private, ACME-compatible)
  - Privacy-first Cloudflare integration (DNS-only mode, no traffic proxying)
  - Support for multiple DNS providers: Cloudflare, Route53, DigitalOcean, Namecheap, GoDaddy
  - Wildcard certificate support for public domains (`*.example.com`)
  - Automatic certificate selection based on service routing (`public: true/false`)
  - Client root CA installation scripts for all major operating systems
  - Traefik v3.0 integration with dual certificate resolvers
  - Security headers middleware (HSTS, X-Content-Type-Options, etc.)
  - Dashboard authentication with htpasswd
  - Comprehensive documentation: [docs/guides/certificates.md](docs/guides/certificates.md)
  - Cloudflare privacy hardening guide: [docs/guides/cloudflare-privacy.md](docs/guides/cloudflare-privacy.md)
  - New role: `roles/step-ca/` for Smallstep CA deployment
  - Updated Traefik configuration with dynamic routing
  - Vault integration for certificate secrets

- **Smallstep CA Role** (`roles/step-ca/`):
  - Self-hosted ACME-compatible certificate authority
  - Docker-based deployment (~128MB RAM)
  - Automatic certificate renewal (30-day default)
  - ACME protocol support for Traefik integration
  - Configurable certificate durations
  - Client installation scripts for Linux, macOS, Windows
  - Health checks and monitoring integration

- **Enhanced Traefik Configuration**:
  - Upgraded to Traefik v3.0
  - Dual certificate resolvers: `letsencrypt` (public) + `step-ca` (internal)
  - DNS-01 challenge support for privacy-focused certificate validation
  - Dynamic service routing with automatic cert selection
  - Security headers middleware for all routes
  - Rate limiting and compression middlewares
  - Internal-only access middleware for private services
  - Dashboard with authentication (no more insecure mode by default)

- **Service Routing Configuration**:
  - New `services` configuration section for defining public/internal services
  - Automatic Traefik labels generation based on service type
  - Pre-configured routes for default services (Dockge, Netdata, Grafana, etc.)
  - Wildcard domain support for public services
  - Health check configuration per service

- **DNS & Service Discovery (Pi-hole + Unbound)**:
  - Complete DNS role with Pi-hole for ad-blocking and local DNS (~100MB RAM)
  - Unbound recursive DNS resolver for privacy (~50MB RAM)
  - Automatic service discovery: All enabled services auto-register to DNS
  - Access services via clean names like `grafana.internal` instead of IPs
  - Network-wide ad blocking for all devices
  - DNSSEC validation via Unbound
  - Prometheus exporter for Pi-hole metrics (~20MB RAM)
  - Integration with Grafana (dashboard ID: 10176), Netdata, and Uptime Kuma
  - Configurable upstream DNS with DNS-over-TLS support
  - Custom DNS records for databases, applications, and infrastructure
  - Dark theme web UI with query logging
  - Comprehensive documentation: [roles/dns/README.md](roles/dns/README.md)
  - Quick start guide: [docs/DNS_QUICKSTART.md](docs/DNS_QUICKSTART.md)
  - Automatic firewall configuration (ports 53, 8080)
  - Vault integration for Pi-hole admin password
  - Docker network integration with monitoring stack
  - Auto-generated custom.list from Ansible inventory

- **Centralized Logging Stack (Loki + Promtail + Grafana)**:
  - Complete logging role with Loki for log aggregation (~150MB RAM)
  - Promtail for automatic log collection from Docker containers and system logs (~50MB RAM)
  - Grafana for log visualization and dashboard creation (~200MB RAM)
  - Pre-configured datasource connection between Grafana and Loki
  - Automatic collection of Docker container logs, syslog, auth logs, and /var/log/* files
  - Configurable log retention (default: 31 days)
  - LogQL query interface for powerful log searching and filtering
  - Support for custom log sources via additional_jobs configuration
  - Optional SMTP configuration for Grafana email alerts
  - Comprehensive documentation: [docs/guides/logging-stack.md](docs/guides/logging-stack.md)
  - Quick start guide: [docs/LOGGING_QUICKSTART.md](docs/LOGGING_QUICKSTART.md)
  - Automatic firewall configuration (ports 3000, 3100)
  - Vault integration for secure password management

- **Multi-Server Support Documentation**:
  - Comprehensive guide for managing multiple physical servers ([docs/MULTI_SERVER_SETUP.md](docs/MULTI_SERVER_SETUP.md))
  - Enhanced inventory examples with secondary server configurations
  - Best practices for port management, backup scheduling, and resource isolation
  - Common scenarios: load distribution, environment separation, geographic distribution
  - Per-server variable override examples for ports, backup paths, and schedules
  - Multi-server management commands and troubleshooting guide
  - Server grouping strategies (by environment, location, function)
- **Enhanced Configuration Examples**:
  - Added multi-server configuration section to `group_vars/all.example.yml`
  - Updated `inventory/hosts.example.yml` with detailed secondary server example
  - Documented staggered backup schedules to prevent NAS resource contention
  - Added examples for separate backup repositories per server
- **Authentik SSO Integration**:
  - Complete Authentik identity provider role for centralized authentication
  - OAuth2/OIDC/SAML support for modern application integration
  - Multi-factor authentication (MFA) with TOTP and WebAuthn/Passkeys
  - Reverse proxy authentication for services without native OAuth
  - PostgreSQL and Redis backend for scalable user management
  - Automated deployment via Dockge stack
  - Comprehensive setup guide with integration examples
  - Vault integration for secure credential management
  - Firewall configuration for Authentik ports
  - Email configuration support for password resets and invitations
- **Interactive Server Addition Script** (`scripts/add-server.sh`):
  - Guided wizard for adding new servers to inventory
  - Input validation for IP addresses, hostnames, and ports
  - SSH connectivity testing before adding to inventory
  - Automatic inventory backup before changes
  - Batch mode for adding multiple servers
  - Support for custom SSH ports, keys, and timezones
  - Automatic server group assignment
- **Quick Reference Documentation** ([docs/quick-reference.md](docs/quick-reference.md)):
  - Comprehensive command reference for common operations
  - Common workflows and troubleshooting commands
  - Quick lookup guide for all major features
- GitHub Actions workflow for automated releases
- Changelog verification in pull requests
- Automatic release note generation

---

## Version 1.0.0 - Complete Rewrite: Ansible Edition (2025-12-27)

### 🧹 Post-Release Updates (2025-12-27)

#### Vault Management Enhancements

**New Vault Helper Scripts:**

Added comprehensive vault management tooling to simplify Ansible Vault operations:

- **Master script `vault.sh`**: All-in-one vault management tool
  - `vault.sh init` - Initialize vault setup (creates password & vault file)
  - `vault.sh status` - Health check for vault configuration
  - `vault.sh create/edit/view` - Secure vault file operations
  - `vault.sh validate` - Validate vault files can be decrypted
  - `vault.sh backup/restore` - Vault file backup management
  - `vault.sh diff` - Show git diff of encrypted files
  - `vault.sh rekey` - Rotate vault passwords

- **Individual helper scripts**:
  - `vault-edit.sh` - Safe editing (recommended, no plain text files)
  - `vault-view.sh` - Read-only viewing (secure)
  - `vault-encrypt.sh` - Encrypt plain text files
  - `vault-decrypt.sh` - Decrypt files (with security warnings)
  - `vault-rekey.sh` - Password rotation (single file or all)

- **Security features**:
  - ✅ Automatic backups before destructive operations
  - ✅ Colored output (green/red/yellow) for clear feedback
  - ✅ Multiple confirmation prompts for dangerous operations
  - ✅ File permission validation
  - ✅ Comprehensive error handling

**New Documentation:**

- **External secret management integration** ([docs/integrations/external-secrets.md](docs/integrations/external-secrets.md)):
  - HashiCorp Vault integration
  - AWS Systems Manager Parameter Store
  - AWS Secrets Manager
  - Azure Key Vault
  - Google Cloud Secret Manager
  - 1Password CLI integration
  - Environment variables for CI/CD
  - Migration strategies and comparison matrix

- **CI/CD workflow integration** ([docs/workflows/vault-in-ci-cd.md](docs/workflows/vault-in-ci-cd.md)):
  - GitHub Actions integration examples
  - GitLab CI/CD pipelines
  - Jenkins integration
  - Azure DevOps pipelines
  - Git hooks (pre-commit) for vault security
  - Team collaboration workflows
  - Automated secret rotation
  - Vault validation tests

- **Script documentation** ([scripts/README.md](scripts/README.md)):
  - Complete guide to all vault helper scripts
  - Usage examples and workflows
  - Best practices and security guidelines
  - Troubleshooting guide

**README Updates:**

- Added vault helper scripts section with usage examples
- Added links to new documentation
- Improved vault setup instructions

**Files Added:**

- `scripts/vault.sh` - Master vault management tool
- `scripts/vault-edit.sh` - Safe vault editing
- `scripts/vault-view.sh` - Read-only vault viewing
- `scripts/vault-encrypt.sh` - Encrypt plain text files
- `scripts/vault-decrypt.sh` - Decrypt vault files (with warnings)
- `scripts/vault-rekey.sh` - Password rotation tool
- `docs/integrations/external-secrets.md` - External secret manager integration guide
- `docs/workflows/vault-in-ci-cd.md` - CI/CD workflow guide
- `scripts/README.md` - Scripts documentation

**Benefits:**

- 🚀 Easier vault management (no need to remember ansible-vault commands)
- 🔒 Enhanced security (automatic validations, warnings, backups)
- 📚 Better documentation (CI/CD integration, external secrets)
- 🤝 Improved team collaboration (standardized workflows)
- 🔄 Automated workflows (CI/CD examples, secret rotation)

---

**Codebase Cleanup & Bug Fixes:**

- **Fixed variable naming inconsistencies**: Standardized `monitoring.netdata.*` variables across all roles
- **Fixed Netdata deployment**: Added proper deployment tasks to netdata role (was missing)
- **Fixed backup playbook**: Corrected broken task import reference
- **Added missing variables**: Control node configuration for Uptime Kuma, Scanopy, PruneMate
- **Created missing templates**: security-report.j2, control-monitoring-targets.yml.j2
- **Removed duplicate code**: Deleted legacy setup.yml playbook and unused nas role
- **Documentation reorganization**: Moved all docs to `docs/` directory with clear structure
  - `docs/guides/` - Usage guides
  - `docs/reference/` - Quick references
  - `docs/development/` - Developer docs
  - `docs/archive/` - Historical documents
- **Removed redundant docs**: Deleted 8 outdated/duplicate markdown files
- **Updated README**: Added documentation section with proper links to reorganized docs

**Files Affected:**

- Cleaned up 20+ markdown files into organized structure
- Fixed 10+ variable references across roles
- Created 2 new templates
- Removed 2 unused components

---

## Version 1.0.0 - Initial Release (2025-12-23)

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
- `reverse-proxy` - Traefik (optional)
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
