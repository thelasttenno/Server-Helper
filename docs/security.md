# Security

## Security Model

| Layer | Implementation |
|-------|---------------|
| SSH | Drop-in config at `/etc/ssh/sshd_config.d/`, key-only auth, max 3 retries |
| Firewall | UFW deny-by-default, only required ports opened per role |
| Intrusion prevention | fail2ban with 24hr ban on 3 SSH failures |
| Auditing | Lynis weekly security scans via systemd timer |
| Secrets | Ansible Vault (AES-256), vault password file with `0600` permissions |
| Internal TLS | Step-CA issues certs, root CA distributed to all targets |
| SSO | Authentik provides OIDC for Grafana (extensible to other services) |
| Docker API | Docker Socket Proxy restricts to read-only, UFW limits to control IP |
| Shell security | Cleanup trap, sensitive var unset on exit, command redaction in logs |

## Vault Management

All secrets are stored in `group_vars/vault.yml`, encrypted with `ansible-vault`:

```bash
# Edit secrets interactively
make vault-edit

# Generate fresh secrets (interactive wizard)
make setup   # → Secrets menu

# Re-key vault with a new password
make vault-rekey
```

The vault password file (`.vault_password`) is:

- Gitignored (never committed)
- Permissions enforced at `0600`
- Referenced in `ansible.cfg` via `vault_password_file`

## Pre-Commit Guards

Two layers prevent committing unencrypted secrets:

### Git native hook (`.githooks/pre-commit`)

Blocks any commit that stages an unencrypted `group_vars/vault.yml`. Checks the first line for `$ANSIBLE_VAULT` header.

### Pre-commit framework (`.pre-commit-config.yaml`)

A `vault-encrypted` local hook performs the same check for users of the `pre-commit` Python framework.

Configure git to use the hooks directory:

```bash
git config core.hooksPath .githooks
```

## Ansible Task Security

All tasks that template files containing vault secrets use `no_log: true` to prevent plaintext secrets from appearing in Ansible output (especially with `diff: always` in `ansible.cfg`).

Protected tasks span 7 roles: authentik, grafana, restic, netdata, step_ca, pihole, traefik.

## File Permissions

| File Type | Mode | Rationale |
|-----------|------|-----------|
| `.env` files with secrets | `0600` | Only root can read |
| `docker-compose.yml` with embedded secrets | `0640` | Root + docker group |
| Init scripts with passwords | `0700` | Executable, root-only |
| Streaming config with API keys | `0600` | Root-only |
| Vault password file | `0600` | Root-only |

## Input Sanitization

### Makefile

All user-supplied variables (`HOST`, `ROLE`, `SERVICE`) are validated against `^[a-zA-Z0-9._-]+$` before being passed to `ansible-playbook`. This prevents shell injection via make targets like `make deploy-host HOST="foo;rm -rf /"`.

### Notification Scripts

All 4 notification channels use safe serialization:

- **Discord & Slack**: `python3 json.dumps()` for JSON payloads
- **Telegram**: `curl --data-urlencode` for URL encoding
- **Email**: `sys.argv` passing to Python (no string interpolation)

### Secrets Generation

The `secrets_mgr.sh` script writes vault contents to a RAM-backed tmpdir (`/dev/shm` when available) before encrypting, avoiding plaintext secrets on disk.

## Security Scanning

Lynis runs weekly via a systemd timer, producing audit reports that can be reviewed at `/var/log/lynis-report.dat`.

## SSH Hardening

Applied via drop-in config at `/etc/ssh/sshd_config.d/`:

- Key-only authentication (password auth disabled)
- Root login disabled
- Max 3 authentication tries
- Only strong ciphers and key exchange algorithms
