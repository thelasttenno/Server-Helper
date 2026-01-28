# DNS Quick Start Guide

Get Pi-hole + Unbound DNS running in 5 minutes.

## 1️⃣ Enable DNS

Edit [group_vars/all.yml](../group_vars/all.yml):

```yaml
dns:
  enabled: true
```

## 2️⃣ Set Password

```bash
# Edit vault
ansible-vault edit group_vars/vault.yml

# Add this section:
vault_dns:
  pihole_password: "change-me-strong-password"
```

Generate strong password:
```bash
openssl rand -base64 32
```

## 3️⃣ Deploy

```bash
# Run setup playbook
ansible-playbook playbooks/setup-targets.yml

# Or just DNS role
ansible-playbook playbooks/setup-targets.yml --tags dns
```

## 4️⃣ Access Pi-hole

```
http://your-server:8080/admin
```

Login with password from vault.

## 5️⃣ Configure Devices

**Network-wide (Recommended):**
1. Log into router admin
2. Change DNS to: `192.168.1.x` (your server IP)
3. Save and reboot router
4. All devices now use Pi-hole

**Per-Device:**
- **Windows**: Settings → Network → Change adapter → DNS → `192.168.1.x`
- **macOS**: System Preferences → Network → Advanced → DNS → `192.168.1.x`
- **Linux**: Edit `/etc/resolv.conf` → `nameserver 192.168.1.x`
- **Android/iOS**: WiFi → Configure DNS → Manual → `192.168.1.x`

## 🎯 Test It Works

```bash
# Test external DNS
dig @your-server google.com

# Test internal DNS
dig @your-server grafana.internal
dig @your-server dockge.internal

# Check what's registered
cat /opt/dockge/stacks/dns/pihole/custom.list
```

## 🎨 Customize

### Add Custom DNS Records

```yaml
# group_vars/all.yml
dns:
  custom_records:
    - domain: nas.internal
      ip: 192.168.1.100
    - domain: router.internal
      ip: 192.168.1.1
```

### Add Database Services

```yaml
dns:
  database_services:
    - name: postgres
      ip: 192.168.1.50
    - name: mysql
      ip: 192.168.1.51
```

Now access via `postgres.internal` and `mysql.internal`.

### Change Theme

```yaml
dns:
  pihole:
    theme: default-darker  # default-light, default-dark, default-darker
```

## 📊 Monitoring

### Grafana Dashboard

1. Open Grafana: `http://your-server:3000`
2. Import dashboard ID: `10176`
3. Select Prometheus data source
4. View Pi-hole metrics

### Uptime Kuma

Add monitors:
- **HTTP**: `http://your-server:8080/admin/` (Pi-hole health)
- **DNS**: Query `google.com` against your server
- **DNS**: Query `grafana.internal` against your server

### Netdata

Pi-hole stats automatically appear in Netdata:
- `http://your-server:19999`
- Look for "Pi-hole" section

## ⚙️ Configuration Options

### Use Faster DNS (Less Private)

```yaml
dns:
  unbound:
    forward_zone: true  # Forward to Cloudflare instead of recursive
    forward_tls: true   # Encrypted DNS queries
```

### Use Custom Upstream DNS

```yaml
dns:
  unbound:
    forward_servers:
      - 9.9.9.9       # Quad9
      - 149.112.112.112
```

### Change Pi-hole Port

```yaml
dns:
  pihole:
    port: 8888  # Use different port
```

Don't forget to update firewall:
```yaml
security:
  ufw_allowed_ports:
    - 8888  # New Pi-hole port
```

## 🔧 Common Tasks

### View Pi-hole Logs

```bash
docker logs pihole
docker logs unbound
```

### Restart DNS

```bash
cd /opt/dockge/stacks/dns
docker compose restart
```

### Update Pi-hole

```bash
cd /opt/dockge/stacks/dns
docker compose pull
docker compose up -d
```

### Backup Pi-hole Config

```bash
# Configs backed up automatically with Restic
# Manual backup:
sudo tar czf pihole-backup.tar.gz /opt/dockge/stacks/dns/pihole/etc-pihole
```

### Restore Pi-hole Config

```bash
# Stop Pi-hole
cd /opt/dockge/stacks/dns
docker compose down

# Restore files
sudo tar xzf pihole-backup.tar.gz -C /

# Start Pi-hole
docker compose up -d
```

## 🐛 Troubleshooting

### DNS not working

```bash
# Check if running
docker ps | grep -E 'pihole|unbound'

# Check firewall
sudo ufw status | grep 53

# Check port conflicts
sudo netstat -tlnp | grep :53

# Test manually
dig @127.0.0.1 google.com
```

### Pi-hole UI not accessible

```bash
# Check if port is open
sudo ufw status | grep 8080

# Check if container is running
docker ps | grep pihole

# Check logs for errors
docker logs pihole --tail 50
```

### Internal domains not resolving

```bash
# Verify custom.list exists
cat /opt/dockge/stacks/dns/pihole/custom.list

# Re-run playbook to regenerate
ansible-playbook playbooks/setup-targets.yml --tags dns

# Restart Pi-hole
docker restart pihole
```

### Ads not being blocked

1. Check Pi-hole is being used: `http://your-server:8080/admin`
2. Look at "Queries" graph - should see traffic
3. If no queries, DNS isn't configured on devices
4. Update blocklists: Tools → Update Gravity

## 📚 Next Steps

- **Whitelist sites**: If legitimate sites are blocked
- **Add blocklists**: Group Management → Adlists
- **View statistics**: Dashboard shows blocked queries
- **Configure DHCP**: Use Pi-hole as DHCP server (advanced)
- **Enable DNSSEC**: Already enabled via Unbound
- **Custom regex blocking**: Advanced blocking rules

## 🌐 Auto-Registered Services

These services are automatically added to DNS:

| Service | DNS Name | Access |
|---------|----------|--------|
| Dockge | `dockge.internal` | Container management |
| Grafana | `grafana.internal` | Dashboards |
| Netdata | `netdata.internal` | Metrics |
| Uptime Kuma | `uptime-kuma.internal` | Monitoring |
| Pi-hole | `pihole.internal` | DNS admin |
| Loki | `loki.internal` | Logs |
| Authentik | `sso.internal` | SSO |

Instead of:
```
http://192.168.1.50:3000
```

Use:
```
http://grafana.internal:3000
```

Much cleaner! 🎉

## 💡 Pro Tips

1. **Bookmark Pi-hole**: Add `http://pihole.internal:8080/admin` to bookmarks
2. **Set router DNS**: Configure router, not individual devices
3. **Monitor queries**: Check Pi-hole dashboard daily
4. **Whitelist apps**: Some apps break with ad blocking (whitelist them)
5. **Use Grafana**: Better long-term stats than Pi-hole UI
6. **Enable logging**: Keep `query_logging: true` to troubleshoot issues

## 🆘 Need Help?

- **Pi-hole Docs**: https://docs.pi-hole.net/
- **Unbound Docs**: https://unbound.docs.nlnetlabs.nl/
- **Server-Helper Issues**: https://github.com/thelasttenno/Server-Helper/issues
- **DNS Role README**: [roles/dns/README.md](../roles/dns/README.md)

## 📖 Full Documentation

See [README.md](../README.md) for complete DNS documentation.
