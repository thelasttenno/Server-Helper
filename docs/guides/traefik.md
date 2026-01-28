# Traefik Reverse Proxy Guide

Traefik is Server Helper's reverse proxy solution, providing automatic HTTPS, load balancing, and routing for all your services.

---

## Overview

Traefik in Server Helper provides:

- **Automatic HTTPS** via Let's Encrypt (public) and Smallstep CA (internal)
- **DNS-01 Challenge** for privacy-focused certificate validation
- **Dynamic Routing** based on Docker labels
- **Security Headers** (HSTS, X-Frame-Options, etc.)
- **Dashboard** for monitoring and debugging

---

## Quick Start

### 1. Enable Traefik

```yaml
# group_vars/all.yml
reverse_proxy:
  enabled: true
  type: "traefik"
  domain: "example.com"
  email: "admin@example.com"
  force_https: true

  traefik:
    dashboard_enabled: true
    dashboard_port: 8080
    dashboard_insecure: false  # Require authentication
    log_level: "INFO"
```

### 2. Configure Certificates

```yaml
# group_vars/all.yml
certificates:
  public:
    enabled: true
    email: "admin@example.com"
    challenge: "dns-01"
    dns_provider: "cloudflare"
    domains:
      - "example.com"
      - "*.example.com"

step_ca:
  enabled: true
  port: 9000
```

### 3. Add Secrets

```yaml
# group_vars/vault.yml (encrypted)
vault_cloudflare_dns_api_token: "your-cloudflare-api-token"
vault_traefik_dashboard_auth: "admin:$$apr1$$hashed-password"
vault_step_ca_password: "strong-ca-password"
```

### 4. Deploy

```bash
ansible-playbook playbooks/setup-targets.yml --tags traefik,step-ca
```

---

## Architecture

```
Internet
    │
    ▼
┌───────────────────────────────────────────────────┐
│                    Traefik                         │
│              (Ports 80, 443, 8080)                │
│                                                    │
│  Entrypoints:                                      │
│    - web (80) ──► redirect to websecure           │
│    - websecure (443) ──► HTTPS with TLS           │
│                                                    │
│  Certificate Resolvers:                            │
│    - letsencrypt ──► Public domains               │
│    - step-ca ──► Internal domains                 │
│                                                    │
│  Middlewares:                                      │
│    - security-headers                             │
│    - rate-limit                                    │
│    - internal-only                                 │
│    - compress                                      │
└───────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────┐
│  PUBLIC SERVICE │    │ INTERNAL SERVICE│
│                 │    │                 │
│ mealie.         │    │ grafana.        │
│ example.com     │    │ internal        │
│                 │    │                 │
│ Let's Encrypt   │    │ Smallstep CA    │
│ Certificate     │    │ Certificate     │
└─────────────────┘    └─────────────────┘
```

---

## Configuration

### Reverse Proxy Settings

```yaml
reverse_proxy:
  enabled: true
  type: "traefik"

  # Domain configuration
  domain: "example.com"
  email: "admin@example.com"

  # HTTPS settings
  force_https: true
  ssl_enabled: true

  # Traefik-specific settings
  traefik:
    dashboard_enabled: true
    dashboard_port: 8080
    dashboard_insecure: false
    log_level: "INFO"  # DEBUG, INFO, WARN, ERROR

    entrypoints:
      - name: "web"
        port: 80
        redirect_to_https: true
      - name: "websecure"
        port: 443
```

### Service Routing

Define services with automatic certificate selection:

```yaml
services:
  # Public service (Let's Encrypt certificate)
  mealie:
    enabled: true
    public: true
    domain: "mealie.example.com"
    port: 9925
    container: "mealie"
    wildcard: false
    rate_limit: true
    compress: true
    health_check: true
    health_check_path: "/health"

  # Internal service (Smallstep CA certificate)
  grafana:
    enabled: true
    public: false
    port: 3000
    container: "grafana"
    # Accessible at: grafana.internal
```

---

## Certificate Resolvers

### Let's Encrypt (Public Domains)

```yaml
certificates:
  public:
    enabled: true
    email: "admin@example.com"
    challenge: "dns-01"  # dns-01, tls-alpn-01, http-01
    dns_provider: "cloudflare"
    staging: false  # Use true for testing
    domains:
      - "example.com"
      - "*.example.com"
```

**Supported DNS Providers:**

