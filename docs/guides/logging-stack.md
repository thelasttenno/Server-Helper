# Logging & Visualization Stack Guide

**Loki + Promtail + Grafana**

A complete centralized logging and visualization solution for Server Helper.

---

## 📋 Table of Contents

- [Overview](#overview)
- [What You Get](#what-you-get)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Using Grafana](#using-grafana)
- [Querying Logs with LogQL](#querying-logs-with-logql)
- [Common Use Cases](#common-use-cases)
- [Troubleshooting](#troubleshooting)
- [Resource Usage](#resource-usage)
- [Advanced Configuration](#advanced-configuration)

---

## Overview

The logging stack provides:

- **Centralized Logs**: All Docker container logs and system logs in one place
- **Powerful Search**: Query logs with LogQL (similar to PromQL)
- **Beautiful Dashboards**: Visualize log patterns and trends in Grafana
- **Long-term Storage**: Configurable retention (default: 31 days)
- **Low Resource Usage**: ~350-450MB RAM total

### Components

| Component | Purpose | Port | RAM Usage |
|-----------|---------|------|-----------|
| **Loki** | Log aggregation server | 3100 | ~100-150MB |
| **Promtail** | Log shipper/collector | - | ~30-50MB |
| **Grafana** | Visualization & dashboards | 3000 | ~150-200MB |

---

## What You Get

### Out of the Box

✅ **Docker container logs** - All containers automatically logged
✅ **System logs** - `/var/log/*` collected
✅ **Syslog** - System events tracked
✅ **Auth logs** - SSH and authentication events
✅ **Pre-configured Grafana** - Loki datasource ready
✅ **31-day retention** - Configurable per your needs

### What This Enables

- **Debug issues** without SSH-ing into servers
- **Search logs** across all containers instantly
- **Correlate events** between different services
- **Create alerts** based on log patterns
- **Track metrics** extracted from logs
- **Centralized view** of all server activity

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Servers                         │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐             │
│  │   Docker     │         │   System     │             │
│  │  Containers  │────────▶│    Logs      │             │
│  │              │         │  /var/log/*  │             │
│  └──────────────┘         └──────────────┘             │
│         │                        │                      │
│         └────────┬───────────────┘                      │
│                  ▼                                       │
│         ┌──────────────┐                                │
│         │  Promtail    │  (Collects & ships logs)      │
│         └──────┬───────┘                                │
│                │                                         │
│                ▼                                         │
│         ┌──────────────┐                                │
│         │     Loki     │  (Stores & indexes logs)      │
│         └──────┬───────┘                                │
│                │                                         │
│                ▼                                         │
│         ┌──────────────┐                                │
│         │   Grafana    │  (Query & visualize)          │
│         └──────────────┘                                │
└─────────────────────────────────────────────────────────┘
```

**How it works:**

1. **Promtail** scrapes logs from:
   - Docker containers (via Docker socket)
   - System log files (`/var/log/*`)
   - Custom log sources (configurable)

2. **Loki** receives logs from Promtail:
   - Indexes labels (not full text)
   - Compresses and stores log streams
   - Manages retention and cleanup

3. **Grafana** queries Loki:
   - Provides Explore interface for ad-hoc queries
   - Displays dashboards with log panels
   - Sends alerts based on log patterns

---

## Installation

### Prerequisites

- Server Helper already installed
- Docker running
- Ports available: 3000 (Grafana), 3100 (Loki)

### Step 1: Configure Logging Settings

Edit `group_vars/all.yml`:

```yaml
logging:
  # Stack directory
  stack_dir: /opt/dockge/stacks/logging

  # Loki - Log aggregation
  loki:
    enabled: true
    version: latest
    port: 3100
    retention_period: "744h"  # 31 days

  # Promtail - Log collector
  promtail:
    enabled: true
    version: latest

  # Grafana - Visualization
  grafana:
    enabled: true
    version: latest
    port: 3000
    admin_user: admin
```

### Step 2: Set Grafana Password

Edit your vault file:

```bash
ansible-vault edit group_vars/vault.yml
```

Add:

```yaml
# Grafana admin password
vault_grafana_admin_password: "YourStrongPassword123!"
```

### Step 3: Deploy the Stack

```bash
# Full deployment
ansible-playbook playbooks/setup-targets.yml

# Or just the logging role
ansible-playbook playbooks/setup-targets.yml --tags logging
```

### Step 4: Access Grafana

1. Open browser: `http://your-server:3000`
2. Login with:
   - Username: `admin`
   - Password: (from vault)
3. The Loki datasource is pre-configured!

---

## Configuration

### Basic Settings

Located in `group_vars/all.yml`:

```yaml
logging:
  loki:
    retention_period: "744h"  # How long to keep logs
    # Options: 168h (7 days), 720h (30 days), 2160h (90 days)

  grafana:
    admin_user: admin         # Admin username
    port: 3000                # Web UI port
    plugins: ""               # Additional plugins (comma-separated)
```

### Custom Log Sources

Add custom log files to Promtail:

```yaml
logging:
  promtail:
    additional_jobs:
      - name: "nginx"
        path: "/var/log/nginx/*.log"
        pipeline_stages:
          - regex:
              expression: '^(?P<remote_addr>[\w\.]+) - .*'

      - name: "app_logs"
        path: "/opt/myapp/logs/*.log"
```

### Email Alerts (Optional)

Configure SMTP in Grafana:

```yaml
logging:
  grafana:
    smtp:
      enabled: true
      host: "smtp.gmail.com"
      port: 587
      user: "your-email@gmail.com"
      from_address: "grafana@example.com"
      from_name: "Grafana Alerts"
      # Password stored in vault: vault_grafana_smtp_password
```

---

## Using Grafana

### Initial Setup

After logging in for the first time:

1. **Change your password**
   - Click profile icon → Preferences → Change Password

2. **Verify Loki datasource**
   - Navigate to: Configuration → Data Sources
   - You should see "Loki" already configured
   - Test it: Click "Loki" → "Save & Test"

### Exploring Logs

The **Explore** feature is your log search interface:

1. Click **Explore** icon (compass) in left sidebar
2. Select **Loki** datasource
3. Use the query builder or write LogQL directly

**Example: View all container logs**

```logql
{job="docker"}
```

**Example: Filter by container name**

```logql
{container="netdata"}
```

**Example: Search for errors**

```logql
{job="docker"} |= "error"
```

### Creating Dashboards

1. Click **+** → **Dashboard**
2. Add Panel → Select Visualization Type
3. Choose **Loki** datasource
4. Enter LogQL query
5. Save dashboard

**Pro tip**: Import pre-built dashboards:
- Grafana.com Dashboard ID: 13639 (Loki Dashboard)
- Grafana.com Dashboard ID: 13407 (Docker Logs)

---

## Querying Logs with LogQL

LogQL is Loki's query language, similar to Prometheus' PromQL.

### Basic Syntax

```logql
{label_selector} |= "search text" | filters
```

### Label Selectors

```logql
# All Docker logs
{job="docker"}

# Specific container
{container="grafana"}

# Multiple conditions
{job="docker", container="loki"}

# Regular expression
{container=~"grafana|loki"}
```

### Log Filters

```logql
# Contains text
{job="docker"} |= "error"

# Does not contain
{job="docker"} != "debug"

# Case-insensitive
{job="docker"} |~ "(?i)error"

# Regular expression
{job="docker"} |~ "error|fail|exception"
```

### Aggregations

```logql
# Count log lines
count_over_time({job="docker"}[5m])

# Rate of logs
rate({job="docker"}[5m])

# Logs per container
sum by (container) (rate({job="docker"}[5m]))
```

### Time Ranges

```logql
# Last 5 minutes
{job="docker"} [5m]

# Last hour
{job="docker"} [1h]

# Last day
{job="docker"} [24h]
```

---

## Common Use Cases

### 1. Debug Container Crashes

**Find error messages before crash:**

```logql
{container="myapp"} |= "error" | logfmt | severity="error"
```

### 2. Monitor Authentication Attempts

**SSH login attempts:**

```logql
{job="auth"} |~ "Failed password|Accepted password"
```

### 3. Track API Requests

**HTTP requests with status codes:**

```logql
{job="docker", container="api"} | json | status_code >= 400
```

### 4. Find Slow Queries

**Database query times:**

```logql
{container="postgres"} | regexp "duration: (?P<duration>\\d+)ms" | duration > 1000
```

### 5. Monitor Disk Space Warnings

**System disk warnings:**

```logql
{job="syslog"} |~ "disk.*full|no space left"
```

### 6. Application Error Tracking

**Application errors grouped by service:**

```logql
sum by (compose_service) (count_over_time({job="docker"} |= "ERROR" [5m]))
```

---

## Troubleshooting

### Logs Not Appearing

**Check Promtail is running:**

```bash
docker ps | grep promtail
docker logs promtail
```

**Verify Loki connection:**

```bash
docker logs promtail | grep "loki"
```

### Can't Access Grafana

**Check Grafana container:**

```bash
docker ps | grep grafana
docker logs grafana
```

**Verify port is open:**

```bash
sudo ufw status | grep 3000
```

**Test locally:**

```bash
curl http://localhost:3000/api/health
```

### Loki Running Out of Disk Space

**Check disk usage:**

```bash
du -sh /opt/dockge/stacks/logging/
```

**Reduce retention period:**

Edit `group_vars/all.yml`:

```yaml
logging:
  loki:
    retention_period: "168h"  # Reduce to 7 days
```

Re-deploy:

```bash
ansible-playbook playbooks/setup-targets.yml --tags logging
```

### Slow Queries

**Tips for better performance:**

1. **Use specific labels** - `{container="app"}` faster than `{job="docker"}`
2. **Limit time ranges** - `[5m]` faster than `[24h]`
3. **Avoid regex when possible** - `|= "text"` faster than `|~ "text"`
4. **Pre-filter** - Filter by labels first, then grep

---

## Resource Usage

### Expected RAM Usage

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

### Optimization Tips

**Reduce Loki RAM:**

```yaml
# In loki-config.yml.j2 (already optimized)
limits_config:
  ingestion_rate_mb: 8  # Lower from 16
  ingestion_burst_size_mb: 16  # Lower from 32
```

**Reduce Promtail overhead:**

```yaml
# In promtail-config.yml.j2
scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - refresh_interval: 30s  # Increase from 5s
```

---

## Advanced Configuration

### Multi-Tenant Setup

Loki supports multi-tenancy for isolating logs:

```yaml
# Not enabled by default, but possible
auth_enabled: true
```

### External Loki Instance

Point multiple servers to one Loki:

```yaml
# In promtail-config.yml.j2
clients:
  - url: http://central-loki-server:3100/loki/api/v1/push
```

### Custom Dashboard Provisioning

Add your own dashboards automatically:

1. Export dashboard JSON from Grafana
2. Save to `roles/logging/templates/grafana-provisioning/dashboards/my-dashboard.json.j2`
3. Re-deploy

### Alert Rules in Loki

Create alert rules directly in Loki:

```yaml
# In loki-config.yml.j2 (advanced)
ruler:
  alertmanager_url: http://alertmanager:9093
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /tmp/rules
```

### Integration with Prometheus

Use both metrics (Prometheus) and logs (Loki) together:

1. Install Prometheus (future enhancement)
2. Add Prometheus datasource in Grafana
3. Create dashboards combining both:
   - Metrics from Prometheus
   - Logs from Loki
   - Correlated views

---

## Next Steps

### Recommended

1. **Import pre-built dashboards** from Grafana.com
2. **Create custom dashboards** for your applications
3. **Set up alerts** for critical log patterns
4. **Configure email notifications** for alerts

### Future Enhancements

Consider adding:

- **Prometheus** for metrics (complements logs)
- **Alertmanager** for sophisticated alert routing
- **Tempo** for distributed tracing
- **Mimir** for long-term metrics storage

---

## Resources

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Reference](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)

---

## Support

For issues with the logging stack:

1. Check [Troubleshooting](#troubleshooting) section
2. Review logs: `docker logs loki`, `docker logs promtail`, `docker logs grafana`
3. Open issue: https://github.com/thelasttenno/Server-Helper/issues

---

**Happy Logging!** 🔍📊
