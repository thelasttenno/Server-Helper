# Server Helper Setup Script

**Version 0.2.3 - Integration Update**

A comprehensive server management script for Ubuntu 24.04.3 LTS that automates NAS mounting, Docker/Dockge installation, system monitoring, backups, updates, and security hardening.

## 🌟 Features

- **NAS Management**: Automatic NAS mounting with credential management
- **🆕 Emergency Unmount**: Force unmount stuck NAS shares with 4 fallback methods
- **Docker & Dockge**: Automated installation and configuration
- **🆕 Pre-Installation Detection**: Detects and manages existing installations
- **Monitoring**: 24/7 service monitoring with auto-recovery
- **Backups**: Scheduled Dockge backups to NAS with retention management (includes config backup)
- **System Updates**: Automated system updates with scheduled reboots
- **Security**: Comprehensive security auditing and hardening (fail2ban, UFW, SSH)
- **Disk Management**: Automatic disk cleanup and space monitoring
- **Uptime Kuma Integration**: Push monitor heartbeats
- **Auto-Start**: Systemd service for boot-time startup
- **Debug Mode**: Enhanced debugging with detailed logging
- **🆕 Installation Management**: Check and clean existing components

---

## 📦 Installation

### Quick Install

```bash
# 1. Download/create the script
sudo git clone https://github.com/thelasttenno/Server-Helper.git

# 2. Make executable
sudo chmod +x server_helper_setup.sh

# 3. First run (creates config file)
sudo bash /opt/Server-Helper/server_helper_setup.sh
```

### Configure

```bash
# Edit configuration file with your settings
sudo nano server-helper.conf

# Required settings:
# - NAS_IP
# - NAS_SHARE
# - NAS_USERNAME
# - NAS_PASSWORD

# Validate configuration
sudo ./server_helper_setup.sh validate-config
```

### Run Setup

```bash
# Run full setup (includes pre-installation check)
sudo bash /opt/Server-Helper/server_helper_setup.sh

# Script will:
# - Check for existing installations
# - Offer cleanup options if found
# - Mount NAS
# - Install Docker & Dockge
# - Create initial configuration backup
# - Optionally enable auto-start
# - Start monitoring
```

---

## 🆕 What's New in v0.2.3

### Pre-Installation Detection (Integrated)

Automatically detects existing installations during setup to prevent conflicts:

```bash
# Run standalone check
sudo ./server_helper_setup.sh check-install

# Automatically runs during setup
sudo ./server_helper_setup.sh setup
```

**Detects:**
- Systemd services
- NAS mounts and credentials
- Dockge installations
- Docker installations
- Configuration files
- Existing backups

**Options when existing installation found:**
1. Keep existing installation (skip setup)
2. Remove and reinstall (clean slate)
3. Selective cleanup (choose components)
4. Cancel and exit

### Emergency NAS Unmount (NEW)

Force unmount stuck NAS shares when normal methods fail:

```bash
# Emergency unmount default mount point
sudo ./server_helper_setup.sh unmount-nas

# Specify custom mount point
sudo ./server_helper_setup.sh unmount-nas /mnt/custom

# Also available in menu as option 21
```

**Features:**
- Detects processes using the mount
- Optional process termination
- 4 unmount methods (normal → lazy → force → force+lazy)
- Automatic fstab cleanup
- Credential file removal
- Detailed troubleshooting output

### Installation Management Commands

```bash
# Check what's installed
sudo ./server_helper_setup.sh check-install

# Clean existing components
sudo ./server_helper_setup.sh clean-install
```

**Menu items 36-37** provide access to these features in the interactive menu.

---

## 🐛 Debug Mode

### Overview

Debug mode provides detailed logging for troubleshooting and monitoring script execution. When enabled, it logs:

- Function entry and exit points
- Variable values and state
- File operations
- Network operations
- Command execution details
- Error conditions and recovery attempts

### Enabling Debug Mode

```bash
# Enable debug mode for a single command
DEBUG=true sudo ./server_helper_setup.sh <command>

# Examples:
DEBUG=true sudo ./server_helper_setup.sh monitor
DEBUG=true sudo ./server_helper_setup.sh backup
DEBUG=true sudo ./server_helper_setup.sh setup
```

