# Automated Remediation System

Automated failure handling and self-healing capabilities for Server Helper.

## Overview

The automated remediation system monitors your infrastructure and automatically responds to common failure scenarios:

- **Service failures** → Automatic container/service restart
- **Disk space alerts** → Automated cleanup procedures
- **Certificate expiration** → Automatic renewal
- **Resource exhaustion** → Health checks and notifications

## Architecture

```
Monitoring Layer          Trigger Layer              Remediation Layer
┌─────────────┐          ┌──────────────┐           ┌────────────────┐
│ Netdata     │─alerts─→ │   Webhook    │─triggers─→│  Remediation   │
│ Uptime Kuma │          │   Handler    │           │   Playbook     │
│ Prometheus  │          │  (port 9090) │           │                │
└─────────────┘          └──────────────┘           └────────────────┘
                                │                            │
                                │                            ▼
                                │                    ┌──────────────┐
                                └──────────────────→ │ Trigger      │
                                                     │ Scripts      │
                                                     └──────────────┘
```

## Automated Scenarios

### 1. Service Auto-Restart

**Trigger:** Service health check fails
**Detection:** Uptime Kuma HTTP monitors, Netdata alarms, Prometheus alerts
**Action:** Automatically restart the failed service/container

#### Example Flow

```bash
# Netdata detects container is down
→ Webhook sent to remediation handler
→ Handler calls /usr/local/bin/trigger-service-restart.sh
→ Ansible remediation playbook runs:
  - Detects failed Docker containers
  - Restarts containers automatically
  - Checks systemd service status
  - Restarts failed services
→ Sends success/failure notification to Uptime Kuma
```

#### Systemd Auto-Restart

All critical services are configured with automatic restart policies:

```systemd
[Service]
Restart=on-failure
RestartSec=10
StartLimitInterval=100
StartLimitBurst=5
```

**Configuration:** [docker-auto-restart.conf.j2](../roles/monitoring/templates/docker-auto-restart.conf.j2)

### 2. Disk Space Cleanup

**Trigger:** Disk usage exceeds 80% (warning) or 90% (critical)
**Detection:** Netdata disk alarms, Prometheus node_exporter
**Action:** Automated cleanup procedures

#### Cleanup Actions

1. **Docker cleanup** (prune unused resources)
   ```bash
   docker system prune -f
   docker image prune -a --filter "until=720h" -f
   ```

2. **Package manager cache**
   ```bash
   apt autoclean && apt autoremove
   ```

3. **Old log files** (>30 days)
   ```bash
   find /var/log -name "*.log" -mtime +30 -delete
   ```

4. **Systemd journal** (keep last 7 days)
   ```bash
   journalctl --vacuum-time=7d
   ```

5. **Temp files** (>10 days)
   ```bash
   find /tmp -type f -atime +10 -delete
   ```

#### Example Flow

```bash
# Disk usage reaches 82%
→ Netdata alarm triggers
→ Webhook: http://localhost:9090?action=disk_cleanup&severity=warning
→ Handler calls /usr/local/bin/trigger-disk-cleanup.sh
→ Ansible remediation playbook runs cleanup tasks
→ Reports freed space to Uptime Kuma
```

### 3. Certificate Auto-Renewal

**Trigger:** Certificate expiring in < 10 days
**Detection:** Prometheus SSL exporter, manual cert checks
**Action:** Automatic certificate renewal using certbot

#### Example Flow

```bash
# Certificate check detects expiration < 10 days
→ Scheduled daily check or Prometheus alert
→ Webhook: http://localhost:9090?action=cert_renewal
→ Handler calls /usr/local/bin/trigger-cert-renewal.sh
→ Ansible remediation playbook:
  - Finds expiring certificates
  - Runs certbot renew
  - Reloads affected services (nginx, traefik, etc.)
→ Sends renewal status to Uptime Kuma
```

## Configuration

### Enable Auto-Remediation

Add to [group_vars/all.yml](../group_vars/all.example.yml):

