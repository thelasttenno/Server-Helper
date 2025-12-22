# Server Helper v0.2.2 - Quick Start Guide

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
# - NAS_IP="your_nas_ip"
# - NAS_SHARE="your_share_name"
# - NAS_USERNAME="your_username"
# - NAS_PASSWORD="your_password"

# Optional: Enable debug mode
# DEBUG="true"
```

### Step 4: Run Setup
```bash
# Standard setup
sudo ./server_helper_setup.sh setup

# Or with debug mode
DEBUG=true sudo ./server_helper_setup.sh setup
```

### Step 5: Enable Auto-Start (Recommended)
```bash
sudo ./server_helper_setup.sh enable-autostart
sudo ./server_helper_setup.sh start
```

## 🎯 Essential Commands

### Daily Operations
```bash
# Check status
sudo ./server_helper_setup.sh service-status

# Create backup
sudo ./server_helper_setup.sh backup

# View logs
sudo ./server_helper_setup.sh logs

# Check for updates
sudo ./server_helper_setup.sh check-updates
```

### With Debug Mode
```bash
# Any command can be run with debug mode
DEBUG=true sudo ./server_helper_setup.sh <command>

# Examples:
DEBUG=true sudo ./server_helper_setup.sh monitor
DEBUG=true sudo ./server_helper_setup.sh backup
DEBUG=true sudo ./server_helper_setup.sh security-audit
```

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
```

#### Service Won't Start
```bash
# Debug service status
DEBUG=true sudo ./server_helper_setup.sh service-status

# Check logs
sudo journalctl -u server-helper -n 50
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

## 📖 Full Documentation

For complete documentation, see:
- `README.md` - Comprehensive user guide
- `CHANGELOG.md` - Version history and changes

## 🆘 Getting Help

1. Enable debug mode
2. Check log files: `/var/log/server-helper/`
3. Review README troubleshooting section
4. Provide debug output when seeking support

## ✨ Key Features

- ✅ Automated server setup
- ✅ 24/7 monitoring
- ✅ Automatic backups
- ✅ Security hardening
- ✅ Update management
- ✅ **NEW: Debug mode for troubleshooting**

**Version:** 0.2.2 - Enhanced Debug Edition
**Target:** Ubuntu 24.04.3 LTS
