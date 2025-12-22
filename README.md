# Server Helper Setup Script

A comprehensive server management script for Ubuntu 24.04.3 LTS that automates NAS mounting, Docker/Dockge installation, system monitoring, backups, updates, and security hardening.

## 🌟 New in Version 2.2

- **🔍 Pre-Installation Detection**: Automatically detects existing installations and offers cleanup options
- **🐛 Debug Mode**: Comprehensive debug logging for troubleshooting
- **💾 Configuration Backup**: Automatic backup of all system configuration files
- **🧹 Selective Removal**: Choose which components to remove during reinstall
- **📊 Enhanced Logging**: Detailed function-level debug output

---

## 🌟 Features

- **NAS Management**: Automatic NAS mounting with credential management
- **Docker & Dockge**: Automated installation and configuration
- **Monitoring**: 24/7 service monitoring with auto-recovery
- **Backups**: Scheduled Dockge + config backups to NAS with retention management
- **System Updates**: Automated system updates with scheduled reboots
- **Security**: Comprehensive security auditing and hardening (fail2ban, UFW, SSH)
- **Disk Management**: Automatic disk cleanup and space monitoring
- **Uptime Kuma Integration**: Push monitor heartbeats
- **Auto-Start**: Systemd service for boot-time startup
- **Pre-Install Check**: Detects and manages existing installations

---

## 📦 Installation

### Quick Install

```bash
# 1. Download/clone the script
sudo git clone https://github.com/thelasttenno/Server-Helper.git
cd Server-Helper

# 2. Make executable
sudo chmod +x server_helper_setup.sh

# 3. First run (creates config file)
sudo ./server_helper_setup.sh
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

### Run Setup (with Pre-Installation Check)

```bash
# Run full setup
sudo ./server_helper_setup.sh setup

# The script will:
# 1. Check for existing installations
# 2. Offer cleanup options if found
# 3. Mount NAS
# 4. Install Docker & Dockge
# 5. Create initial config backup
# 6. Optionally enable auto-start
```

---

## 🆕 Pre-Installation Detection

### What Gets Detected

When you run `setup` or `check-install`, the script automatically checks for:

1. **Systemd Service** - Existing server-helper.service
2. **NAS Mounts** - CIFS mounts in fstab and currently mounted
3. **Dockge Installation** - /opt/dockge directory and containers
4. **Docker Installation** - Docker engine and running containers
5. **Configuration Files** - Existing server-helper.conf
6. **Backups** - Existing backup directories

### Cleanup Options

When an existing installation is detected, you'll see:

```
═══════════════════════════════════════════════════════
         EXISTING INSTALLATION DETECTED
═══════════════════════════════════════════════════════

Installation Component Status:
  ✓ Systemd Service
  ✓ NAS Mounts
  ✓ Dockge
  ✓ Docker
  ✓ Configuration File
  ✓ Existing Backups

What would you like to do?

1) Continue with existing installation (skip setup)
2) Remove and reinstall (clean slate)
3) Selective cleanup (choose components)
4) Cancel and exit

Choice [1-4]:
```

#### Option 1: Continue
- Keeps everything as-is
- Useful for updates or configuration changes

#### Option 2: Complete Removal
- Removes ALL components
- Creates backups before removal (with confirmation)
- Fresh installation

#### Option 3: Selective Cleanup
- Choose which components to remove:
  - Remove systemd service?
  - Remove Dockge installation?
  - Cleanup NAS mounts?
  - Remove Docker? (requires extra confirmation)
- Keep what you want, remove what you don't

#### Option 4: Cancel
- Exits without making any changes

### Manual Pre-Check

```bash
# Check for existing installation without running setup
sudo ./server_helper_setup.sh check-install

# Remove existing installation components
sudo ./server_helper_setup.sh remove-install
```

---

## 🐛 Debug Mode

### Enable Debug Logging

```bash
# Run any command with debug output
DEBUG=true sudo ./server_helper_setup.sh <command>

