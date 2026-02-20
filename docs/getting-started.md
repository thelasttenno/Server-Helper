# Getting Started

## Prerequisites

- **Control machine**: Linux/macOS/WSL with Python 3.8+ and Ansible 2.14+
- **Target servers**: Ubuntu 22.04/24.04 LTS or Debian 12, with SSH access and a sudo-capable user
- **Network**: Control machine can SSH to all targets; targets can reach the internet for package installs

## Installation

```bash
# 1. Clone the repository
git clone <repo-url> && cd Server-Helper-Reborn

# 2. Run the interactive setup wizard
bash setup.sh
```

The script automatically handles:

- Copying default configuration files
- Installing Ansible dependencies
- Launching the interactive wizard

The wizard walks you through:

- Network configuration (domain, control node IP)
- Inventory setup (adding your servers)
- Secret generation (passwords, API keys)
- Vault encryption
- **Deployment** (optional)

## First Deployment

```bash
# Dry run — verify what will change without applying
make deploy-check

# Full deployment — all tiers, all hosts
make deploy
```

Deployment order:

1. **Tier 1 (Foundation)** — base OS, Docker, security, backups on ALL nodes
2. **Tier 2 (Agents)** — Netdata, Promtail, Dockge on target nodes
3. **Tier 3 (Stacks)** — Traefik, Authentik, Grafana, etc. on control node

## Post-Deploy Services

| Service | URL | Default Port |
|---------|-----|-------------|
| Traefik Dashboard | `https://traefik.{domain}` | 8080 |
| Grafana | `https://grafana.{domain}` | 3000 |
| Netdata | `https://netdata.{domain}` | 19999 |
| Uptime Kuma | `https://status.{domain}` | 3001 |
| Pi-hole | `https://pihole.{domain}` | 8053 |
| Authentik | `https://auth.{domain}` | 9000 |
| Step-CA | `https://step-ca.{domain}` | 9443 |
| Step-CA | `https://step-ca.{domain}` | 9443 |
| Dockge | `https://dockge.{domain}` | 5001 |
| Homarr | `https://dashboard.{domain}` | 7575 |
| Loki | *(internal only)* | 3100 |

Services with complex post-deploy setup (Authentik, Step-CA, Pi-hole, Uptime Kuma) render a `SETUP-GUIDE.md` into their stack directory at `/opt/stacks/{service}/`.

## Adding a New Server

```bash
make add-target
# or manually:
# 1. Add the host to inventory/hosts.yml under the 'targets' group
# 2. Run: make deploy-host HOST=new-server
```

## Next Steps

- [Architecture](architecture.md) — understand the tier model and data flows
- [Configuration](configuration.md) — customize variables, vault, and per-host overrides
- [Operations](operations.md) — day-to-day commands for backups, upgrades, and troubleshooting
