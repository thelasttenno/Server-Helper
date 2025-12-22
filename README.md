# Server Helper v2.1

**Enhanced Config Backup Edition**

A comprehensive, modular server management toolkit for Ubuntu 24.04 LTS that simplifies Docker/Dockge deployment, NAS integration, automated backups, security hardening, and system maintenance.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell_Script-bash-green.svg)](https://www.gnu.org/software/bash/)

---

## 📑 Table of Contents

- [Features](#-features)
- [Repository Structure](#-repository-structure)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [Backup System](#-backup-system)
- [Monitoring](#-monitoring)
- [Security](#-security)
- [Troubleshooting](#-troubleshooting)
- [Uninstallation](#️-uninstallation)
- [License](#-license)

---

## 🌟 Features

### Core Functionality
- ✅ **Docker & Dockge** - Automated installation and container management UI
- ✅ **Multi-NAS Support** - SMB/CIFS mounting with auto-reconnection
- ✅ **Enhanced Backups** - Dockge data + system configuration backups
- ✅ **Security Suite** - fail2ban, UFW, SSH hardening, security audits
- ✅ **24/7 Monitoring** - Health checks with Uptime Kuma integration
- ✅ **Disk Management** - Auto-cleanup when thresholds exceeded
- ✅ **Update Manager** - Automated updates with scheduled reboots
- ✅ **Interactive Menu** - User-friendly TUI interface
- ✅ **Systemd Service** - Auto-start monitoring on boot

### What's New in v2.1
- 🆕 **Configuration Backup** - Automatic backup of critical system configs
- 🆕 **Backup Manifests** - Detailed file listings in all backups
- 🆕 **Restore Config** - Separate config restoration functionality
- 🆕 **Enhanced Help** - Comprehensive help system with examples

### Configuration Files Backed Up
- `/etc/fstab`, `/etc/hosts`, `/etc/hostname`
- `/etc/ssh/sshd_config`
- `/etc/fail2ban/jail.local`
- `/etc/ufw/ufw.conf`
- `/etc/docker/` directory
- Server Helper configuration and credentials
- Systemd service files

---

## 📁 Repository Structure

```
Server-Helper/
├── server_helper_setup.sh          # Main entry point script
├── lib/                            # Modular components
│   ├── core.sh                     # Core utilities & helpers
│   ├── config.sh                   # Configuration management
│   ├── validation.sh               # Input validation functions
│   ├── nas.sh                      # NAS mounting & management
│   ├── docker.sh                   # Docker & Dockge setup
│   ├── backup.sh                   # Backup & restore (enhanced v2.1)
│   ├── disk.sh                     # Disk cleanup & monitoring
│   ├── updates.sh                  # System update management
│   ├── security.sh                 # Security hardening tools
│   ├── service.sh                  # Systemd service management
│   ├── menu.sh                     # Interactive menu interface
│   └── uninstall.sh                # Clean uninstall procedures
├── LICENSE                         # GNU GPL v3 license
└── README.md                       # This file

Generated at runtime:
├── server-helper.conf              # User configuration (auto-created)
├── /var/log/server-helper/         # Log directory
│   ├── server-helper.log           # Main log file
│   └── error.log                   # Error log
├── /opt/dockge/                    # Dockge installation
│   ├── docker-compose.yml
│   ├── data/
│   └── stacks/
└── /etc/systemd/system/
    └── server-helper.service       # Systemd service (when enabled)
```

---

## 📋 Requirements

| Requirement | Details |
|------------|---------|
| **OS** | Ubuntu 24.04 LTS (24.04.3 recommended) |
| **Privileges** | Root or sudo access |
| **Network** | Internet connection for package installation |
| **Optional** | NAS/SMB share for network backups |
| **Disk Space** | ~1GB for Docker + Dockge |

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
# Clone from GitHub
git clone https://github.com/yourusername/Server-Helper.git
cd Server-Helper

# Verify file structure
ls -la lib/
```

### 2. Make Executable

```bash
chmod +x server_helper_setup.sh
```

### 3. Initial Setup

```bash
# First run creates default configuration
sudo ./server_helper_setup.sh

# Edit configuration with your settings
sudo ./server_helper_setup.sh edit-config
```

### 4. Configure Your Settings

Edit the auto-created `server-helper.conf` file:

```bash
sudo nano server-helper.conf
```

**Minimum required settings:**
```bash
NAS_IP="192.168.1.100"
NAS_SHARE="share"
NAS_USERNAME="your_username"
NAS_PASSWORD="your_password"
```

### 5. Run Full Setup

```bash
# Automated setup
sudo ./server_helper_setup.sh setup

# Or use interactive menu
sudo ./server_helper_setup.sh menu
```

### 6. Enable Auto-Start (Recommended)

```bash
sudo ./server_helper_setup.sh enable-autostart
sudo ./server_helper_setup.sh start
```

---

## ⚙️ Configuration

The `server-helper.conf` file is automatically created on first run. All settings are customizable:

### NAS Configuration

```bash
# Single NAS share
NAS_IP="192.168.1.100"
NAS_SHARE="share"
NAS_MOUNT_POINT="/mnt/nas"
NAS_USERNAME="your_username"
NAS_PASSWORD="your_password"
NAS_MOUNT_REQUIRED="false"
NAS_MOUNT_SKIP="false"

# Multiple NAS shares (advanced)
NAS_SHARES="192.168.1.100:share1:/mnt/nas1:user1:pass1;192.168.1.101:share2:/mnt/nas2:user2:pass2"
```

### Dockge Configuration

```bash
DOCKGE_PORT="5001"                  # Web UI port
DOCKGE_DATA_DIR="/opt/dockge"       # Installation directory
```

### Backup Configuration

```bash
BACKUP_DIR="$NAS_MOUNT_POINT/dockge_backups"
BACKUP_RETENTION_DAYS="30"          # Auto-delete backups older than this
BACKUP_ADDITIONAL_DIRS=""           # Semicolon-separated additional paths
```

### System Configuration

```bash
NEW_HOSTNAME=""                      # Set on first setup
DISK_CLEANUP_THRESHOLD="80"         # Percentage to trigger cleanup
AUTO_CLEANUP_ENABLED="true"         # Enable automatic disk cleanup
```

### Update Management

```bash
AUTO_UPDATE_ENABLED="false"         # Enable automatic updates
UPDATE_CHECK_INTERVAL="24"          # Hours between checks
AUTO_REBOOT_ENABLED="false"         # Reboot after updates if needed
REBOOT_TIME="03:00"                 # Scheduled reboot time (24h format)
```

### Security Configuration

```bash
SECURITY_CHECK_ENABLED="true"       # Enable security audits
SECURITY_CHECK_INTERVAL="12"        # Hours between audits
FAIL2BAN_ENABLED="false"           # Setup fail2ban on install
UFW_ENABLED="false"                # Setup UFW firewall on install
SSH_HARDENING_ENABLED="false"      # Harden SSH on install
```

### Uptime Kuma Integration

```bash
UPTIME_KUMA_NAS_URL=""             # Push monitor URL for NAS
UPTIME_KUMA_DOCKGE_URL=""          # Push monitor URL for Dockge
UPTIME_KUMA_SYSTEM_URL=""          # Push monitor URL for system
```

### Debug Options

```bash
DEBUG="false"                       # Enable verbose logging
```

---

## 📖 Usage

### Command Reference

#### Configuration Commands
```bash
sudo ./server_helper_setup.sh edit-config          # Edit configuration file
sudo ./server_helper_setup.sh show-config          # Display config (passwords masked)
sudo ./server_helper_setup.sh validate-config      # Validate configuration
```

#### Setup & Monitoring
```bash
sudo ./server_helper_setup.sh setup                # Run full setup
sudo ./server_helper_setup.sh monitor              # Start monitoring (foreground)
sudo ./server_helper_setup.sh menu                 # Interactive menu (default)
```

#### Service Management
```bash
sudo ./server_helper_setup.sh enable-autostart     # Create systemd service
sudo ./server_helper_setup.sh disable-autostart    # Remove systemd service
sudo ./server_helper_setup.sh start                # Start service
sudo ./server_helper_setup.sh stop                 # Stop service
sudo ./server_helper_setup.sh restart              # Restart service
sudo ./server_helper_setup.sh service-status       # Show service status
sudo ./server_helper_setup.sh logs                 # View live logs
```

#### Backup & Restore Commands (v2.1 Enhanced)
```bash
sudo ./server_helper_setup.sh backup               # Backup Dockge (includes config backup)
sudo ./server_helper_setup.sh backup-config        # Backup configuration files only
sudo ./server_helper_setup.sh backup-all           # Backup everything (Dockge + config)
sudo ./server_helper_setup.sh restore              # Restore Dockge from backup
sudo ./server_helper_setup.sh restore-config       # Restore configuration files
sudo ./server_helper_setup.sh list-backups         # List all backups
sudo ./server_helper_setup.sh show-manifest <file> # Show backup contents
```

#### NAS Management
```bash
sudo ./server_helper_setup.sh list-nas             # List NAS shares and status
sudo ./server_helper_setup.sh mount-nas            # Mount all NAS shares
```

#### System Management
```bash
sudo ./server_helper_setup.sh set-hostname <name>  # Set system hostname
sudo ./server_helper_setup.sh show-hostname        # Show current hostname
sudo ./server_helper_setup.sh clean-disk           # Clean disk space
sudo ./server_helper_setup.sh disk-space           # Show disk usage
```

#### Update Management
```bash
sudo ./server_helper_setup.sh update               # Update system packages
sudo ./server_helper_setup.sh full-upgrade         # Full system upgrade (interactive)
sudo ./server_helper_setup.sh check-updates        # Check for available updates
sudo ./server_helper_setup.sh update-status        # Show update status
sudo ./server_helper_setup.sh schedule-reboot      # Schedule system reboot
```

#### Security Commands
```bash
sudo ./server_helper_setup.sh security-audit       # Run security audit
sudo ./server_helper_setup.sh security-status      # Show security status
sudo ./server_helper_setup.sh security-harden      # Apply security hardening
sudo ./server_helper_setup.sh setup-fail2ban       # Setup fail2ban
sudo ./server_helper_setup.sh setup-ufw            # Setup UFW firewall
sudo ./server_helper_setup.sh harden-ssh           # Harden SSH configuration
```

#### Other Commands
```bash
sudo ./server_helper_setup.sh uninstall            # Uninstall Server Helper
sudo ./server_helper_setup.sh help                 # Show help message
sudo ./server_helper_setup.sh version              # Show version
```

### Environment Variables

Run any command with these environment variables:

```bash
# Dry-run mode (show what would happen, make no changes)
DRY_RUN=true sudo ./server_helper_setup.sh update

# Debug mode (verbose logging)
DEBUG=true sudo ./server_helper_setup.sh monitor

# Custom config file location
CONFIG_FILE=/path/to/custom.conf sudo ./server_helper_setup.sh setup
```

### Interactive Menu

The menu provides easy access to all features:

```bash
sudo ./server_helper_setup.sh menu
```

**Menu Options:**
- **Configuration** (1-3): Edit, show, validate
- **Setup** (4-5): Full setup, monitoring
- **Service** (6-12): Enable, disable, start, stop, restart, status, logs
- **Backup** (13-18): Dockge, config, all, restore-dockge, restore-config, list
- **NAS** (19-20): List, mount
- **System** (21-23): Hostname, clean disk, disk space
- **Updates** (24-28): Update, full upgrade, check, status, reboot
- **Security** (29-34): Audit, status, harden, fail2ban, UFW, SSH
- **Other** (35): Uninstall

---

## 💾 Backup System

### Overview

Version 2.1 includes an enhanced backup system that preserves both application data and critical system configurations.

### Backup Types

#### 1. Dockge Backup
Includes Dockge stacks and data, **plus automatic config backup**:
```bash
sudo ./server_helper_setup.sh backup
```

#### 2. Configuration Backup
System configuration files only:
```bash
sudo ./server_helper_setup.sh backup-config
```

#### 3. Complete Backup
Everything (Dockge + configs):
```bash
sudo ./server_helper_setup.sh backup-all
```

### What Gets Backed Up

**Dockge Backups** (`dockge_backup_*.tar.gz`):
- Docker stacks
- Dockge data directory
- Automatically includes config backup

**Configuration Backups** (`config_backup_*.tar.gz`):
- `/etc/fstab` - Filesystem mounts
- `/etc/hosts`, `/etc/hostname` - Network identity
- `/etc/ssh/sshd_config` - SSH configuration
- `/etc/fail2ban/jail.local` - fail2ban rules
- `/etc/ufw/ufw.conf` - Firewall configuration
- `/etc/docker/` - Docker configuration
- `/etc/systemd/system/server-helper.service` - Systemd service
- `server-helper.conf` - Server Helper config
- NAS credentials files
- **Backup manifest** - Complete file listing

### Backup Locations

```bash
# Default (on NAS)
$NAS_MOUNT_POINT/dockge_backups/
├── dockge_backup_20241221_120000.tar.gz
├── dockge_backup_20241221_180000.tar.gz
└── config/
    ├── config_backup_20241221_120000.tar.gz
    └── config_backup_20241221_180000.tar.gz

# Fallback (if NAS unavailable)
/opt/dockge_backups_local/
```

### Backup Frequency

**Automatic** (when monitoring is enabled):
- Every 3 hours (180 minutes)
- Includes both Dockge and configuration

**Manual**:
```bash
sudo ./server_helper_setup.sh backup-all
```

### Retention Policy

- Default: 30 days (configurable via `BACKUP_RETENTION_DAYS`)
- Older backups automatically deleted
- Override in config: `BACKUP_RETENTION_DAYS="60"`

### Viewing Backup Contents

```bash
# List all backups
sudo ./server_helper_setup.sh list-backups

# Show what's in a specific backup
sudo ./server_helper_setup.sh show-manifest /path/to/backup.tar.gz

# Example output:
# Backup manifest for: config_backup_20241221_120000.tar.gz
# ================================
# Server Helper Configuration Backup
# Created: Sat Dec 21 12:00:00 PST 2024
# Hostname: docker-server
# Kernel: 6.8.0-51-generic
# Files backed up: 15
```

### Restore Procedures

#### Restore Dockge Data
```bash
sudo ./server_helper_setup.sh restore

# Select backup:
# - Type filename, or
# - Type 'latest' for most recent
```

#### Restore Configuration Files
```bash
sudo ./server_helper_setup.sh restore-config

# Emergency backup created automatically
# Review changes after restore
```

**Important**: 
- Emergency backups created before every restore
- Review restored files, especially SSH config
- Reboot may be required after config restore

---

## 📊 Monitoring

### Monitoring Service

When enabled as a systemd service, monitors every **2 minutes**:

1. **NAS Health**
   - Mount point availability
   - Network connectivity
   - Auto-remount on failure

2. **Dockge Status**
   - Container running state
   - Web interface responsiveness
   - Auto-restart on failure

3. **Disk Usage**
   - Current usage percentage
   - Auto-cleanup when > threshold
   - Space-freed reporting

4. **System Updates** (configurable interval)
   - Available updates check
   - Automatic installation (if enabled)
   - Scheduled reboot handling

5. **Security Checks** (configurable interval)
   - Security audit execution
   - Issue detection and logging

### Heartbeat Monitoring

```bash
# Configure in server-helper.conf
UPTIME_KUMA_NAS_URL="http://uptime-kuma:3001/api/push/abc123"
UPTIME_KUMA_DOCKGE_URL="http://uptime-kuma:3001/api/push/def456"
UPTIME_KUMA_SYSTEM_URL="http://uptime-kuma:3001/api/push/ghi789"
```

Sends status every 2 minutes:
- `?status=up` - Service healthy
- `?status=down` - Service failed

### Log Monitoring

```bash
# Real-time logs
sudo ./server_helper_setup.sh logs

# Last 50 entries
sudo journalctl -u server-helper -n 50

# All logs today
sudo journalctl -u server-helper --since today

# Error log
sudo tail -f /var/log/server-helper/error.log
```

---

## 🔒 Security

### Security Features

#### 1. fail2ban
Protects against brute-force attacks:
```bash
sudo ./server_helper_setup.sh setup-fail2ban
```

**Configuration**:
- SSH: 3 failed attempts = 24-hour ban
- Ban time: 1 hour (default services)
- Find time: 10 minutes

#### 2. UFW Firewall
Simple firewall management:
```bash
sudo ./server_helper_setup.sh setup-ufw
```

**Default Rules**:
- Deny all incoming
- Allow all outgoing
- Allow: SSH (22), HTTP (80), HTTPS (443), Dockge (5001)

#### 3. SSH Hardening
Secure SSH configuration:
```bash
sudo ./server_helper_setup.sh harden-ssh
```

**Changes Applied**:
- Disable root login
- Disable password authentication
- Enable public key authentication only
- Disable empty passwords
- Disable X11 forwarding
- Limit authentication attempts to 3

**⚠️ Warning**: Have SSH keys configured before hardening!

#### 4. Security Audit
Comprehensive security check:
```bash
sudo ./server_helper_setup.sh security-audit
```

**Checks**:
- ✅ Root login status
- ✅ UFW firewall active
- ✅ fail2ban running
- ✅ Password authentication status
- ✅ Reports issues found

### Applying All Security Hardening

```bash
# Interactive hardening (recommended)
sudo ./server_helper_setup.sh security-harden

# Or configure in server-helper.conf
FAIL2BAN_ENABLED="true"
UFW_ENABLED="true"
SSH_HARDENING_ENABLED="true"
```

### Best Practices

1. **Before SSH Hardening**:
   ```bash
   # On your local machine
   ssh-copy-id user@server
   
   # Test key-based login
   ssh user@server
   ```

2. **After UFW Setup**:
   - Ensure you have console access
   - Test SSH connection
   - Add custom rules as needed

3. **Regular Audits**:
   ```bash
   # Run monthly
   sudo ./server_helper_setup.sh security-audit
   ```

4. **Monitor Security Logs**:
   ```bash
   # fail2ban status
   sudo fail2ban-client status sshd
   
   # UFW logs
   sudo tail -f /var/log/ufw.log
   ```

---

## 🔍 Troubleshooting

### Common Issues

#### NAS Mount Failures

**Symptoms**: 
- "NAS required but failed" error
- Mount point not accessible

**Solutions**:
```bash
# 1. Check NAS connectivity
ping $NAS_IP

# 2. Verify credentials in config
sudo ./server_helper_setup.sh show-config

# 3. Test manual mount
sudo mount -t cifs //NAS_IP/SHARE /mnt/nas -o username=USER,password=PASS,vers=3.0

# 4. Check SMB version support
sudo mount -t cifs //NAS_IP/SHARE /mnt/nas -o username=USER,password=PASS,vers=2.1

# 5. View detailed logs
sudo ./server_helper_setup.sh logs

# 6. If NAS is optional, set in config:
NAS_MOUNT_REQUIRED="false"
```

#### Dockge Not Starting

**Symptoms**:
- Can't access http://server:5001
- Container not running

**Solutions**:
```bash
# 1. Check Docker status
sudo systemctl status docker
sudo systemctl start docker

# 2. Check Dockge container
sudo docker ps -a | grep dockge

# 3. View Dockge logs
cd /opt/dockge
sudo docker compose logs

# 4. Restart Dockge
cd /opt/dockge
sudo docker compose restart

# 5. Check port availability
sudo ss -tulpn | grep :5001

# 6. Rebuild if necessary
cd /opt/dockge
sudo docker compose down
sudo docker compose up -d
```

#### Service Won't Start

**Symptoms**:
- systemd service fails
- "Service not installed" error

**Solutions**:
```bash
# 1. Check service status
sudo ./server_helper_setup.sh service-status

# 2. View systemd logs
sudo journalctl -u server-helper -n 50 --no-pager

# 3. Check script permissions
ls -la server_helper_setup.sh
chmod +x server_helper_setup.sh

# 4. Verify all modules exist
ls -la lib/

# 5. Recreate service
sudo ./server_helper_setup.sh disable-autostart
sudo ./server_helper_setup.sh enable-autostart

# 6. Manual service control
sudo systemctl daemon-reload
sudo systemctl enable server-helper
sudo systemctl start server-helper
```

#### Disk Space Issues

**Symptoms**:
- "No space left on device"
- Backups failing
- Docker errors

**Solutions**:
```bash
# 1. Check disk usage
sudo ./server_helper_setup.sh disk-space

# 2. Run cleanup
sudo ./server_helper_setup.sh clean-disk

# 3. Check Docker space
sudo docker system df

# 4. Aggressive Docker cleanup
sudo docker system prune -a --volumes

# 5. Remove old backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

# 6. Check for large files
sudo du -h / | sort -rh | head -20
```

#### Module Loading Errors

**Symptoms**:
- "Module not found" error
- "No such file or directory"

**Solutions**:
```bash
# 1. Verify file structure
ls -la lib/

# Required files:
# lib/core.sh
# lib/config.sh
# lib/validation.sh
# lib/nas.sh
# lib/docker.sh
# lib/backup.sh
# lib/disk.sh
# lib/updates.sh
# lib/security.sh
# lib/service.sh
# lib/menu.sh
# lib/uninstall.sh

# 2. Make all modules executable
chmod +x lib/*.sh

# 3. Check for syntax errors
bash -n server_helper_setup.sh
bash -n lib/*.sh

# 4. Run with debug mode
DEBUG=true sudo ./server_helper_setup.sh setup
```

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
# Temporary (one command)
DEBUG=true sudo ./server_helper_setup.sh [command]

# Permanent (in config)
sudo nano server-helper.conf
# Set: DEBUG="true"

# Then restart service
sudo ./server_helper_setup.sh restart
```

### Getting Help

1. **Check Logs**:
   ```bash
   # Main log
   sudo tail -100 /var/log/server-helper/server-helper.log
   
   # Error log
   sudo cat /var/log/server-helper/error.log
   
   # Systemd journal
   sudo journalctl -u server-helper -n 100
   ```

2. **Run Validation**:
   ```bash
   sudo ./server_helper_setup.sh validate-config
   ```

3. **Create Issue on GitHub**:
   - Include log output
   - Include configuration (remove passwords!)
   - Describe steps to reproduce

---

## 🗑️ Uninstallation

The uninstall process is interactive and safe:

```bash
sudo ./server_helper_setup.sh uninstall
```

### What Gets Removed (with confirmation)

1. **Systemd Service**
   - Stops service
   - Disables auto-start
   - Removes service file

2. **NAS Mounts**
   - Unmounts all NAS shares
   - Removes fstab entries
   - Keeps credentials (optional)

3. **Dockge**
   - Stops containers
   - Option to delete data
   - Creates final backup (optional)

4. **Docker**
   - Option to remove Docker completely
   - Requires typing "yes" to confirm
   - Option to keep Docker data

5. **Configuration Files**
   - server-helper.conf
   - NAS credentials

6. **Backups**
   - Requires typing "DELETE" to confirm
   - Creates list before deletion

7. **Script Files**
   - Server Helper directory
   - Option to remove entirely

### Safe Uninstall Steps

1. **Create Final Backup**:
   ```bash
   sudo ./server_helper_setup.sh backup-all
   ```

2. **Copy Backups Off Server** (if needed):
   ```bash
   scp -r user@server:/mnt/nas/dockge_backups ./local-backups
   ```

3. **Run Uninstall**:
   ```bash
   sudo ./server_helper_setup.sh uninstall
   ```

4. **Answer Prompts Carefully**:
   - Read each prompt
   - Confirm destructive actions
   - Keep backups unless certain

### Selective Removal

You can skip any step during uninstall by answering "no" to prompts.

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0**.

See the [LICENSE](LICENSE) file for details.

### Summary of GPL v3.0

- ✅ Free to use, modify, and distribute
- ✅ Must keep source code available
- ✅ Must license modifications under GPL v3.0
- ✅ No warranty provided

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. **Fork the Repository**
2. **Create Feature Branch**: `git checkout -b feature/AmazingFeature`
3. **Commit Changes**: `git commit -m 'Add AmazingFeature'`
4. **Push to Branch**: `git push origin feature/AmazingFeature`
5. **Open Pull Request**

### Areas for Contribution

- 🔧 Additional backup targets (databases, configs)
- 🌐 NFS and WebDAV support
- 📧 Email notifications
- 🎨 Web dashboard
- ☁️ Cloud storage integration
- 🔄 Multi-server orchestration
- 📱 Mobile notifications
- 🐳 Additional container platforms

---

## 📞 Support & Contact

### Issues & Bugs

Open an issue on GitHub with:
- Log output (from `/var/log/server-helper/`)
- Steps to reproduce
- Expected vs. actual behavior
- Configuration (remove sensitive data!)

### Documentation

- **This README** - Complete user guide
- **Help Command**: `sudo ./server_helper_setup.sh help`
- **Comments in Scripts** - Inline documentation
- **Config File** - Comments explain each setting

---

## 🙏 Acknowledgments

- **Dockge** by [Louis Lam](https://github.com/louislam)
- **Docker** by Docker Inc.
- **Ubuntu Community**
- **GNU/Linux** developers and maintainers

---

## 📊 Quick Reference

### Installation
```bash
git clone https://github.com/yourusername/Server-Helper.git
cd Server-Helper
chmod +x server_helper_setup.sh
sudo ./server_helper_setup.sh
```

### Daily Commands
```bash
sudo ./server_helper_setup.sh service-status    # Check status
sudo ./server_helper_setup.sh logs              # View logs
sudo ./server_helper_setup.sh backup-all        # Create backup
sudo ./server_helper_setup.sh security-audit    # Security check
```

### Maintenance
```bash
sudo ./server_helper_setup.sh check-updates     # Check updates
sudo ./server_helper_setup.sh clean-disk        # Clean disk
sudo ./server_helper_setup.sh list-backups      # List backups
```

---

**Version**: 2.1.0  
**Release**: Enhanced Config Backup Edition  
**Target**: Ubuntu 24.04 LTS  
**License**: GPL v3.0  

**🌟 Star this repo if you find it useful!**
