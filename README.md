# Server Helper v0.4.0

Infrastructure automation framework for managing a fleet of Docker-based servers using Ansible, Docker Compose, and Bash scripts.

## Architecture

```
Control Node                         Target Nodes (N)
┌─────────────────────┐             ┌─────────────────────┐
│ Tier 3: Stacks      │             │ Tier 2: Agents      │
│  ├─ Traefik         │◄───────────►│  ├─ Netdata (child) │
│  ├─ Authentik       │             │  ├─ Promtail        │
│  ├─ Step-CA         │             │  ├─ Docker Socket   │
│  ├─ Pi-hole         │             │  ├─ Loki            │
│  ├─ Uptime Kuma     │             │  └─ Dockge          │
│  ├─ Netdata (parent)│             │ Tier 1: Foundation  │
│  ├─ Grafana         │             │  ├─ common          │
│  └─ Dockge          │             │  ├─ security        │
├─────────────────────┤             │  ├─ docker          │
│ Tier 1: Foundation  │             │  ├─ watchtower      │
│  (same as targets)  │             │  └─ restic          │
└─────────────────────┘
```

| Tier | Name | Hosts | Purpose |
|------|------|-------|---------|
| **Tier 1** | Foundation | `all` | Base OS hardening, Docker, backups — identical on every node |
| **Tier 2** | Target Agents | `targets` | Lightweight monitoring/logging agents that stream to control |
| **Tier 3** | Control Stacks | `control` | Full management services (proxy, SSO, dashboards, DNS, PKI) |

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> && cd Server-Helper-Reborn

# 2. Run the interactive setup wizard
bash setup.sh
```

The script will automatically:

- Copy default configuration files (`.example.yml` → `.yml`)
- Install required Ansible dependencies (`make deps`)
- Launch the interactive setup wizard

The wizard walks you through:

- Network configuration (domain, control node IP)
- Inventory setup (adding your servers)
- Secret generation (passwords, API keys)
- Vault encryption
- **Deployment** (optional interactive step at the end)

### First Deployment

If you didn't deploy during the wizard, you can run:

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
| Dockge | `https://dockge.{domain}` | 5001 |
| Loki | *(internal only)* | 3100 |

## Key Commands

### Deployment

| Command | Description |
|---------|-------------|
| `make deploy` | Full 3-tier deployment (`site.yml`) |
| `make deploy-control` | Control node only |
| `make deploy-targets` | Target nodes only |
| `make deploy-host HOST=server1` | Specific host |
| `make deploy-role ROLE=docker` | Specific role (optionally `HOST=`) |
| `make deploy-check` | Dry run with diff output |

### Updates & Upgrades

| Command | Description |
|---------|-------------|
| `make update` | Rolling apt upgrades (`serial: 1`) |
| `make update-reboot` | Updates with reboot |
| `make upgrade` | Docker image pull + recreate |
| `make upgrade-service SERVICE=grafana` | Upgrade specific service |
| `make upgrade-cleanup` | Upgrade with unused image pruning |

### Backups, Monitoring & Vault

| Command | Description |
|---------|-------------|
| `make backup` | Trigger backups on all hosts |
| `make backup-host HOST=server1` | Backup specific host |
| `make ping` | Ansible ping all hosts |
| `make status` | Docker status across fleet |
| `make doctor` | Fleet diagnostics |
| `make vault-edit` | Edit encrypted vault |
| `make vault-view` | View decrypted vault |

### Testing & Linting

| Command | Description |
|---------|-------------|
| `make test` | Run all Molecule tests |
| `make test-role ROLE=common` | Test specific role |
| `make lint` | ansible-lint + yamllint |

## Project Structure

```
├── ansible.cfg                 # Ansible configuration
├── Makefile                    # 40+ automation targets
├── VERSION                     # Semver (0.4.0)
├── requirements.yml            # Galaxy dependencies
├── group_vars/                 # Variable hierarchy
├── host_vars/                  # Per-host overrides
├── inventory/                  # Host inventory
├── playbooks/                  # 8 orchestration playbooks
├── roles/                      # 20 Ansible roles
│   └── {role}/
│       ├── defaults/main.yml
│       ├── tasks/main.yml
│       ├── meta/main.yml
│       ├── templates/
│       ├── handlers/main.yml
│       └── molecule/default/
├── scripts/
│   ├── setup.sh                # Interactive CLI
│   └── lib/                    # 10 library modules
├── docs/                       # Documentation
└── .github/                    # CI/CD workflows
```

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Prerequisites, installation, first deploy |
| [Architecture](docs/architecture.md) | Tier model, data flows, playbook orchestration |
| [Configuration](docs/configuration.md) | Variables, vault, host_vars, inventory |
| [Roles Reference](docs/roles.md) | All 20 roles with vars, templates, deploy paths |
| [Security](docs/security.md) | Hardening, vault, pre-commit hooks, audit model |
| [Operations](docs/operations.md) | Backups, upgrades, troubleshooting |
| [Development](docs/development.md) | Testing, CI/CD, linting, contributing |

## License

MIT
