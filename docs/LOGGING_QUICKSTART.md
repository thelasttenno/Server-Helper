# Logging Stack Quick Start

Get up and running with Loki + Promtail + Grafana in 5 minutes.

---

## 🚀 Quick Setup

### 1. Configure

Edit `group_vars/all.yml` - the logging section is already there with sensible defaults:

```yaml
logging:
  loki:
    enabled: true
    port: 3100
    retention_period: "744h"  # 31 days

  promtail:
    enabled: true

  grafana:
    enabled: true
    port: 3000
    admin_user: admin
```

### 2. Set Password

```bash
ansible-vault edit group_vars/vault.yml
```

Add:

```yaml
vault_grafana_admin_password: "YourStrongPassword123!"
```

### 3. Deploy

```bash
# Full deployment
ansible-playbook playbooks/setup-targets.yml

# Or just logging
ansible-playbook playbooks/setup-targets.yml --tags logging
```

### 4. Access

Open browser: `http://your-server:3000`

- Username: `admin`
- Password: (from vault)

---

## 📊 First Steps in Grafana

### View Container Logs

1. Click **Explore** (compass icon)
2. Select **Loki** datasource
3. Enter query:

```logql
{job="docker"}
```

4. Click **Run query**

### Search for Errors

```logql
{job="docker"} |= "error"
```

### Filter by Container

```logql
{container="netdata"}
```

---

## 🔍 Common Queries

### Last Hour of Logs

```logql
{job="docker"} [1h]
```

### Authentication Logs

```logql
{job="auth"}
```

### System Logs

```logql
{job="syslog"}
```

### All Errors (any source)

```logql
{job=~".*"} |~ "(?i)error|fail|exception"
```

---

## 🎯 Pro Tips

### Import Pre-built Dashboards

1. Click **+** → **Import**
2. Enter dashboard ID:
   - **13639** - Loki Dashboard
   - **13407** - Docker Logs
3. Select **Loki** datasource
4. Click **Import**

### Create Alert

1. Create panel with query
2. Click **Alert** tab
3. Set conditions
4. Configure notifications

### Optimize Performance

- Use specific labels: `{container="app"}` vs `{job="docker"}`
- Limit time ranges: `[5m]` vs `[24h]`
- Avoid regex when possible: `|= "text"` vs `|~ "text"`

---

## 🛠️ Troubleshooting

### No Logs Appearing

```bash
docker logs promtail
docker logs loki
```

### Can't Login to Grafana

```bash
# Check container
docker ps | grep grafana

# View logs
docker logs grafana

# Test health
curl http://localhost:3000/api/health
```

### High Disk Usage

Reduce retention in `group_vars/all.yml`:

```yaml
logging:
  loki:
    retention_period: "168h"  # Change to 7 days
```

Then redeploy:

```bash
ansible-playbook playbooks/setup-targets.yml --tags logging
```

---

## 📚 Learn More

- **Full Guide**: [docs/guides/logging-stack.md](guides/logging-stack.md)
- **LogQL Reference**: https://grafana.com/docs/loki/latest/logql/
- **Grafana Dashboards**: https://grafana.com/grafana/dashboards/

---

**That's it!** You now have centralized logging for all your containers and system logs. 🎉
