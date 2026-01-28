# DNS Role - Pi-hole + Unbound

This role deploys a complete DNS solution with Pi-hole (ad-blocking) and Unbound (recursive resolver) for your homelab.

## Features

- **Pi-hole**: Network-wide ad blocking and custom DNS records
- **Unbound**: Privacy-focused recursive DNS resolver
- **Auto-Discovery**: Services automatically registered to DNS via Ansible
- **Monitoring Integration**: Grafana dashboards, Netdata, and Uptime Kuma
- **Docker-based**: Easy deployment and updates via Dockge

## Requirements

- Docker and Docker Compose
- DNS network created (automatically handled)
- Vault password for Pi-hole admin access

## Quick Start

### 1. Enable DNS in Configuration

```yaml
# group_vars/all.yml
dns:
  enabled: true
  private_domain: internal
```

### 2. Set Pi-hole Password in Vault

```bash
# Edit vault file
ansible-vault edit group_vars/vault.yml

# Add under vault_dns:
vault_dns:
  pihole_password: "your-strong-password"
```

### 3. Run Playbook

```bash
ansible-playbook playbooks/setup-targets.yml
```

### 4. Access Pi-hole

```
http://your-server:8080/admin
```

## Auto-Discovered Services

The role automatically creates DNS records for:

| Service | DNS Name | Points To |
|---------|----------|-----------|
| Dockge | `dockge.internal` | Server IP |
| Grafana | `grafana.internal` | Server IP |
| Netdata | `netdata.internal` | Server IP |
| Uptime Kuma | `uptime-kuma.internal` or `uptime.internal` | Server IP |
| Pi-hole | `pihole.internal` | Server IP |
| Authentik | `authentik.internal` or `sso.internal` | Server IP |
| Loki | `loki.internal` | Server IP |

## Custom DNS Records

Add custom DNS entries:

```yaml
dns:
  # Manual records
  custom_records:
    - domain: nas.internal
      ip: 192.168.1.100
    - domain: router.internal
      ip: 192.168.1.1

  # Database servers
  database_services:
    - name: postgres
      ip: 192.168.1.50
    - name: mysql
      ip: 192.168.1.51

  # Application servers
  application_services:
    - name: webapp
      ip: 192.168.1.100
    - name: api
      ip: 192.168.1.101
```

## Configuration Options

### Pi-hole Settings

```yaml
dns:
  pihole:
    version: latest
    port: 8080
    https_port: false
    theme: default-dark  # default-light, default-dark, default-darker
    temp_unit: c  # c or f
    query_logging: true
    rev_server: true  # Enable reverse DNS
```

### Unbound Settings

```yaml
dns:
  unbound:
    version: latest
    ipv6: false
    num_threads: 2
    msg_cache_size: 50m
    rrset_cache_size: 100m

    # Forwarding mode (faster but less private)
    forward_zone: false  # true = forward to upstream, false = recursive
    forward_tls: true    # Use DNS-over-TLS
    forward_servers:
      - 1.1.1.1  # Cloudflare
      - 1.0.0.1
```

### Monitoring

```yaml
dns:
  monitoring:
    enabled: true
    grafana_dashboard: true
    uptime_kuma: true
    netdata: true

  exporter:
    port: 9617
    interval: 30s
```

## Architecture

```
┌─────────────────────────────────────────┐
│           DNS Stack                      │
│                                          │
│  ┌──────────────┐    ┌──────────────┐  │
│  │   Pi-hole    │◄───│   Unbound    │  │
│  │ (Ad Block +  │    │ (Recursive   │  │
│  │  Local DNS)  │    │  Resolver)   │  │
│  └──────┬───────┘    └──────────────┘  │
│         │                                │
│         │ Metrics                        │
│         ▼                                │
│  ┌──────────────┐                       │
│  │  Prometheus  │                       │
│  │   Exporter   │───► Grafana           │
│  └──────────────┘                       │
└─────────────────────────────────────────┘
         │
         │ Port 53 (DNS)
         │ Port 8080 (UI)
         ▼
    Client Devices
```

