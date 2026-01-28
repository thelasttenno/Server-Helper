# Automated Remediation - Quick Reference

## Quick Commands

### Manual Triggers

```bash
# Restart failed service
/usr/local/bin/trigger-service-restart.sh "docker" "critical"

# Clean up disk space
/usr/local/bin/trigger-disk-cleanup.sh "warning"

# Renew certificates
/usr/local/bin/trigger-cert-renewal.sh

# Run health check
ansible-playbook /opt/ansible/playbooks/remediation.yml -e "action=health_check"
```

### Check Status

```bash
# View remediation logs
tail -f /var/log/auto-remediation.log

# Check webhook service
systemctl status remediation-webhook

# View webhook logs
tail -f /var/log/remediation-webhook.log

# Check recent activity
journalctl -u remediation-webhook -f
```

### Webhook API

```bash
# Trigger via webhook
curl "http://localhost:9090?action=service_restart&service=docker&severity=critical"
curl "http://localhost:9090?action=disk_cleanup&severity=warning"
curl "http://localhost:9090?action=cert_renewal"
curl "http://localhost:9090?action=health_check"
```

## Configuration Files

| File | Purpose |
|------|---------|
| `/playbooks/remediation.yml` | Main remediation playbook |
| `/roles/monitoring/tasks/remediation.yml` | Setup tasks |
| `/etc/systemd/system/remediation-webhook.service` | Webhook service |
| `/usr/local/bin/trigger-*.sh` | Trigger scripts |
| `/var/log/auto-remediation.log` | Main log file |
| `/root/uptime-kuma-monitors.json` | Monitor configuration |

## Automated Actions

| Trigger | Detection | Action |
|---------|-----------|--------|
| Service fails | Uptime Kuma/Netdata | Auto-restart container/service |
| Disk > 80% | Netdata alarm | Docker prune, clean logs, remove old files |
| Disk > 90% | Netdata alarm | Aggressive cleanup + critical alert |
| Cert < 10 days | Daily check | Run certbot renew |

## Uptime Kuma Setup

1. **Access:** `http://your-server:3001`
2. **Create push monitors:**
   - System Health (15 min interval)
   - Disk Space (5 min interval)
   - Certificate Check (daily)
3. **Note push URLs** and add to `group_vars/all.yml`
4. **Configure webhooks** in monitor settings

## Troubleshooting

```bash
# Restart webhook service
systemctl restart remediation-webhook

# Test webhook
curl "http://localhost:9090?action=health_check"

# Check script permissions
ls -la /usr/local/bin/trigger-*.sh

# View systemd errors
journalctl -u remediation-webhook -n 50

# Manual cleanup test
docker system df  # Check disk usage
/usr/local/bin/trigger-disk-cleanup.sh "warning"
docker system df  # Verify freed space
```

## Log Rotation

- **Retention:** 14 days
- **Config:** `/etc/logrotate.d/remediation`
- **Logs rotated:** Daily, compressed with gzip

## Security Notes

- Webhook port 9090 is localhost-only
- No authentication (localhost binding provides security)
- Scripts run as root - review before deploying
- Restrict log file access (contains system info)

## See Also

- [Full Documentation](./AUTOMATED_REMEDIATION.md)
- [Monitoring Setup](./MONITORING.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
