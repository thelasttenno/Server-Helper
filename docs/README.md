# Server Helper Documentation

Complete documentation for Server Helper v1.0.0 - Ansible-based infrastructure management for Ubuntu 24.04 LTS.

---

## Quick Start

1. Clone the repository
2. Run `./setup.sh` on your command node (laptop/desktop)
3. Follow the interactive prompts
4. Access your services via the URLs shown

---

## Documentation Index

### Getting Started

| Guide | Description |
|-------|-------------|
| [Setup Script Guide](guides/setup-script.md) | Interactive setup walkthrough |
| [Command Node Architecture](guides/command-node.md) | Multi-server management from your laptop |
| [Running Playbooks](guides/playbooks.md) | Complete playbook usage guide |
| [Multi-Server Setup](MULTI_SERVER_SETUP.md) | Managing multiple physical servers |
| [Inventory Management](guides/inventory-management.md) | Server inventory configuration |

### Security & Secrets

| Guide | Description |
|-------|-------------|
| [Ansible Vault Guide](guides/vault.md) | Complete secrets management |
| [Vault Commands Reference](reference/vault-commands.md) | Quick command reference |
| [External Secret Managers](integrations/external-secrets.md) | HashiCorp Vault, AWS, Azure, GCP integration |
| [Vault in CI/CD](workflows/vault-in-ci-cd.md) | Automation workflows |

### Certificate Management

