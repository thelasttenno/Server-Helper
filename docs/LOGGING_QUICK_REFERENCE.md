# Logging Stack Quick Reference

Quick reference card for Loki + Promtail + Grafana

---

## 🔗 URLs

| Service | URL | Default Port |
|---------|-----|--------------|
| Grafana | `http://your-server:3000` | 3000 |
| Loki API | `http://your-server:3100` | 3100 |

**Default Login**: admin / (from vault)

---

## 📋 Common LogQL Queries

### Basic Queries

```logql
# All Docker logs
{job="docker"}

# Specific container
{container="netdata"}

# All system logs
{job="syslog"}

# Authentication logs
{job="auth"}
```

### Search & Filter

```logql
# Contains text
{job="docker"} |= "error"

# Does not contain
{job="docker"} != "debug"

# Regex search (case-insensitive)
{job="docker"} |~ "(?i)error|fail"

# Multiple containers
{container=~"loki|grafana"}
```

### Aggregations

```logql
# Count logs per container
sum by (container) (count_over_time({job="docker"}[5m]))

# Rate of logs
rate({job="docker"}[5m])

# Total log lines
count_over_time({job="docker"}[1h])
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

## 🎯 Common Use Cases

### Debug Container Issues

```logql
{container="myapp"} |= "error"
```

### Monitor Failed Logins

```logql
{job="auth"} |~ "Failed password"
```

### Track Container Restarts

```logql
{job="docker"} |~ "started|stopped|restarting"
```

### Find Slow Queries

```logql
{container="postgres"} | regexp "duration: (?P<duration>\\d+)ms" | duration > 1000
```

### Application Errors by Service

```logql
sum by (compose_service) (count_over_time({job="docker"} |= "ERROR" [5m]))
```

---

## 🛠️ Management Commands

### Check Stack Status

```bash
docker ps | grep -E "loki|promtail|grafana"
```

### View Logs

```bash
docker logs loki
docker logs promtail
docker logs grafana
```

### Restart Stack

```bash
cd /opt/dockge/stacks/logging
docker-compose restart
```

### Test Health

```bash
# Loki
curl http://localhost:3100/ready

# Grafana
curl http://localhost:3000/api/health
```

---

## 📝 Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| Docker Compose | `/opt/dockge/stacks/logging/docker-compose.yml` | Stack definition |
| Loki Config | `/opt/dockge/stacks/logging/loki-config.yml` | Loki settings |
| Promtail Config | `/opt/dockge/stacks/logging/promtail-config.yml` | Log sources |
| Grafana Datasource | `/opt/dockge/stacks/logging/grafana-provisioning/datasources/` | Loki connection |

---

## ⚙️ Ansible Variables

### Enable/Disable Components

```yaml
logging:
  loki:
    enabled: true
  promtail:
    enabled: true
  grafana:
    enabled: true
```

### Adjust Retention

```yaml
logging:
  loki:
    retention_period: "168h"  # 7 days
    # 744h = 31 days (default)
    # 2160h = 90 days
```

### Change Ports

```yaml
logging:
  loki:
    port: 3100
  grafana:
    port: 3000
```

---

## 🔥 Troubleshooting

### No Logs Appearing

```bash
# Check Promtail
docker logs promtail | tail -50

# Check Loki
docker logs loki | tail -50

# Verify connection
docker exec promtail wget -qO- http://loki:3100/ready
```

### Can't Login to Grafana

```bash
# Reset password
docker exec -it grafana grafana-cli admin reset-admin-password newpassword

# Check container
docker logs grafana | grep error
```

### High Disk Usage

```bash
# Check size
du -sh /opt/dockge/stacks/logging/

# Reduce retention (edit group_vars/all.yml)
retention_period: "168h"  # 7 days

# Force cleanup
docker exec loki wget -qO- http://localhost:3100/loki/api/v1/delete
```

### Slow Queries

- Use specific labels: `{container="app"}` not `{job="docker"}`
- Limit time range: `[5m]` not `[24h]`
- Avoid regex: `|= "text"` not `|~ "text"`
- Filter early: Labels first, then text search

---

## 📊 Grafana Tips

### Import Dashboard

1. Click **+** → **Import**
2. Enter ID: **13639** (Loki) or **13407** (Docker)
3. Select Loki datasource
4. Click Import

### Create Alert

1. Create panel with query
2. Click **Alert** tab
3. Set condition: `avg() > threshold`
4. Configure notification channel
5. Save

### Export Dashboard

1. Dashboard Settings → JSON Model
2. Copy JSON
3. Save to file
4. Import on another server

---

## 🎓 LogQL Cheat Sheet

| Pattern | Syntax | Example |
|---------|--------|---------|
| Label match | `{label="value"}` | `{container="app"}` |
| Regex match | `{label=~"regex"}` | `{container=~"app.*"}` |
| Negative match | `{label!="value"}` | `{container!="test"}` |
| Contains | `\|= "text"` | `\|= "error"` |
| Not contains | `!= "text"` | `!= "debug"` |
| Regex search | `\|~ "regex"` | `\|~ "error\|fail"` |
| Count | `count_over_time()` | `count_over_time({job="docker"}[5m])` |
| Rate | `rate()` | `rate({job="docker"}[1m])` |
| Sum | `sum by (label)` | `sum by (container) (rate({job="docker"}[5m]))` |

---

## 📞 Quick Help

### Full Documentation

- **Complete Guide**: [docs/guides/logging-stack.md](../guides/logging-stack.md)
- **Quick Start**: [docs/LOGGING_QUICKSTART.md](../LOGGING_QUICKSTART.md)

### External Resources

- **LogQL**: https://grafana.com/docs/loki/latest/logql/
- **Grafana**: https://grafana.com/docs/grafana/latest/
- **Dashboards**: https://grafana.com/grafana/dashboards/

### Deploy Changes

```bash
ansible-playbook playbooks/setup-targets.yml --tags logging
```

---

**Keep this reference handy!** 📌
