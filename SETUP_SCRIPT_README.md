# Server Helper - Automated Setup Script

## Overview

The `setup.sh` script provides a **fully automated installation** of Server Helper v1.0.0. It handles all dependency installation and configuration through interactive prompts.

## Features

- ✅ **Automatic dependency installation** (Ansible, Python packages, Galaxy roles)
- ✅ **Interactive configuration prompts** for all settings
- ✅ **Automatic vault creation** with encrypted secrets
- ✅ **Pre-flight checks** before installation
- ✅ **Colored output** for better readability
- ✅ **Detailed logging** to `setup.log`
- ✅ **One-command setup** - from zero to fully configured server

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# 2. Run the setup script
./setup.sh

# 3. Follow the interactive prompts
# The script will:
#   - Install all dependencies
#   - Prompt for configuration
#   - Create inventory and config files
#   - Set up encrypted vault
#   - Run the Ansible playbook
```

## What the Script Does

### 1. System Checks
- Verifies you're not running as root
- Checks for sudo privileges
- Detects OS version (Ubuntu 24.04 LTS recommended)

### 2. Dependency Installation
- **System packages**: `ansible`, `python3-pip`, `git`, `curl`, `wget`, `sshpass`
- **Python packages**: From `requirements.txt`
- **Ansible Galaxy**: Collections and roles from `requirements.yml`

### 3. Configuration Prompts

The script will prompt you for:

#### System Configuration
- Server hostname (default: `server-01`)
- Timezone (default: `America/New_York`)

#### NAS Configuration (Optional)
- Enable NAS mounts (y/N)
- NAS IP address
- NAS share name
- NAS mount point
- NAS username and password

#### Backup Configuration
- Enable backups (Y/n)
- Backup schedule (cron format)
- Backup destinations:
  - NAS backup (Y/n)
  - Local backup (Y/n)
  - S3 backup (y/N)
- Repository passwords for each destination

#### Monitoring Configuration
- Enable Netdata (Y/n)
  - Port (default: 19999)
  - Netdata Cloud claim token (optional)
- Enable Uptime Kuma (Y/n)
  - Port (default: 3001)

#### Container Management
- Enable Dockge (Y/n)
  - Port (default: 5001)

#### Security Configuration
- Enable fail2ban (Y/n)
- Enable UFW firewall (Y/n)
- Enable SSH hardening (Y/n)
  - SSH port (default: 22)
  - Disable password authentication (Y/n)
  - Disable root login (Y/n)
- Enable Lynis security scanning (Y/n)

#### Target Server
- Target server IP/hostname (default: localhost)
- SSH username (default: current user)

### 4. File Generation

The script automatically creates:

- **`inventory/hosts.yml`**: Ansible inventory with your server details
- **`group_vars/all.yml`**: Main configuration file with all settings
- **`group_vars/vault.yml`**: Encrypted vault with secrets
- **`.vault_password`**: Vault password file (keep this secure!)

### 5. Playbook Execution

After configuration, the script:
- Runs pre-flight checks
- Shows a summary of what will be installed
- Asks for final confirmation
- Executes `ansible-playbook playbooks/setup.yml`
- Shows service URLs upon completion

## Configuration Examples

### Example 1: Minimal Setup (Local Server)
```
Hostname: homelab
Timezone: America/Los_Angeles
NAS: No
Backups: Local only
Monitoring: Netdata + Uptime Kuma
Dockge: Yes
Security: All enabled
Target: localhost
```

### Example 2: Full Setup (Remote Server with NAS)
```
Hostname: production-server
Timezone: America/New_York
NAS: Yes (192.168.1.100/backup)
Backups: NAS + S3
Monitoring: Netdata + Uptime Kuma + Netdata Cloud
Dockge: Yes
Security: All enabled + SSH hardening
Target: 192.168.1.50
```

### Example 3: Development Setup
```
Hostname: dev-server
Timezone: UTC
NAS: No
Backups: Local only
Monitoring: Netdata only
Dockge: Yes
Security: Minimal (fail2ban only)
Target: localhost
```

## Default Values

The script provides sensible defaults for all prompts:

| Setting | Default |
|---------|---------|
| Hostname | `server-01` |
| Timezone | `America/New_York` |
| NAS | Disabled |
| Backups | Enabled |
| Backup Schedule | `0 2 * * *` (2 AM daily) |
| Netdata | Enabled on port 19999 |
| Uptime Kuma | Enabled on port 3001 |
| Dockge | Enabled on port 5001 |
| fail2ban | Enabled |
| UFW | Enabled |
| SSH Hardening | Enabled |
| SSH Port | 22 |
| Target Server | localhost |

Press Enter to accept defaults, or type a custom value.

## After Installation

Once the script completes, you'll see:

### Service URLs
```
Access your services:
  Dockge:      http://your-server:5001
  Netdata:     http://your-server:19999
  Uptime Kuma: http://your-server:3001
