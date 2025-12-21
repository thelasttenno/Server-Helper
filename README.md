# Server Helper Setup Script

A comprehensive server management script for Ubuntu 24.04.3 LTS that automates NAS mounting, Docker/Dockge installation, system monitoring, backups, updates, and security hardening.

## 🌟 Features

- **NAS Management**: Automatic NAS mounting with credential management
- **Docker & Dockge**: Automated installation and configuration
- **Monitoring**: 24/7 service monitoring with auto-recovery
- **Backups**: Scheduled Dockge backups to NAS with retention management
- **System Updates**: Automated system updates with scheduled reboots
- **Security**: Comprehensive security auditing and hardening (fail2ban, UFW, SSH)
- **Disk Management**: Automatic disk cleanup and space monitoring
- **Uptime Kuma Integration**: Push monitor heartbeats
- **Auto-Start**: Systemd service for boot-time startup

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
# Run full setup
sudo bash /opt/Server-Helper/server_helper_setup.sh

# Script will:
# - Mount NAS
# - Install Docker & Dockge
# - Optionally enable auto-start
# - Start monitoring
```

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
| `restore` | Restore from backup (interactive) |
| `list-backups` | List all available backups |

**Examples:**
```bash
sudo ./server_helper_setup.sh backup
sudo ./server_helper_setup.sh list-backups
sudo ./server_helper_setup.sh restore
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
└── server-helper.conf         # Configuration (chmod 600)

/opt/dockge/
├── docker-compose.yml
├── data/
└── stacks/

/mnt/nas/
└── dockge_backups/
    ├── dockge_backup_20241220_120000.tar.gz
    └── dockge_backup_20241220_180000.tar.gz

/etc/systemd/system/
└── server-helper.service      # Systemd service

/root/
└── .nascreds                  # NAS credentials (chmod 600)
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
```

---

## 🔧 Troubleshooting

### NAS Not Mounting

```bash
# Check NAS connectivity
ping $NAS_IP

# Verify credentials
sudo ./server_helper_setup.sh show-config

# Check mount manually
sudo mount -t cifs //$NAS_IP/$NAS_SHARE /mnt/nas -o username=xxx,password=xxx
```

### Service Not Starting

```bash
# Check service status
sudo systemctl status server-helper

# View detailed logs
sudo journalctl -u server-helper -n 50

# Verify script permissions
ls -l /opt/Server-Helper/server_helper_setup.sh
```

### Dockge Not Accessible

```bash
# Check Docker status
sudo docker ps

# Check Dockge logs
cd /opt/dockge
sudo docker compose logs

# Restart Dockge
sudo docker compose restart
```

### Disk Space Issues

```bash
# Check disk usage
sudo ./server_helper_setup.sh disk-space

# Manual cleanup
sudo ./server_helper_setup.sh clean-disk

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
```

---

## 📝 License

This script is provided as-is for personal and commercial use.

## 🤝 Support

For issues, questions, or contributions, please refer to the script documentation or contact your system administrator.

---

## ✨ Summary

**Server Helper** is your all-in-one solution for:
- 🔧 Automated server setup
- 📊 24/7 monitoring
- 💾 Reliable backups
- 🔒 Security hardening
- 🔄 Update management
- 🧹 Disk maintenance

**Total Commands: 31** | **Auto-Start: ✅** | **Security: ✅** | **Monitoring: ✅**