# Examples:
DEBUG=true sudo ./server_helper_setup.sh setup
DEBUG=true sudo ./server_helper_setup.sh backup
DEBUG=true sudo ./server_helper_setup.sh mount-nas
```

### What Debug Mode Shows

Debug mode provides detailed logging for:

- **Function Entry/Exit**: See when functions start and end
- **Variable Values**: Track variable states and changes
- **Decision Points**: See which code paths are taken
- **File Operations**: Monitor file creation, copying, deletion
- **Network Calls**: Track API calls and network operations
- **Command Execution**: See exact commands being run
- **Error Context**: More detailed error information

### Debug Output Example

```
[2024-12-21 10:30:45] DEBUG: backup_dockge() - Starting Dockge backup
[2024-12-21 10:30:45] DEBUG: backup_dockge() - Backup file: /mnt/nas/dockge_backups/dockge_backup_20241221_103045.tar.gz
[2024-12-21 10:30:45] DEBUG: backup_dockge() - Source directory: /opt/dockge
[2024-12-21 10:30:45] DEBUG: backup_dockge() - Creating Dockge tarball
[2024-12-21 10:30:47] DEBUG: backup_dockge() - Dockge backup successful
[2024-12-21 10:30:47] DEBUG: backup_dockge() - Triggering automatic config backup
[2024-12-21 10:30:47] DEBUG: backup_config_files() - Starting configuration backup
```

### Debug Log File

All debug output is also saved to:
```
/var/log/server-helper/server-helper.log
```

---

## 💾 Configuration Backup Feature

### What Gets Backed Up

The script automatically backs up critical configuration files:

**System Files:**
- `/etc/fstab` - Filesystem mounts
- `/etc/hosts` - Host file
- `/etc/hostname` - System hostname
- `/etc/ssh/sshd_config` - SSH configuration
- `/etc/fail2ban/jail.local` - fail2ban rules
- `/etc/ufw/ufw.conf` - Firewall settings

**Directories:**
- `/etc/docker/` - Docker configuration
- `/etc/apt/sources.list.d/` - APT sources
- `/etc/systemd/system/server-helper.service` - Service file

**Credentials:**
- `/root/.nascreds_*` - NAS credentials
- Server Helper configuration file

### When Backups Occur

1. **Automatic**: Every time you run `backup` (Dockge backup)
2. **Manual**: Run `backup-config` command
3. **During Setup**: After successful installation
4. **Before Restore**: Emergency backup created automatically

### Backup Commands

```bash
# Backup only configuration files
sudo ./server_helper_setup.sh backup-config

# Backup Dockge (includes config automatically)
sudo ./server_helper_setup.sh backup

# Backup everything explicitly
sudo ./server_helper_setup.sh backup-all

# List all backups (Dockge + Config)
sudo ./server_helper_setup.sh list-backups

# Show what's in a config backup
sudo ./server_helper_setup.sh show-manifest /path/to/config_backup_xxx.tar.gz
```

### Restore Configuration

```bash
# Restore configuration from backup
sudo ./server_helper_setup.sh restore-config

# Select backup:
# - Type filename
# - Or type 'latest' for most recent

# The script will:
# 1. Show backup manifest
# 2. Ask for confirmation
# 3. Create emergency backup
# 4. Restore files
# 5. Show what was restored
```

### Backup Locations

```
NAS (Primary):
/mnt/nas/dockge_backups/
├── dockge_backup_20241221_120000.tar.gz
├── dockge_backup_20241221_180000.tar.gz
└── config/
    ├── config_backup_20241221_120005.tar.gz
    └── config_backup_20241221_180005.tar.gz

Local (Fallback):
/opt/dockge_backups_local/
└── config/
```

---

## 🚀 Usage

### Initial Setup Workflow

```bash
# 1. Create and configure
sudo ./server_helper_setup.sh              # Creates config, runs pre-check
sudo ./server_helper_setup.sh edit-config  # Edit settings
sudo ./server_helper_setup.sh setup        # Run setup

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
| `setup` | Run full setup with pre-installation check |
| `monitor` | Start monitoring in foreground |

**Examples:**
```bash
sudo ./server_helper_setup.sh setup       # Full setup with detection
DEBUG=true sudo ./server_helper_setup.sh setup  # With debug logging
sudo ./server_helper_setup.sh monitor     # Manual monitoring
```

---

### 🔍 Installation Management (NEW)