```

### Next Steps
1. **Change default passwords** - Login to each service and change default admin passwords
2. **Configure Uptime Kuma** - Set up notification endpoints (Discord, Telegram, Email, etc.)
3. **Verify backups** - Check that Restic repositories are initialized correctly
4. **Review security** - Run `ansible-playbook playbooks/security.yml` for security audit

### Useful Commands
```bash
# View service status
ansible all -m shell -a "docker ps"

# Run backup manually
ansible-playbook playbooks/backup.yml

# Security audit
ansible-playbook playbooks/security.yml

# Update system
ansible-playbook playbooks/update.yml

# View logs
tail -f setup.log
```

## Troubleshooting

### Script Fails During Dependency Installation
```bash
# Manually install dependencies
sudo apt-get update
sudo apt-get install -y ansible python3-pip git

# Re-run script
./setup.sh
```

### Ansible Connectivity Issues
```bash
# Test SSH connectivity
ssh user@target-server

# Verify SSH key is added
ssh-copy-id user@target-server

# Run script again
./setup.sh
```

### Playbook Execution Fails
```bash
# Check the log file
tail -f setup.log

# Run playbook manually with verbose output
ansible-playbook playbooks/setup.yml -vvv

# Check specific task
ansible-playbook playbooks/setup.yml --start-at-task="Task Name"
```

### Vault Password Issues
```bash
# Regenerate vault password
openssl rand -base64 32 > .vault_password
chmod 600 .vault_password

# Re-encrypt vault file
ansible-vault rekey group_vars/vault.yml
```

## Advanced Usage

### Non-Interactive Mode

You can pre-create configuration files to skip prompts:

```bash
# Create files manually
cp inventory/hosts.example.yml inventory/hosts.yml
cp group_vars/all.example.yml group_vars/all.yml

# Edit files with your values
nano inventory/hosts.yml
nano group_vars/all.yml

# Create vault
ansible-vault create group_vars/vault.yml

# Run playbook directly
ansible-playbook playbooks/setup.yml
```

### Customizing the Script

Edit `setup.sh` to:
- Change default values
- Add custom prompts
- Skip certain configuration sections
- Add additional validation

### Running on Remote Server

```bash
# On control node (your laptop)
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
./setup.sh

# When prompted for target:
# - Enter remote server IP
# - Enter SSH username
# - Ensure SSH key is configured
```

### Running Locally

```bash
# On the server itself
git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper
./setup.sh

# When prompted for target:
# - Use "localhost" or "127.0.0.1"
# - Use your current username
```

## Security Notes

1. **Vault Password**: Keep `.vault_password` secure. Never commit to Git.
2. **Passwords**: Use strong, unique passwords for all services
3. **SSH Keys**: Prefer SSH key authentication over passwords
4. **Firewall**: The script configures UFW - ensure SSH port is allowed
5. **Default Credentials**: Change all default admin passwords after installation

## Log Files

The script creates several log files:

- **`setup.log`**: Complete setup script execution log
- **`/var/log/ansible-pull.log`**: Ansible pull/update logs (on target server)
- **`/var/log/restic-backup.log`**: Backup logs (on target server)
- **`/var/log/lynis/report.dat`**: Security audit reports (on target server)

## Support

If you encounter issues:

1. Check `setup.log` for errors
2. Review the [main README](README.md)
3. Consult [VAULT_GUIDE.md](VAULT_GUIDE.md) for vault issues
4. Open an issue: https://github.com/thelasttenno/Server-Helper/issues

## What Gets Installed

### System Packages
- `ansible` - Automation engine
- `python3-pip` - Python package manager
- `git` - Version control
- `curl`, `wget` - Download tools
- `sshpass` - SSH password utility

### Ansible Collections
- `community.general` - General-purpose modules
- `community.docker` - Docker management
- `ansible.posix` - POSIX utilities

### Ansible Roles
- `geerlingguy.docker` - Docker installation
- `geerlingguy.security` - Security hardening
- `geerlingguy.pip` - Python pip installation
- `weareinteractive.ufw` - UFW firewall
- `robertdebock.fail2ban` - fail2ban configuration

### Docker Containers (via Dockge)
- **Dockge** - Container stack manager
- **Netdata** - System monitoring
- **Uptime Kuma** - Uptime monitoring
- **Watchtower** - Auto-updates (optional)

### System Services (via systemd)
- `restic-backup.service` / `restic-backup.timer` - Scheduled backups
- `lynis-scan.service` / `lynis-scan.timer` - Security scans
- `ansible-pull.service` / `ansible-pull.timer` - Auto-updates

## Comparison: Manual vs Automated Setup

| Task | Manual | setup.sh |
|------|--------|----------|
| Install Ansible | 5 commands | Automatic |
| Install dependencies | 10+ commands | Automatic |
| Create inventory | Manual editing | Interactive prompts |
| Create config | Copy + edit 370 lines | Interactive prompts |
| Create vault | 5 commands + editing | Automatic |
| Run playbook | 1 command | Automatic |
| **Total time** | 30-60 minutes | 5-10 minutes |
| **Error prone** | High | Low |
| **Reproducible** | Medium | High |

## License

GNU General Public License v3.0

---

**Made with ❤️ for Ubuntu 24.04 LTS**
