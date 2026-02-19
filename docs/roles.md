# Roles Reference

All 20 Ansible roles organized by tier. Each role is self-contained with its own defaults, tasks, templates, meta, and Molecule tests.

---

## Tier 1 — Foundation (all nodes)

### `common`

Base system configuration: packages, NTP, locale, sysctl tuning, Docker log rotation.

| Item | Detail |
|------|--------|
| **Templates** | `chrony.conf.j2`, `docker-logrotate.j2` |
| **Handlers** | Restart chrony |
| **Key vars** | `target_timezone`, `common_upgrade_packages`, `common_microcode_enabled`, `common_sysctl_tuning` |

### `lvm_config`

Extends LVM volumes to use 100% free space. Supports ext4 and xfs. Auto-skipped on LXC containers.

| Item | Detail |
|------|--------|
| **Skip flag** | `lvm_skip: true` |
| **Handlers** | Resize filesystem |
| **Key vars** | `target_lvm_config.auto_extend_ubuntu`, custom LV list |

### `swap`

Creates a swap file (default 2GB) and sets swappiness. Auto-skipped on LXC.

| Item | Detail |
|------|--------|
| **Skip flag** | `swap_skip: true` |
| **Key vars** | `swap_size_gb`, `swap_skip` |

### `qemu_agent`

Installs `qemu-guest-agent` for VM host visibility. Only runs on KVM/QEMU VMs.

| Item | Detail |
|------|--------|
| **Skip flag** | `qemu_agent_skip: true` |

### `security`

SSH hardening, UFW firewall, fail2ban, and Lynis audits. See [Security](security.md) for details.

| Item | Detail |
|------|--------|
| **Task files** | `tasks/ssh.yml`, `tasks/ufw.yml`, `tasks/fail2ban.yml`, `tasks/lynis.yml` |
| **Templates** | `sshd_hardening.conf.j2`, `jail.local.j2`, `lynis-scan.sh.j2`, `lynis-scan.service.j2`, `lynis-scan.timer.j2` |
| **Handlers** | Restart sshd, restart fail2ban |
| **Key vars** | `target_security.ssh_hardening.*`, `target_security.fail2ban.*`, `target_security.ufw.*` |

### `docker`

Installs Docker CE from the official repository with a configured `daemon.json`.

| Item | Detail |
|------|--------|
| **Templates** | `daemon.json.j2` |
| **Handlers** | Restart Docker |
| **Key vars** | `target_docker.log_driver`, `target_docker.log_max_size`, `target_docker.log_max_file` |

### `watchtower`

Deploys Watchtower container for automatic Docker image updates.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/watchtower` |
| **Templates** | `docker-compose.yml.j2` |
| **Key vars** | `target_watchtower.schedule`, `target_watchtower.cleanup` |

### `restic`

Automated backups with version-pinned restic binary (from GitHub releases), systemd timers, JSONL metrics, and multi-channel failure notifications.

| Item | Detail |
|------|--------|
| **Templates** | `restic-env.j2`, `restic-excludes.j2`, `restic-backup.sh.j2`, `restic-check.sh.j2`, `restic-verify.sh.j2`, systemd service/timer units |
| **Handlers** | Reload systemd, start timers |
| **Key vars** | `restic_version` (default `0.18.1`), `target_restic.schedule`, `target_restic.retention.*`, `target_restic.destinations.*`, `vault_restic_credentials` |
| **Features** | `--compression auto`, stale lock cleanup, backup verify (monthly), metrics to `/var/log/restic/metrics.json` |

---

## Tier 2 — Target Agents

### `netdata`

Dual-mode monitoring: child mode on targets streams to parent mode on control. Uses `allow_duplicates: true` because it's invoked twice in `site.yml`.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/netdata` |
| **Templates** | `docker-compose.yml.j2`, `netdata.conf.j2`, `stream.conf.j2`, `netdata.env.j2`, health alarm configs |
| **Mode variable** | `netdata_mode: "child"` or `"parent"` |
| **Key vars** | `vault_netdata_stream_api_key`, alarm thresholds (`cpu_warning`, etc.), Netdata Cloud claim token |

### `promtail`

