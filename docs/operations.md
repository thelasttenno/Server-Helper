# Operations

## Makefile Quick Reference

### Deployment

| Command | Description |
|---------|-------------|
| `make deploy` | Full 3-tier deployment (`site.yml`) |
| `make deploy-control` | Control node only |
| `make deploy-targets` | Target nodes only |
| `make deploy-host HOST=server1` | Specific host |
| `make deploy-role ROLE=docker` | Specific role (optionally `HOST=`) |
| `make deploy-check` | Dry run with diff output |

### Updates & Upgrades

| Command | Description |
|---------|-------------|
| `make update` | Rolling apt upgrades (`serial: 1`) |
| `make update-reboot` | Updates with reboot |
| `make upgrade` | Docker image pull + recreate |
| `make upgrade-service SERVICE=grafana` | Upgrade specific service |
| `make upgrade-cleanup` | Upgrade with unused image pruning |

### Backups

| Command | Description |
|---------|-------------|
| `make backup` | Trigger backups on all hosts |
| `make backup-host HOST=server1` | Backup specific host |

### Monitoring & Status

| Command | Description |
|---------|-------------|
| `make ping` | Ansible ping all hosts |
| `make status` | Docker status across fleet |
| `make facts HOST=server1` | Gather facts from host |

### Vault

| Command | Description |
|---------|-------------|
| `make vault-edit` | Edit encrypted vault |
| `make vault-view` | View decrypted vault |
| `make vault-encrypt` | Encrypt vault file |
| `make vault-decrypt` | Decrypt vault file |

### Testing & Linting

| Command | Description |
|---------|-------------|
| `make test` | Run all Molecule tests |
| `make test-role ROLE=common` | Test specific role |
| `make lint` | ansible-lint + yamllint |

---

## Backups (Restic)

### How It Works

Each target runs 3 systemd timers:

| Timer | Schedule | Script |
|-------|----------|--------|
| `restic-backup.timer` | Daily 2:00 AM | Full backup with retention pruning |
| `restic-check.timer` | Weekly (Sunday 3:00 AM) | Repository integrity check |
| `restic-verify.timer` | Monthly | Read 5% of data to prove restorability |

### Backup Features

- **Stale lock cleanup**: `restic unlock --remove-all` before each run
- **Compression**: `--compression auto` (requires restic ≥ 0.16)
- **Failure notifications**: Sent via `server-helper-notify` (all configured channels)
- **Health heartbeat**: Pushes to Uptime Kuma on success/failure
- **JSONL metrics**: Appended to `/var/log/restic/metrics.json` after each backup

### Metrics Format

Each backup run appends one JSON line:

```json
{
  "hostname": "server1",
  "timestamp": "2026-02-19T02:01:27-08:00",
  "duration_seconds": 127,
  "total_size_bytes": 4294967296,
  "snapshot_count": 14,
  "status": "success"
}
```

### Retention Defaults

| Policy | Value |
|--------|-------|
| Daily | 7 |
| Weekly | 4 |
| Monthly | 6 |
| Yearly | 1 |

Override per-host via `host_vars/{hostname}.yml`:

```yaml
target_restic:
  retention:
    keep_daily: 14
    keep_weekly: 8
```

### Manual Operations

```bash
# SSH to target, then:
source /etc/restic/restic.env
restic snapshots              # List backups
restic stats latest           # Size of latest snapshot
restic restore latest --target /tmp/restore  # Restore
```

### Upgrading Restic

Change `restic_version` in `roles/restic/defaults/main.yml` (or override in group/host vars), then redeploy:

```bash
make deploy-role ROLE=restic
```

---

## Upgrades

### Docker Images

```bash
make upgrade                          # All services, rolling
make upgrade-service SERVICE=grafana  # Single service
make upgrade-cleanup                  # With image pruning
```

The `upgrade.yml` playbook:

1. Auto-detects deployed services per host
2. Pulls new images
3. Recreates containers
4. Runs health checks
5. Uses `serial: 1` for safety

### System Updates

```bash
make update         # apt upgrade, Watchtower trigger
make update-reboot  # With reboot if required
```

---

## Troubleshooting

### Common Issues

**Ansible can't connect to host**

```bash
make ping                    # Check SSH connectivity
ssh -v user@host             # Debug SSH manually
```

**Task fails with permission denied**

```bash
# Ensure the ansible user has sudo without password:
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
```

**Docker service won't start**

```bash
# On the target:
cd /opt/stacks/{service}
docker compose logs
docker compose up -d          # Restart
```

**Encrypted vault issues**

```bash
make vault-view              # Verify vault is readable
make vault-decrypt           # Decrypt for debugging
# Re-encrypt when done:
make vault-encrypt
```

**Stale restic locks**

```bash
source /etc/restic/restic.env
restic unlock --remove-all
```

### Logs

| Component | Log Location |
|-----------|-------------|
| Ansible output | Terminal (stdout) |
| Restic backups | `/var/log/restic/backup-*.log` |
| Restic checks | `/var/log/restic/check-*.log` |
| Restic verify | `/var/log/restic/verify-*.log` |
| Lynis audits | `/var/log/lynis-report.dat` |
| Docker services | `docker compose logs` in `/opt/stacks/{service}` |
| System services | `journalctl -u {service-name}` |
