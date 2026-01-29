# Quick Reference

One-page reference for common Server Helper operations.

## Deployment Commands

```bash
# Full deployment
ansible-playbook playbooks/site.yml

# Deploy to specific host
ansible-playbook playbooks/site.yml --limit "server1"

# Deploy specific role
ansible-playbook playbooks/site.yml --tags "grafana"

# Deploy tier only
ansible-playbook playbooks/site.yml --tags "tier1"
ansible-playbook playbooks/site.yml --tags "tier2"
ansible-playbook playbooks/site.yml --tags "tier3"

# Dry run (check mode)
ansible-playbook playbooks/site.yml --check

# Verbose output
ansible-playbook playbooks/site.yml -vvvv
```

## Vault Operations

```bash
# Encrypt vault
ansible-vault encrypt group_vars/vault.yml

# Edit encrypted vault (recommended - keeps file encrypted)
ansible-vault edit group_vars/vault.yml

# View encrypted vault (read-only, decrypts in memory only)
ansible-vault view group_vars/vault.yml

# Change vault password
ansible-vault rekey group_vars/vault.yml

# Using vault.sh helper
./scripts/vault.sh encrypt
./scripts/vault.sh edit
./scripts/vault.sh view

# Using individual scripts
./scripts/vault-edit.sh group_vars/vault.yml
./scripts/vault-view.sh group_vars/vault.yml
./scripts/vault-encrypt.sh group_vars/vault.yml
./scripts/vault-rekey.sh group_vars/vault.yml
./scripts/vault-rekey.sh --all  # Re-key all vault files
```

> **Security Note**: The `decrypt` command has been removed. Use `edit` to modify
> encrypted files (keeps them encrypted) or `view` to read them (decrypts in memory only).

## Validation Commands

```bash
# Full fleet validation
./scripts/validate-fleet.sh

# Quick ping test
./scripts/validate-fleet.sh --quick

# Control services only
./scripts/validate-fleet.sh --services

# Ansible connectivity
ansible all -m ping
ansible targets -m ping
ansible control -m ping
```

## Docker Commands

```bash
# View running containers
docker ps

# View container logs
docker logs <container_name>
docker logs --tail 100 -f <container_name>

# Restart container
docker restart <container_name>

# Restart entire stack
cd /opt/stacks/<service>
docker compose restart

# Rebuild stack
docker compose down
docker compose up -d

# Clean up unused images
docker system prune -a
```

## Service URLs (Default)

| Service | URL |
|---------|-----|
| Traefik | `https://traefik.{domain}` |
| Grafana | `https://grafana.{domain}` |
| Netdata | `https://netdata.{domain}` |
| Uptime Kuma | `https://status.{domain}` |
| Pi-hole | `https://pihole.{domain}` |
| Authentik | `https://auth.{domain}` |
| Dockge | `https://dockge.{domain}` |

## Common Ports

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH | TCP |
| 53 | Pi-hole DNS | TCP/UDP |
| 80 | Traefik HTTP | TCP |
| 443 | Traefik HTTPS | TCP |
| 2375 | Docker Socket Proxy | TCP |
| 3000 | Grafana | TCP |
| 3001 | Uptime Kuma | TCP |
| 3100 | Loki | TCP |
| 5001 | Dockge | TCP |
| 8053 | Pi-hole Web | TCP |
| 9000 | Authentik | TCP |
| 19999 | Netdata | TCP |

## Configuration Files

| File | Purpose |
|------|---------|
| `inventory/hosts.yml` | Host definitions |
| `group_vars/all.yml` | Global variables |
| `group_vars/control.yml` | Control node settings |
| `group_vars/targets.yml` | Target node settings |
| `group_vars/vault.yml` | Encrypted secrets |
| `host_vars/{host}.yml` | Per-host overrides |
| `ansible.cfg` | Ansible configuration |

## Upgrade Commands

```bash
# Access upgrade menu through setup.sh
./setup.sh
# Then select: Extras -> Upgrade Services

# Options available in menu:
# - Upgrade all services on all hosts
# - Upgrade specific host
# - Upgrade specific service
# - Dry run (preview only)
```

## Script Libraries

| File | Purpose |
|------|---------|
| `scripts/lib/security.sh` | **Core security module** - cleanup trap, permission checks, memory sanitization. Source FIRST. |
| `scripts/lib/ui_utils.sh` | Colors, headers, secure logging (redacts sensitive commands) |
| `scripts/lib/vault_mgr.sh` | Vault operations, interactive menu, RAM disk temp files |
| `scripts/lib/menu_extras.sh` | Extras menu functions: add server, open UI, validate, test, upgrade |
| `scripts/lib/inventory_mgr.sh` | Inventory parsing and host management |
| `scripts/lib/health_check.sh` | SSH, Docker, disk, memory health checks |
| `scripts/lib/config_mgr.sh` | YAML configuration management |
| `scripts/lib/upgrade.sh` | Docker image upgrades and service restarts |

### Library Architecture

All scripts use **strict sourcing** - libraries are required, not optional:

```bash
# security.sh must be sourced FIRST (provides cleanup trap)
if [[ ! -f "${LIB_DIR}/security.sh" ]]; then
    echo "FATAL: Required library not found" >&2
    exit 1
fi
source "${LIB_DIR}/security.sh"
security_register_cleanup  # Registers EXIT/SIGINT/SIGTERM trap
```

## Key Variables

```yaml
# group_vars/all.yml
target_domain: "example.com"
target_timezone: "America/Vancouver"
control_node_ip: "192.168.1.10"
ansible_user: "ansible"

# Service toggles
restic_enabled: true
netdata_enabled: true
grafana_enabled: true
```

## Inventory Format

```yaml
# inventory/hosts.yml
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

        # LXC container
        lxc-server:
          ansible_host: 192.168.1.20
          lvm_skip: true
          swap_skip: true
          qemu_agent_skip: true
```

## Backup Commands

```bash
# Manual backup
sudo /opt/restic/backup.sh

# View snapshots
source /opt/restic/restic.env
restic snapshots

# Restore from backup
restic restore <snapshot-id> --target /tmp/restore

# Check backup integrity
sudo /opt/restic/check.sh
```

## Troubleshooting

```bash
# Check SSH connectivity
ssh -vvv user@host

# Check firewall status
sudo ufw status verbose

# Check fail2ban status
sudo fail2ban-client status sshd

# Check Docker status
sudo systemctl status docker

# Check container logs
docker logs <container> 2>&1 | tail -50

# Check disk space
df -h

# Check memory
free -m
```

## Emergency Recovery

```bash
# If locked out via SSH, access via console and:
sudo nano /etc/ssh/sshd_config.d/99-server-helper.conf
# Temporarily set PasswordAuthentication yes
sudo systemctl restart sshd

# Restore from backup
source /opt/restic/restic.env
restic snapshots
restic restore latest --target /tmp/restore

# Rebuild entire control node
ansible-playbook playbooks/control.yml
```

## Adding New Server

```bash
# Option 1: Interactive
./scripts/add-server.sh

# Option 2: Manual
# 1. Add to inventory/hosts.yml
# 2. Run bootstrap
ansible-playbook playbooks/bootstrap.yml --limit "new-server"
# 3. Deploy agents
ansible-playbook playbooks/target.yml --limit "new-server"
```
