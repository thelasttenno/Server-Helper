# Server Helper v0.3.0 - Quick Start Guide

## 🚀 Installation (5 minutes)

### Step 1: Download
```bash
sudo git clone https://github.com/thelasttenno/Server-Helper.git /opt/Server-Helper
cd /opt/Server-Helper
```

### Step 2: Make Executable
```bash
sudo chmod +x server_helper_setup.sh
sudo chmod +x lib/*.sh
```

### Step 3: Configure
```bash
# First run creates configuration file
sudo ./server_helper_setup.sh

# Edit the configuration
sudo nano server-helper.conf

# Update these required fields:
# - NAS_IP="192.168.1.100"
# - NAS_SHARE="your_share_name"
# - NAS_USERNAME="your_username"
# - NAS_PASSWORD="your_password"

# Optional: Enable debug mode
# DEBUG="true"
```

### Step 4: Run Setup
```bash
# Standard setup (includes pre-installation check)
sudo ./server_helper_setup.sh setup

# Or with debug mode
DEBUG=true sudo ./server_helper_setup.sh setup
```

The setup will:
- ✅ Check for existing installations
- ✅ Offer cleanup options if components are found
- ✅ Mount NAS shares
- ✅ Install Docker & Dockge
- ✅ Create initial configuration backup

### Step 5: Enable Auto-Start (Recommended)
```bash
sudo ./server_helper_setup.sh enable-autostart
sudo ./server_helper_setup.sh start
```

### Step 6: Verify Installation
```bash
sudo ./server_helper_setup.sh service-status
```

---

## 🎯 Essential Commands

### Daily Operations
```bash
# Check status
sudo ./server_helper_setup.sh service-status

# Create backup
sudo ./server_helper_setup.sh backup

# Backup everything (Dockge + config)
sudo ./server_helper_setup.sh backup-all

# View logs
sudo ./server_helper_setup.sh logs

# Check for system updates
sudo ./server_helper_setup.sh check-updates
```

### Self-Update (NEW in 0.3.0)
```bash
# Check for Server Helper script updates
sudo ./server_helper_setup.sh check-updates-script

# Update to latest version (auto-backup + config preserved)
sudo ./server_helper_setup.sh self-update

# Rollback to previous version if needed
sudo ./server_helper_setup.sh rollback

# View update changelog from GitHub
sudo ./server_helper_setup.sh changelog
```

### Installation Management
```bash
# Check for existing installation
sudo ./server_helper_setup.sh check-install

# Emergency unmount stuck NAS
sudo ./server_helper_setup.sh unmount-nas

# Clean existing installation components
sudo ./server_helper_setup.sh clean-install
```

### With Debug Mode
```bash
# Any command can be run with debug mode
DEBUG=true sudo ./server_helper_setup.sh <command>

# Examples:
DEBUG=true sudo ./server_helper_setup.sh monitor
DEBUG=true sudo ./server_helper_setup.sh backup
DEBUG=true sudo ./server_helper_setup.sh security-audit
DEBUG=true sudo ./server_helper_setup.sh unmount-nas
```

---

## 🆕 New in v0.3.0 - Self-Update & Loading Indicators

### Self-Updater System
Keep Server Helper automatically updated from GitHub:

```bash
# Check for updates
sudo ./server_helper_setup.sh check-updates-script

# Update to latest version (with automatic backup)
sudo ./server_helper_setup.sh self-update

# View what's new
sudo ./server_helper_setup.sh changelog

# Rollback if needed
sudo ./server_helper_setup.sh rollback
```

**Features:**
- One-command update from GitHub
- Automatic backup before updating
- Configuration file preservation
- Service state management (auto stop/restart)
- Rollback capability to previous version
- Optional auto-update checking (every 12 hours)
- Uptime Kuma integration for notifications

**Enable auto-update checking:**
```bash
sudo ./server_helper_setup.sh edit-config
# Set: AUTO_UPDATE_CHECK="true"
# Optional: UPTIME_KUMA_UPDATE_URL="http://uptime-kuma:3001/api/push/xyz"
```

### Loading Indicators
Visual feedback for operations:

**Built-in indicators:**
- **Spinner animation** - Background processes show rotating spinner (|/-\)
- **Progress bars** - Multi-step operations display percentage
- **Execute with spinner** - Commands run with visual feedback

No additional tools needed - pure bash implementation that works with DEBUG mode.

### Enhanced Interactive Menu
Now with **43 options** (up from 38):

```bash
# Access interactive menu
sudo ./server_helper_setup.sh menu
```

**New menu items:**
- **39**: Check for Server Helper updates
- **40**: Update to latest version
- **41**: Rollback to previous version
- **42**: View changelog
- **43**: Uninstall (shifted from 38)

---

## 🐛 Troubleshooting

### Enable Debug Mode
For any issues, always enable debug mode first:
```bash
DEBUG=true sudo ./server_helper_setup.sh <failing-command>
```

### Common Issues

#### NAS Won't Mount
```bash
# Debug the mount process
DEBUG=true sudo ./server_helper_setup.sh mount-nas

# Check connectivity
ping <nas_ip>

# If stuck, use emergency unmount
sudo ./server_helper_setup.sh unmount-nas
```

