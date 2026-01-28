# Server Helper Architecture

A comprehensive overview of Server Helper's architecture, components, and how they interact.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SERVER HELPER v1.0.0                               │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         REVERSE PROXY LAYER                          │   │
│  │                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │                        TRAEFIK                                │  │   │
│  │  │                                                               │  │   │
│  │  │  Entrypoints:         Certificate Resolvers:                  │  │   │
│  │  │    - :80 (web)          - letsencrypt (public domains)       │  │   │
│  │  │    - :443 (websecure)   - step-ca (internal domains)         │  │   │
│  │  │    - :8080 (dashboard)                                        │  │   │
│  │  │                                                               │  │   │
│  │  │  Middlewares: security-headers, rate-limit, internal-only    │  │   │
│  │  └──────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│  ┌─────────────────────────────────┼─────────────────────────────────────┐ │
│  │                                 ▼                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    CERTIFICATE AUTHORITY                         │ │ │
│  │  │                                                                  │ │ │
│  │  │  ┌─────────────────┐              ┌─────────────────┐          │ │ │
│  │  │  │  Let's Encrypt  │              │  Smallstep CA   │          │ │ │
│  │  │  │  (External)     │              │  (Self-Hosted)  │          │ │ │
│  │  │  │                 │              │                 │          │ │ │
│  │  │  │  Public domains │              │ Internal domains│          │ │ │
│  │  │  │  via DNS-01     │              │ via ACME        │          │ │ │
│  │  │  └─────────────────┘              └─────────────────┘          │ │ │
│  │  └─────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         APPLICATION LAYER                              │ │
│  │                                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │ │
│  │  │   DOCKGE     │  │   NETDATA    │  │ UPTIME KUMA  │                │ │
│  │  │   :5001      │  │   :19999     │  │   :3001      │                │ │
│  │  │              │  │              │  │              │                │ │
│  │  │ Container    │  │ System       │  │ Uptime       │                │ │
│  │  │ Management   │  │ Metrics      │  │ Monitoring   │                │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │ │
│  │                                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │ │
│  │  │    LOKI      │  │   GRAFANA    │  │   PI-HOLE    │                │ │
│  │  │   :3100      │  │   :3000      │  │   :53/:8080  │                │ │
│  │  │              │  │              │  │              │                │ │
│  │  │ Log          │  │ Dashboards   │  │ DNS +        │                │ │
│  │  │ Aggregation  │  │ Visualization│  │ Ad-blocking  │                │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │ │
│  │                                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │ │
│  │  │  AUTHENTIK   │  │  SEMAPHORE   │  │   UNBOUND    │                │ │
│  │  │ :9000/:9443  │  │   :3000      │  │   :5335      │                │ │
│  │  │              │  │              │  │              │                │ │
│  │  │ SSO +        │  │ Ansible      │  │ Recursive    │                │ │
│  │  │ Identity     │  │ Web UI       │  │ DNS          │                │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         SYSTEM LAYER                                   │ │
│  │                                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │ │
│  │  │   RESTIC     │  │    LYNIS     │  │  FAIL2BAN    │                │ │
│  │  │              │  │              │  │              │                │ │
│  │  │ Encrypted    │  │ Security     │  │ Intrusion    │                │ │
│  │  │ Backups      │  │ Auditing     │  │ Prevention   │                │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │ │
│  │                                                                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                │ │
│  │  │     UFW      │  │   DOCKER     │  │ ANSIBLE-PULL │                │ │
│  │  │              │  │              │  │              │                │ │
│  │  │ Firewall     │  │ Container    │  │ Self-Update  │                │ │
│  │  │              │  │ Runtime      │  │              │                │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘                │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                         STORAGE LAYER                                  │ │
│  │                                                                        │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐ │ │
│  │  │                     BACKUP DESTINATIONS                           │ │ │
│  │  │                                                                   │ │ │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐            │ │ │
│  │  │  │   NAS   │  │  AWS S3 │  │   B2    │  │  Local  │            │ │ │
│  │  │  │  (CIFS) │  │         │  │         │  │         │            │ │ │
│  │  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘            │ │ │
│  │  └──────────────────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Details

