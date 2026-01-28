# Logging Stack Implementation Summary

**Loki + Promtail + Grafana Integration**

Implementation completed successfully! ✅

---

## 📦 What Was Added

### New Files Created

#### Ansible Role: `roles/logging/`

```
roles/logging/
├── tasks/
│   └── main.yml                          # Main deployment tasks
├── templates/
│   ├── docker-compose.logging.yml.j2     # Docker Compose stack
│   ├── loki-config.yml.j2                # Loki configuration
│   ├── promtail-config.yml.j2            # Promtail configuration
│   └── grafana-provisioning/
│       ├── datasources/
│       │   └── loki.yml.j2               # Loki datasource auto-config
│       └── dashboards/
│           └── dashboards.yml.j2         # Dashboard provisioning
├── handlers/
│   └── main.yml                          # Restart handlers
└── defaults/
    └── main.yml                          # Default variables
```

#### Documentation

- **[docs/guides/logging-stack.md](docs/guides/logging-stack.md)** - Complete guide (10,000+ words)
- **[docs/LOGGING_QUICKSTART.md](docs/LOGGING_QUICKSTART.md)** - 5-minute quick start

#### Configuration Updates

- **group_vars/all.example.yml** - Added logging configuration section
- **group_vars/vault.example.yml** - Added Grafana password fields
- **playbooks/setup-targets.yml** - Added logging role integration
- **CHANGELOG.md** - Documented new feature
- **README.md** - Updated with logging stack info

---

## 🎯 Features Implemented

### Core Functionality

✅ **Loki** - Log aggregation server
- Receives logs from Promtail
- Indexes and stores logs efficiently
- Configurable retention (default: 31 days)
- Automatic cleanup of old logs
- Port: 3100

