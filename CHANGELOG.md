# Changelog

All notable changes to Server Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-02-19

### Added

#### Security Audit & Hardening

- `no_log: true` on all Ansible tasks that template vault secrets (11 tasks across 7 roles)
- Pre-commit hook (`.githooks/pre-commit`) blocks commits with unencrypted `vault.yml`
- Vault encryption check added to `.pre-commit-config.yaml` as a local hook
- Makefile input validation — `HOST`, `ROLE`, `SERVICE` checked against `[a-zA-Z0-9._-]`
- `.ansible_cache/` added to `.gitignore`
- File permissions hardened: compose files → `0640`, stream.conf → `0600`, init-ca.sh → `0700`

#### Notification Security

- Discord & Slack templates use `python3 json.dumps()` for safe JSON serialization
- Telegram template uses `curl --data-urlencode` for URL encoding
- Email template passes args via `sys.argv` instead of shell interpolation

#### Restic Improvements

- Install restic from GitHub releases (version-pinned, default `0.18.1`) instead of apt
- Architecture auto-detection (amd64/arm64) for binary download
- `--compression auto` enabled on backups
- Stale lock cleanup (`restic unlock --remove-all`) before each backup
- JSONL backup metrics written to `/var/log/restic/metrics.json` (hostname, duration, size, snapshot count)
- Backup verify script (`restic-verify.sh`) with monthly systemd timer
- All 3 backup scripts now use `server-helper-notify` instead of inline curl

#### Documentation

- Consolidated all docs into `/docs` folder (single source of truth)
  - `getting-started.md` — Prerequisites, installation, first deploy
  - `architecture.md` — Tier model, data flows, playbooks, LXC support
  - `configuration.md` — Variables, vault, host_vars, inventory
  - `roles.md` — All 20 roles with vars, templates, deploy paths
  - `security.md` — Hardening, vault, pre-commit hooks, audit model
  - `operations.md` — Makefile reference, backups, upgrades, troubleshooting
  - `development.md` — Script library, Molecule testing, CI/CD, contributing
- Root `setup.sh` and `bootstrap-target.sh` wrappers for quick clone-and-run

### Changed

- Traefik dashboard auth now uses bcrypt hash (`password_hash('bcrypt')`) instead of plaintext password
- `secrets_mgr.sh` writes vault to secure tmpdir (RAM-backed) before encrypting, never writes plaintext to disk
- README.md slimmed to overview + docs index (detail moved to `/docs`)
- Combined `CHANGELOG_old.md` into unified changelog

### Removed

- `PROJECT_HANDOFF.md` — content absorbed into `/docs`

### Security

- Traefik basicauth label was rendering plaintext password (both a security bug and functional bug — Traefik expects htpasswd format)
- Notification scripts were vulnerable to shell injection via message content
- Makefile targets passed user input directly to shell commands without validation
- `secrets_mgr.sh` wrote plaintext secrets to `group_vars/vault.yml` before encryption

---

## [0.3.0] — 2026-02-19

### Added

#### Project Improvements (12 enhancements)

- Docker Compose health checks on all services
- Auto-detect LXC containers and set skip flags
- YAML stdout callback and profile_tasks for better output
- `notifications` role — multi-channel dispatcher (Discord, Slack, Telegram, Email)
- Pre-commit hooks and git hooks (`.githooks/pre-push` syntax check)
- Backup verification script with monthly timer
- `make doctor` command for fleet diagnostics
- README files generated for all roles

### Changed

- Molecule test suites added/updated for all 19 roles
- 3 GitHub Actions CI/CD workflows added

---

## [0.2.0] — 2026-02-19

### Added

- Complete project rebuild from specification
- 19 Ansible roles across 3 tiers (Foundation, Target Agents, Control Stacks)
- 8 orchestration playbooks (site, bootstrap, control, target, add-target, update, upgrade, backup)
- Interactive setup.sh CLI with 10 library modules

### Tier 1 Roles (Foundation)

- `common` — Package installation, chrony NTP, locale, microcode, sysctl tuning
- `lvm_config` — Extend LVM volumes, supports ext4/xfs
- `swap` — Create swap file, set swappiness
- `qemu_agent` — Install QEMU guest agent on KVM/QEMU VMs
- `security` — SSH hardening, fail2ban, UFW, Lynis audits
- `docker` — Docker CE from official repo with daemon.json
- `watchtower` — Automatic Docker image updates
- `restic` — Automated backups with systemd timers

