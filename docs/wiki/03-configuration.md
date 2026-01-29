# Configuration Reference

Complete reference for all Server Helper configuration options.

## Table of Contents

1. [Inventory Configuration](#inventory-configuration)
2. [Global Variables](#global-variables)
3. [Vault Secrets](#vault-secrets)
4. [Host Variables](#host-variables)
5. [Role Variables](#role-variables)

---

## Inventory Configuration

### File: `inventory/hosts.yml`

```yaml
all:
  children:
    # Control node group (exactly one node)
    control:
      hosts:
        control-node:
          ansible_host: 192.168.1.10
          ansible_user: ansible  # Optional override

    # Target nodes group (one or more nodes)
    targets:
      hosts:
        server1:
          ansible_host: 192.168.1.11

        server2:
          ansible_host: 192.168.1.12
          ansible_user: admin  # Different user

        # LXC container with skip flags
        lxc-web:
          ansible_host: 192.168.1.20
          lvm_skip: true
          swap_skip: true
          qemu_agent_skip: true

  # Global inventory variables
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

### Host Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ansible_host` | string | - | IP address or hostname |
| `ansible_user` | string | `ansible` | SSH user |
| `ansible_port` | int | `22` | SSH port |
| `lvm_skip` | bool | `false` | Skip LVM expansion |
| `swap_skip` | bool | `false` | Skip swap creation |
| `qemu_agent_skip` | bool | `false` | Skip QEMU agent |

---

## Global Variables

### File: `group_vars/all.yml`

### Core Settings

```yaml
# Domain for all services (required)
target_domain: "example.com"

# Timezone for all servers
target_timezone: "America/Vancouver"

# Control node IP (required - targets connect here)
control_node_ip: "192.168.1.10"

# Default SSH user for Ansible
ansible_user: "ansible"
```

### Service Toggles

```yaml
# Target node services
restic_enabled: true      # Backup automation
netdata_enabled: true     # Metrics collection
promtail_enabled: true    # Log shipping

# Control node services
traefik_enabled: true     # Reverse proxy
grafana_enabled: true     # Dashboards
loki_enabled: true        # Log aggregation
uptime_kuma_enabled: true # Status monitoring
pihole_enabled: true      # DNS/ad-blocking
step_ca_enabled: true     # Certificate authority
authentik_enabled: true   # SSO/identity
dockge_enabled: true      # Stack manager
```

### Security Settings

```yaml
target_security:
  ssh_hardening:
    enabled: true
    permit_root_login: false
    password_authentication: false
    pubkey_authentication: true
    max_auth_tries: 3

  ufw:
    enabled: true
    default_incoming: "deny"
    default_outgoing: "allow"

  fail2ban:
    enabled: true
    sshd_maxretry: 3
    sshd_bantime: 86400  # 24 hours

  lynis:
    enabled: true
    schedule: "0 3 * * 0"  # Weekly Sunday 3 AM
```

### Backup Settings

```yaml
target_backup:
  enabled: true
  repository: "s3:http://nas.local:9000/backups"
  schedule: "0 2 * * *"  # Daily 2 AM

  retention:
    keep_last: 7
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6
    keep_yearly: 1
```

### Monitoring Settings

```yaml
# Netdata streaming
netdata_streaming_enabled: true

# Alert thresholds (percentage)
netdata_alarm_cpu_threshold: 85
netdata_alarm_ram_threshold: 90
netdata_alarm_disk_threshold: 90
```

### Network Settings

```yaml
# Traefik Docker network
traefik_docker_network: "traefik-public"

# Let's Encrypt email
traefik_acme_email: "admin@example.com"

# DNS configuration for Pi-hole upstream servers
target_dns:
  upstream_servers:
    - "1.1.1.1"    # Cloudflare primary
    - "1.0.0.1"    # Cloudflare secondary
  # Alternative DNS providers:
  # Google: 8.8.8.8, 8.8.4.4
  # Quad9: 9.9.9.9, 149.112.112.112

# Notification email for security alerts (fail2ban, lynis, etc.)
target_notification_email: "admin@example.com"

# Pi-hole custom DNS records
pihole_custom_dns_records:
  - hostname: "control.example.com"
    ip: "192.168.1.10"
  - hostname: "nas.example.com"
    ip: "192.168.1.5"

# Pi-hole CNAME records
pihole_custom_cname_records:
  - hostname: "grafana.example.com"
    target: "control.example.com"
```

---

## Vault Secrets

### File: `group_vars/vault.yml`

**Always encrypt this file:** `ansible-vault encrypt group_vars/vault.yml`

### Restic Backup

```yaml
# Backup passwords (separate for local and NAS)
vault_restic_passwords:
  local: "strong-local-password"
  nas: "strong-nas-password"

# AWS/S3 credentials (for S3-compatible storage)
vault_aws_credentials:
  access_key: "minio-access-key"
  secret_key: "minio-secret-key"

# NAS credentials (for NAS/SMB storage)
vault_nas_credentials:
  - username: "backup_user"
    password: "nas-password"
```

### Netdata Streaming

```yaml
# Generate: uuidgen or openssl rand -hex 16
vault_netdata_stream_api_key: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Grafana

```yaml
vault_control_grafana_password: "grafana-admin-password"

# OAuth/OIDC (after Authentik setup)
vault_grafana_oidc:
  client_id: "grafana-client-id"
  client_secret: "grafana-client-secret"
```

### Pi-hole

```yaml
vault_pihole_password: "pihole-admin-password"
```

### Step-CA

```yaml
vault_step_ca_password: "step-ca-password"
```

### Authentik

```yaml
vault_authentik_credentials:
  admin_password: "authentik-admin-password"
  # Generate: openssl rand -hex 32
  secret_key: "64-character-hex-string"
  postgres_password: "postgres-password"
```

### Uptime Kuma

```yaml
vault_uptime_kuma_credentials:
  username: "admin"
  password: "uptime-kuma-password"
```

### Traefik Dashboard

```yaml
vault_traefik_dashboard:
  username: "admin"
  password: "traefik-password"
```

### Dockge

```yaml
vault_dockge_credentials:
  username: "admin"
  password: "dockge-password"
```

---

## Host Variables

Per-host variables override group variables.

### File: `host_vars/server1.yml` (example)

```yaml
# Override backup settings for this host
target_backup:
  enabled: true
  repository: "s3:http://different-nas:9000/backups"

# Additional UFW rules for this host
security_ufw_extra_rules:
  - { rule: allow, port: "8080", proto: tcp, comment: "Custom app" }

# Custom Netdata alarms
netdata_alarm_disk_threshold: 95  # Higher threshold
```

---

## Role Variables

### Common Role

```yaml
# Packages to install
common_packages:
  - curl
  - wget
  - htop
  - vim
  - git
  # ... (see defaults/main.yml)

# Chrony NTP servers
common_chrony_servers:
  - "0.pool.ntp.org"
  - "1.pool.ntp.org"

# CPU microcode
common_microcode_enabled: true

# Docker logrotate
common_docker_logrotate_enabled: true
common_docker_logrotate_size: "10M"
common_docker_logrotate_rotate: 5

# Sysctl tuning
common_sysctl_tuning: true
```

### Docker Role

```yaml
docker_enabled: true
docker_version: ""  # Empty = latest

# Users to add to docker group
docker_users:
  - "{{ ansible_user }}"

# Daemon configuration
docker_storage_driver: "overlay2"
docker_log_driver: "json-file"
docker_log_max_size: "10m"
docker_log_max_file: "3"
docker_live_restore: true

# Stacks directory
docker_stacks_dir: "/opt/stacks"
```

### Traefik Role

```yaml
traefik_enabled: true
traefik_image_tag: "v3.0"

# Ports
traefik_http_port: 80
traefik_https_port: 443
traefik_dashboard_port: 8080

# Dashboard
traefik_dashboard_enabled: true
traefik_dashboard_insecure: false

# ACME (Let's Encrypt)
traefik_acme_enabled: true
traefik_acme_email: "admin@example.com"
traefik_acme_ca_server: "https://acme-v02.api.letsencrypt.org/directory"

# DNS challenge for wildcards
traefik_acme_dns_challenge_enabled: false
traefik_acme_dns_provider: ""  # cloudflare, route53, etc.

# Step-CA integration
traefik_step_ca_enabled: false
traefik_step_ca_endpoint: "https://step-ca:9000"
```

### Netdata Role

```yaml
netdata_enabled: true
netdata_mode: "child"  # or "parent"

# Streaming
netdata_streaming_enabled: true
netdata_stream_api_key: "{{ vault_netdata_stream_api_key }}"

# Parent connection (for child mode)
netdata_parent_host: "{{ control_node_ip }}"
netdata_parent_port: 19999

# Retention (parent only)
netdata_dbengine_multihost_disk_space: 2048  # MB

# Netdata Cloud (optional)
netdata_claim_token: ""
netdata_claim_rooms: ""
```

### Grafana Role

```yaml
grafana_enabled: true
grafana_port: 3000

# Admin
grafana_admin_user: "admin"
grafana_admin_password: "{{ vault_grafana_admin_password }}"

# OAuth/Authentik
grafana_oauth_enabled: false
grafana_oauth_client_id: "{{ vault_grafana_oauth_client_id }}"
grafana_oauth_client_secret: "{{ vault_grafana_oauth_client_secret }}"

# Datasources (auto-provisioned)
grafana_datasources:
  - name: Loki
    type: loki
    url: "http://loki:3100"
    is_default: true
```

### Authentik Role

```yaml
authentik_enabled: true
authentik_image_tag: "2024.2"

# Ports
authentik_http_port: 9000
authentik_https_port: 9443

# Database
authentik_postgres_db: "authentik"
authentik_postgres_user: "authentik"
authentik_postgres_password: "{{ vault_authentik_postgres_password }}"

# Bootstrap
authentik_bootstrap_email: "{{ vault_authentik_admin_email }}"
authentik_bootstrap_password: "{{ vault_authentik_admin_password }}"
```

### Restic Role

```yaml
restic_enabled: true
restic_repository: "{{ target_backup.repository }}"
restic_password: "{{ vault_restic_password }}"

# Backup paths
restic_backup_paths:
  - "/opt/stacks"
  - "/etc"

# Exclude patterns
restic_exclude_patterns:
  - "*.tmp"
  - "*.log"
  - "**/node_modules/**"

# Schedule
restic_backup_schedule: "0 2 * * *"

# Retention
restic_retention_keep_last: 7
restic_retention_keep_daily: 7
restic_retention_keep_weekly: 4
restic_retention_keep_monthly: 6
restic_retention_keep_yearly: 1
```

---

## Environment Variables

These can be set in your shell for convenience:

```bash
# Ansible Vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=.vault_password

# Skip host key checking (dev only)
export ANSIBLE_HOST_KEY_CHECKING=False

# Increase verbosity
export ANSIBLE_VERBOSITY=1
```

---

## Next Steps

- [Role Reference](04-roles.md) - Detailed documentation for each role
- [Security Guide](05-security.md) - Security configuration details