### Persistent Debug Mode

To enable debug mode permanently, edit your configuration file:

```bash
sudo nano server-helper.conf

# Add or change:
DEBUG="true"
```

### Debug Output

Debug messages are displayed in blue and include:
- Timestamp
- Function name
- Operation details
- Status information

Example debug output:
```
[2024-12-21 10:30:45] DEBUG: [mount_nas] Starting NAS mount process
[2024-12-21 10:30:45] DEBUG: [mount_nas] Processing single NAS configuration
[2024-12-21 10:30:46] DEBUG: [mount_single_nas] IP: 192.168.1.100, Share: share, Mount: /mnt/nas
[2024-12-21 10:30:46] DEBUG: [mount_single_nas] Attempting mount with SMB 3.0
[2024-12-21 10:30:47] DEBUG: [mount_single_nas] Mount successful with SMB 3.0
[2024-12-21 10:30:47] DEBUG: [mount_nas] Mount process complete
```

### When to Use Debug Mode

- **Troubleshooting**: When operations fail unexpectedly
- **Development**: When modifying or extending the script
- **Monitoring**: When you need detailed operational insights
- **Support**: When seeking help with issues

---

## 🚀 Usage

### Initial Setup Workflow

```bash
# 1. Create and configure
sudo bash /opt/Server-Helper/server_helper_setup.sh           # Creates config
sudo ./server_helper_setup.sh edit-config  # Edit settings
sudo bash /opt/Server-Helper/server_helper_setup.sh             # Run setup

# 2. Enable auto-start (recommended)
sudo ./server_helper_setup.sh enable-autostart

# 3. Start monitoring
sudo ./server_helper_setup.sh start
```

### Daily Operations

```bash
# Check system status
sudo ./server_helper_setup.sh service-status

# View live logs
sudo ./server_helper_setup.sh logs

# Create manual backup
sudo ./server_helper_setup.sh backup

# Check for updates
sudo ./server_helper_setup.sh check-updates

# Run security audit
sudo ./server_helper_setup.sh security-audit
```

---

## 📋 Complete Command Reference

### 🔧 Configuration Management

| Command | Description |
|---------|-------------|
| `edit-config` | Edit configuration file with nano/vim |
| `show-config` | Display config (passwords masked) |
| `validate-config` | Validate configuration settings |

**Examples:**
```bash
sudo ./server_helper_setup.sh edit-config
sudo ./server_helper_setup.sh show-config
sudo ./server_helper_setup.sh validate-config
```

---

### 🚀 Setup & Monitoring

| Command | Description |
|---------|-------------|
| *(no args)* | Run full interactive setup |
| `monitor` | Start monitoring in foreground |

**Examples:**
```bash
sudo ./server_helper_setup.sh          # Full setup
sudo ./server_helper_setup.sh monitor  # Manual monitoring

# With debug mode
DEBUG=true sudo ./server_helper_setup.sh monitor
```

---

### ⚙️ Service Management (Auto-Start)

| Command | Description |
|---------|-------------|
| `enable-autostart` | Create systemd service for boot |
| `disable-autostart` | Remove systemd service |
| `start` | Start the service now |
| `stop` | Stop the service |
| `restart` | Restart the service |
| `service-status` | Show service status |
| `logs` | View live service logs |

**Examples:**
```bash
sudo ./server_helper_setup.sh enable-autostart
sudo ./server_helper_setup.sh start
sudo ./server_helper_setup.sh service-status
sudo ./server_helper_setup.sh logs

# Or use systemctl directly:
sudo systemctl status server-helper
sudo journalctl -u server-helper -f
```

---

### 💾 Backup & Restore

| Command | Description |
|---------|-------------|
| `backup` | Create manual backup to NAS |
| `backup-config` | Backup configuration files only |
| `backup-all` | Backup everything (Dockge + config) |
| `restore` | Restore from backup (interactive) |
| `restore-config` | Restore configuration files |
| `list-backups` | List all available backups |
| `show-manifest <file>` | Show backup contents |