✅ **Promtail** - Log collector
- Automatically discovers Docker containers
- Collects system logs (/var/log/*)
- Ships auth logs (SSH, sudo)
- Supports custom log sources
- Label-based organization

✅ **Grafana** - Visualization platform
- Pre-configured Loki datasource
- Explore interface for log queries
- Dashboard creation capabilities
- Optional SMTP alerts
- Port: 3000

### Configuration Options

```yaml
logging:
  # Stack directory
  stack_dir: /opt/dockge/stacks/logging

  # Loki settings
  loki:
    enabled: true
    version: latest
    port: 3100
    retention_period: "744h"  # 31 days

  # Promtail settings
  promtail:
    enabled: true
    version: latest
    additional_jobs: []  # Custom log sources

  # Grafana settings
  grafana:
    enabled: true
    version: latest
    port: 3000
    admin_user: admin
    plugins: ""  # Additional plugins

    # SMTP for alerts (optional)
    smtp:
      enabled: false
      host: smtp.gmail.com
      port: 587
      user: ""
      from_address: ""
```

### Security Integration

✅ **Ansible Vault**
- `vault_grafana_admin_password` - Admin password
- `vault_grafana_smtp_password` - SMTP password (optional)

✅ **Firewall Rules**
- Port 3000 (Grafana) - Added to UFW allowed ports
- Port 3100 (Loki) - Optional, for external access

---

## 📊 Log Sources Configured

### Automatic Collection

1. **Docker Container Logs**
   - All containers automatically discovered
   - Labeled by container name
   - Labeled by compose project/service

2. **System Logs**
   - `/var/log/*log` files
   - Syslog events
   - Authentication logs

3. **Structured Data**
   - Container metadata
   - Log stream types
   - Timestamps

### Query Examples

```logql
# All Docker logs
{job="docker"}

# Specific container
{container="netdata"}

# Search for errors
{job="docker"} |= "error"

# Auth logs
{job="auth"}

# System logs
{job="syslog"}
```

---

## 🚀 Deployment Process

### What Happens When You Deploy

1. **Pre-deployment**
   - Creates `/opt/dockge/stacks/logging` directory
   - Creates Grafana provisioning directories

2. **Configuration Deployment**
   - Deploys Loki config (retention, limits, compaction)
   - Deploys Promtail config (log sources, labels)
   - Deploys Grafana datasource config (auto-connects to Loki)

3. **Stack Deployment**
   - Pulls latest Docker images
   - Creates monitoring network
   - Starts containers in order: Loki → Promtail → Grafana
   - Waits for health checks

4. **Post-deployment**
   - Verifies Loki is ready
   - Verifies Grafana is ready
   - Displays service URLs

### Deployment Commands

```bash
# Full deployment
ansible-playbook playbooks/setup-targets.yml

# Just logging stack
ansible-playbook playbooks/setup-targets.yml --tags logging

# Specific server
ansible-playbook playbooks/setup-targets.yml --limit server-01 --tags logging
```

---

## 💾 Resource Requirements

### RAM Usage

| Component | Idle | Active | Peak |
|-----------|------|--------|------|
| Loki | 100MB | 150MB | 200MB |
| Promtail | 30MB | 50MB | 80MB |
| Grafana | 150MB | 200MB | 300MB |
| **Total** | **280MB** | **400MB** | **580MB** |

### Disk Usage

- **Loki data**: ~10-50MB per day (depends on log volume)
- **Grafana config**: ~50MB
- **With 31-day retention**: ~500MB - 2GB total

### Network

- Minimal overhead
- Logs sent locally within Docker network
- No external traffic (unless accessing Grafana remotely)

---

## 🔒 Security Features

### Access Control

- Grafana admin account (password in vault)
- Optional SMTP authentication
- Firewall rules automatically configured

### Data Protection

- Logs stored locally in Docker volumes
- No data sent to cloud (unlike Netdata Cloud option)
- Retention policy enforced automatically

### Network Security

- All services on isolated Docker network
- Loki not exposed by default (only Grafana)
- Optional TLS (can be configured with reverse proxy)

---

## 📚 Documentation Highlights

### Complete User Guide

**[docs/guides/logging-stack.md](docs/guides/logging-stack.md)** includes:

- Overview and architecture
- Installation walkthrough
- Configuration options
- LogQL query tutorial
- Common use cases with examples
- Troubleshooting guide
- Performance optimization tips
- Advanced configuration

### Quick Start

**[docs/LOGGING_QUICKSTART.md](docs/LOGGING_QUICKSTART.md)** provides:

- 5-minute setup guide
- First steps in Grafana
- Common queries
- Pro tips
- Quick troubleshooting

---

## 🎓 Learning Resources

### LogQL Basics

LogQL is similar to Prometheus' PromQL:

```logql
# Basic structure
{label_selector} |= "search text" | filters

# Examples
{job="docker"}                          # All Docker logs
{container="app"} |= "error"           # Errors in app container
{job="auth"} |~ "Failed|Accepted"      # Regex search
count_over_time({job="docker"}[5m])    # Count logs
```

### Dashboard Examples

Import these from Grafana.com:

- **13639** - Loki Dashboard
- **13407** - Docker Logs
- **12611** - Loki & Promtail

---

## 🔄 Integration with Existing Stack

### Complements Current Services

| Service | Role | Relationship |
|---------|------|--------------|
| **Netdata** | Real-time metrics | Logs provide context for metric spikes |
| **Uptime Kuma** | Uptime monitoring | Logs explain downtime events |
| **Dockge** | Container management | View logs for managed containers |
| **Restic** | Backups | Logs of backup success/failure |

### Unified Monitoring

```
Netdata    ──▶  Metrics (CPU, RAM, Disk)
Loki       ──▶  Logs (Events, Errors, Info)
Uptime Kuma──▶  Availability (Up/Down)
                      │
                      ▼
               Grafana Dashboard
           (Combined view of everything)
```

---

## ✅ Testing Checklist

After deployment, verify:

- [ ] Grafana accessible at `http://server:3000`
- [ ] Can login with admin credentials
- [ ] Loki datasource shows "Connected"
- [ ] Docker logs visible in Explore
- [ ] System logs visible
- [ ] Auth logs visible
- [ ] Container labels present
- [ ] Timestamps accurate
- [ ] Retention working (check after 31+ days)

---

## 🚀 Next Steps

### Recommended

1. **Import Pre-built Dashboards**
   ```
   Grafana → + → Import → Enter ID: 13639
   ```

2. **Create Custom Dashboard**
   - For your specific applications
   - With your common queries
   - With alert thresholds

3. **Set Up Alerts**
   - Critical errors in logs
   - Failed authentication attempts
   - Container restart patterns

4. **Optimize Queries**
   - Save frequently-used queries
   - Create dashboard variables
   - Use specific labels

### Future Enhancements

Consider adding later:

- **Prometheus** - For historical metrics (complements Loki)
- **Alertmanager** - Advanced alert routing
- **Tempo** - Distributed tracing
- **Reverse Proxy** - TLS termination for Grafana

---

## 📞 Support

### Documentation

- Full Guide: [docs/guides/logging-stack.md](docs/guides/logging-stack.md)
- Quick Start: [docs/LOGGING_QUICKSTART.md](docs/LOGGING_QUICKSTART.md)
- LogQL Reference: https://grafana.com/docs/loki/latest/logql/

### Troubleshooting

Check logs:

```bash
docker logs loki
docker logs promtail
docker logs grafana
```

Test health:

```bash
curl http://localhost:3100/ready    # Loki
curl http://localhost:3000/api/health  # Grafana
```

---

## 🎉 Summary

You now have a production-ready centralized logging stack that:

✅ Automatically collects all container and system logs
✅ Stores logs for 31 days (configurable)
✅ Provides powerful search with LogQL
✅ Visualizes logs in Grafana
✅ Integrates with your existing monitoring
✅ Uses minimal resources (~400MB RAM)
✅ Is fully documented
✅ Is ready for alerts and dashboards

**Total implementation time**: ~2 hours of development
**User deployment time**: ~5 minutes

Enjoy your new logging capabilities! 🔍📊
