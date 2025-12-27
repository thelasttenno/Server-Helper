# Uptime Kuma Role

Configures Uptime Kuma monitoring and alerting platform with setup guidance.

## Features

- **Hybrid Monitoring**: Pull (HTTP/Ping) and Push (webhook) monitors
- **Setup Guide**: Comprehensive guide at `/root/uptime-kuma-setup-guide.md`
- **Helper Script**: Interactive monitor configuration
- **Multiple Notification Channels**: Email, Discord, Telegram, Slack, and more
- **Status Pages**: Public status page creation
- **Manual Configuration**: API requires initial admin account creation

## Requirements

- Docker installed
- Uptime Kuma container deployed via Dockge role

## Variables

```yaml
uptime_kuma:
  enabled: true
  port: 3001
  admin_username: "{{ vault_uptime_kuma_credentials.username }}"
  admin_password: "{{ vault_uptime_kuma_credentials.password }}"
```

## Initial Setup (Required)

### 1. Access UI
```
http://your-server:3001
```

### 2. Create Admin Account
Use credentials from vault:
- Username: (from `vault_uptime_kuma_credentials.username`)
- Password: (from `vault_uptime_kuma_credentials.password`)

**Change these after first login!**

### 3. Configure Monitors

#### Option A: Interactive Helper
```bash
sudo /usr/local/bin/configure-uptime-kuma-monitors.sh
```

#### Option B: Manual Setup
See `/root/uptime-kuma-setup-guide.md` for detailed instructions.

## Recommended Monitors

### Pull Monitors (HTTP/Ping)
- Netdata Health: `http://localhost:19999/api/v1/info`
- Dockge: `http://localhost:5001`
- Docker Daemon: `http://localhost:2375/_ping`
- NAS: Ping to NAS IP

### Push Monitors (Webhooks)
- System Health (5 min heartbeat)
- Backup Status (24 hour heartbeat)
- Security Scan (7 day heartbeat)
- Netdata CPU Alert (5 min heartbeat)
- Netdata RAM Alert (5 min heartbeat)
- Netdata Disk Alert (5 min heartbeat)
- Netdata Docker Alert (5 min heartbeat)

## Push URL Configuration

### 1. Create Push Monitor in UI
- Type: Push
- Name: System Health
- Heartbeat Interval: 5 minutes

### 2. Copy Webhook URL
Example: `http://localhost:3001/api/push/ABC123XYZ?status=up&msg=OK`

### 3. Add to Vault
```bash
ansible-vault edit group_vars/vault.yml
```

Add URLs:
```yaml
vault_uptime_kuma_push_urls:
  system: "http://localhost:3001/api/push/ABC123XYZ"
  backup: "http://localhost:3001/api/push/DEF456XYZ"
  security: "http://localhost:3001/api/push/GHI789XYZ"
```

### 4. Re-run Setup
```bash
ansible-playbook playbooks/setup.yml
```

## Notification Channels

### Email (SMTP)
1. Settings → Notifications
2. Setup Notification → Email (SMTP)
3. Configure with vault credentials

### Discord
1. Create webhook in Discord server
2. Settings → Notifications
3. Setup Notification → Discord
4. Paste webhook URL

### Telegram
1. Create bot with @BotFather
2. Get chat ID from @userinfobot
3. Settings → Notifications
4. Setup Notification → Telegram

## Status Pages

Create public status page:
1. Go to Status Pages
2. New Status Page
3. Add monitors to display
4. Customize theme
5. Share public URL

## Backup & Restore

### Backup
```bash
docker exec uptime-kuma cat /app/data/kuma.db > ~/uptime-kuma-backup.db
```

### Restore
```bash
docker exec -i uptime-kuma sh -c 'cat > /app/data/kuma.db' < ~/uptime-kuma-backup.db
docker restart uptime-kuma
```

## Security

1. **Change default credentials** immediately
2. **Enable 2FA** in Settings → Security
3. **Use HTTPS** with reverse proxy for external access
4. **Limit access** with firewall or VPN
5. **Regular backups** of database

## Troubleshooting

```bash
# Check container status
docker ps | grep uptime-kuma

# View logs
docker logs uptime-kuma

# Restart container
cd /opt/dockge/stacks/uptime-kuma
docker compose restart

# Reset admin password
docker exec -it uptime-kuma npm run reset-password

# Test push monitor
curl -fsS "YOUR_PUSH_URL?status=up&msg=test"
```

## API Access

Uptime Kuma has a REST API:
- **Docs**: http://localhost:3001/api-docs
- **Authentication**: Required (login first)

## Files Created

- `/root/uptime-kuma-setup-guide.md` - Comprehensive setup guide
- `/usr/local/bin/configure-uptime-kuma-monitors.sh` - Interactive helper

## Usage

Included automatically in `playbooks/setup.yml`.

Manual run:
```bash
ansible-playbook playbooks/setup.yml --tags uptime-kuma
```

## Additional Resources

- **Documentation**: https://github.com/louislam/uptime-kuma/wiki
- **Community**: https://github.com/louislam/uptime-kuma/discussions
- **Feature Requests**: https://github.com/louislam/uptime-kuma/issues

## Note

Uptime Kuma requires manual UI configuration for initial setup and monitor creation. The API does not support automated setup without authentication, which requires an initial admin account created via the web interface.

This is by design for security reasons.