#### Service Won't Start
```bash
# Debug service status
DEBUG=true sudo ./server_helper_setup.sh service-status

# Check logs
sudo journalctl -u server-helper -n 50

# Check for conflicts
sudo ./server_helper_setup.sh check-install
```

#### Dockge Not Accessible
```bash
# Debug Dockge status
DEBUG=true sudo ./server_helper_setup.sh service-status

# Manual check
cd /opt/dockge
sudo docker compose ps
sudo docker compose logs
```

#### Existing Installation Conflicts
```bash
# Check what's installed
sudo ./server_helper_setup.sh check-install

# Clean up selectively or completely
sudo ./server_helper_setup.sh clean-install
```

---

## 📂 File Structure

```
Server-Helper/
├── server_helper_setup.sh          # Main entry point
├── server-helper.conf              # Configuration file (auto-created)
├── VERSION                         # Version number (0.3.0)
├── lib/                            # Library modules
│   ├── core.sh                    # Core utilities + loading indicators
│   ├── config.sh                  # Configuration management
│   ├── validation.sh              # Input validation
│   ├── preinstall.sh              # Pre-installation detection
│   ├── nas.sh                     # NAS management + emergency unmount
│   ├── docker.sh                  # Docker/Dockge installation
│   ├── backup.sh                  # Backup/restore system
│   ├── disk.sh                    # Disk management
│   ├── updates.sh                 # System updates
│   ├── security.sh                # Security hardening
│   ├── service.sh                 # Systemd service + monitoring
│   ├── selfupdate.sh              # Self-update system (NEW in v0.3.0)
│   ├── menu.sh                    # Interactive menu (43 options)
│   └── uninstall.sh               # Uninstallation
├── README.md                       # Complete documentation
├── CHANGELOG.md                    # Version history
└── QUICKSTART.md                   # This file
```

---

## 📖 Full Documentation

For complete documentation, see:
- `README.md` - Comprehensive user guide
- `CHANGELOG.md` - Version history and changes
- `CLAUDE.md` - Development guidance (for contributors)

---

## 🆘 Getting Help

1. **Enable debug mode** - `DEBUG=true sudo ./server_helper_setup.sh <command>`
2. **Check log files** - `/var/log/server-helper/server-helper.log` and `error.log`
3. **Review README** - Troubleshooting section
4. **Check installation** - `sudo ./server_helper_setup.sh check-install`
5. **Provide debug output** when seeking support

---

## ✨ Key Features

### Core Functionality
- ✅ Automated server setup with pre-installation check
- ✅ 24/7 monitoring with auto-recovery
- ✅ Automatic backups (Dockge + configuration)
- ✅ Security hardening (fail2ban, UFW, SSH)
- ✅ Update management
- ✅ Disk cleanup

### v0.3.0 Additions
- ✅ **Self-updater** - GitHub integration with one-command updates
- ✅ **Loading indicators** - Spinners and progress bars for visual feedback
- ✅ **Auto-update checking** - Optional 12-hour update monitoring
- ✅ **Rollback capability** - Revert to previous version if needed
- ✅ **Enhanced menu** - 43 options with self-update section
- ✅ **Configuration preservation** - Auto-saved during updates
- ✅ **Update notifications** - Uptime Kuma integration

### Previous Additions
- ✅ **Pre-installation detection** - Prevents conflicts
- ✅ **Emergency NAS unmount** - Force unmount stuck shares
- ✅ **Installation management** - Check and clean components
- ✅ **Configuration backup** - System-wide config preservation
- ✅ **Debug mode** - Comprehensive troubleshooting

---

## 🎓 Quick Reference

### Most Used Commands
```bash
# Interactive menu (recommended for beginners)
sudo ./server_helper_setup.sh menu

# Quick status check
sudo ./server_helper_setup.sh service-status

# Create backup
sudo ./server_helper_setup.sh backup-all

# View live logs
sudo ./server_helper_setup.sh logs

# Check for script updates
sudo ./server_helper_setup.sh check-updates-script

# Update Server Helper
sudo ./server_helper_setup.sh self-update

# Emergency NAS unmount
sudo ./server_helper_setup.sh unmount-nas
```

### Configuration
```bash
# Edit config
sudo ./server_helper_setup.sh edit-config

# Show config (passwords masked)
sudo ./server_helper_setup.sh show-config

# Validate config
sudo ./server_helper_setup.sh validate-config
```

### Service Management
```bash
# Enable auto-start
sudo ./server_helper_setup.sh enable-autostart

# Start/stop/restart
sudo ./server_helper_setup.sh start
sudo ./server_helper_setup.sh stop
sudo ./server_helper_setup.sh restart
```

---

## 🎉 You're Ready!

**Version:** 0.3.0 - Self-Update & Loading Indicators
**Target:** Ubuntu 24.04.3 LTS
**License:** GPL v3

Server Helper is now fully configured and ready to manage your server!

Access Dockge: `http://localhost:5001` (default)

**Pro Tip:** Enable auto-update checking in your config to stay current with the latest features!

```bash
sudo ./server_helper_setup.sh edit-config
# Set: AUTO_UPDATE_CHECK="true"
```

**Happy Server Managing! 🚀**
