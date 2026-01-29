# Architecture Overview

This document describes the architecture and design principles of Server Helper.

## Table of Contents

1. [Design Principles](#design-principles)
2. [Tiered Architecture](#tiered-architecture)
3. [Network Architecture](#network-architecture)
4. [Data Flow](#data-flow)
5. [Service Dependencies](#service-dependencies)
6. [Security Architecture](#security-architecture)

---

## Design Principles

### 1. Tiered Inheritance

Every node receives the same foundation hardening, ensuring consistent security posture across the fleet.

```
Tier 1 (Foundation) → Applied to ALL nodes
Tier 2 (Agents)     → Applied to TARGET nodes only
Tier 3 (Stacks)     → Applied to CONTROL node only
```

### 2. Idempotency

All operations are idempotent - running playbooks multiple times produces the same result without side effects.

### 3. Dockge Compatibility

All Docker services deploy to `/opt/stacks/{service-name}/` with `compose.yaml` files, enabling visual management through Dockge.

### 4. Security First

- All secrets stored in Ansible Vault
- SSH hardening on all nodes
- Firewall (UFW) deny-by-default
- Internal PKI for TLS certificates
- Centralized authentication (Authentik SSO)

### 5. Observability

- Metrics: Netdata parent/child streaming
- Logs: Promtail → Loki → Grafana
- Status: Uptime Kuma health checks

---

## Tiered Architecture

### Tier 1: Foundation (All Nodes)

Applied to every managed node, including the control node.

```
┌─────────────────────────────────────────────────────────────┐
│                    TIER 1: FOUNDATION                       │
├─────────────────────────────────────────────────────────────┤
│  common       │ Base packages, timezone, NTP, sysctl        │
│  lvm_config   │ LVM volume expansion (skip LXC)             │
│  swap         │ 2GB swap file (skip LXC)                    │
│  qemu_agent   │ QEMU guest agent (VMs only)                 │
│  security     │ SSH hardening, UFW, fail2ban, Lynis         │
│  docker       │ Docker CE installation                      │
│  watchtower   │ Automatic container updates                 │
│  restic       │ Backup automation                           │
└─────────────────────────────────────────────────────────────┘
```

### Tier 2: Target Agents (Worker Nodes)

Monitoring and security agents for target nodes.

```
┌─────────────────────────────────────────────────────────────┐
│                  TIER 2: TARGET AGENTS                      │
├─────────────────────────────────────────────────────────────┤
│  netdata (child)       │ Stream metrics to parent           │
│  promtail              │ Ship logs to Loki                  │
│  docker_socket_proxy   │ Secure Docker API access           │
└─────────────────────────────────────────────────────────────┘
```

### Tier 3: Control Stacks (Management Node)

Full service stacks on the control node.

```
┌─────────────────────────────────────────────────────────────┐
│                 TIER 3: CONTROL STACKS                      │
├─────────────────────────────────────────────────────────────┤
│  GATEWAY       │ traefik          │ Reverse proxy           │
│  IDENTITY      │ authentik        │ SSO/OIDC                │
│  PKI           │ step_ca          │ Certificate authority   │
│  DNS           │ pihole + unbound │ Ad-blocking DNS         │
│  METRICS       │ netdata (parent) │ Metrics aggregation     │
│  LOGS          │ loki             │ Log aggregation         │
│  DASHBOARDS    │ grafana          │ Visualization           │
│  STATUS        │ uptime_kuma      │ Health monitoring       │
│  MANAGEMENT    │ dockge           │ Stack manager           │
└─────────────────────────────────────────────────────────────┘
```

---

## Network Architecture

### Port Map

#### Control Node - External (Internet-facing)

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 80 | Traefik | HTTP | Redirect to HTTPS |
| 443 | Traefik | HTTPS | All web services |

#### Control Node - Internal (From targets)

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 53 | Pi-hole | DNS | Network DNS |
| 3100 | Loki | HTTP | Log ingestion |
| 19999 | Netdata | HTTP | Metrics streaming |

#### Target Nodes - Internal

| Port | Service | Protocol | Description |
|------|---------|----------|-------------|
| 22 | SSH | SSH | Management |
| 2375 | Docker Proxy | HTTP | Control node only |
| 9080 | Promtail | HTTP | Health checks |

### Network Diagram

```
                    INTERNET
                        │
                        ▼
                   ┌────────┐
                   │ Router │
                   └───┬────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
         ▼             ▼             ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ Control │   │ Target1 │   │ Target2 │
    │  :443   │   │         │   │         │
    │  :53    │◄──│ DNS     │   │ DNS     │
    │  :3100  │◄──│ Logs    │◄──│ Logs    │
    │  :19999 │◄──│ Metrics │◄──│ Metrics │
    └─────────┘   └─────────┘   └─────────┘

    Legend:
    ─────► Traffic flow
    :port  Listening port
```

### DNS Resolution

All services use subdomains routed through Traefik:

```
*.example.com → Control Node IP → Traefik → Service

grafana.example.com  → Traefik → Grafana (:3000)
auth.example.com     → Traefik → Authentik (:9000)
pihole.example.com   → Traefik → Pi-hole (:8053)
```

---

## Data Flow

### Metrics Flow

```
┌─────────────┐     Stream API Key      ┌─────────────┐
│   Target    │ ─────────────────────► │   Control   │
│   Netdata   │      Port 19999        │   Netdata   │
│   (Child)   │                        │   (Parent)  │
└─────────────┘                        └──────┬──────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │   Grafana   │
                                       │ (Dashboard) │
                                       └─────────────┘
```

### Log Flow

```
┌─────────────┐                        ┌─────────────┐
│   Target    │      HTTP POST         │   Control   │
│  Promtail   │ ─────────────────────► │    Loki     │
│             │      Port 3100         │             │
└─────────────┘                        └──────┬──────┘
      │                                       │
      │ Scrapes:                              │
      │ - /var/log/*.log                      ▼
      │ - /var/log/syslog              ┌─────────────┐
      │ - Docker container logs        │   Grafana   │
      │                                │  (Explore)  │
      └─────────────────────────────── └─────────────┘
```

### Authentication Flow

```
┌─────────────┐                        ┌─────────────┐
│    User     │ ────── HTTPS ────────► │   Traefik   │
│  (Browser)  │                        │             │
└─────────────┘                        └──────┬──────┘
                                              │
                              ┌───────────────┼───────────────┐
                              ▼               ▼               ▼
                       ┌───────────┐   ┌───────────┐   ┌───────────┐
                       │  Grafana  │   │  Dockge   │   │  Other    │
                       │           │   │           │   │ Services  │
                       └─────┬─────┘   └─────┬─────┘   └─────┬─────┘
                             │               │               │
                             └───────────────┼───────────────┘
                                             │
                                             ▼
                                      ┌─────────────┐
                                      │  Authentik  │
                                      │    (SSO)    │
                                      └─────────────┘
```

### Backup Flow

```
┌─────────────┐                        ┌─────────────┐
│   Target    │      S3 Protocol       │     NAS     │
│   Restic    │ ─────────────────────► │   (MinIO)   │
│             │                        │             │
└─────────────┘                        └─────────────┘
      │
      │ Backs up:
      │ - /opt/stacks/
      │ - /etc/
      │ - Custom paths
      │
      └─────────────────────────────────────────────
```

---

## Service Dependencies

### Startup Order

The playbook deploys services in dependency order:

```
1. Foundation (Tier 1)
   └─► common, security, docker

2. Gateway
   └─► traefik (needs docker)

3. Infrastructure
   ├─► step_ca (needs traefik for ACME)
   ├─► pihole (needs docker)
   └─► authentik (needs docker, traefik)

4. Monitoring
   ├─► loki (needs docker)
   ├─► netdata parent (needs docker)
   ├─► grafana (needs loki, authentik)
   └─► uptime_kuma (needs docker)

5. Target Agents (Tier 2)
   ├─► netdata child (needs parent)
   ├─► promtail (needs loki)
   └─► docker_socket_proxy (needs docker)
```

### Dependency Graph

```
                    ┌──────────┐
                    │  Docker  │
                    └────┬─────┘
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │ Traefik │   │  Loki   │   │ Pi-hole │
      └────┬────┘   └────┬────┘   └─────────┘
           │             │
     ┌─────┼─────┐       │
     ▼     ▼     ▼       ▼
┌───────┐ ┌───┐ ┌───────────┐
│Authntk│ │CA │ │  Grafana  │
└───┬───┘ └───┘ └───────────┘
    │
    ▼
┌───────────┐
│ All OAuth │
│ Services  │
└───────────┘
```

---

## Security Architecture

### Defense in Depth

```
Layer 1: Network
├── UFW firewall (deny by default)
├── Docker Socket Proxy (control IP only)
└── Traefik (TLS termination)

Layer 2: Authentication
├── SSH key-only authentication
├── Authentik SSO for web services
└── fail2ban intrusion prevention

Layer 3: Authorization
├── sudo with NOPASSWD for ansible user only
├── Docker group membership
└── Authentik group-based RBAC

Layer 4: Encryption
├── TLS for all web traffic (Traefik)
├── Internal TLS (Step-CA)
└── Ansible Vault for secrets

Layer 5: Monitoring
├── Lynis security auditing
├── fail2ban alerts
└── Uptime Kuma health checks
```

### Trust Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│                     TRUSTED ZONE                            │
│                                                             │
│   ┌───────────┐    ┌───────────┐    ┌───────────┐         │
│   │  Control  │◄──►│  Target1  │◄──►│  Target2  │         │
│   │   Node    │    │   Node    │    │   Node    │         │
│   └───────────┘    └───────────┘    └───────────┘         │
│                                                             │
│   Internal network - SSH, metrics, logs                    │
└─────────────────────────────────────────────────────────────┘
         │
         │ TLS (Traefik)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    UNTRUSTED ZONE                           │
│                                                             │
│   Internet users accessing web services                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Next Steps

- [Configuration Reference](03-configuration.md) - All configuration options
- [Role Reference](04-roles.md) - Detailed role documentation
- [Security Guide](05-security.md) - Security best practices
