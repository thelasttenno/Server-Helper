# Server Helper v2.0

Infrastructure automation framework for managing a fleet of Docker-based servers using Ansible, Docker Compose, and Bash scripts.

## Architecture

```
Control Node                         Target Nodes (N)
┌─────────────────────┐             ┌─────────────────────┐
│ Tier 3: Stacks      │             │ Tier 2: Agents      │
│  ├─ Traefik         │◄───────────►│  ├─ Netdata (child) │
│  ├─ Authentik       │             │  ├─ Promtail        │
│  ├─ Step-CA         │             │  ├─ Docker Socket   │
│  ├─ Pi-hole         │             │  └─ Dockge          │
│  ├─ Loki            │             ├─────────────────────┤
│  ├─ Netdata (parent)│             │ Tier 1: Foundation  │
│  ├─ Grafana         │             │  ├─ common          │
│  ├─ Uptime Kuma     │             │  ├─ security        │
│  └─ Dockge          │             │  ├─ docker          │
├─────────────────────┤             │  ├─ watchtower      │
│ Tier 1: Foundation  │             │  └─ restic          │
│  (same as targets)  │             └─────────────────────┘
└─────────────────────┘
```

## Quick Start

```bash
git clone <repo-url> && cd Server-Helper-Reborn
cp group_vars/all.example.yml group_vars/all.yml
cp group_vars/vault.example.yml group_vars/vault.yml
cp inventory/hosts.example.yml inventory/hosts.yml
make deps && make setup && make deploy
```

## Key Commands

| Command | Description |
|---------|-------------|
| `make setup` | Interactive setup wizard |
| `make deploy` | Full 3-tier deployment |
| `make deploy-check` | Dry run |
| `make update` | Rolling system updates |
| `make upgrade` | Docker image upgrades |
| `make backup` | Trigger backups |
| `make test` | Run all Molecule tests |
| `make lint` | Run linting |
| `make vault-edit` | Edit encrypted vault |
| `make status` | Docker status across fleet |

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