| Guide | Description |
|-------|-------------|
| [Certificate Management](guides/certificates.md) | Hybrid certificate setup (Let's Encrypt + Smallstep CA) |
| [Cloudflare Privacy Guide](guides/cloudflare-privacy.md) | DNS-only mode for maximum privacy |
| [Smallstep CA Guide](guides/smallstep-ca.md) | Self-hosted internal certificate authority |
| [Traefik Reverse Proxy](guides/traefik.md) | Reverse proxy configuration |

### Monitoring & Logging

| Guide | Description |
|-------|-------------|
| [Logging Stack](guides/logging-stack.md) | Loki + Promtail + Grafana setup |
| [Logging Quickstart](LOGGING_QUICKSTART.md) | Get started with logging in 5 minutes |
| [Logging Quick Reference](LOGGING_QUICK_REFERENCE.md) | Common logging commands |
| [Automated Remediation](AUTOMATED_REMEDIATION.md) | Self-healing infrastructure |
| [Remediation Quick Reference](REMEDIATION_QUICKREF.md) | Remediation commands |

### DNS & Service Discovery

| Guide | Description |
|-------|-------------|
| [DNS Quickstart](DNS_QUICKSTART.md) | Pi-hole + Unbound setup |
| [DNS Implementation](DNS_IMPLEMENTATION.md) | Technical implementation details |

### Testing & Quality

| Guide | Description |
|-------|-------------|
| [Testing Quickstart](testing-quickstart.md) | Get started with testing in 5 minutes |
| [Complete Testing Guide](testing.md) | Molecule + Testinfra documentation |
| [Testing Setup](../TESTING_SETUP.md) | Setting up test environment |

### Scripts & Automation

| Guide | Description |
|-------|-------------|
| [Scripts Guide](scripts-guide.md) | All helper scripts documentation |
| [Quick Reference](quick-reference.md) | Common commands cheat sheet |
| [Deployment Automation](deployment-automation.md) | CI/CD deployment |

### Development

| Guide | Description |
|-------|-------------|
| [Contributing Guide](development/contributing.md) | Git workflow and commit guidelines |
| [Implementation Details](development/implementation.md) | Architecture and technical notes |
| [Release Process](development/release-process.md) | How releases are made |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Server Helper v1.0.0                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                      Traefik                            │    │
│  │              (Reverse Proxy + Certificates)             │    │
│  │                                                         │    │
│  │  letsencrypt (public) ──► mealie.example.com           │    │
│  │  step-ca (internal)   ──► grafana.internal             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Netdata    │  │ Uptime Kuma  │  │   Dockge     │         │
│  │  (Metrics)   │  │  (Alerting)  │  │  (Stacks)    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Loki      │  │   Grafana    │  │  Smallstep   │         │
│  │   (Logs)     │  │ (Dashboards) │  │     CA       │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │   Restic     │  │    Lynis     │  │   Pi-hole    │         │
│  │  (Backups)   │  │  (Security)  │  │    (DNS)     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  Optional: Authentik (SSO) │ Semaphore (Ansible UI)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Common Operations

### Deployment

```bash
# Deploy to all target servers
ansible-playbook playbooks/setup-targets.yml

# Deploy specific components
ansible-playbook playbooks/setup-targets.yml --tags traefik,step-ca
ansible-playbook playbooks/setup-targets.yml --tags monitoring
ansible-playbook playbooks/setup-targets.yml --tags security

# Dry run (preview changes)
ansible-playbook playbooks/setup-targets.yml --check

# Deploy to specific server
ansible-playbook playbooks/setup-targets.yml --limit webserver
```

### Certificate Management

```bash
# Deploy Traefik + Smallstep CA
ansible-playbook playbooks/setup-targets.yml --tags traefik,step-ca

# Install root CA on client (after deployment)
curl -sSL https://your-server:9000/install-root-ca.sh | bash

# Check certificate status
docker exec traefik cat /letsencrypt/acme.json | jq .
docker logs step-ca
```

### Secrets Management

```bash
# Initialize vault
./scripts/vault.sh init

# Edit secrets
./scripts/vault.sh edit group_vars/vault.yml

# View secrets
./scripts/vault.sh view group_vars/vault.yml

# Validate vault files
./scripts/vault.sh validate
```

### Backups & Security

```bash
# Manual backup
ansible-playbook playbooks/backup.yml

# Security audit
ansible-playbook playbooks/security.yml

# View backup status
sudo restic -r /path/to/repo snapshots
```

---

## Service Ports

| Service | Port | Type | Description |
|---------|------|------|-------------|
| **Traefik** | 80, 443 | Public | Reverse proxy (HTTP/HTTPS) |
| **Traefik Dashboard** | 8080 | Internal | Traefik management UI |
| **Dockge** | 5001 | Internal | Container stack management |
| **Netdata** | 19999 | Internal | System metrics |
| **Uptime Kuma** | 3001 | Internal | Uptime monitoring |
| **Grafana** | 3000 | Internal | Log visualization |
| **Loki** | 3100 | Internal | Log aggregation |
| **Smallstep CA** | 9000 | Internal | Certificate authority |
| **Pi-hole** | 53, 8080 | Internal | DNS + Web UI |
| **Authentik** | 9000, 9443 | Internal | SSO provider |
| **Semaphore** | 3000 | Internal | Ansible UI |

---

## Configuration Files

| File | Purpose |
|------|---------|
| `group_vars/all.yml` | Main configuration (services, settings) |
| `group_vars/vault.yml` | Encrypted secrets (passwords, API keys) |
| `inventory/hosts.yml` | Server inventory (IPs, hostnames) |
| `.vault_password` | Vault decryption password (never commit!) |

---

## Features Overview

### Core Features

- **Declarative Configuration** - Define desired state in YAML
- **Idempotent Operations** - Run playbooks safely multiple times
- **Multi-Node Support** - Manage dozens of servers from one place
- **Secure Secrets** - AES-256 encrypted Ansible Vault

### Certificate Management

- **Hybrid Certificates** - Let's Encrypt (public) + Smallstep CA (internal)
- **Privacy-First** - Cloudflare DNS-only mode (no traffic proxying)
- **Wildcard Support** - `*.example.com` via DNS-01 challenge
- **Auto-Renewal** - Certificates renew automatically

### Monitoring & Alerting

- **Real-time Metrics** - Netdata dashboards
- **Centralized Logging** - Loki + Grafana
- **Uptime Monitoring** - Uptime Kuma with notifications
- **Auto-Remediation** - Self-healing infrastructure

### Security

- **fail2ban** - Intrusion prevention
- **UFW Firewall** - Default deny policy
- **SSH Hardening** - Key-only authentication
- **Lynis Audits** - Weekly security scans
- **Traefik Security** - HSTS, security headers

### Backups

- **Restic** - Encrypted, deduplicated backups
- **Multiple Destinations** - NAS, S3, B2, local
- **Flexible Retention** - Daily, weekly, monthly, yearly

---

## Getting Help

1. **Check the guides** - Most questions are answered here
2. **Review role READMEs** - Each role has detailed docs in `roles/*/README.md`
3. **Enable verbose output** - Run playbooks with `-vvv`
4. **Check logs** - Use `journalctl -u service-name -f`
5. **Open an issue** - GitHub Issues for bugs and features

---

## External Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Smallstep CA](https://smallstep.com/docs/)
- [Let's Encrypt](https://letsencrypt.org/docs/)
- [Netdata Docs](https://learn.netdata.cloud/)
- [Restic Docs](https://restic.readthedocs.io/)

---

## Directory Structure

```
docs/
├── README.md                    # This file - documentation index
├── ARCHITECTURE.md              # System architecture overview
├── MULTI_SERVER_SETUP.md        # Multi-server management
├── DNS_QUICKSTART.md            # Pi-hole + Unbound setup
├── LOGGING_QUICKSTART.md        # Loki + Grafana setup
├── AUTOMATED_REMEDIATION.md     # Self-healing infrastructure
├── quick-reference.md           # Common commands cheat sheet
├── testing.md                   # Testing documentation
├── guides/                      # Detailed usage guides
│   ├── certificates.md          # Certificate management
│   ├── cloudflare-privacy.md    # Cloudflare privacy guide
│   ├── command-node.md          # Command node setup
│   ├── logging-stack.md         # Logging configuration
│   ├── playbooks.md             # Playbook usage
│   ├── setup-script.md          # Setup script guide
│   └── vault.md                 # Ansible Vault guide
├── reference/                   # Quick reference materials
│   └── vault-commands.md        # Vault command reference
├── integrations/                # External integrations
│   └── external-secrets.md      # External secret managers
├── workflows/                   # Workflow documentation
│   └── vault-in-ci-cd.md        # CI/CD integration
├── development/                 # Developer documentation
│   ├── contributing.md          # Contribution guidelines
│   ├── implementation.md        # Implementation details
│   └── release-process.md       # Release process
└── archive/                     # Historical documents
    ├── new-features-v1.md
    └── refactoring-v1.md
```

---

**Server Helper v1.0.0** - Made with care for Ubuntu 24.04 LTS
