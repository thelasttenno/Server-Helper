# Server Helper - Scripts Quick Reference

One-page cheat sheet for all deployment scripts and commands.

## 🚀 Quick Start

```bash
# First-time setup (interactive)
./setup.sh

# Bootstrap target servers
make bootstrap

# Deploy everything
make deploy

# Open web interfaces
make ui
```

---

## 📋 Core Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| **setup.sh** | Interactive setup wizard | `./setup.sh` |
| **bootstrap-target.sh** | Prepare new server | `sudo ./bootstrap-target.sh` |
| **upgrade.sh** | Upgrade Docker images | `./upgrade.sh [OPTIONS]` |
| **scripts/open-ui.sh** | Open web UIs | `./scripts/open-ui.sh [SERVICE]` |

---

## 🛠️ Make Commands

### Setup & Bootstrap
```bash
make setup                          # Interactive setup
make bootstrap                      # Bootstrap all servers
make bootstrap-host HOST=server-01  # Bootstrap one server
```

### Deployment
```bash
make deploy                         # Deploy to all servers
make deploy-host HOST=server-01     # Deploy to one server
make deploy-control                 # Deploy control node
make deploy-check                   # Dry run (no changes)
```

### Operations
```bash
make update                         # Update from Git
make upgrade                        # Upgrade Docker images
make backup                         # Run backups
make security                       # Security audit
make restart-all                    # Restart all services
```

### Testing
```bash
make test                           # Run all tests
make test-role ROLE=common          # Test one role
make lint                           # Run linters
make syntax-check                   # Check syntax
```

### UI & Monitoring
```bash
make ui                             # List service URLs
make ui-all                         # Open all UIs
make ui-dockge                      # Open Dockge
make ui-netdata                     # Open Netdata
make ui-uptime                      # Open Uptime Kuma
```

### Vault
```bash
make vault-edit                     # Edit vault
make vault-view                     # View vault
make vault-status                   # Check status
make vault-validate                 # Validate encryption
```

### Status
```bash
make status                         # Service status (all)
make ping                           # Ping all hosts
make list-hosts                     # List inventory
make disk-space                     # Check disk usage
make version                        # Show versions
```

### Cleanup
```bash
make clean                          # Clean test artifacts
make clean-logs                     # Clean log files
make clean-docker                   # Clean Docker resources
```

---

## 🔧 upgrade.sh Options

```bash
./upgrade.sh                        # Upgrade all
./upgrade.sh --service netdata      # Upgrade one service
./upgrade.sh --host server-01       # Upgrade one host
./upgrade.sh --dry-run              # Preview changes
./upgrade.sh --pull-only            # Pull without restart
./upgrade.sh --verbose              # Detailed output

# Combine options
./upgrade.sh --host server-01 --service dockge --dry-run
```

**Services:** `dockge`, `netdata`, `uptime-kuma`, `all`

---

## 🌐 UI Launcher

```bash
./scripts/open-ui.sh list           # List all URLs
./scripts/open-ui.sh dockge         # Open Dockge
./scripts/open-ui.sh netdata server-01  # Open on specific host
./scripts/open-ui.sh all            # Open all UIs
```

**Services:** `dockge`, `netdata`, `uptime-kuma`, `all`, `list`

---

## 📂 File Locations

```
Server-Helper/
├── setup.sh                    # Setup wizard
├── bootstrap-target.sh         # Target bootstrap
├── upgrade.sh                  # Upgrade script
├── Makefile                    # Make targets
└── scripts/
    ├── open-ui.sh              # UI launcher
    ├── vault.sh                # Vault manager
    ├── test-all-roles.sh       # Test runner
    └── test-single-role.sh     # Single test
```

---

## 🔑 Environment Variables

```bash
# Custom inventory
INVENTORY=inventory/prod.yml make deploy

# Ansible options
ANSIBLE_OPTS="-vvv" make deploy

# Vault password file
VAULT_PASSWORD_FILE=.vault_prod make vault-edit

# Combine multiple
INVENTORY=inventory/prod.yml ANSIBLE_OPTS="-v" make deploy
```

---

## 📊 Common Workflows

### New Server Setup
```bash
1. ./bootstrap-target.sh          # On target
2. vim inventory/hosts.yml        # Add to inventory
3. make deploy-host HOST=new      # Deploy
4. make status-host HOST=new      # Verify
```

### Monthly Maintenance
```bash
1. make update                    # Update config
2. make upgrade                   # Upgrade images
3. make security                  # Run audit
4. make backup                    # Run backup
5. make status                    # Check all
```

### Troubleshooting
```bash
1. make ping                      # Test connectivity
2. make status                    # Check services
3. make disk-space                # Check space
4. make deploy-check              # Dry run
5. ANSIBLE_OPTS="-vvv" make deploy  # Verbose
```

### Testing Changes
```bash
1. make lint                      # Check syntax
2. make test-role ROLE=common     # Test role
3. make deploy-check              # Preview
4. make deploy-host HOST=test     # Test deploy
5. make status-host HOST=test     # Verify
```

---

## 🆘 Quick Fixes

### Services not running
```bash
make restart-all
make status
```

### Disk space issues
```bash
make disk-space
make clean-docker
```

### Can't access UI
```bash
make ui              # Get URLs
make ping            # Check connectivity
```

### Ansible errors
```bash
make ping            # Test connection
make list-hosts      # Verify inventory
ANSIBLE_OPTS="-vvv" make deploy  # Debug
```

### Vault issues
```bash
make vault-status    # Check status
make vault-validate  # Test decryption
```

---

## 🎯 Default Ports

| Service | Port | URL Format |
|---------|------|------------|
| **Dockge** | 5001 | `http://HOST:5001` |
| **Netdata** | 19999 | `http://HOST:19999` |
| **Uptime Kuma** | 3001 | `http://HOST:3001` |

Access via `make ui` or `./scripts/open-ui.sh`

---

## 📖 Full Documentation

- **Scripts Guide**: [docs/scripts-guide.md](docs/scripts-guide.md)
- **Setup Guide**: [docs/guides/setup-script.md](docs/guides/setup-script.md)
- **Vault Guide**: [docs/guides/vault.md](docs/guides/vault.md)
- **Testing Guide**: [docs/testing.md](docs/testing.md)
- **README**: [README.md](README.md)

---

## 💡 Pro Tips

1. **Use tab completion**: Most shells support `make <TAB>`
2. **Chain commands**: `make deploy && make status`
3. **Dry run first**: Always use `--dry-run` or `deploy-check`
4. **Test on one host**: Use `HOST=test` before deploying to all
5. **Keep logs**: Don't `clean-logs` until issues resolved
6. **Bookmark `make help`**: Shows all available commands

---

**Need help?** Run `make help` or see [docs/scripts-guide.md](docs/scripts-guide.md)
