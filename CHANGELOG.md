# Changelog

All notable changes to Server Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] — 2025-01-01

### Added
- Complete project rebuild from PROJECT_HANDOFF.md specification
- 19 Ansible roles across 3 tiers (Foundation, Target Agents, Control Stacks)
- 8 orchestration playbooks (site, bootstrap, control, target, add-target, update, upgrade, backup)
- Interactive setup.sh CLI with 10 library modules
- Molecule test suites for all 19 roles
- 3 GitHub Actions CI/CD workflows
- Docker Compose health checks on all services (improvement #6)
- Auto-detect LXC containers and set skip flags (improvement #4)
- YAML stdout callback and profile_tasks for better output (improvement #5)

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

## [1.0.0] — Previous Version
- Original implementation (see PROJECT_HANDOFF.md for details)