### Tier 2 Roles (Target Agents)

- `netdata` — Dual-mode monitoring (child/parent)
- `promtail` — Log shipping to Loki
- `docker_socket_proxy` — Read-only Docker API proxy
- `dockge` — Visual Docker Compose manager

### Tier 3 Roles (Control Stacks)

- `traefik` — Reverse proxy with Let's Encrypt and security headers
- `authentik` — SSO/OIDC with PostgreSQL and Redis
- `step_ca` — Internal certificate authority
- `pihole` — DNS with Unbound recursive resolver and DNSSEC
- `loki` — Log aggregation with boltdb-shipper
- `grafana` — Dashboards with auto-provisioned datasources
- `uptime_kuma` — Status monitoring

---

## [0.1.0] — 2025-01-29

### Major Release — Complete Architecture Rewrite

This release represents a complete rewrite of Server Helper with a focus on modularity, security, and ease of use.

### Added

#### Bootstrap Scripts

- **setup.sh**: Complete rewrite with interactive menu system
  - Pure controller architecture: handles only sourcing and menu orchestration
  - All functional logic extracted to library modules
  - Strict sourcing: exits with FATAL error if required library missing
  - Vault management via menu (encrypt, edit, view, re-key)
  - Security hardening: cleanup trap clears sensitive variables on exit
  - Vault permission check: auto-validates/fixes .vault_password 600 permissions

- **scripts/lib/**: Modular library structure
  - `security.sh` — Core security (cleanup trap, secure tmpdir, permission enforcement)
  - `ui_utils.sh` — Colors, headers, secure logging with command redaction
  - `vault_mgr.sh` — Vault operations with interactive menu, RAM disk temp files
  - `menu_extras.sh` — Extras menu (add server, open UI, validate, test, upgrade)
  - `inventory_mgr.sh` — Inventory parsing with no temp file residue
  - `health_check.sh` — SSH, Docker, disk, memory health checking
  - `config_mgr.sh` — YAML configuration management with Python parsing
  - `upgrade.sh` — Docker image upgrades and service restarts with tracking

- **bootstrap-target.sh**: Day 0 target preparation
  - Standalone design (no library dependencies)
  - Virtualization detection (LXC, VM, bare metal)
  - LVM expansion, swap creation, QEMU agent, SSH hardening, admin user setup

#### Configuration Wizard

- Quick Setup Mode with auto-detection (IP, timezone, user, domain)
- Auto-generate all vault secrets with one-click
- DNS configuration presets (Cloudflare, Google, Quad9)
- Backup destination configuration (local, NAS, S3)

#### Tiered Playbook Architecture

- **site.yml** — 3-tier deployment with post-deploy cert distribution and health checks
- **bootstrap.yml** — Day 0 target prep via Ansible
- **target.yml** / **control.yml** — Targeted deployments
- **update.yml** — Rolling system updates with reboot support
- **backup.yml** — Manual backup triggers
- **add-target.yml** — Dynamic server addition

#### Configuration

- `ansible.cfg` with vault integration, SSH multiplexing, fact caching
- `requirements.yml` with Galaxy dependencies
- Example files for inventory, group_vars, and vault

### Changed

- Complete rewrite from monolithic scripts to modular Ansible roles
- All Docker services deploy to `/opt/stacks/` for Dockge compatibility
- Standardized variable naming (`target_*`, `control_*`, `vault_*`)

### Security

- SSH hardening via drop-in config at `/etc/ssh/sshd_config.d/`
- UFW firewall with deny-by-default
- fail2ban with aggressive SSH protection
- Lynis weekly security audits
- Ansible Vault for all secrets
- Docker Socket Proxy restricts API access
- Step-CA for internal TLS
- Authentik SSO
- Zero-leak shell security: log redaction, cleanup trap, RAM disk temp files, vault permission enforcement

### Removed

- Legacy monolithic deployment scripts
- Hardcoded credentials
- Deprecated roles: dns, logging, lynis (standalone), nas_mounts, proxy, semaphore, system_setup, system_users

---

## [0.0.1] — Previous Release

Initial release with basic Ansible playbooks and bash scripts.