## DNS Query Flow

1. Client queries `grafana.internal`
2. Query goes to Pi-hole (port 53)
3. Pi-hole checks local records → Found! Returns server IP
4. Client connects to `grafana.internal` (resolves to server)

For external domains:
1. Client queries `google.com`
2. Pi-hole checks blocklist → Not blocked
3. Pi-hole forwards to Unbound
4. Unbound recursively resolves from root DNS
5. Response cached and returned to client

## File Structure

```
/opt/dockge/stacks/dns/
├── docker-compose.yml           # Main stack
├── .env                         # Environment variables
├── pihole/
│   ├── etc-pihole/             # Pi-hole configuration
│   ├── etc-dnsmasq.d/          # Dnsmasq config
│   └── custom.list             # Auto-generated DNS records
└── unbound/
    └── etc-unbound/
        └── unbound.conf        # Unbound configuration
```

## Templates

- `docker-compose.dns.yml.j2`: Main DNS stack compose file
- `unbound.conf.j2`: Unbound recursive resolver config
- `custom.list.j2`: Auto-generated DNS records
- `pihole.env.j2`: Pi-hole environment variables
- `docker-compose.dns-exporter.yml.j2`: Prometheus exporter
- `prometheus-pihole.yml.j2`: Prometheus scrape config
- `netdata-pihole.conf.j2`: Netdata monitoring config

## Tasks

1. **main.yml**: Orchestrates DNS deployment
   - Creates directories
   - Deploys configurations
   - Starts containers
   - Displays access info

2. **monitoring.yml**: Sets up monitoring integration
   - Deploys Prometheus exporter
   - Configures Grafana scraping
   - Creates Netdata config

## Handlers

- `restart dns stack`: Restarts Pi-hole and Unbound containers
- `restart netdata`: Restarts Netdata to reload Pi-hole monitoring

## Variables

See `defaults/main.yml` for all available variables and their defaults.

## Security Considerations

- Pi-hole admin password stored in Ansible Vault
- DNS runs on privileged port 53 (container has cap_add: NET_ADMIN)
- UFW firewall rules automatically added
- Only internal networks allowed in Unbound (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)

## Monitoring & Alerting

### Grafana Dashboard

Import Pi-hole dashboard: https://grafana.com/grafana/dashboards/10176

### Uptime Kuma Monitors

Add these monitors in Uptime Kuma:
- **Pi-hole Health**: HTTP → `http://server:8080/admin/`
- **DNS Resolution**: DNS → Query `google.com` against server IP
- **Internal DNS**: DNS → Query `grafana.internal` against server IP

### Netdata

Automatically monitors:
- DNS query rate
- Blocked queries
- Response times
- Cache hit rate

## Troubleshooting

### Pi-hole not starting

```bash
# Check logs
docker logs pihole
docker logs unbound

# Check if ports are available
sudo netstat -tlnp | grep -E '53|8080'

# Restart stack
cd /opt/dockge/stacks/dns
docker compose restart
```

### DNS not resolving

```bash
# Test Pi-hole directly
dig @localhost google.com
dig @localhost grafana.internal

# Check custom DNS records
cat /opt/dockge/stacks/dns/pihole/custom.list

# Verify Unbound is running
docker exec unbound unbound-control status
```

### Services not auto-registering

```bash
# Re-run Ansible to regenerate custom.list
ansible-playbook playbooks/setup-targets.yml --tags dns

# Check the generated file
cat /opt/dockge/stacks/dns/pihole/custom.list
```

## Performance Tuning

### For High Query Volume

```yaml
dns:
  unbound:
    num_threads: 4
    msg_cache_size: 100m
    rrset_cache_size: 200m
```

### For Low Memory Systems

```yaml
dns:
  unbound:
    num_threads: 1
    msg_cache_size: 25m
    rrset_cache_size: 50m
```

## License

GNU General Public License v3.0