| Provider | Config Value | Vault Variable |
|----------|--------------|----------------|
| Cloudflare | `cloudflare` | `vault_cloudflare_dns_api_token` |
| AWS Route53 | `route53` | `vault_aws_access_key_id`, `vault_aws_secret_access_key` |
| DigitalOcean | `digitalocean` | `vault_digitalocean_api_token` |
| Namecheap | `namecheap` | `vault_namecheap_api_user`, `vault_namecheap_api_key` |
| GoDaddy | `godaddy` | `vault_godaddy_api_key`, `vault_godaddy_api_secret` |

### Smallstep CA (Internal Domains)

```yaml
step_ca:
  enabled: true
  name: "Server-Helper Internal CA"
  port: 9000

  dns_names:
    - "step-ca"
    - "step-ca.internal"
    - "localhost"

  default_cert_duration: "720h"  # 30 days
  max_cert_duration: "2160h"     # 90 days
```

---

## Middlewares

### Security Headers

Applied to all routes by default:

```yaml
# Automatically configured
- HSTS (31536000 seconds)
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin
```

### Rate Limiting

```yaml
services:
  api:
    enabled: true
    public: true
    domain: "api.example.com"
    port: 3000
    rate_limit: true  # Enables rate limiting
```

### Internal Only Access

Services with `public: false` automatically get internal-only middleware:

```yaml
# Allows only:
# - 127.0.0.1/32
# - 10.0.0.0/8
# - 172.16.0.0/12
# - 192.168.0.0/16
```

---

## Dashboard

### Enable Dashboard

```yaml
reverse_proxy:
  traefik:
    dashboard_enabled: true
    dashboard_port: 8080
    dashboard_insecure: false  # Require authentication
```

### Generate Dashboard Password

```bash
# Generate htpasswd hash
htpasswd -nb admin your-password

# Or with sed escaping for Docker
echo $(htpasswd -nb admin your-password) | sed -e s/\\$/\\$\\$/g
```

Add to vault:

```yaml
vault_traefik_dashboard_auth: "admin:$$apr1$$xyz123$$hashedpassword"
```

### Access Dashboard

```bash
# Via port (if enabled)
http://your-server:8080/dashboard/

# Via internal domain (with Smallstep CA)
https://traefik.internal/dashboard/
```

---

## Docker Labels

Traefik uses Docker labels for configuration. Server Helper generates these automatically, but you can add custom services:

### Public Service Example

```yaml
# docker-compose.yml
services:
  myapp:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"
    networks:
      - proxy
```

### Internal Service Example

```yaml
services:
  internal-tool:
    image: internal-tool:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.internal-tool.rule=Host(`tool.internal`)"
      - "traefik.http.routers.internal-tool.entrypoints=websecure"
      - "traefik.http.routers.internal-tool.tls.certresolver=step-ca"
      - "traefik.http.routers.internal-tool.middlewares=internal-only"
      - "traefik.http.services.internal-tool.loadbalancer.server.port=8080"
    networks:
      - proxy
```

---

## Troubleshooting

### Check Traefik Logs

```bash
# View all logs
docker logs traefik

# Follow logs
docker logs -f traefik

# Filter for errors
docker logs traefik 2>&1 | grep -i error

# Filter for certificate issues
docker logs traefik 2>&1 | grep -i "acme\|certificate"
```

### Check Certificate Status

```bash
# View Let's Encrypt certificates
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates'

# View Smallstep CA certificates
docker exec traefik cat /letsencrypt/step-ca-acme.json | jq .

# Check certificate for specific domain
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Common Issues

**Certificate not issuing:**

1. Check DNS is pointing to your server
2. Verify API token permissions
3. Check Traefik logs for ACME errors
4. Try staging mode first to avoid rate limits

**Dashboard not accessible:**

1. Check firewall allows port 8080
2. Verify dashboard_enabled is true
3. Check authentication credentials

**Service not routing:**

1. Verify service is on the `proxy` network
2. Check Docker labels are correct
3. Verify container is running

---

## Security Best Practices

1. **Use DNS-01 challenge** for privacy (no port exposure needed)
2. **Enable dashboard authentication** (never use insecure mode in production)
3. **Use internal-only middleware** for private services
4. **Enable rate limiting** for public APIs
5. **Keep Traefik updated** for security patches
6. **Monitor access logs** for suspicious activity

---

## Further Reading

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certificate Management Guide](certificates.md)
- [Cloudflare Privacy Guide](cloudflare-privacy.md)