### Reverse Proxy Layer

**Traefik** handles all incoming traffic:

| Component | Port | Purpose |
|-----------|------|---------|
| Web Entrypoint | 80 | HTTP (redirects to HTTPS) |
| WebSecure Entrypoint | 443 | HTTPS with TLS |
| Dashboard | 8080 | Traefik management UI |

**Certificate Resolvers:**

- `letsencrypt` - For public domains via DNS-01 challenge
- `step-ca` - For internal domains via self-hosted CA

### Certificate Authority Layer

**Let's Encrypt (External):**
- Public domains (`*.example.com`)
- DNS-01 challenge via Cloudflare/Route53/etc.
- 90-day certificates, auto-renewed
- Browser-trusted by default

**Smallstep CA (Self-Hosted):**
- Internal domains (`*.internal`)
- ACME protocol for Traefik integration
- 30-day certificates, auto-renewed
- Requires one-time root CA installation on clients

### Application Layer

| Service | Port | Purpose | RAM |
|---------|------|---------|-----|
| Dockge | 5001 | Container stack management | ~50MB |
| Netdata | 19999 | System metrics and monitoring | ~100MB |
| Uptime Kuma | 3001 | Uptime monitoring and alerting | ~50MB |
| Loki | 3100 | Log aggregation | ~150MB |
| Grafana | 3000 | Dashboards and visualization | ~200MB |
| Pi-hole | 53, 8080 | DNS and ad-blocking | ~100MB |
| Unbound | 5335 | Recursive DNS resolver | ~50MB |
| Authentik | 9000, 9443 | SSO and identity provider | ~300MB |
| Semaphore | 3000 | Ansible web UI | ~100MB |
| Smallstep CA | 9000 | Internal certificate authority | ~128MB |

### System Layer

| Service | Purpose | Type |
|---------|---------|------|
| Restic | Encrypted, deduplicated backups | Systemd Timer |
| Lynis | Security auditing | Systemd Timer |
| fail2ban | Intrusion prevention | Systemd Service |
| UFW | Firewall management | Systemd Service |
| Docker | Container runtime | Systemd Service |
| ansible-pull | Self-updating | Systemd Timer |

---

## Docker Networks

```
┌─────────────────────────────────────────────────────────────┐
│                     DOCKER NETWORKS                          │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    PROXY NETWORK                        │ │
│  │                                                         │ │
│  │  Traefik ◄──► All services needing reverse proxy       │ │
│  │                                                         │ │
│  │  Members: traefik, mealie, vaultwarden, homepage, etc. │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  MONITORING NETWORK                     │ │
│  │                                                         │ │
│  │  Netdata ◄──► Loki ◄──► Grafana ◄──► Prometheus       │ │
│  │                                                         │ │
│  │  Members: netdata, loki, promtail, grafana             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                     DNS NETWORK                         │ │
│  │                                                         │ │
│  │  Pi-hole ◄──► Unbound ◄──► Exporter                   │ │
│  │                                                         │ │
│  │  Members: pihole, unbound, pihole-exporter             │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### HTTPS Request Flow

```
User Request
    │
    ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│  DNS    │────►│ Traefik │────►│ Service │
│(Pi-hole)│     │ :443    │     │         │
└─────────┘     └─────────┘     └─────────┘
                    │
                    ▼
            ┌─────────────┐
            │ TLS Termination
            │ Certificate from:
            │ - Let's Encrypt (public)
            │ - Smallstep CA (internal)
            └─────────────┘
