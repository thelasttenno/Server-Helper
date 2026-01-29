# Server Helper Documentation

Welcome to the Server Helper documentation. This wiki provides comprehensive guides for deploying and managing your infrastructure.

## Quick Navigation

| Guide | Description |
|-------|-------------|
| [Installation](wiki/01-installation.md) | Prerequisites, setup, and deployment |
| [Architecture](wiki/02-architecture.md) | System design and tiered model |
| [Configuration](wiki/03-configuration.md) | Variables, vault, and customization |
| [Roles](wiki/04-roles.md) | Complete role reference (21 roles) |
| [Security](wiki/05-security.md) | Hardening, PKI, and SSO |
| [Troubleshooting](wiki/06-troubleshooting.md) | Common issues and recovery |
| [Quick Reference](wiki/07-quick-reference.md) | One-page command cheat sheet |

## Quick Start

```bash
# 1. Clone and setup
git clone https://github.com/yourusername/server-helper.git
cd server-helper
./setup.sh

# 2. Configure
cp inventory/hosts.example.yml inventory/hosts.yml
cp group_vars/all.example.yml group_vars/all.yml
cp group_vars/vault.example.yml group_vars/vault.yml

# Edit files with your settings
nano inventory/hosts.yml
nano group_vars/all.yml
ansible-vault encrypt group_vars/vault.yml

# 3. Deploy
ansible-galaxy install -r requirements.yml
ansible-playbook playbooks/site.yml
```

## Architecture Overview

```text
                    ┌─────────────────────────────────────┐
                    │          CONTROL NODE               │
                    │  Traefik │ Grafana │ Loki │ Dockge │
                    │  Authentik │ Pi-hole │ Step-CA     │
                    │  Netdata (Parent) │ Uptime Kuma    │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
        ┌─────┴─────┐        ┌─────┴─────┐       ┌─────┴─────┐
        │  TARGET 1 │        │  TARGET 2 │       │  TARGET N │
        │  Netdata  │        │  Netdata  │       │  Netdata  │
        │  Promtail │        │  Promtail │       │  Promtail │
        │  Dockge   │        │  Dockge   │       │  Dockge   │
        └───────────┘        └───────────┘       └───────────┘
```

## Tiered Deployment Model

| Tier | Scope | Roles |
|------|-------|-------|
| **Tier 1: Foundation** | All nodes | common, lvm_config, swap, qemu_agent, security, docker, watchtower, restic |
| **Tier 2: Agents** | Targets only | netdata (child), promtail, docker_socket_proxy, dockge |
| **Tier 3: Stacks** | Control only | traefik, authentik, step_ca, pihole, netdata (parent), loki, grafana, uptime_kuma |

## Key Playbooks

| Playbook | Purpose |
|----------|---------|
| `site.yml` | Full deployment - all tiers, all nodes |
| `bootstrap.yml` | Day 0 preparation for new targets |
| `target.yml` | Deploy agents to target nodes |
| `control.yml` | Deploy stacks to control node |
| `update.yml` | Rolling system updates |
| `backup.yml` | Manual backup trigger |
| `add-target.yml` | Add new server to fleet |

## Services After Deployment

| Service | Default URL | Port |
|---------|-------------|------|
| Traefik Dashboard | `https://traefik.{domain}` | 443 |
| Grafana | `https://grafana.{domain}` | 3000 |
| Netdata | `https://netdata.{domain}` | 19999 |
| Uptime Kuma | `https://status.{domain}` | 3001 |
| Pi-hole | `https://pihole.{domain}` | 8053 |
| Authentik | `https://auth.{domain}` | 9000 |
| Dockge | `https://dockge.{domain}` | 5001 |
| Loki | (internal) | 3100 |

## Validation

```bash
# Full fleet validation
./scripts/validate-fleet.sh

# Quick connectivity test
./scripts/validate-fleet.sh --quick

# Control services only
./scripts/validate-fleet.sh --services

# Ansible ping
ansible all -m ping
```

## Getting Help

1. Check the [Troubleshooting Guide](wiki/06-troubleshooting.md)
2. Run validation: `./scripts/validate-fleet.sh`
3. Enable verbose mode: `ansible-playbook site.yml -vvvv`
4. Check service logs: `docker logs <container_name>`

## Contributing

See the main [README](../README.md) for contribution guidelines.
