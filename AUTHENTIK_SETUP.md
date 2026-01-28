# Authentik SSO Integration

Authentik has been successfully integrated into Server Helper! This document explains how to enable and use it.

## What is Authentik?

Authentik is a modern, open-source identity provider that adds enterprise-grade authentication to your homelab:

- **Single Sign-On (SSO)**: One login for all your services
- **Multi-Factor Authentication (MFA)**: TOTP, WebAuthn/Passkeys support
- **OAuth2/OIDC/SAML**: Industry-standard protocols
- **User Management**: Centralized user accounts and groups
- **Reverse Proxy Auth**: Protect any web service

## Quick Start

### 1. Enable Authentik

Edit `group_vars/all.yml`:

```yaml
authentik:
  enabled: true
  http_port: 9000
  https_port: 9443
```

### 2. Configure Vault Secrets

Edit your vault file:

```bash
ansible-vault edit group_vars/vault.yml
```

Add the following (generate strong random values):

```yaml
vault_authentik_credentials:
  # Generate with: openssl rand -base64 60
  secret_key: "your-generated-secret-key-here"

  # Generate with: openssl rand -base64 32
  db_password: "your-strong-database-password"

  # Set during first login
  admin_email: "admin@example.com"
  admin_password: "change-me-on-first-login"

  # If using email features
  email_password: "your-smtp-password"
```

### 3. Configure Firewall (if using UFW)

The Authentik port (9000) is already added to the firewall configuration example. Make sure it's in your `group_vars/all.yml`:

```yaml
security:
  ufw_allowed_ports:
    - 22      # SSH
    - 5001    # Dockge
    - 19999   # Netdata
    - 3001    # Uptime Kuma
    - 9000    # Authentik
```

### 4. Deploy

Run the playbook:

```bash
ansible-playbook playbooks/setup-targets.yml --tags authentik
```

Or deploy everything:

```bash
ansible-playbook playbooks/setup-targets.yml
```

### 5. Initial Setup

1. Access Authentik at: `http://your-server-ip:9000/if/flow/initial-setup/`
2. Complete the setup wizard with your admin credentials
3. Access the admin interface at: `http://your-server-ip:9000/if/admin/`

## Optional: Email Configuration

To enable email features (password resets, invitations), edit `group_vars/all.yml`:

```yaml
authentik:
  enabled: true
  http_port: 9000
  https_port: 9443

  email:
    enabled: true
    host: "smtp.gmail.com"
    port: 587
    username: "your-email@gmail.com"
    from: "authentik@example.com"
    use_tls: true
```

Don't forget to set the email password in vault:

```yaml
vault_authentik_credentials:
  email_password: "your-app-specific-password"
```

## Service Integration Examples

### Grafana OAuth2

1. In Authentik, create an OAuth2 provider:
   - Name: Grafana
   - Client type: Confidential
   - Redirect URI: `http://your-grafana:3000/login/generic_oauth`

2. In Grafana (`grafana.ini`):
   ```ini
   [auth.generic_oauth]
   enabled = true
   name = Authentik
   client_id = <from-authentik>
   client_secret = <from-authentik>
   scopes = openid email profile
   auth_url = http://your-server:9000/application/o/authorize/
   token_url = http://your-server:9000/application/o/token/
   api_url = http://your-server:9000/application/o/userinfo/
   ```

### Reverse Proxy Authentication

For services without native OAuth support (Netdata, Uptime Kuma, etc.):

1. Create a Proxy Provider in Authentik
2. Configure your reverse proxy (Traefik/Nginx) to forward auth to Authentik
3. Authentik will handle authentication before passing requests to your service

## Files Created

The following files have been created for Authentik:

- `roles/authentik/tasks/main.yml` - Deployment tasks
- `roles/authentik/templates/docker-compose.authentik.yml.j2` - Docker compose template
- `roles/authentik/templates/authentik-setup-guide.md.j2` - Detailed setup guide
- `roles/authentik/defaults/main.yml` - Default variables
- `roles/authentik/handlers/main.yml` - Service handlers

## Documentation

After deployment, a comprehensive setup guide will be available on your server at:

```
/root/authentik-setup-guide.md
```

This guide includes:
- Step-by-step setup instructions
- OAuth2/OIDC configuration examples
- MFA/WebAuthn setup
- Service integration guides
- Backup and recovery procedures
- Troubleshooting tips

## Resources

- Official Documentation: https://goauthentik.io/docs/
- Integration Examples: https://goauthentik.io/integrations/
- Community: https://github.com/goauthentik/authentik/discussions

## Architecture

Authentik is deployed as a Dockge stack with the following components:

- **PostgreSQL**: Database for Authentik data
- **Redis**: Cache and message queue
- **Server**: Main Authentik web server
- **Worker**: Background task processor

All components run in Docker containers and are managed via Dockge.

## Resource Usage

- RAM: ~200-300MB (PostgreSQL + Redis + Authentik)
- Disk: ~500MB for images, variable for data
- Ports: 9000 (HTTP), 9443 (HTTPS - optional)

## Security Notes

1. **Secret Key**: Must be kept secure - used for encryption
2. **Database Password**: Should be strong and unique
3. **Admin Password**: Change after first login
4. **HTTPS**: Consider using reverse proxy with SSL/TLS
5. **Firewall**: Ensure port 9000 is only accessible from trusted networks

## Next Steps

1. Complete the initial setup wizard
2. Create your first application in Authentik
3. Integrate with existing services (Grafana, Netdata, etc.)
4. Enable MFA for enhanced security
5. Configure groups and permissions
6. Customize branding

Enjoy centralized authentication for your homelab! 🎉