| Command | Description |
|---------|-------------|
| `check-install` | Check for existing installation |
| `remove-install` | Remove all existing components |

**Examples:**
```bash
# Check what's installed
sudo ./server_helper_setup.sh check-install

# Remove everything
sudo ./server_helper_setup.sh remove-install
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
| `backup` | Create Dockge backup (includes config auto) |
| `backup-config` | Backup configuration files only (NEW) |
| `backup-all` | Backup everything explicitly |
| `restore` | Restore Dockge from backup (interactive) |
| `restore-config` | Restore configuration from backup (NEW) |
| `list-backups` | List all available backups |
| `show-manifest` | Show backup contents (NEW) |

**Examples:**
```bash
# Backup operations
sudo ./server_helper_setup.sh backup              # Dockge + Config
sudo ./server_helper_setup.sh backup-config       # Config only
sudo ./server_helper_setup.sh backup-all          # Explicit all

# View backups
sudo ./server_helper_setup.sh list-backups
sudo ./server_helper_setup.sh show-manifest /path/to/backup.tar.gz

# Restore operations
sudo ./server_helper_setup.sh restore             # Restore Dockge
sudo ./server_helper_setup.sh restore-config      # Restore config

# Debug backup
DEBUG=true sudo ./server_helper_setup.sh backup
```

**Automatic Backups:**
- Runs every 6 hours during monitoring
- Stored on NAS: `$NAS_MOUNT_POINT/dockge_backups/`
- Config backups: `$NAS_MOUNT_POINT/dockge_backups/config/`
- Auto-cleanup: Deletes backups older than 30 days (configurable)
- Emergency backups created before any restore

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
DEBUG=true sudo ./server_helper_setup.sh clean-disk  # With debug
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
DEBUG=true sudo ./server_helper_setup.sh update  # With debug
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
DEBUG=true sudo ./server_helper_setup.sh security-audit  # With debug
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

# Debug
DEBUG="false"
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
├── server_helper_setup.sh    # Main script
├── server-helper.conf         # Configuration (chmod 600)
└── lib/                       # Library modules
    ├── core.sh               # Core utilities (enhanced debug)
    ├── config.sh             # Configuration management
    ├── validation.sh         # Input validation
    ├── preinstall.sh         # Pre-installation detection (NEW)
    ├── nas.sh                # NAS management
    ├── docker.sh             # Docker/Dockge
    ├── backup.sh             # Backup/restore (enhanced)
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

/mnt/nas/dockge_backups/
├── dockge_backup_20241221_120000.tar.gz
├── dockge_backup_20241221_180000.tar.gz
└── config/
    ├── config_backup_20241221_120005.tar.gz
    └── config_backup_20241221_180005.tar.gz

/opt/dockge_backups_local/    # Fallback location
└── config/

/etc/systemd/system/
└── server-helper.service      # Systemd service

/var/log/server-helper/
├── server-helper.log          # Main log (includes debug)
└── error.log                  # Error log

/root/
├── .nascreds_*                # NAS credentials (chmod 600)
└── emergency_*_backup_*.tar.gz  # Emergency backups
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

# With debug for detailed info
DEBUG=true sudo ./server_helper_setup.sh security-audit
```

---

## 🔧 Troubleshooting

### Enable Debug Mode First

For any issue, enable debug mode to see detailed information:
```bash
DEBUG=true sudo ./server_helper_setup.sh <command>
```

### NAS Not Mounting

```bash
# Check with debug
DEBUG=true sudo ./server_helper_setup.sh mount-nas

# Check NAS connectivity
ping $NAS_IP

# Verify credentials
sudo ./server_helper_setup.sh show-config

# Check mount manually
sudo mount -t cifs //$NAS_IP/$NAS_SHARE /mnt/nas -o username=xxx,password=xxx
```

### Service Not Starting

```bash
# Check service status with debug
DEBUG=true sudo ./server_helper_setup.sh service-status

# View detailed logs
sudo journalctl -u server-helper -n 50

# Check all logs
tail -f /var/log/server-helper/server-helper.log
```

### Dockge Not Accessible