**Examples:**
```bash
sudo ./server_helper_setup.sh backup
sudo ./server_helper_setup.sh backup-config
sudo ./server_helper_setup.sh backup-all
sudo ./server_helper_setup.sh list-backups
sudo ./server_helper_setup.sh restore

# With debug mode
DEBUG=true sudo ./server_helper_setup.sh backup
```

**Automatic Backups:**
- Runs every 6 hours during monitoring
- Stored on NAS: `$NAS_MOUNT_POINT/dockge_backups/`
- Auto-cleanup: Deletes backups older than 30 days (configurable)

---

### 🖥️ System Management

| Command | Description |
|---------|-------------|
| `set-hostname <name>` | Set system hostname |
| `show-hostname` | Display current hostname |

**Examples:**
```bash
sudo ./server_helper_setup.sh set-hostname docker-server-01
sudo ./server_helper_setup.sh show-hostname
```

---

### 🧹 Disk Management

| Command | Description |
|---------|-------------|
| `clean-disk` | Run disk cleanup manually |
| `disk-space` | Show disk usage information |

**Examples:**
```bash
sudo ./server_helper_setup.sh clean-disk
sudo ./server_helper_setup.sh disk-space

# With debug mode
DEBUG=true sudo ./server_helper_setup.sh clean-disk
```

**What Gets Cleaned:**
- APT cache and old packages
- Old kernel versions
- Docker (stopped containers, dangling images, unused volumes)
- System logs (keeps last 7 days)
- Temporary files

**Automatic Cleanup:**
- Triggers when disk usage exceeds 80% (configurable)
- Runs during monitoring checks

---

### 🔄 System Updates

| Command | Description |
|---------|-------------|
| `update` | Update system packages |
| `full-upgrade` | Full system upgrade (interactive) |
| `check-updates` | Check for available updates |
| `update-status` | Show detailed update status |
| `schedule-reboot [time]` | Schedule system reboot |

**Examples:**
```bash
sudo ./server_helper_setup.sh update
sudo ./server_helper_setup.sh check-updates
sudo ./server_helper_setup.sh schedule-reboot 03:00
sudo ./server_helper_setup.sh full-upgrade

# With debug mode
DEBUG=true sudo ./server_helper_setup.sh update
```

**Automatic Updates:**
- Enable in config: `AUTO_UPDATE_ENABLED="true"`
- Checks every 24 hours (configurable)
- Auto-reboot option available

---

### 🔒 Security & Compliance

| Command | Description |
|---------|-------------|
| `security-audit` | Run complete security audit |
| `security-status` | Show detailed security status |
| `security-harden` | Apply all security hardening |
| `setup-fail2ban` | Install/configure fail2ban |
| `setup-ufw` | Setup UFW firewall |
| `harden-ssh` | Harden SSH configuration |

**Examples:**
```bash
sudo ./server_helper_setup.sh security-audit
sudo ./server_helper_setup.sh security-status
sudo ./server_helper_setup.sh security-harden

# With debug mode
DEBUG=true sudo ./server_helper_setup.sh security-audit
```

**Security Audit Checks:**
- ✅ SSH configuration (root login, password auth)
- ✅ Firewall status (UFW)
- ✅ Intrusion prevention (fail2ban)
- ✅ File permissions
- ✅ User account security
- ✅ Docker security
- ✅ Automatic updates configured

**Security Hardening Includes:**
- **fail2ban**: Protects against brute force attacks
- **UFW Firewall**: Default deny with specific allows
- **SSH Hardening**: Disables password auth, root login
- **Unattended Upgrades**: Automatic security patches

---

## 📁 Configuration File

### Location
`/opt/Server-Helper/server-helper.conf`

### Required Settings

```bash
# NAS Configuration
NAS_IP="192.168.1.100"              # Your NAS IP address
NAS_SHARE="share"                    # Your NAS share name
NAS_USERNAME="your_username"         # NAS username
NAS_PASSWORD="your_password"         # NAS password
```

### Optional Settings

