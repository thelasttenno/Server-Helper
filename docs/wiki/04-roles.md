# Role Reference

Detailed documentation for each Ansible role in Server Helper.

## Table of Contents

1. [Tier 1: Foundation Roles](#tier-1-foundation-roles)
2. [Tier 2: Target Agent Roles](#tier-2-target-agent-roles)
3. [Tier 3: Control Stack Roles](#tier-3-control-stack-roles)

---

## Tier 1: Foundation Roles

These roles are applied to ALL nodes (control and targets).

### common

**Purpose:** Base system configuration and essential packages.

**What it does:**
- Installs base packages (curl, wget, htop, vim, git, jq, etc.)
- Configures timezone and locale
- Sets up Chrony for NTP synchronization
- Installs CPU microcode updates
- Configures Docker log rotation
- Applies sysctl performance tuning

**Files:**
- `roles/common/defaults/main.yml` - Default variables
- `roles/common/tasks/main.yml` - Task definitions
- `roles/common/handlers/main.yml` - Service handlers
- `roles/common/templates/chrony.conf.j2` - NTP configuration
- `roles/common/templates/docker-logrotate.j2` - Log rotation

**Key Variables:**
```yaml
common_timezone: "America/Vancouver"
common_packages: [curl, wget, htop, ...]
common_chrony_enabled: true
common_sysctl_tuning: true
```

---

### lvm_config

**Purpose:** Expand LVM logical volumes to use all available space.

**What it does:**
- Detects root logical volume
- Extends LV to 100% of free space
- Resizes filesystem (ext4 or xfs)

**Conditions:**
- Skipped on LXC containers (`lvm_skip: true`)
- Skipped if no LVM volumes found

**Files:**
- `roles/lvm_config/defaults/main.yml`
- `roles/lvm_config/tasks/main.yml`

**Key Variables:**
```yaml
lvm_config_enabled: true
lvm_skip: false  # Set true for LXC
lvm_auto_extend: true
```

---

### swap

**Purpose:** Create and configure swap file.

**What it does:**
- Creates 2GB swap file at `/swapfile`
- Sets appropriate permissions (600)
- Configures fstab for persistence
- Sets swappiness via sysctl

**Conditions:**
- Skipped on LXC containers (`swap_skip: true`)
- Skipped if swap already exists

**Files:**
- `roles/swap/defaults/main.yml`
- `roles/swap/tasks/main.yml`

**Key Variables:**
```yaml
swap_enabled: true
swap_skip: false  # Set true for LXC
swap_file_path: "/swapfile"
swap_file_size: "2G"
swap_swappiness: 10
```

---

### qemu_agent

**Purpose:** Install QEMU guest agent for VM management.

**What it does:**
- Detects if running on KVM/QEMU
- Installs qemu-guest-agent package
- Enables and starts the service

**Conditions:**
- Only runs on VMs (not LXC, not bare metal)
- Skipped if `qemu_agent_skip: true`

**Files:**
- `roles/qemu_agent/defaults/main.yml`
- `roles/qemu_agent/tasks/main.yml`

**Key Variables:**
```yaml
qemu_agent_enabled: true
qemu_agent_skip: false
```

---

### security

**Purpose:** Comprehensive security hardening.

**What it does:**
- SSH hardening (drop-in config)
- UFW firewall configuration
- fail2ban intrusion prevention
- Lynis security auditing (weekly)

**Files:**
- `roles/security/defaults/main.yml`
- `roles/security/tasks/main.yml`
- `roles/security/tasks/ssh.yml`
- `roles/security/tasks/ufw.yml`
- `roles/security/tasks/fail2ban.yml`
- `roles/security/tasks/lynis.yml`
- `roles/security/templates/sshd_hardening.conf.j2`
- `roles/security/templates/jail.local.j2`
- `roles/security/templates/lynis-scan.sh.j2`

**Key Variables:**
```yaml
security_ssh_enabled: true
security_ssh_permit_root_login: "no"
security_ssh_password_auth: "no"
security_ufw_enabled: true
security_ufw_default_incoming: "deny"
security_fail2ban_enabled: true
security_fail2ban_sshd_maxretry: 3
security_lynis_enabled: true
security_lynis_schedule: "0 3 * * 0"
```

---

### docker

**Purpose:** Install and configure Docker CE.

**What it does:**
- Removes old Docker packages
- Adds official Docker repository
- Installs Docker CE, CLI, and Compose plugin
- Configures daemon.json
- Creates `/opt/stacks/` directory

**Files:**
- `roles/docker/defaults/main.yml`
- `roles/docker/tasks/main.yml`
- `roles/docker/handlers/main.yml`
- `roles/docker/templates/daemon.json.j2`

**Key Variables:**
```yaml
docker_enabled: true
docker_version: ""  # latest
docker_stacks_dir: "/opt/stacks"
docker_log_driver: "json-file"
docker_log_max_size: "10m"
```

---

### watchtower

**Purpose:** Automatic Docker container updates.

**What it does:**
- Deploys Watchtower container
- Configures update schedule
- Enables image cleanup

**Files:**
- `roles/watchtower/defaults/main.yml`
- `roles/watchtower/tasks/main.yml`
- `roles/watchtower/templates/docker-compose.yml.j2`

**Key Variables:**
```yaml
watchtower_enabled: true
watchtower_schedule: "0 0 4 * * *"  # 4 AM daily
watchtower_cleanup: true
watchtower_monitor_only: false
```

---

### restic

**Purpose:** Automated backup with Restic.

**What it does:**
- Installs Restic
- Configures backup repository
- Creates backup scripts
- Sets up systemd timers
- Implements retention policies

**Files:**
- `roles/restic/defaults/main.yml`
- `roles/restic/tasks/main.yml`
- `roles/restic/templates/restic-backup.sh.j2`
- `roles/restic/templates/restic-env.j2`
- `roles/restic/templates/restic-backup.service.j2`
- `roles/restic/templates/restic-backup.timer.j2`

**Key Variables:**
```yaml
restic_enabled: true
restic_repository: "s3:http://nas:9000/backups"
restic_backup_paths:
  - "/opt/stacks"
  - "/etc"
restic_backup_schedule: "0 2 * * *"
restic_retention_keep_daily: 7
```

---

## Tier 2: Target Agent Roles

These roles are applied only to target nodes.

### netdata (child mode)

**Purpose:** Real-time metrics collection and streaming.

**What it does:**
- Deploys Netdata container
- Configures streaming to parent
- Disables local storage (memory-only)

**Files:**
- `roles/netdata/defaults/main.yml`
- `roles/netdata/tasks/main.yml`
- `roles/netdata/templates/docker-compose.yml.j2`
- `roles/netdata/templates/stream.conf.j2`
- `roles/netdata/templates/netdata.conf.j2`

**Key Variables (child mode):**
```yaml
netdata_mode: "child"
netdata_streaming_enabled: true
netdata_parent_host: "{{ control_node_ip }}"
netdata_parent_port: 19999
netdata_child_memory_mode: "none"
```

---

### promtail

**Purpose:** Log shipping to Loki.

**What it does:**
- Deploys Promtail container
- Configures log scraping
- Ships logs to Loki

**Files:**
- `roles/promtail/defaults/main.yml`
- `roles/promtail/tasks/main.yml`
- `roles/promtail/templates/docker-compose.yml.j2`
- `roles/promtail/templates/promtail-config.yml.j2`

**Key Variables:**
```yaml
promtail_enabled: true
promtail_loki_url: "http://{{ control_node_ip }}:3100/loki/api/v1/push"
promtail_log_paths:
  - name: system
    path: /var/log/*.log
  - name: docker
    path: /var/lib/docker/containers/*/*.log
```

---

### docker_socket_proxy

**Purpose:** Secure Docker API access from control node.

**What it does:**
- Deploys Tecnativa Docker Socket Proxy
- Configures read-only permissions
- Sets UFW rules to allow only control IP

**Files:**
- `roles/docker_socket_proxy/defaults/main.yml`
- `roles/docker_socket_proxy/tasks/main.yml`
- `roles/docker_socket_proxy/templates/docker-compose.yml.j2`

**Key Variables:**
```yaml
docker_socket_proxy_enabled: true
docker_socket_proxy_port: 2375
docker_socket_proxy_allowed_ip: "{{ control_node_ip }}"
```

---

## Tier 3: Control Stack Roles

These roles are applied only to the control node.

### traefik

**Purpose:** Reverse proxy with automatic SSL.

**What it does:**
- Deploys Traefik v3
- Configures Let's Encrypt ACME
- Sets up Docker provider
- Enables dashboard

**Stack Location:** `/opt/stacks/traefik/`

**Files:**
- `roles/traefik/defaults/main.yml`
- `roles/traefik/tasks/main.yml`
- `roles/traefik/templates/docker-compose.yml.j2`
- `roles/traefik/templates/traefik.yml.j2`
- `roles/traefik/templates/dynamic-config.yml.j2`

**Access:** `https://traefik.{domain}`

---

### authentik

**Purpose:** SSO/OIDC identity provider.

**What it does:**
- Deploys Authentik server and worker
- Sets up PostgreSQL and Redis
- Configures bootstrap credentials

**Stack Location:** `/opt/stacks/authentik/`

**Access:** `https://auth.{domain}`

---

### step_ca

**Purpose:** Internal certificate authority.

**What it does:**
- Deploys Smallstep CA
- Auto-initializes with ACME provisioner
- Generates root CA certificate

**Stack Location:** `/opt/stacks/step-ca/`

**Access:** `https://step-ca.{domain}:9000`

---

### pihole

**Purpose:** DNS with ad-blocking.

**What it does:**
- Deploys Pi-hole container
- Configures Unbound recursive resolver
- Sets up custom DNS records

**Stack Location:** `/opt/stacks/pihole/`

**Access:** `https://pihole.{domain}`

---

### netdata (parent mode)

**Purpose:** Metrics aggregation and alerting.

**What it does:**
- Deploys Netdata as streaming parent
- Configures dbengine storage
- Sets up health alarms

**Stack Location:** `/opt/stacks/netdata/`

**Access:** `https://netdata.{domain}`

---

### loki

**Purpose:** Log aggregation.

**What it does:**
- Deploys Grafana Loki
- Configures retention and compactor
- Accepts logs from Promtail agents

**Stack Location:** `/opt/stacks/loki/`

---

### grafana

**Purpose:** Dashboards and visualization.

**What it does:**
- Deploys Grafana
- Auto-provisions Loki datasource
- Configures Authentik SSO

**Stack Location:** `/opt/stacks/grafana/`

**Access:** `https://grafana.{domain}`

---

### uptime_kuma

**Purpose:** Status monitoring and pages.

**What it does:**
- Deploys Uptime Kuma
- Monitors service health
- Provides status pages

**Stack Location:** `/opt/stacks/uptime-kuma/`

**Access:** `https://status.{domain}`

---

### dockge

**Purpose:** Docker Compose stack manager.

**What it does:**
- Deploys Dockge
- Provides web UI for stack management
- Monitors all `/opt/stacks/` services

**Stack Location:** `/opt/stacks/dockge/`

**Access:** `https://dockge.{domain}`

---

## Next Steps

- [Security Guide](05-security.md) - Detailed security documentation
- [Troubleshooting](06-troubleshooting.md) - Common issues and solutions