```

### Certificate Issuance Flow

```
                    PUBLIC DOMAIN                    INTERNAL DOMAIN
                    ─────────────                    ───────────────
                         │                                │
                         ▼                                ▼
              ┌──────────────────┐            ┌──────────────────┐
              │     Traefik      │            │     Traefik      │
              │ (needs cert for  │            │ (needs cert for  │
              │ mealie.example.  │            │ grafana.internal)│
              │ com)             │            │                  │
              └────────┬─────────┘            └────────┬─────────┘
                       │                               │
                       ▼                               ▼
              ┌──────────────────┐            ┌──────────────────┐
              │  Let's Encrypt   │            │   Smallstep CA   │
              │     ACME         │            │     ACME         │
              └────────┬─────────┘            └────────┬─────────┘
                       │                               │
                       ▼                               ▼
              ┌──────────────────┐            ┌──────────────────┐
              │   DNS-01 via     │            │  TLS Challenge   │
              │   Cloudflare     │            │  (local)         │
              └────────┬─────────┘            └────────┬─────────┘
                       │                               │
                       ▼                               ▼
              ┌──────────────────┐            ┌──────────────────┐
              │ Certificate      │            │ Certificate      │
              │ Issued (90 days) │            │ Issued (30 days) │
              └──────────────────┘            └──────────────────┘
```

### Backup Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      BACKUP FLOW                             │
│                                                              │
│  Systemd Timer (Daily 2 AM)                                 │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────┐                                            │
│  │   Restic    │                                            │
│  │   Backup    │                                            │
│  └──────┬──────┘                                            │
│         │                                                    │
│         ├────────────────┬────────────────┬────────────────┤│
│         ▼                ▼                ▼                ▼│
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────┐│
│  │     NAS     │  │   AWS S3    │  │     B2      │  │Local││
│  │   (CIFS)    │  │             │  │             │  │     ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────┘│
│                                                              │
│  Backed up paths:                                           │
│    - /opt/dockge/stacks                                     │
│    - /opt/dockge/data                                       │
│    - /opt/step-ca                                           │
│    - /etc                                                    │
│    - /home                                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
/opt/
├── dockge/
│   ├── docker-compose.yml          # Dockge service
│   ├── data/                        # Dockge data
│   └── stacks/                      # All Docker stacks
│       ├── netdata/
│       ├── uptime-kuma/
│       ├── traefik/
│       ├── step-ca/
│       ├── logging/
│       ├── dns/
│       └── ...
│
├── step-ca/
│   ├── docker-compose.yml          # Smallstep CA service
│   ├── config/
│   │   ├── ca.json                 # CA configuration
│   │   └── defaults.json           # Default settings
│   ├── secrets/
│   │   ├── password                # CA password
│   │   └── provisioner-password    # Provisioner password
│   └── certs/
│       └── root_ca.crt             # Root CA certificate
│
├── backups/
│   └── restic/                      # Local backup repository
│
└── ansible/
    └── Server-Helper/               # Ansible playbooks (for self-update)

/mnt/
└── nas/
    └── backup/
        └── restic/                  # NAS backup repository

/var/log/
├── ansible-pull.log                 # Self-update logs
├── restic-backup.log                # Backup logs
└── lynis/
    └── report.dat                   # Security audit reports

/etc/systemd/system/
├── restic-backup.service            # Backup service
├── restic-backup.timer              # Backup schedule
├── lynis-scan.service               # Security scan service
├── lynis-scan.timer                 # Security scan schedule
├── ansible-pull.service             # Self-update service
└── ansible-pull.timer               # Self-update schedule
```

---

## Ansible Structure

```
Server-Helper/
├── ansible.cfg                      # Ansible configuration
├── requirements.yml                 # Galaxy dependencies
│
├── inventory/
│   ├── hosts.yml                    # Server inventory
│   └── hosts.example.yml            # Example inventory
│
├── group_vars/
│   ├── all.yml                      # Main configuration
│   ├── all.example.yml              # Example configuration
│   ├── vault.yml                    # Encrypted secrets
│   └── vault.example.yml            # Example secrets template
│
├── playbooks/
│   ├── bootstrap.yml                # First-time server setup
│   ├── setup-targets.yml            # Main deployment
│   ├── setup-control.yml            # Control node setup
│   ├── backup.yml                   # Backup operations
│   ├── security.yml                 # Security audit
│   └── update.yml                   # Self-update
│
├── roles/
│   ├── common/                      # Base system setup
│   ├── security/                    # Security hardening
│   ├── dockge/                      # Container management
│   ├── netdata/                     # Monitoring
│   ├── uptime-kuma/                 # Uptime monitoring
│   ├── step-ca/                     # Internal CA
│   ├── logging/                     # Loki + Grafana
│   ├── dns/                         # Pi-hole + Unbound
│   ├── authentik/                   # SSO
│   ├── semaphore/                   # Ansible UI
│   └── ...
│
├── scripts/
│   ├── setup.sh                     # Interactive setup
│   ├── add-server.sh                # Add servers to inventory
│   ├── vault.sh                     # Vault management
│   └── ...
│
└── docs/
    ├── README.md                    # Documentation index
    ├── ARCHITECTURE.md              # This file
    └── guides/
        ├── certificates.md          # Certificate management
        ├── traefik.md               # Reverse proxy
        └── ...
```

