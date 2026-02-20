# Traefik Role

Deploys [Traefik](https://traefik.io), the modern reverse proxy and edge router.

## Features

- **Automatic SSL**: Let's Encrypt certificates via DNS challenge.
- **Security Headers**: Middleware for HSTS, X-Frame-Options, etc.
- **Dashboard**: Protected web UI at `https://traefik.{{ target_domain }}`.
- **Observability**: Access logs are written to a volume and scraped by Promtail/Loki.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `control_traefik.http_port` | `80` | HTTP external port |
| `control_traefik.https_port` | `443` | HTTPS external port |
| `control_traefik.dashboard_port` | `8080` | Dashboard internal port |
| `control_traefik.acme_email` | (required) | Email for Let's Encrypt |
| `control_traefik.log_level` | `INFO` | Log verbosity |

## Integration

Traefik acts as the ingress for all other services. Use standard labels to expose containers:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`app.example.com`)"
```