```bash
# Check with debug
DEBUG=true sudo ./server_helper_setup.sh monitor

# Check Docker status
sudo docker ps

# Check Dockge logs
cd /opt/dockge
sudo docker compose logs

# Restart Dockge
sudo docker compose restart
```

### Pre-Installation Check Issues

```bash
# Run manual check
sudo ./server_helper_setup.sh check-install

# With debug output
DEBUG=true sudo ./server_helper_setup.sh check-install

# Remove all components
sudo ./server_helper_setup.sh remove-install
```

### Backup/Restore Issues

```bash
# Check backups with debug
DEBUG=true sudo ./server_helper_setup.sh list-backups

# Show what's in a backup
sudo ./server_helper_setup.sh show-manifest /path/to/backup.tar.gz

# Restore with debug
DEBUG=true sudo ./server_helper_setup.sh restore-config
```

---

## 📊 Quick Reference Card

### Most Common Commands

```bash
# Status & Logs
sudo ./server_helper_setup.sh service-status
sudo ./server_helper_setup.sh logs
DEBUG=true sudo ./server_helper_setup.sh service-status  # With debug

# Installation
sudo ./server_helper_setup.sh check-install    # Check existing
sudo ./server_helper_setup.sh setup            # Install (with detection)

# Backups
sudo ./server_helper_setup.sh backup           # Dockge + Config
sudo ./server_helper_setup.sh backup-config    # Config only
sudo ./server_helper_setup.sh list-backups     # List all

# Maintenance
sudo ./server_helper_setup.sh check-updates
sudo ./server_helper_setup.sh clean-disk
sudo ./server_helper_setup.sh security-audit

# Service Control
sudo systemctl start server-helper
sudo systemctl stop server-helper
sudo systemctl restart server-helper
```

### Emergency Commands

```bash
# Stop monitoring immediately
sudo ./server_helper_setup.sh stop

# Check what's installed
sudo ./server_helper_setup.sh check-install

# Restore from latest backup
sudo ./server_helper_setup.sh restore
# Type: latest

# Restore config from latest
sudo ./server_helper_setup.sh restore-config
# Type: latest

# Complete removal
sudo ./server_helper_setup.sh remove-install

# Manual NAS unmount
sudo umount -f /mnt/nas
```

### Debug Mode Examples

```bash
# Setup with debug
DEBUG=true sudo ./server_helper_setup.sh setup

# Backup with debug
DEBUG=true sudo ./server_helper_setup.sh backup

# Monitor with debug
DEBUG=true sudo ./server_helper_setup.sh monitor

# Any command with debug
DEBUG=true sudo ./server_helper_setup.sh <command>
```

---

## 📝 Changelog

### Version 2.2.0 (Current)
- ✨ Added pre-installation detection system
- ✨ Added comprehensive debug logging to all functions
- ✨ Added configuration file backup feature
- ✨ Added selective component removal
- ✨ Added backup manifest viewing
- ✨ Enhanced error handling and logging
- 🐛 Fixed module loading order
- 🐛 Fixed NAS array handling
- 📚 Comprehensive README update

### Version 2.1.0
- ✨ Added configuration backup to Dockge backups
- ✨ Added backup manifest generation
- 🐛 Improved backup reliability

### Version 2.0.0
- ✨ Modular architecture
- ✨ Interactive menu system
- ✨ Comprehensive monitoring

---

## 📝 License

GNU General Public License v3.0 - See LICENSE file for details

## 🤝 Support

For issues, questions, or contributions:
- Check debug logs: `tail -f /var/log/server-helper/server-helper.log`
- Run with debug: `DEBUG=true sudo ./server_helper_setup.sh <command>`
- Check pre-installation status: `sudo ./server_helper_setup.sh check-install`

---

## ✨ Summary

**Server Helper v2.2** is your all-in-one solution for:
- 🔧 Automated server setup with installation detection
- 📊 24/7 monitoring with comprehensive debug logging
- 💾 Reliable backups (Dockge + Configuration)
- 🔒 Security hardening and auditing
- 🔄 Update management
- 🧹 Disk maintenance
- 🐛 Detailed troubleshooting capabilities

**Total Commands: 35+** | **Auto-Start: ✅** | **Security: ✅** | **Monitoring: ✅** | **Debug Mode: ✅**
