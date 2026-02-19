# Configuration

## Variable System

### Precedence (low → high)

1. `roles/{role}/defaults/main.yml` — Role defaults
2. `group_vars/all.yml` — Global: domain, IPs, Docker config, security policies
3. `group_vars/control.yml` — Control services: ports, versions, toggles
4. `group_vars/targets.yml` — Target services: Netdata alarms, Restic retention, Promtail
5. `host_vars/{host}.yml` — Per-host: timezone override, backup paths, alarm thresholds
6. `inventory/hosts.yml` inline vars — Connection-level: SSH user, skip flags for LXC

### Naming Conventions

| Prefix | Scope | Example |
|--------|-------|---------|
| `target_*` | Global settings | `target_domain`, `target_timezone`, `target_dns` |
| `control_*` | Control node services | `control_traefik`, `control_grafana`, `control_loki` |
| `vault_*` | Encrypted secrets | `vault_authentik_credentials`, `vault_pihole_password` |
| `*_skip` | LXC skip flags | `lvm_skip`, `swap_skip`, `qemu_agent_skip` |

## Group Variables

### `group_vars/all.yml`

Global settings applied to every host:

```yaml
target_domain: "example.com"
target_timezone: "America/Los_Angeles"
target_control_ip: "192.168.1.10"
target_dns:
  upstream_servers:
    - "1.1.1.1"
    - "8.8.8.8"
```

### `group_vars/control.yml`

Service-specific settings for the control node — ports, versions, feature toggles for Traefik, Authentik, Grafana, Loki, Pi-hole, Step-CA, and Uptime Kuma.

### `group_vars/targets.yml`

Agent settings for target nodes — Watchtower schedule, Netdata alarms, Promtail Loki URL, Restic backup schedule and retention.

## Vault (`group_vars/vault.yml`)

Encrypted with `ansible-vault`. Organized by tier:

```yaml
# TIER 1: Foundation
vault_restic_credentials:          { password }

# TIER 2: Target Agents
vault_netdata_credentials:         { claim_token, claim_room }
vault_netdata_stream_api_key:      "uuid"

# TIER 3: Control — Critical
vault_authentik_credentials:       { secret_key, bootstrap_password, postgres_password, redis_password }
vault_grafana_credentials:         { admin_password, secret_key }
vault_step_ca_credentials:         { password }
vault_traefik_dashboard:           { username, password }
vault_pihole_password:             "string"

# TIER 3: Control — Integration
vault_grafana_oidc:                { client_id, client_secret }
vault_uptime_kuma_credentials:     { username, password }
vault_uptime_kuma_push_urls:       { nas, dockge, system, backup, security, update }

# Notifications (optional)
vault_smtp_credentials:            { host, port, username, password, from, to[] }
vault_discord_webhook:             "url"
vault_telegram_credentials:        { bot_token, chat_id }
vault_slack_webhook:               "url"

# System
vault_system_users:                { admin_password, admin_ssh_key }
```

### Vault Commands

| Command | Description |
|---------|-------------|
| `make vault-edit` | Edit encrypted vault interactively |
| `make vault-view` | View decrypted vault contents |
| `make vault-encrypt` | Encrypt an unencrypted vault file |
| `make vault-decrypt` | Decrypt vault for editing |

## Host Variables

Place per-host override files in `host_vars/{hostname}.yml`. These override group variables for a specific host.

### Example: Custom backup paths

```yaml
# host_vars/server1.yml
target_timezone: "Europe/London"
target_restic:
  backup_paths:
    - "/opt/stacks"
    - "/etc"
    - "/home/admin/data"
```

### Example: LXC container

```yaml
# host_vars/lxc-container.yml
lvm_skip: true
swap_skip: true
qemu_agent_skip: true
```

### Example: Custom alarm thresholds

```yaml
# host_vars/high-load-server.yml
target_netdata:
  alarms:
    cpu_warning: 90
    cpu_critical: 98
    ram_warning: 90
    ram_critical: 98
```

## Inventory (`inventory/hosts.yml`)

```yaml
all:
  children:
    control:
      hosts:
        control-node:
          ansible_host: 192.168.1.10
    targets:
      hosts:
        server1:
          ansible_host: 192.168.1.11
        server2:
          ansible_host: 192.168.1.12
```

See [Ansible Variable Precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable) for full details.
