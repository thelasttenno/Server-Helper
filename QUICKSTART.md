# Server Helper v0.2.3 - Quick Start Guide

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

# Check for updates
sudo ./server_helper_setup.sh check-updates
```

### Installation Management (NEW in 0.2.3)
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

## 🆕 New in v0.2.3 - Integration Update

### Pre-Installation Detection (Integrated)
Automatically detects and manages existing installations:
```bash
# Check what's installed
sudo ./server_helper_setup.sh check-install

# The setup command now runs this automatically!
sudo ./server_helper_setup.sh setup
```

**What it detects:**
- Systemd services
- NAS mounts and credentials
- Dockge installations
- Docker installations
- Configuration files
- Existing backups

**Cleanup options:**
1. Keep existing installation
2. Remove and reinstall (clean slate)
3. Selective cleanup (choose components)
4. Cancel and exit

### Emergency NAS Unmount (NEW)
Force unmount stuck NAS shares with 4 fallback methods:
```bash
# Emergency unmount default mount point
sudo ./server_helper_setup.sh unmount-nas

# Specify custom mount point
sudo ./server_helper_setup.sh unmount-nas /mnt/custom

# Also available in menu as option 21
```

**Features:**
- Detects and optionally kills blocking processes
- 4 unmount methods (normal → lazy → force → force+lazy)
- Cleans up fstab entries
- Removes credential files
- Comprehensive troubleshooting output

### Enhanced Interactive Menu
Now with 38 options (up from 35):
```bash
# Access interactive menu
sudo ./server_helper_setup.sh menu
```

**New menu items:**
- **21**: Emergency NAS Unmount
- **36**: Check Installation
- **37**: Clean Installation

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
├── VERSION                         # Version number (0.2.3)
├── lib/                            # Library modules
│   ├── core.sh                    # Core utilities
│   ├── config.sh                  # Configuration management
│   ├── validation.sh              # Input validation
│   ├── preinstall.sh              # Pre-installation detection (INTEGRATED)
│   ├── nas.sh                     # NAS management + emergency unmount
│   ├── docker.sh                  # Docker/Dockge installation
│   ├── backup.sh                  # Backup/restore system
│   ├── disk.sh                    # Disk management
│   ├── updates.sh                 # System updates
│   ├── security.sh                # Security hardening
│   ├── service.sh                 # Systemd service
│   ├── menu.sh                    # Interactive menu (38 options)
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

### v0.2.3 Additions
- ✅ **Pre-installation detection** - Prevents conflicts
- ✅ **Emergency NAS unmount** - Force unmount stuck shares
- ✅ **Installation management** - Check and clean components
- ✅ **Enhanced menu** - 38 options organized by category
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

**Version:** 0.2.3 - Integration Update
**Target:** Ubuntu 24.04.3 LTS
**License:** GPL v3

Server Helper is now fully configured and ready to manage your server!

Access Dockge: `http://localhost:5001` (default)

**Happy Server Managing! 🚀**
