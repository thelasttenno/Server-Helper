# Smallstep CA Guide

Smallstep CA is a self-hosted certificate authority that provides ACME-compatible certificates for internal services. It enables HTTPS for your internal domains without relying on external certificate providers.

---

## Overview

Smallstep CA in Server Helper provides:

- **Self-Hosted CA** - 100% under your control
- **ACME Protocol** - Native Traefik integration
- **Automatic Renewal** - 30-day certificates, auto-renewed
- **No Internet Required** - Works offline/air-gapped
- **Internal Domains** - Secure `*.internal` services

---

## Quick Start

### 1. Enable Smallstep CA

```yaml
# group_vars/all.yml
step_ca:
  enabled: true
  name: "Server-Helper Internal CA"
  port: 9000

  dns_names:
    - "step-ca"
    - "step-ca.internal"
    - "localhost"

  default_cert_duration: "720h"    # 30 days
  max_cert_duration: "2160h"       # 90 days

  acme:
    enabled: true
```

### 2. Add Secrets

```yaml
# group_vars/vault.yml (encrypted)
vault_step_ca_password: "generate-with-openssl-rand-base64-32"
vault_step_ca_provisioner_password: "another-strong-password"
```

### 3. Deploy

```bash
ansible-playbook playbooks/setup-targets.yml --tags step-ca
```

### 4. Install Root CA on Clients

```bash
# Run the install script
curl -sSL https://your-server:9000/install-root-ca.sh | bash
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Your Infrastructure                           │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │  Smallstep   │◄────────┤   Traefik    │                     │
│  │     CA       │  ACME   │ (requests    │                     │
│  │              │ Protocol│  certs)      │                     │
│  └──────────────┘         └──────────────┘                     │
│         │                                                        │
│         │ Issues certificates for:                               │
│         │                                                        │
│         ├──► grafana.internal                                   │
│         ├──► netdata.internal                                   │
│         ├──► dockge.internal                                    │
│         ├──► uptime-kuma.internal                               │
│         └──► *.internal (any internal service)                  │
│                                                                  │
│  Client Devices:                                                │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                          │
│  │ Laptop  │ │ Desktop │ │  Phone  │                          │
│  │         │ │         │ │         │                          │
│  │ Root CA │ │ Root CA │ │ Root CA │ ◄── One-time install     │
│  │installed│ │installed│ │installed│                          │
│  └─────────┘ └─────────┘ └─────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Configuration

### Basic Configuration

```yaml
step_ca:
  enabled: true

  # CA identity
  name: "Server-Helper Internal CA"
  dns_names:
    - "step-ca"
    - "step-ca.internal"
    - "localhost"

  # Network
  port: 9000

  # Certificate settings
  provisioner_name: "admin"
  default_cert_duration: "720h"    # 30 days
  max_cert_duration: "2160h"       # 90 days
  min_cert_duration: "5m"

  # ACME configuration
  acme:
    enabled: true
    require_eab: false

  # Data persistence
  data_dir: "/opt/step-ca"

  # Resource limits
  resources:
    memory: "128M"
    cpu: "0.5"
```

### Advanced Configuration

```yaml
step_ca:
  enabled: true

  # SSH certificate support (optional)
  ssh:
    enabled: true

  # Custom provisioner settings
  provisioner_name: "acme-provisioner"

  # Shorter certificates for high-security environments
  default_cert_duration: "24h"
  max_cert_duration: "168h"  # 7 days
```

---

## Client Installation

After deploying Smallstep CA, you must install the root certificate on each client device to avoid browser warnings.

### Automatic Installation Script

```bash
# Download and run the install script
curl -sSL https://your-server:9000/install-root-ca.sh | bash
```

### Manual Installation

#### Linux (Debian/Ubuntu)

```bash
# Download certificate
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt

# Install to system trust store
sudo cp step-ca-root.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

# Verify
ls /etc/ssl/certs/ | grep step
```

#### Linux (RHEL/CentOS/Fedora)

```bash
# Download certificate
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt

# Install to system trust store
sudo cp step-ca-root.crt /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust

# Verify
trust list | grep "Server-Helper"
```

#### macOS

```bash
# Download certificate
curl -k https://your-server:9000/roots.pem -o step-ca-root.crt

# Install to System Keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain step-ca-root.crt

# Verify (open Keychain Access and search for "Server-Helper")
```

#### Windows (PowerShell as Administrator)

```powershell
# Download certificate
Invoke-WebRequest -Uri "https://your-server:9000/roots.pem" -OutFile "step-ca-root.crt" -SkipCertificateCheck

# Install to Trusted Root store
certutil -addstore -f "ROOT" step-ca-root.crt

# Verify
certutil -store ROOT | findstr "Server-Helper"
```

#### iOS

1. Download the certificate from `https://your-server:9000/roots.pem`
2. Open the downloaded file
3. Go to Settings → General → VPN & Device Management
4. Tap on the certificate profile and install it
5. Go to Settings → General → About → Certificate Trust Settings
6. Enable full trust for the certificate

#### Android