```bash
# Dockge
DOCKGE_PORT="5001"
DOCKGE_DATA_DIR="/opt/dockge"
BACKUP_DIR="$NAS_MOUNT_POINT/dockge_backups"
BACKUP_RETENTION_DAYS="30"

# Uptime Kuma (leave empty to disable)
UPTIME_KUMA_NAS_URL=""
UPTIME_KUMA_DOCKGE_URL=""
UPTIME_KUMA_SYSTEM_URL=""

# Automatic Features
DISK_CLEANUP_THRESHOLD="80"
AUTO_CLEANUP_ENABLED="true"
AUTO_UPDATE_ENABLED="false"
UPDATE_CHECK_INTERVAL="24"
AUTO_REBOOT_ENABLED="false"
REBOOT_TIME="03:00"

# Security
SECURITY_CHECK_ENABLED="true"
SECURITY_CHECK_INTERVAL="12"
FAIL2BAN_ENABLED="false"
UFW_ENABLED="false"
SSH_HARDENING_ENABLED="false"

# Debug (NEW in v0.2.2)
DEBUG="false"  # Set to "true" for detailed logging
```

---

## 🔄 Monitoring Features

### What Gets Monitored (Every 2 Minutes)

1. **NAS Connectivity**
   - Mount point status
   - Network accessibility
   - Auto-remount on failure

2. **Dockge Service**
   - Container running status
   - Web interface responsiveness
   - Auto-restart on failure

3. **Disk Usage**
   - Automatic cleanup at threshold
   - Real-time usage reporting

4. **System Updates**
   - Periodic update checks
   - Automatic installation (optional)
   - Scheduled reboots (optional)

5. **Security**
   - Periodic security audits
   - Issue detection and reporting

### Uptime Kuma Integration

Configure push monitor URLs in config file:
```bash
UPTIME_KUMA_NAS_URL="http://uptime-kuma:3001/api/push/abc123"
UPTIME_KUMA_DOCKGE_URL="http://uptime-kuma:3001/api/push/def456"
UPTIME_KUMA_SYSTEM_URL="http://uptime-kuma:3001/api/push/ghi789"
```

Monitors send:
- Status: `up` or `down`
- Messages: Detailed error information
- Heartbeat: Every 2 minutes

---

## 📂 File Structure

```
/opt/Server-Helper/
├── server_helper_setup.sh    # Main script (v0.2.2)
├── server-helper.conf         # Configuration (chmod 600)
└── lib/                       # Module library
    ├── core.sh               # Core utilities
    ├── config.sh             # Configuration management
    ├── validation.sh         # Input validation
    ├── nas.sh                # NAS management
    ├── docker.sh             # Docker & Dockge
    ├── backup.sh             # Backup & restore
    ├── disk.sh               # Disk management
    ├── updates.sh            # System updates
    ├── security.sh           # Security features
    ├── service.sh            # Systemd service
    ├── menu.sh               # Interactive menu
    └── uninstall.sh          # Uninstallation

/opt/dockge/
├── docker-compose.yml
├── data/
└── stacks/

/mnt/nas/
└── dockge_backups/
    ├── dockge_backup_20241220_120000.tar.gz
    ├── dockge_backup_20241220_180000.tar.gz
    └── config/
        ├── config_backup_20241220_120000.tar.gz
        └── config_backup_20241220_180000.tar.gz

/etc/systemd/system/
└── server-helper.service      # Systemd service

/root/
└── .nascreds                  # NAS credentials (chmod 600)

/var/log/server-helper/
├── server-helper.log          # Main log file
└── error.log                  # Error log file
```

---

## 🛡️ Security Best Practices

### 1. Protect Configuration File
```bash
sudo chmod 600 /opt/Server-Helper/server-helper.conf
```

### 2. Use SSH Keys
Before enabling SSH hardening:
```bash
# On your local machine
ssh-copy-id user@server

# Test SSH key login
ssh user@server

# Then enable hardening
sudo ./server_helper_setup.sh harden-ssh
```

### 3. Enable Security Features
```bash
# Edit config
FAIL2BAN_ENABLED="true"
UFW_ENABLED="true"
SSH_HARDENING_ENABLED="true"

# Apply hardening
sudo ./server_helper_setup.sh security-harden
```

### 4. Regular Audits
```bash
# Run security audit regularly
sudo ./server_helper_setup.sh security-audit

# With debug mode for detailed information
DEBUG=true sudo ./server_helper_setup.sh security-audit
```

