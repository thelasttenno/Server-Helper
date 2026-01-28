# Deployment Scripts Guide

Server Helper includes several convenient scripts to simplify deployment and management tasks. This guide covers all available scripts and their usage.

## Table of Contents

- [Quick Start Scripts](#quick-start-scripts)
- [Deployment Scripts](#deployment-scripts)
- [UI Launch Scripts](#ui-launch-scripts)
- [Makefile Targets](#makefile-targets)
- [Examples & Workflows](#examples--workflows)

---

## Quick Start Scripts

### setup.sh

**Purpose:** Interactive setup wizard for first-time configuration of Server Helper.

**Usage:**
```bash
./setup.sh
```

**What it does:**
1. Installs Ansible and dependencies on your command node (laptop/desktop)
2. Prompts for target server configuration (IPs, hostnames, credentials)
3. Collects service preferences (monitoring, backups, security settings)
4. Creates inventory file with target servers
5. Generates configuration files (`group_vars/all.yml`)
6. Creates encrypted Ansible Vault for secrets
7. Offers to bootstrap target servers
8. Runs deployment playbooks

**When to use:**
- First time setting up Server Helper
- Adding new infrastructure from scratch
- Guided configuration for beginners

**Example:**
```bash
# Clone the repository
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# Run setup wizard
./setup.sh

# Follow the prompts to configure your servers
```

---

### bootstrap-target.sh

**Purpose:** Prepares a fresh Ubuntu server to be managed by Ansible (run on target server).

**Usage:**
```bash
# On target server as root
./bootstrap-target.sh

# Or remotely
curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash
```

**What it does:**
1. Updates system packages
2. Installs Python 3 (required by Ansible)
3. Installs OpenSSH server
4. Creates admin user with sudo privileges
5. Configures passwordless sudo
6. Adds SSH public key for authentication

**When to use:**
- Preparing a brand new Ubuntu server
- Before adding server to inventory
- Initial server setup before Ansible management

**Example:**
```bash
# SSH into target server
ssh user@192.168.1.100

# Run bootstrap script
sudo ./bootstrap-target.sh

# Follow prompts to create ansible user and add SSH key
```

---

## Deployment Scripts

### upgrade.sh

**Purpose:** Upgrades Docker images and restarts services across managed servers.

**Usage:**
```bash
./upgrade.sh [OPTIONS]
```

**Options:**
- `--all` - Upgrade all services on all hosts (default)
- `--host <hostname>` - Upgrade services on specific host
- `--service <name>` - Upgrade specific service only
- `--pull-only` - Pull images but don't restart services
- `--dry-run` - Show what would be upgraded
- `--verbose` - Show detailed output
- `--help` - Show help message

**Supported services:**
- `dockge` - Container management platform
- `netdata` - System monitoring
- `uptime-kuma` - Uptime monitoring
- `all` - All services (default)

**Examples:**

```bash
# Upgrade all services on all servers
./upgrade.sh

# Upgrade only netdata on all servers
./upgrade.sh --service netdata

# Upgrade all services on specific server
./upgrade.sh --host server-01

# Upgrade specific service on specific server
./upgrade.sh --host server-01 --service dockge

# Preview what would be upgraded (dry run)
./upgrade.sh --dry-run

# Pull new images without restarting
./upgrade.sh --pull-only

# Verbose output for debugging
./upgrade.sh --verbose
```

**What it does:**
1. Checks prerequisites (Ansible, inventory)
2. Verifies target hosts exist
3. Pulls latest Docker images
4. Restarts services with new images
5. Waits for services to be healthy
6. Verifies services are running
7. Optionally cleans up old Docker resources

**When to use:**
- Monthly maintenance to update container images
- After upstream releases new versions
- Security updates for containerized services
- Regular maintenance windows

---

## UI Launch Scripts

### scripts/open-ui.sh

**Purpose:** Opens web interfaces for Server Helper services in your default browser.

**Usage:**
```bash
./scripts/open-ui.sh [SERVICE] [HOST]
```

**Services:**
- `dockge` - Container management platform
- `netdata` - System monitoring dashboard
- `uptime-kuma` - Uptime monitoring and alerting
- `all` - Open all service UIs
- `list` - List available services and URLs (default)

**Examples:**

```bash
# List all available services and their URLs
./scripts/open-ui.sh
./scripts/open-ui.sh list

# Open Dockge on first host in inventory
./scripts/open-ui.sh dockge

# Open Netdata on specific server
./scripts/open-ui.sh netdata server-01

# Open all UIs for first host
./scripts/open-ui.sh all

# Open all UIs for specific host
./scripts/open-ui.sh all server-01

# Show URLs for specific host
./scripts/open-ui.sh list server-02
```

**What it does:**
1. Reads inventory file to get host IPs
2. Reads configuration file for service ports
3. Constructs service URLs
4. Opens URLs in default browser (Linux/macOS/Windows)
5. Prints URLs for manual access if browser detection fails

**Supported platforms:**
- **Linux:** Uses `xdg-open`
- **macOS:** Uses `open`
- **Windows (Git Bash/WSL):** Uses `start`

**When to use:**
- Quick access to web interfaces
- After deployment to verify services
- Daily monitoring and management
- Sharing URLs with team members

---

## Makefile Targets

The `Makefile` provides convenient shortcuts for common operations.

### Setup & Bootstrap

```bash
make setup                   # Run interactive setup script
make bootstrap              # Bootstrap all target servers
make bootstrap-host HOST=server-01  # Bootstrap specific host
```

### Deployment

```bash
make deploy                 # Deploy to all target servers
make deploy-host HOST=server-01     # Deploy to specific host
make deploy-control         # Deploy centralized monitoring to control node
make deploy-check           # Dry run deployment (check mode)
```

### Operations

```bash
make update                 # Update all servers (self-update from Git)
make update-host HOST=server-01     # Update specific host
make upgrade                # Upgrade Docker images on all servers
make upgrade-service SERVICE=netdata  # Upgrade specific service
make backup                 # Run backups on all servers
make backup-host HOST=server-01      # Run backup on specific host
make security               # Run security audit (Lynis)
make security-host HOST=server-01    # Run audit on specific host
make restart-all            # Restart all Docker services
```

### Testing & Quality

```bash
make test                   # Run all Molecule tests
make test-role ROLE=common  # Test specific role
make lint                   # Run ansible-lint and yamllint
make syntax-check           # Check playbook syntax
```

### UI & Monitoring

```bash
make ui                     # List all service URLs
make ui-all                 # Open all UIs in browser
make ui-dockge              # Open Dockge
make ui-netdata             # Open Netdata
make ui-uptime              # Open Uptime Kuma
```

### Vault Management

```bash
make vault-init             # Initialize Ansible Vault
make vault-edit             # Edit vault file (default: group_vars/vault.yml)
make vault-edit FILE=custom.yml     # Edit custom vault file
make vault-view             # View vault file (read-only)
make vault-status           # Check vault status
make vault-validate         # Validate vault can be decrypted
make vault-rekey            # Change vault password
```

### Status & Information

```bash
make status                 # Show service status on all hosts
make status-host HOST=server-01     # Show status on specific host
make ping                   # Ping all hosts
make ping-host HOST=server-01       # Ping specific host
make list-hosts             # List all hosts in inventory
make disk-space             # Check disk space on all hosts
make version                # Show version information
```

### Dependencies

```bash
make install-deps           # Install all dependencies
make install-test-deps      # Install testing dependencies
```

### Cleanup

```bash
make clean                  # Clean up test artifacts
make clean-logs             # Clean up log files
make clean-docker           # Clean up unused Docker resources
```

---

## Examples & Workflows

### First-Time Setup Workflow

```bash
# 1. Clone repository on your command node (laptop/desktop)
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# 2. Run interactive setup
make setup
# OR
./setup.sh

# 3. Follow prompts to configure servers
# - Enter target server IPs
# - Configure services (monitoring, backups, security)
# - Set up secrets in vault

# 4. Access services
make ui
```

### Adding a New Server

```bash
# 1. Bootstrap the new server (run on target OR from command node)
# Option A: On target server
ssh user@new-server
sudo ./bootstrap-target.sh

# Option B: From command node via Ansible
make bootstrap-host HOST=new-server

# 2. Add to inventory/hosts.yml
vim inventory/hosts.yml

# 3. Deploy to new server
make deploy-host HOST=new-server

# 4. Verify deployment
make status-host HOST=new-server
make ui
```

### Monthly Maintenance Workflow

```bash
# 1. Update configuration from Git
make update

# 2. Upgrade Docker images
make upgrade

# 3. Run security audit
make security

# 4. Check backup status
make backup

# 5. Verify all services
make status

# 6. Check disk space
make disk-space

# 7. Clean up old Docker resources
make clean-docker
```

### Development & Testing Workflow

```bash
# 1. Make changes to roles/playbooks
vim roles/common/tasks/main.yml

# 2. Run linting
make lint

# 3. Check syntax
make syntax-check

# 4. Test specific role
make test-role ROLE=common

# 5. Test all roles
make test

# 6. Deploy to test server
make deploy-host HOST=test-server

# 7. Verify changes
make status-host HOST=test-server
```

### Emergency Procedures

```bash
# Immediate backup
make backup

# Restart all services
make restart-all

# Check service status
make status

# View logs (via Ansible ad-hoc)
ansible all -m shell -a "journalctl -n 100 --no-pager"

# Security audit
make security
```

### Troubleshooting Workflow

```bash
# 1. Check connectivity
make ping

# 2. Check service status
make status

# 3. Check disk space
make disk-space

# 4. Open UIs to verify services
make ui-all

# 5. Run in verbose mode
make deploy ANSIBLE_OPTS="-vvv"

# 6. Dry run to see what would change
make deploy-check
```

---

## Environment Variables

You can customize behavior with environment variables:

```bash
# Use custom inventory file
INVENTORY=inventory/prod.yml make deploy

# Use custom Ansible options
ANSIBLE_OPTS="-vvv" make deploy

# Use custom vault password file
VAULT_PASSWORD_FILE=.vault_prod make vault-edit
```

---

## Script Locations

```
Server-Helper/
├── setup.sh                      # Interactive setup wizard
├── bootstrap-target.sh           # Target server bootstrap
├── upgrade.sh                    # Docker image upgrade script
├── Makefile                      # Common operation shortcuts
└── scripts/
    ├── open-ui.sh                # UI launcher
    ├── vault.sh                  # Vault management
    ├── vault-edit.sh             # Edit vault files
    ├── vault-view.sh             # View vault files
    ├── vault-encrypt.sh          # Encrypt files
    ├── vault-decrypt.sh          # Decrypt files
    ├── vault-rekey.sh            # Change vault password
    ├── test-all-roles.sh         # Test all roles
    └── test-single-role.sh       # Test specific role
```

---

## Tips & Best Practices

### General Tips

1. **Always use `make help`** to see available commands
2. **Use dry-run modes** before making changes: `make deploy-check`
3. **Test on single host first** before deploying to all: `make deploy-host HOST=test`
4. **Keep scripts executable**: `chmod +x *.sh scripts/*.sh`
5. **Use verbose mode for debugging**: `ANSIBLE_OPTS="-vvv" make deploy`

### Upgrade Best Practices

1. **Schedule maintenance windows** for upgrades
2. **Use `--dry-run` first** to preview changes
3. **Upgrade one service at a time** for critical systems
4. **Monitor services** after upgrade
5. **Keep old images temporarily** (don't clean immediately)

### UI Script Tips

1. **Bookmark the list command**: `make ui` for quick reference
2. **Use SSH tunnels** for remote access to localhost services
3. **Configure reverse proxy** for HTTPS access
4. **Share URLs with team** using `make ui`

### Makefile Tips

1. **Tab completion**: Use shell completion for `make` targets
2. **Chain commands**: `make deploy && make status`
3. **Custom variables**: `make deploy HOST=server-01 ANSIBLE_OPTS="-v"`
4. **Dry run everything**: Add `--check` to ANSIBLE_OPTS

---

## Troubleshooting

### Scripts not executable

```bash
chmod +x setup.sh bootstrap-target.sh upgrade.sh
chmod +x scripts/*.sh
```

### Make targets not found

```bash
# Ensure you're in the project root
cd Server-Helper

# Verify Makefile exists
ls -la Makefile

# Run make help
make help
```

### Browser not opening

The UI script should detect your OS automatically, but if it fails:

```bash
# Manually get URLs
make ui

# Copy and paste URLs into browser
```

### Ansible connectivity issues

```bash
# Test connectivity
make ping

# Check inventory
make list-hosts

# Verify SSH access
ssh ansible@server-ip
```

---

## Next Steps

- **Setup Guide**: [docs/guides/setup-script.md](../guides/setup-script.md)
- **Vault Guide**: [docs/guides/vault.md](../guides/vault.md)
- **Testing Guide**: [docs/testing.md](../testing.md)
- **Contributing**: [CONTRIBUTING.md](../../CONTRIBUTING.md)

---

**Questions or issues?**
- [GitHub Issues](https://github.com/thelasttenno/Server-Helper/issues)
- [Documentation](https://github.com/thelasttenno/Server-Helper/wiki)