---

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                           │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   NETWORK LAYER                         │ │
│  │                                                         │ │
│  │  UFW Firewall (default deny)                           │ │
│  │    - Port 22: SSH                                       │ │
│  │    - Port 80: HTTP → HTTPS redirect                    │ │
│  │    - Port 443: HTTPS                                    │ │
│  │    - Port 53: DNS (if Pi-hole enabled)                 │ │
│  │    - Service ports (internal only)                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   ACCESS LAYER                          │ │
│  │                                                         │ │
│  │  fail2ban                                               │ │
│  │    - SSH brute-force protection                        │ │
│  │    - Automatic IP banning                              │ │
│  │                                                         │ │
│  │  SSH Hardening                                          │ │
│  │    - Key-only authentication                           │ │
│  │    - Root login disabled                               │ │
│  │    - Max 3 auth tries                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 TRANSPORT LAYER                         │ │
│  │                                                         │ │
│  │  TLS 1.2+ for all HTTPS                                │ │
│  │  Strong cipher suites                                   │ │
│  │  HSTS enabled                                           │ │
│  │  Security headers on all responses                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   DATA LAYER                            │ │
│  │                                                         │ │
│  │  Ansible Vault (AES-256)                               │ │
│  │    - Encrypted secrets                                  │ │
│  │    - Password-protected                                 │ │
│  │                                                         │ │
│  │  Restic Backups (AES-256)                              │ │
│  │    - Encrypted at rest                                  │ │
│  │    - Deduplicated and compressed                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                   AUDIT LAYER                           │ │
│  │                                                         │ │
│  │  Lynis Security Audits (weekly)                        │ │
│  │  Centralized logging (Loki)                            │ │
│  │  Uptime monitoring (Uptime Kuma)                       │ │
│  │  Container vulnerability scanning (Scanopy)            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Resource Usage

### Minimum Requirements

| Component | RAM | CPU | Disk |
|-----------|-----|-----|------|
| Docker | 100MB | 0.1 | 5GB |
| Dockge | 50MB | 0.1 | 100MB |
| Netdata | 100MB | 0.2 | 500MB |
| Uptime Kuma | 50MB | 0.1 | 100MB |
| **Total (Core)** | **300MB** | **0.5** | **6GB** |

### Full Stack Requirements

| Component | RAM | CPU | Disk |
|-----------|-----|-----|------|
| Core Services | 300MB | 0.5 | 6GB |
| Loki + Grafana | 350MB | 0.3 | 10GB |
| Pi-hole + Unbound | 150MB | 0.2 | 1GB |
| Smallstep CA | 128MB | 0.1 | 500MB |
| Traefik | 50MB | 0.1 | 100MB |
| Authentik | 300MB | 0.3 | 2GB |
| Semaphore | 100MB | 0.1 | 1GB |
| **Total (Full)** | **~1.5GB** | **~1.5** | **~20GB** |

---

## Further Reading

- [Certificate Management](guides/certificates.md)
- [Traefik Configuration](guides/traefik.md)
- [Smallstep CA](guides/smallstep-ca.md)
- [Logging Stack](guides/logging-stack.md)
- [DNS Setup](DNS_QUICKSTART.md)
- [Security Hardening](AUTOMATED_REMEDIATION.md)
