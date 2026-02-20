# Homarr Role

Deploys [Homarr](https://homarr.dev), a customizable dashboard for your self-hosted services.

## Integration

- **Traefik**: Exposed at `https://dashboard.{{ target_domain }}`
- **Authentik**: Protected by SSO middleware (same as Grafana/Dockge)
- **Docker**: Mounts `/var/run/docker.sock` to display container status

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `control_homarr.enabled` | `true` | Enable/disable the role |
| `control_homarr.version` | `latest` | Docker image tag |
| `control_homarr.port` | `7575` | Internal port |

## Access

- URL: `https://dashboard.example.com`
- Username: (via Authentik)