Ships logs (Docker JSON, syslog, auth) to Loki on the control node.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/promtail` |
| **Templates** | `docker-compose.yml.j2`, `promtail-config.yml.j2`, `promtail.env.j2` |
| **Key vars** | `promtail_loki_url` (defaults to `http://{control_ip}:3100/loki/api/v1/push`) |

### `docker_socket_proxy`

Read-only Docker API proxy with UFW rules restricting access to control node IP only.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/docker-socket-proxy` |
| **Templates** | `docker-compose.yml.j2`, `docker_socket_proxy.env.j2` |
| **Security** | POST/SECRETS operations disabled (0), read operations enabled (1) |

### `dockge`

Visual Docker Compose manager. Deployed on **both** control and target nodes. All other stacks deploy to `/opt/stacks/` so they appear in Dockge.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/dockge` |
| **Templates** | `docker-compose.yml.j2` |
| **Key vars** | `target_dockge.port` (default 5001) |

---

## Tier 3 — Control Stacks

### `traefik`

Reverse proxy with Let's Encrypt ACME, DNS challenge for wildcards, Step-CA integration, security headers middleware, bcrypt-hashed dashboard auth.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/traefik` |
| **Templates** | `docker-compose.yml.j2`, `traefik.yml.j2`, `dynamic-config.yml.j2` |
| **Network** | Creates `traefik-public` Docker network |
| **Key vars** | `control_traefik.*`, `traefik_acme_email`, `vault_traefik_dashboard` |

### `authentik`

SSO/OIDC with PostgreSQL + Redis backend. Generates bootstrap credentials and renders a setup guide.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/authentik` |
| **Templates** | `docker-compose.yml.j2`, `authentik.env.j2`, `setup-guide.md.j2` |
| **Key vars** | `vault_authentik_credentials.{secret_key, bootstrap_password, postgres_password, redis_password}` |

### `step_ca`

Internal certificate authority (Smallstep). Root CA is distributed to all targets during post-deploy.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/step-ca` |
| **Templates** | `docker-compose.yml.j2`, `init-ca.sh.j2`, `step_ca.env.j2`, `setup-guide.md.j2` |
| **Key vars** | `control_step_ca.*`, `vault_step_ca_credentials.password` |

### `pihole`

DNS with Unbound recursive resolver, custom DNS records, custom CNAME records, DNSSEC.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/pihole` |
| **Templates** | `docker-compose.yml.j2`, `unbound.conf.j2`, `custom.list.j2`, `05-custom-cname.conf.j2`, `setup-guide.md.j2` |
| **Key vars** | `control_dns.*`, `pihole_custom_dns_records`, `vault_pihole_password` |

### `loki`

Log aggregation with boltdb-shipper, compactor, and configurable retention.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/loki` |
| **Templates** | `docker-compose.yml.j2`, `loki-config.yml.j2`, `loki.env.j2` |
| **Key vars** | `control_loki.retention_period` (default `744h` = 31 days) |

### `grafana`

Dashboards with auto-provisioned Loki + Netdata datasources and Authentik OIDC integration.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/grafana` |
| **Templates** | `docker-compose.yml.j2`, `grafana.ini.j2`, `grafana.env.j2`, `datasources.yml.j2`, `dashboards.yml.j2` |
| **Key vars** | `control_grafana.*`, `vault_grafana_credentials`, `vault_grafana_oidc` |

### `uptime_kuma`

Status monitoring with setup guide.

| Item | Detail |
|------|--------|
| **Deploy path** | `/opt/stacks/uptime-kuma` |
| **Templates** | `docker-compose.yml.j2`, `setup-guide.md.j2` |
| **Key vars** | `control_uptime_kuma.*`, `vault_uptime_kuma_credentials` |

---

## Cross-Cutting Role

### `notifications`

Multi-channel notification dispatcher. Not assigned to a tier — used by other roles (restic, security) via `server-helper-notify`.

| Item | Detail |
|------|--------|
| **Templates** | `notify.sh.j2`, `notify-discord.sh.j2`, `notify-slack.sh.j2`, `notify-telegram.sh.j2`, `notify-email.sh.j2` |
| **Channels** | Discord, Slack, Telegram, Email (SMTP) |
| **Key vars** | `notifications_enabled`, `vault_discord_webhook`, `vault_telegram_credentials`, `vault_slack_webhook`, `vault_smtp_credentials` |
| **Usage** | `server-helper-notify "Subject" "Message body"` from any script |