---

## 🔧 Troubleshooting

### Using Debug Mode

For any troubleshooting, always enable debug mode first:

```bash
DEBUG=true sudo ./server_helper_setup.sh <command>
```

### NAS Not Mounting

```bash
# Check NAS connectivity with debug mode
DEBUG=true sudo ./server_helper_setup.sh mount-nas

# Manual check
ping $NAS_IP

# Verify credentials
sudo ./server_helper_setup.sh show-config

# Check mount manually
sudo mount -t cifs //$NAS_IP/$NAS_SHARE /mnt/nas -o username=xxx,password=xxx
```

### Service Not Starting

```bash
# Check service status with debug mode
DEBUG=true sudo ./server_helper_setup.sh service-status

# View detailed logs
sudo journalctl -u server-helper -n 50

# Verify script permissions
ls -l /opt/Server-Helper/server_helper_setup.sh
```

### Dockge Not Accessible

```bash
# Check Docker status with debug mode
DEBUG=true sudo ./server_helper_setup.sh service-status

# Check Dockge logs
cd /opt/dockge
sudo docker compose logs

# Restart Dockge
sudo docker compose restart
```

### Disk Space Issues

```bash
# Check disk usage with debug mode
DEBUG=true sudo ./server_helper_setup.sh disk-space

# Manual cleanup with debug
DEBUG=true sudo ./server_helper_setup.sh clean-disk

# Check Docker usage
sudo docker system df
sudo docker system prune -a
```

---

## 📊 Quick Reference Card

### Most Common Commands

```bash
# Status & Logs
sudo ./server_helper_setup.sh service-status
sudo ./server_helper_setup.sh logs

# Backups
sudo ./server_helper_setup.sh backup
sudo ./server_helper_setup.sh list-backups

# Maintenance
sudo ./server_helper_setup.sh check-updates
sudo ./server_helper_setup.sh clean-disk
sudo ./server_helper_setup.sh security-audit

# Service Control
sudo systemctl start server-helper
sudo systemctl stop server-helper
sudo systemctl restart server-helper

# With Debug Mode
DEBUG=true sudo ./server_helper_setup.sh <command>
```

### Emergency Commands

```bash
# Stop monitoring immediately
sudo ./server_helper_setup.sh stop

# Restore from latest backup
sudo ./server_helper_setup.sh restore
# Type: latest

# Disable auto-start
sudo ./server_helper_setup.sh disable-autostart

# Manual NAS unmount
sudo umount -f /mnt/nas

# Enable debug for troubleshooting
DEBUG=true sudo ./server_helper_setup.sh monitor
```

---

## 📝 Version History

### v0.2.2 - Enhanced Debug Edition (Current)
- ✨ Added comprehensive debug mode to all functions
- 📝 Enhanced logging with function-level tracing
- 🔍 Improved troubleshooting capabilities
- 📚 Updated README with debug mode documentation
- 🏷️ Standardized version numbering (SemVer)

### v0.2.1 - Config Backup Edition
- 💾 Added configuration file backup functionality
- 📦 Enhanced backup manifest with file listings
- 🔄 Automatic config backup with Dockge backups

### v0.2.0 - Modular Architecture
- 🏗️ Restructured into modular library system
- 📁 Organized code into separate functional modules
- 🔧 Improved maintainability and extensibility

---

## 📝 License

This script is provided under the GNU General Public License v3.0.

## 🤝 Support

For issues, questions, or contributions:
- Enable debug mode for detailed error information
- Check log files in `/var/log/server-helper/`
- Review the troubleshooting section
- Contact your system administrator

---

## ✨ Summary

**Server Helper v0.2.2** is your all-in-one solution for:
- 🔧 Automated server setup
- 📊 24/7 monitoring
- 💾 Reliable backups
- 🔒 Security hardening
- 🔄 Update management
- 🧹 Disk maintenance
- 🐛 Advanced debugging

**Total Commands: 31** | **Auto-Start: ✅** | **Security: ✅** | **Monitoring: ✅** | **Debug Mode: ✅**

---

**Made with ❤️ for Ubuntu 24.04.3 LTS**