```yaml
monitoring:
  # Enable automated remediation
  auto_remediation:
    enabled: true

  # Webhook handler port
  remediation_webhook_port: 9090

  # Uptime Kuma push URLs for notifications
  uptime_kuma_push_url: "http://localhost:3001/api/push/REMEDIATION123"
  uptime_kuma_critical_key: "CRITICAL123"
  uptime_kuma_service_key: "SERVICE123"
  uptime_kuma_disk_key: "DISK123"
  uptime_kuma_cert_key: "CERT123"

  # Netdata alarm integration
  netdata:
    enabled: true
    port: 19999
    alarms:
      enabled: true
      cpu_warning: 80
      cpu_critical: 95
      ram_warning: 80
      ram_critical: 95
      disk_warning: 80
      disk_critical: 90
```

### Setup Uptime Kuma Monitors

1. **Access Uptime Kuma** at `http://your-server:3001`

2. **Create Push Monitors** for remediation tracking:
   - System Health Check (every 15 minutes)
   - Disk Space Monitor (every 5 minutes)
   - Certificate Monitor (daily)
   - Backup Status (after each backup)

3. **Configure HTTP Monitors** for services:
   - Netdata: `http://localhost:19999/api/v1/info`
   - Dockge: `http://localhost:5001`
   - Docker containers (individual endpoints)

4. **Set up Webhooks** in monitor settings:
   - On failure → Trigger remediation webhook
   - On recovery → Send notification

**Helper script:** `/usr/local/bin/configure-uptime-kuma-monitors.sh`

**Configuration template:** `/root/uptime-kuma-monitors.json`

### Prometheus Alerting (Optional)

If using Prometheus + Alertmanager:

```yaml
# Add to prometheus.yml
rule_files:
  - '/etc/prometheus/alerts/*.yml'

# Alertmanager config
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - localhost:9093
```

**Alert rules:** [prometheus-alerts.yml.j2](../roles/monitoring/templates/prometheus-alerts.yml.j2)
**Alertmanager config:** [alertmanager-config.yml.j2](../roles/monitoring/templates/alertmanager-config.yml.j2)

## Manual Triggers

You can manually trigger remediation actions:

### Service Restart
```bash
# Restart specific service
/usr/local/bin/trigger-service-restart.sh "service-name" "critical"

# Or via Ansible
ansible-playbook /opt/ansible/playbooks/remediation.yml \
  -e "action=service_restart" \
  -e "service=docker"
```

### Disk Cleanup
```bash
# Trigger disk cleanup
/usr/local/bin/trigger-disk-cleanup.sh "warning"

# Or via Ansible
ansible-playbook /opt/ansible/playbooks/remediation.yml \
  -e "action=disk_cleanup"
```

### Certificate Renewal
```bash
# Renew certificates
/usr/local/bin/trigger-cert-renewal.sh

# Or via Ansible
ansible-playbook /opt/ansible/playbooks/remediation.yml \
  -e "action=cert_renewal"
```

### Health Check
```bash
# Run comprehensive health check
ansible-playbook /opt/ansible/playbooks/remediation.yml \
  -e "action=health_check"
```

## Webhook API

The remediation webhook handler accepts HTTP GET requests:

```bash
# Service restart
curl "http://localhost:9090?action=service_restart&service=docker&severity=critical"

# Disk cleanup
curl "http://localhost:9090?action=disk_cleanup&severity=warning"

# Certificate renewal
curl "http://localhost:9090?action=cert_renewal"

# Health check
curl "http://localhost:9090?action=health_check"
```

**Response format:**
```json
{
  "status": "accepted",
  "action": "service_restart"
}
```

## Monitoring & Logs

### Log Files

- **Remediation logs:** `/var/log/auto-remediation.log`
- **Webhook handler:** `/var/log/remediation-webhook.log`
- **System journal:** `journalctl -u remediation-webhook`

### View Logs

```bash
# Tail remediation logs
tail -f /var/log/auto-remediation.log

# View recent webhook activity
tail -f /var/log/remediation-webhook.log

# Check systemd service status
systemctl status remediation-webhook

# View all remediation activity
journalctl -u remediation-webhook -f
```

### Log Rotation

Logs are automatically rotated daily and compressed:

- **Retention:** 14 days
- **Compression:** gzip
- **Config:** `/etc/logrotate.d/remediation`

## Scheduled Tasks

### Automated Health Checks

Runs every 15 minutes via cron:

```cron
*/15 * * * * /usr/local/bin/ansible-playbook /opt/ansible/playbooks/remediation.yml -e 'action=health_check' >> /var/log/auto-remediation.log 2>&1
```