1. Download the certificate from `https://your-server:9000/roots.pem`
2. Go to Settings → Security → Encryption & credentials
3. Tap "Install a certificate" → "CA certificate"
4. Select the downloaded file
5. Confirm the installation

---

## Traefik Integration

Smallstep CA integrates with Traefik via the ACME protocol:

```yaml
# Traefik automatically requests certificates from Smallstep CA
# for any service with public: false

services:
  grafana:
    enabled: true
    public: false  # Uses Smallstep CA
    port: 3000
    container: "grafana"
    # Accessible at: grafana.internal
```

### How It Works

1. Traefik detects a new internal service
2. Traefik requests a certificate from Smallstep CA via ACME
3. Smallstep CA validates and issues the certificate
4. Traefik serves HTTPS with the new certificate
5. Certificate auto-renews before expiry

---

## Operations

### Check CA Status

```bash
# Check CA health
curl -k https://localhost:9000/health

# View CA logs
docker logs step-ca

# Check CA fingerprint
docker exec step-ca step certificate fingerprint /home/step/certs/root_ca.crt
```

### Get Root Certificate

```bash
# Download root CA certificate
curl -k https://your-server:9000/roots.pem -o root_ca.crt

# View certificate details
openssl x509 -in root_ca.crt -text -noout
```

### Manual Certificate Issuance

For non-Traefik services:

```bash
# Enter the CA container
docker exec -it step-ca sh

# Issue a certificate
step ca certificate myservice.internal myservice.crt myservice.key

# Exit container
exit
```

### Revoke a Certificate

```bash
# Enter the CA container
docker exec -it step-ca sh

# Revoke by serial number
step ca revoke <serial-number>

# Or revoke by certificate file
step ca revoke --cert myservice.crt --key myservice.key

exit
```

---

## Backup and Recovery

### Backup CA Data

The CA data directory contains critical files:

```yaml
restic:
  backup_paths:
    - /opt/step-ca  # Include CA data in backups
```

### Manual Backup

```bash
# Backup CA data
sudo tar -czvf step-ca-backup.tar.gz /opt/step-ca

# Store securely (encrypted, off-site)
```

### Recovery

```bash
# Stop CA
docker stop step-ca

# Restore data
sudo tar -xzvf step-ca-backup.tar.gz -C /

# Restart CA
docker start step-ca
```

---

## Security Best Practices

1. **Strong Passwords** - Use `openssl rand -base64 32` for CA passwords
2. **Secure Backups** - Encrypt and store CA backups securely
3. **Limit Access** - Only allow internal network access to port 9000
4. **Short Cert Lifetimes** - Default 30 days provides good security
5. **Monitor Logs** - Watch for unauthorized certificate requests
6. **Rotate Secrets** - Periodically rotate CA passwords

### Firewall Configuration

```yaml
# Only allow internal access to Smallstep CA
security:
  ufw_allowed_ports:
    - 9000  # Only if needed externally
```

For maximum security, keep port 9000 internal-only:

```bash
# Allow only from internal networks
sudo ufw allow from 192.168.0.0/16 to any port 9000
sudo ufw allow from 10.0.0.0/8 to any port 9000
```

---

## Troubleshooting

### CA Not Starting

```bash
# Check container status
docker ps -a | grep step-ca

# Check logs
docker logs step-ca

# Verify password file exists
ls -la /opt/step-ca/secrets/password
```

### Certificate Not Trusted

1. Verify root CA is installed on client
2. Check if browser/app respects system trust store
3. Try restarting the browser/application
4. Verify certificate chain is complete

```bash
# Test certificate chain
echo | openssl s_client -connect your-service.internal:443 2>/dev/null | openssl x509 -noout -issuer -subject
```

### ACME Errors

```bash
# Check Traefik logs
docker logs traefik 2>&1 | grep -i step-ca

# Verify ACME endpoint is accessible
curl -k https://localhost:9000/acme/acme/directory

# Check CA is running
curl -k https://localhost:9000/health
```

### Certificate Renewal Failures

```bash
# Check Traefik certificate storage
docker exec traefik cat /letsencrypt/step-ca-acme.json | jq .

# Force certificate refresh
docker restart traefik
```

---

## Comparison: Smallstep CA vs Let's Encrypt

| Feature | Smallstep CA | Let's Encrypt |
|---------|--------------|---------------|
| **Hosting** | Self-hosted | External service |
| **Internet Required** | No | Yes |
| **Domains** | Any (including internal) | Public domains only |
| **Browser Trust** | After root CA install | Automatic |
| **Privacy** | Complete | Good (ACME logs) |
| **Wildcard Certs** | Yes | Yes (DNS-01 only) |
| **Cost** | Free | Free |
| **Maintenance** | You manage | They manage |

**Use Smallstep CA for:**
- Internal services (`*.internal`)
- Air-gapped environments
- Complete privacy
- Custom certificate policies

**Use Let's Encrypt for:**
- Public websites
- Automatic browser trust
- Zero maintenance

---

## Further Reading

- [Smallstep Documentation](https://smallstep.com/docs/)
- [ACME Protocol](https://datatracker.ietf.org/doc/html/rfc8555)
- [Certificate Management Guide](certificates.md)
- [Traefik Guide](traefik.md)
