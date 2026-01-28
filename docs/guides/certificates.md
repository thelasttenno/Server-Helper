# Certificate Management Guide

Server Helper provides **hybrid certificate management** with maximum privacy:

- **Public domains** → Let's Encrypt via DNS-01 challenge (auto-renewed, browser-trusted)
- **Internal domains** → Smallstep CA (self-hosted, fully private)

---

## Quick Start

### 1. Enable Certificate Management

```yaml
# group_vars/all.yml

# Enable reverse proxy
reverse_proxy:
  enabled: true
  type: "traefik"
  domain: "yourdomain.com"
  email: "admin@yourdomain.com"
  force_https: true

# Enable Smallstep CA for internal services
step_ca:
  enabled: true
  name: "My Internal CA"

# Configure public certificates
certificates:
  public:
    enabled: true
    email: "admin@yourdomain.com"
    challenge: "dns-01"
    dns_provider: "cloudflare"
    domains:
      - "yourdomain.com"
      - "*.yourdomain.com"

  internal:
    enabled: true
    domain: "internal"
```

### 2. Add Secrets to Vault

```bash
# Edit vault
ansible-vault edit group_vars/vault.yml
```

Add these secrets:

```yaml
# Smallstep CA passwords
vault_step_ca_password: "generate-with-openssl-rand-base64-32"
vault_step_ca_provisioner_password: "generate-with-openssl-rand-base64-32"

# Cloudflare DNS API token (for DNS-01 challenge)
vault_cloudflare_dns_api_token: "your-cloudflare-dns-api-token"

# Traefik dashboard auth
vault_traefik_dashboard_auth: "admin:$$apr1$$hashed-password"
```

### 3. Deploy

```bash
ansible-playbook playbooks/setup-targets.yml --tags traefik,step-ca
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Your Infrastructure                           │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐     │
│  │                      Traefik                            │     │
│  │                  (Reverse Proxy)                        │     │
│  │                                                         │     │
│  │  Certificate Resolvers:                                 │     │
│  │    - letsencrypt (public)  → mealie.tennogen.ca        │     │
│  │    - step-ca (internal)    → grafana.internal          │     │
│  └──────┬─────────────────────────────────────┬───────────┘     │
│         │                                      │                  │
│    PUBLIC SERVICES                      INTERNAL SERVICES        │
│    (Let's Encrypt)                      (Smallstep CA)           │
│         │                                      │                  │
│  ┌──────▼──────┐                        ┌─────▼──────┐          │
│  │   Mealie    │                        │  Netdata   │          │
│  │   (HTTPS)   │                        │  (HTTPS)   │          │
│  └─────────────┘                        └────────────┘          │
│                                                                   │
│  ┌──────────────┐                                                │
│  │  Smallstep   │ ◄── Issues certs for *.internal domains       │
│  │      CA      │                                                │
│  └──────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Public Certificates (Let's Encrypt)

### Challenge Methods

| Method | Ports Required | Wildcard Support | Best For |
|--------|---------------|------------------|----------|
| **DNS-01** | None | ✅ Yes | Privacy-focused, internal networks |
| TLS-ALPN-01 | 443 | ❌ No | Simple public servers |
| HTTP-01 | 80 | ❌ No | Legacy/simple setups |

### DNS-01 Configuration (Recommended)

DNS-01 is the **recommended** method because:
- ✅ No ports need to be exposed for validation
- ✅ Supports wildcard certificates
- ✅ Works on private networks
- ✅ Maximum privacy (Cloudflare only handles DNS, not traffic)

```yaml
certificates:
  public:
    enabled: true
    email: "admin@tennogen.ca"
    challenge: "dns-01"
    dns_provider: "cloudflare"
    staging: false  # Set true for testing
    domains:
      - "tennogen.ca"
      - "*.tennogen.ca"
      - "publicpower.org"
      - "*.publicpower.org"