### Certificate Renewal Checks

Daily certificate expiration check:

```cron
0 2 * * * /usr/local/bin/trigger-cert-renewal.sh >> /var/log/auto-remediation.log 2>&1
```

## Testing

### Test Webhook Handler

```bash
# Check if webhook service is running
systemctl status remediation-webhook

# Test webhook endpoint
curl "http://localhost:9090?action=health_check"

# Verify response
echo $?  # Should return 0
```

### Test Service Restart

```bash
# Stop a container
docker stop netdata

# Wait for detection (up to 2 minutes)
# Check logs for auto-restart
tail -f /var/log/auto-remediation.log

# Verify container restarted
docker ps | grep netdata
```

### Test Disk Cleanup

```bash
# Manually trigger cleanup
/usr/local/bin/trigger-disk-cleanup.sh "warning"

# Check freed space
df -h /
```

### Test Certificate Renewal

```bash
# Dry run certificate renewal
certbot renew --dry-run

# Trigger renewal check
/usr/local/bin/trigger-cert-renewal.sh

# Check logs
tail -f /var/log/auto-remediation.log
```

## Troubleshooting

### Webhook Handler Not Running

```bash
# Check service status
systemctl status remediation-webhook

# View recent errors
journalctl -u remediation-webhook -n 50

# Restart service
systemctl restart remediation-webhook
```

### Remediation Not Triggering

1. **Check webhook handler logs:**
   ```bash
   tail -f /var/log/remediation-webhook.log
   ```

2. **Verify Uptime Kuma webhooks:**
   - Check monitor settings
   - Ensure webhook URL is correct
   - Test webhook manually with curl

3. **Check script permissions:**
   ```bash
   ls -la /usr/local/bin/trigger-*.sh
   # Should be 0755 (rwxr-xr-x)
   ```

4. **Test scripts manually:**
   ```bash
   /usr/local/bin/trigger-service-restart.sh "test" "warning"
   ```

### Disk Cleanup Not Freeing Space

```bash
# Check what's using disk space
du -sh /* | sort -h

# Check Docker disk usage
docker system df

# Manual comprehensive cleanup
docker system prune -a --volumes -f
```

## Security Considerations

1. **Webhook port (9090)** is localhost-only by default
2. **No authentication** on webhook - bind to localhost only
3. **Scripts run as root** - review templates before deployment
4. **Log files** may contain sensitive information - restrict access

## Best Practices

1. **Monitor the monitors** - Ensure Uptime Kuma itself is healthy
2. **Test remediation** - Regularly test failure scenarios
3. **Review logs** - Check `/var/log/auto-remediation.log` weekly
4. **Adjust thresholds** - Tune alert thresholds based on your workload
5. **Backup before cleanup** - Automated cleanup runs before backups
6. **Certificate monitoring** - Use multiple methods (Prometheus + cron)

## Related Documentation

- [Monitoring Setup](./MONITORING.md)
- [Backup Configuration](./BACKUPS.md)
- [Security Hardening](./SECURITY.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

## Files Reference

### Playbooks
- [playbooks/remediation.yml](../playbooks/remediation.yml) - Main remediation playbook

### Role Tasks
- [roles/monitoring/tasks/remediation.yml](../roles/monitoring/tasks/remediation.yml) - Setup tasks

### Templates
- [remediation-webhook.sh.j2](../roles/monitoring/templates/remediation-webhook.sh.j2)
- [remediation-webhook.service.j2](../roles/monitoring/templates/remediation-webhook.service.j2)
- [trigger-service-restart.sh.j2](../roles/monitoring/templates/trigger-service-restart.sh.j2)
- [trigger-disk-cleanup.sh.j2](../roles/monitoring/templates/trigger-disk-cleanup.sh.j2)
- [trigger-cert-renewal.sh.j2](../roles/monitoring/templates/trigger-cert-renewal.sh.j2)
- [docker-auto-restart.conf.j2](../roles/monitoring/templates/docker-auto-restart.conf.j2)
- [prometheus-alerts.yml.j2](../roles/monitoring/templates/prometheus-alerts.yml.j2)
- [alertmanager-config.yml.j2](../roles/monitoring/templates/alertmanager-config.yml.j2)
