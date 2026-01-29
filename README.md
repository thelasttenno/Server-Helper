# Server Helper v2.0

[![Ansible](https://img.shields.io/badge/Ansible-2.14+-red.svg)](https://www.ansible.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-orange.svg)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Server Helper** is a comprehensive infrastructure automation framework that combines Bash bootstrap scripts with Ansible playbooks to deploy and manage a complete homelab or small business server environment.

## Features

- **Tiered Architecture**: Foundation hardening for all nodes, specialized agents for targets, management stacks for control
- **Zero-Touch Deployment**: Single command deploys entire infrastructure
- **Dockge Compatible**: All Docker services deploy to `/opt/stacks/` for visual management
- **Security First**: SSH hardening, UFW firewall, fail2ban, Lynis auditing out of the box
- **Centralized Monitoring**: Netdata parent/child streaming, Loki log aggregation, Grafana dashboards
- **Identity Management**: Authentik SSO with OIDC integration for all services
- **Internal PKI**: Step-CA for automatic internal certificate management
- **Idempotent**: Safe to run repeatedly - adds new servers without breaking existing config

## Quick Start

### Prerequisites

- **Control Node**: Ubuntu 24.04 LTS (your management machine)
- **Target Nodes**: Ubuntu 22.04+ or Debian 12+ (VMs, bare metal, or LXC containers)
- SSH key-based authentication configured

### 1. Clone and Setup

```bash
git clone https://github.com/yourusername/server-helper.git
cd server-helper
./setup.sh
```

### 2. Configure

```bash
# Copy example files
cp inventory/hosts.example.yml inventory/hosts.yml
cp group_vars/all.example.yml group_vars/all.yml
cp group_vars/vault.example.yml group_vars/vault.yml

# Edit configuration
nano inventory/hosts.yml      # Add your servers
nano group_vars/all.yml       # Set domain, IPs, options
nano group_vars/vault.yml     # Add passwords/secrets

# Encrypt secrets
ansible-vault encrypt group_vars/vault.yml
```

### 3. Deploy

```bash
# Install Ansible dependencies
ansible-galaxy install -r requirements.yml

# Deploy everything
ansible-playbook playbooks/site.yml
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CONTROL NODE                                 │
│  ┌─────────┐ ┌──────────┐ ┌─────────┐ ┌──────┐ ┌────────┐          │
│  │ Traefik │ │ Authentik│ │ Grafana │ │ Loki │ │ Dockge │          │
│  │ (Proxy) │ │  (SSO)   │ │(Dash)   │ │(Logs)│ │(Stacks)│          │
│  └────┬────┘ └──────────┘ └─────────┘ └──┬───┘ └────────┘          │
│       │                                   │                          │
│  ┌────┴────┐ ┌──────────┐ ┌─────────┐   │    ┌────────────┐        │
│  │ Step-CA │ │ Pi-hole  │ │ Netdata │◄──┼────│Uptime Kuma │        │
│  │  (PKI)  │ │  (DNS)   │ │(Parent) │   │    │  (Status)  │        │
│  └─────────┘ └──────────┘ └────▲────┘   │    └────────────┘        │
└────────────────────────────────┼────────┼───────────────────────────┘
                                 │        │
           ┌─────────────────────┼────────┼─────────────────────┐
           │                     │        │                     │
     ┌─────┴─────┐         ┌─────┴─────┐         ┌─────┴─────┐
     │  TARGET 1 │         │  TARGET 2 │         │  TARGET N │
     │───────────│         │───────────│         │───────────│
     │ Netdata   │────────►│ Netdata   │────────►│ Netdata   │
     │ (Child)   │         │ (Child)   │         │ (Child)   │
     │ Promtail ─┼────────►│ Promtail ─┼────────►│ Promtail  │
     │ Watchtower│         │ Watchtower│         │ Watchtower│
     │ Restic    │         │ Restic    │         │ Restic    │
     └───────────┘         └───────────┘         └───────────┘
```

## Playbooks

| Playbook | Description |
|----------|-------------|
| `site.yml` | Full deployment - all tiers, all nodes |
| `bootstrap.yml` | Day 0 preparation for new targets |
| `target.yml` | Deploy monitoring agents to targets |
| `control.yml` | Deploy management stacks to control |
| `update.yml` | Rolling system updates |
| `backup.yml` | Trigger manual backups |
| `add-target.yml` | Add new server to fleet |

## Roles

### Tier 1: Foundation (All Nodes)
| Role | Description |
|------|-------------|
| `common` | Base packages, timezone, NTP, sysctl tuning |
| `lvm_config` | LVM volume expansion (skipped on LXC) |
| `swap` | 2GB swap file creation (skipped on LXC) |
| `qemu_agent` | QEMU guest agent for VMs |
| `security` | SSH hardening, UFW, fail2ban, Lynis |
| `docker` | Docker CE installation and configuration |
| `watchtower` | Automatic container updates |
| `restic` | Backup automation with retention policies |

### Tier 2: Target Agents
| Role | Description |
|------|-------------|
| `netdata` (child) | Real-time metrics streaming to parent |
| `promtail` | Log shipping to Loki |
| `docker_socket_proxy` | Secure Docker API proxy |

### Tier 3: Control Stacks
| Role | Description |
|------|-------------|
| `traefik` | Reverse proxy with Let's Encrypt |
| `authentik` | SSO/OIDC identity provider |
| `step_ca` | Internal certificate authority |
| `pihole` | DNS with ad-blocking + Unbound |
| `netdata` (parent) | Metrics aggregation and alerting |
| `loki` | Log aggregation |
| `grafana` | Dashboards and visualization |
| `uptime_kuma` | Status monitoring |
| `dockge` | Docker Compose stack manager |

## Services After Deployment

| Service | URL | Description |
|---------|-----|-------------|
| Traefik | `https://traefik.yourdomain.com` | Reverse proxy dashboard |
| Grafana | `https://grafana.yourdomain.com` | Monitoring dashboards |
| Netdata | `https://netdata.yourdomain.com` | Real-time metrics |
| Uptime Kuma | `https://status.yourdomain.com` | Status pages |
| Pi-hole | `https://pihole.yourdomain.com` | DNS admin |
| Authentik | `https://auth.yourdomain.com` | Identity provider |
| Step-CA | `https://step-ca.yourdomain.com` | Certificate authority |
| Dockge | `https://dockge.yourdomain.com` | Stack manager |

## Validation

```bash
# Validate entire fleet
./scripts/validate-fleet.sh

# Quick connectivity test
./scripts/validate-fleet.sh --quick

# Check control services only
./scripts/validate-fleet.sh --services
```

## Documentation

- [Installation Guide](docs/wiki/01-installation.md)
- [Architecture Overview](docs/wiki/02-architecture.md)
- [Configuration Reference](docs/wiki/03-configuration.md)
- [Role Reference](docs/wiki/04-roles.md)
- [Security Guide](docs/wiki/05-security.md)
- [Troubleshooting](docs/wiki/06-troubleshooting.md)

## Requirements

### Control Node
- Ubuntu 24.04 LTS
- Python 3.10+
- Ansible 2.14+
- SSH client

### Target Nodes
- Ubuntu 22.04+ or Debian 12+
- Python 3 (installed by bootstrap)
- SSH server
- sudo access

### Network
- Control node can SSH to all targets
- Targets can reach control node on ports: 3100 (Loki), 19999 (Netdata)
- External access to control node ports: 80, 443

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./scripts/validate-fleet.sh`
5. Submit a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Ansible](https://www.ansible.com/) - Automation platform
- [Netdata](https://www.netdata.cloud/) - Real-time monitoring
- [Grafana](https://grafana.com/) - Visualization
- [Traefik](https://traefik.io/) - Cloud-native proxy
- [Authentik](https://goauthentik.io/) - Identity provider
- [Smallstep](https://smallstep.com/) - Certificate authority
