# Changelog

All notable changes to Server Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-29

### Major Release - Complete Architecture Rewrite

This release represents a complete rewrite of Server Helper with a focus on modularity, security, and ease of use.

### Added

#### Bootstrap Scripts
- **setup.sh**: Complete rewrite with interactive menu system
  - **Pure Controller architecture**: setup.sh handles only sourcing and menu orchestration
  - All functional logic extracted to library modules
  - **Strict sourcing**: Scripts exit with FATAL error if required library missing (no fallbacks)
  - Main menu with Setup, Extras, and Exit options
  - Vault management via menu (encrypt, edit, view, re-key)
  - Add server functionality
  - Service UI launcher
  - Test runners for roles
  - Ask-once logic: detects existing config and offers health check, add servers, re-run, or fresh start
  - **Security hardening**: Cleanup trap clears sensitive variables on exit
  - **Vault permission check**: Auto-validates/fixes .vault_password 600 permissions

- **scripts/lib/**: Modular library structure for shared bash functions
  - `security.sh`: **Core security module** (must be sourced FIRST)
    - Cleanup trap clears sensitive variables on EXIT/SIGINT/SIGTERM
    - Permission enforcement (auto-validates/fixes .vault_password 600 permissions)
    - Secure temp directory selection (RAM disk preferred)
    - Memory sanitization for PASSWORD/SECRET/TOKEN/KEY variables
  - `ui_utils.sh`: Colors, headers, secure logging with command redaction
  - `vault_mgr.sh`: Vault operations with interactive menu, RAM disk temp files
  - `menu_extras.sh`: Extras menu functions (add server, open UI, validate, test, upgrade)
  - `inventory_mgr.sh`: Inventory parsing with no temp file residue
  - `health_check.sh`: SSH, Docker, disk, memory health checking
  - `config_mgr.sh`: YAML configuration management with Python parsing
  - `upgrade.sh`: Docker image upgrades and service restarts with tracking

- **bootstrap-target.sh**: Day 0 target preparation script
  - **Standalone design**: No library dependencies (can be downloaded and run directly)
  - **Recommended usage**: Download → Verify contents → Execute (never pipe curl to bash)
  - Virtualization detection (LXC, VM, bare metal) using `systemd-detect-virt`
  - LVM expansion (auto-skipped on LXC containers)
  - 2GB swap file creation (auto-skipped on LXC containers)
  - QEMU guest agent installation (VMs only)
  - SSH hardening with drop-in configuration
  - Admin user creation with SSH key injection

#### Tiered Playbook Architecture
- **site.yml**: Main entry point with 3-tier model
  - Tier 1 (Foundation): All nodes get identical hardening
  - Tier 2 (Target Muscle): Worker nodes get monitoring agents
  - Tier 3 (Control Brain): Management node gets service stacks
  - Post-deployment: Step-CA certificate distribution
  - Final validation: Service health checks

- **bootstrap.yml**: Day 0 target preparation via Ansible
- **target.yml**: Target node service deployment
- **control.yml**: Control node stack deployment
- **update.yml**: Rolling system updates with reboot support
- **backup.yml**: Manual backup triggers
- **add-target.yml**: Dynamic server addition

#### Core Roles (Tier 1)
- **common**: Base packages, timezone, chrony NTP, CPU microcode, logrotate, sysctl tuning
- **lvm_config**: Automatic LVM expansion to 100% FREE (ext4/xfs support)
- **swap**: 2GB swap file with fallocate, configurable swappiness
- **qemu_agent**: QEMU guest agent for KVM/QEMU VMs
- **security**: SSH hardening, UFW firewall, fail2ban, Lynis security auditing
- **docker**: Docker CE from official repository, daemon.json configuration
- **watchtower**: Automatic container updates with scheduling
- **restic**: Backup automation with S3 support and retention policies

#### Monitoring Roles (Tier 2/3)
- **netdata**: Parent/child streaming architecture
  - Parent mode for control node with dbengine storage
  - Child mode for targets with memory-only streaming
  - Health alarms for CPU, RAM, disk
  - Netdata Cloud claim support

- **loki**: Log aggregation with 31-day retention
  - boltdb-shipper storage
  - Compactor with retention enforcement

- **promtail**: Log shipping agent
  - Docker JSON log parsing
  - System, syslog, auth log collection

- **grafana**: Dashboards and visualization
  - Auto-provisioned Loki and Netdata datasources
  - Authentik SSO integration with role mapping
  - Plugin installation support

- **uptime_kuma**: Status monitoring
  - Docker container monitoring
  - Setup guide generation

#### Identity & Gateway Roles (Tier 3)
- **traefik**: Reverse proxy and load balancer
  - Let's Encrypt ACME with HTTP challenge
  - DNS challenge support for wildcards
  - Step-CA integration for internal certs
  - Security headers middleware

- **authentik**: SSO/OIDC identity provider
  - PostgreSQL + Redis backend
  - Bootstrap credentials
  - OAuth2 provider ready
  - Setup guide generation

- **step_ca**: Internal certificate authority
  - Auto-initialization
  - ACME provisioner for automatic certs
  - Root CA distribution script

- **pihole**: DNS with ad-blocking
  - Unbound recursive resolver
  - Custom DNS/CNAME records
  - DNSSEC validation

- **dockge**: Docker Compose stack manager
  - Visual stack management at `/opt/stacks/`

#### Security Features
- **docker_socket_proxy**: Secure Docker API access for targets
  - UFW rules restrict to control node IP only
  - Read-only permissions by default

#### Validation & Testing
- **scripts/validate-fleet.sh**: Fleet connectivity validation
  - SSH connectivity tests
  - Docker daemon status
  - Control service health checks
  - Target agent connectivity
  - Docker Socket Proxy accessibility
  - `--quick` mode for ping-only
  - `--services` mode for control services only

#### Configuration
- **ansible.cfg**: Optimized Ansible configuration
  - Vault integration with `.vault_password` file
  - SSH multiplexing for performance
  - Fact caching

- **requirements.yml**: Galaxy dependencies
  - community.docker
  - community.general
  - community.crypto
  - community.postgresql
  - ansible.posix

- **inventory/hosts.example.yml**: Example inventory
- **group_vars/all.example.yml**: Example configuration
- **group_vars/vault.example.yml**: Example secrets

### Changed

- Complete rewrite from monolithic scripts to modular Ansible roles
- All Docker services now deploy to `/opt/stacks/` for Dockge compatibility
- Standardized variable naming with `target_*`, `control_*`, `vault_*` prefixes
- Improved idempotency across all roles
- Enhanced virtualization detection using multiple methods

### Security

- SSH hardening uses drop-in config at `/etc/ssh/sshd_config.d/`
- UFW firewall with deny-by-default policy
- fail2ban with aggressive SSH protection
- Lynis weekly security audits
- Ansible Vault for all secrets
- Docker Socket Proxy restricts API access
- Step-CA for internal TLS certificates
- Authentik SSO eliminates password sprawl
- **Zero-Leak Shell Security**:
  - `log_exec` redacts commands containing password/token/vault/secret keywords
  - Cleanup trap unsets sensitive variables on EXIT/SIGINT/SIGTERM
  - Temp files use RAM disk (/dev/shm) when available
  - Vault password file auto-validated for 600 permissions at startup
  - **Removed vault decrypt-to-plaintext** - only `edit` (keeps encrypted) and `view` (memory only) available

### Documentation

- **README.md**: Complete rewrite with architecture diagrams, role tables, service URLs
- **docs/wiki/**: Six comprehensive guides:
  - `01-installation.md` - Prerequisites, setup, deployment steps
  - `02-architecture.md` - Tiered model, data flow diagrams, dependencies
  - `03-configuration.md` - Variable reference, vault secrets, host overrides
  - `04-roles.md` - Complete role documentation for all 21 roles
  - `05-security.md` - SSH hardening, firewall, PKI, SSO configuration
  - `06-troubleshooting.md` - Common issues, recovery procedures, validation
- **Setup guides**: Auto-generated per-service at `/opt/stacks/{service}/SETUP-GUIDE.md`
- **CHANGELOG.md**: Comprehensive version history following Keep a Changelog format

### Removed

- Legacy monolithic deployment scripts
- Hardcoded credentials
- Manual service configuration
- Deprecated roles: dns, logging, lynis (standalone), nas_mounts, proxy, semaphore, system_setup, system_users

### Migration from v1

1. Backup existing configuration
2. Export any custom settings
3. Run `./setup.sh` and choose "Start fresh"
4. Re-enter your configuration
5. Deploy with `ansible-playbook playbooks/site.yml`

---

## [1.0.0] - Previous Release

Initial release with basic Ansible playbooks and bash scripts.

---

## Future Roadmap

### v2.1.0 (Planned)
- [ ] Prometheus metrics integration
- [ ] AlertManager for notifications
- [ ] Automated SSL certificate renewal monitoring
- [ ] Backup verification testing

### v2.2.0 (Planned)
- [ ] Multi-site support
- [ ] VPN mesh networking
- [ ] Kubernetes cluster deployment option
- [ ] Terraform provider integration
