# Netdata Role

Configures Netdata monitoring with health alarms and Uptime Kuma integration.

## Features

- **Health Alarms**: CPU, RAM, Disk, Docker containers
- **Uptime Kuma Integration**: Push notifications for critical alerts
- **Auto-configuration**: Alarm thresholds from variables
- **Systemd Health Checks**: Regular health monitoring
- **Comprehensive Monitoring**:
  - CPU usage (10-minute average and immediate)
  - CPU iowait (disk bottleneck detection)
  - RAM usage (excluding cache/buffers)
  - Swap usage
  - OOM killer detection
  - Disk space usage
  - Disk inode usage
  - Disk read/write latency
  - Docker container health
  - Docker container CPU/RAM
  - Critical container monitoring (Dockge, Netdata, Uptime Kuma)

## Requirements

- Docker installed
- Netdata container deployed via Dockge role
- Uptime Kuma (optional, for push notifications)

## Variables

```yaml
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
    check_interval_minutes: 5
    
    uptime_kuma_urls:
      cpu: "{{ vault_uptime_kuma_push_urls.cpu }}"
      ram: "{{ vault_uptime_kuma_push_urls.ram }}"
      disk: "{{ vault_uptime_kuma_push_urls.disk }}"
      docker: "{{ vault_uptime_kuma_push_urls.docker }}"
```

## Alarm Files

- `health.d/cpu.conf` - CPU usage alarms
- `health.d/ram.conf` - RAM and swap alarms
- `health.d/disk.conf` - Disk space and I/O alarms
- `health.d/docker.conf` - Docker container alarms

## Notification Script

- `/usr/local/bin/netdata_notify_uptime_kuma.sh` - Sends alerts to Uptime Kuma

## Health Check

- Script: `/usr/local/bin/check_netdata_health.sh`
- Timer: `netdata-health-check.timer`
- Service: `netdata-health-check.service`
- Runs every 5 minutes (configurable)

## Usage

Included automatically in `playbooks/setup.yml`.

Manual run:
```bash
ansible-playbook playbooks/setup.yml --tags netdata
```

## Access Netdata

- **UI**: http://your-server:19999
- **Alarms**: Click "Alarms" tab in Netdata UI
- **API**: http://your-server:19999/api/v1/info

## Troubleshooting

```bash
# Check alarm configuration
docker exec netdata cat /etc/netdata/health.d/cpu.conf

# Check Netdata logs
docker logs netdata

# Test notification script
sudo /usr/local/bin/netdata_notify_uptime_kuma.sh

# Check health check timer
systemctl status netdata-health-check.timer
journalctl -u netdata-health-check -f
```

## Alarm Behavior

- **Warning**: Yellow indicator, down delay 15 minutes
- **Critical**: Red indicator, immediate notification
- **Clear**: Green indicator, alarm resolved

## Customization

Edit alarm thresholds in `group_vars/all.yml`:
```yaml
netdata:
  alarms:
    cpu_warning: 70    # Lower threshold
    cpu_critical: 90   # Less critical
```

Re-run setup to apply:
```bash
ansible-playbook playbooks/setup.yml --tags netdata
```