```

### Supported DNS Providers

| Provider | Config Key | Documentation |
|----------|------------|---------------|
| Cloudflare | `cloudflare` | [Cloudflare API](https://developers.cloudflare.com/api/) |
| AWS Route53 | `route53` | [AWS Route53](https://aws.amazon.com/route53/) |
| DigitalOcean | `digitalocean` | [DO API](https://docs.digitalocean.com/reference/api/) |
| Namecheap | `namecheap` | [Namecheap API](https://www.namecheap.com/support/api/) |
| GoDaddy | `godaddy` | [GoDaddy API](https://developer.godaddy.com/) |

### Cloudflare Setup (Privacy-First)

1. **Create DNS-Only API Token** (minimal permissions):

   Go to: https://dash.cloudflare.com/profile/api-tokens

   ```
   Token Name: Server-Helper DNS-01

   Permissions:
     - Zone - DNS - Edit
     - Zone - Zone - Read

   Zone Resources:
     - Include - Specific zone - tennogen.ca
     - Include - Specific zone - publicpower.org
   ```

2. **Configure DNS Records as "DNS Only"** (gray cloud):

   ```
   Type   Name              Content          Proxy Status
   A      mealie            YOUR_IP          DNS Only (gray)
   A      @                 YOUR_IP          DNS Only (gray)
   ```

   **Important:** "DNS Only" means Cloudflare only provides DNS resolution.
   All traffic goes **directly to your server** - Cloudflare never sees it.

3. **Disable Privacy-Invasive Features**:

   In Cloudflare Dashboard:
   - Analytics → Disable Web Analytics
   - Speed → Disable Auto Minify
   - Caching → Disable all (not needed in DNS-only mode)
   - Security → Disable WAF (not needed in DNS-only mode)

---

## Internal Certificates (Smallstep CA)

### What is Smallstep CA?

Smallstep CA is a self-hosted certificate authority that:
- ✅ Issues certificates for internal domains (*.internal)
- ✅ Supports ACME protocol (works with Traefik)
- ✅ Auto-renewal (30-day certificates)
- ✅ 100% self-hosted (no external dependencies)
- ✅ Works offline

### Configuration

```yaml
step_ca:
  enabled: true
  name: "Server-Helper Internal CA"
  port: 9000

  # DNS names for the CA itself
  dns_names:
    - "step-ca"
    - "step-ca.internal"
    - "localhost"

  # Certificate durations
  default_cert_duration: "720h"    # 30 days
  max_cert_duration: "2160h"       # 90 days

  # Enable ACME for Traefik
  acme:
    enabled: true
```

### Client Setup

After deploying Smallstep CA, you need to install the root certificate on client devices (one-time setup).

#### Automatic Script

```bash
# On each client, run:
curl -sSL https://your-server:9000/install-root-ca.sh | bash
```

#### Manual Installation

**Linux (Debian/Ubuntu):**
```bash
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt
sudo cp step-ca-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**macOS:**
```bash
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain step-ca-root.crt
```

**Windows (PowerShell as Admin):**
```powershell
Invoke-WebRequest -Uri "https://your-server:9000/roots.pem" -OutFile "step-ca-root.crt" -SkipCertificateCheck
certutil -addstore -f "ROOT" step-ca-root.crt
```

---

## Service Routing

### Public Services

Services with `public: true` get Let's Encrypt certificates:

```yaml
services:
  mealie:
    enabled: true
    public: true
    domain: "mealie.tennogen.ca"
    port: 9925
    container: "mealie"

  vaultwarden:
    enabled: true
    public: true
    domain: "vault.tennogen.ca"
    port: 80
    container: "vaultwarden"
```

### Internal Services

Services with `public: false` (or undefined) get Smallstep CA certificates:

```yaml
services:
  grafana:
    enabled: true
    public: false  # Internal only
    port: 3000
    container: "grafana"
    # Accessible at: grafana.internal
```

Default internal services (always use Smallstep CA):
- `dockge.internal`
- `netdata.internal`
- `uptime-kuma.internal`
- `grafana.internal`
- `traefik.internal` (dashboard)

---

## Troubleshooting

### Let's Encrypt Issues

**Rate Limited:**
```yaml
# Use staging first for testing
certificates:
  public:
    staging: true  # Uses staging server
```

**DNS-01 Challenge Failing:**
```bash
# Check DNS propagation
dig TXT _acme-challenge.yourdomain.com

# Check Traefik logs
docker logs traefik 2>&1 | grep -i acme
```

### Smallstep CA Issues

**CA Not Starting:**
```bash
# Check CA logs
docker logs step-ca

# Verify password file
cat /opt/step-ca/secrets/password
```

**Certificate Not Trusted:**
```bash
# Verify root CA is installed
# Linux:
ls /usr/local/share/ca-certificates/ | grep step

# macOS:
security find-certificate -a -c "Server-Helper" /Library/Keychains/System.keychain
```

### Traefik Issues

**No Certificate Issued:**
```bash
# Check ACME storage
docker exec traefik cat /letsencrypt/acme.json | jq .

# Check resolver logs
docker logs traefik 2>&1 | grep -i "acme\|certificate"
```

---

## Security Best Practices

1. **Use strong passwords** for Smallstep CA:
   ```bash
   openssl rand -base64 32  # Generate password
   ```

2. **Rotate certificates regularly** (Smallstep does this automatically)

3. **Monitor certificate expiry** with Uptime Kuma:
   ```yaml
   uptime_kuma:
     monitors:
       - name: "SSL Certificate - mealie"
         type: "http"
         url: "https://mealie.tennogen.ca"
         check_certificate: true
   ```

4. **Backup Smallstep CA data**:
   ```yaml
   restic:
     backup_paths:
       - /opt/step-ca
   ```

5. **Use DNS-Only mode** for Cloudflare (no traffic proxying)

---

## Further Reading

- [Smallstep Documentation](https://smallstep.com/docs/)
- [Traefik ACME](https://doc.traefik.io/traefik/https/acme/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Cloudflare Privacy Guide](./cloudflare-privacy.md)
