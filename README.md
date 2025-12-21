## Recommended Location & Setup:

### **Best Practice: `/opt/Server-Helper/`**

```bash
# 1. Create dedicated directory
sudo mkdir -p /opt/Server-Helper
cd /opt/Server-Helper

# 2. Download/copy your script here
sudo nano server_helper_setup.sh
# (paste the script content)

# 3. Make it executable
sudo chmod +x server_helper_setup.sh

# 4. First run creates config file
sudo ./server_helper_setup.sh
# This creates /opt/Server-Helper/server_helper_setup.conf

# 5. Edit configuration
sudo nano server_helper_setup.conf
# (add your NAS credentials and settings)

# 6. Run the setup
sudo ./server_helper_setup.sh
```

### **Why `/opt/Server-Helper/`?**

- ✅ Standard location for third-party/custom applications
- ✅ Survives system upgrades
- ✅ Not in user home directory (safer for systemd service)
- ✅ Easy to backup
- ✅ Clean and organized

### **Alternative Locations:**

**Option 2: `/usr/local/bin/` (for system-wide script)**
```bash
sudo cp server_helper_setup.sh /usr/local/bin/Server-Helper
sudo chmod +x /usr/local/bin/Server-Helper
# Config file: /etc/Server-Helper/server_helper_setup.conf
sudo mkdir -p /etc/Server-Helper
export CONFIG_FILE=/etc/Server-Helper/server_helper_setup.conf
```

**Option 3: Home directory (simplest for testing)**
```bash
mkdir ~/Server-Helper
cd ~/Server-Helper
# (same steps as above)
```

### **Complete Setup Example:**

```bash
# Full setup from scratch
sudo mkdir -p /opt/Server-Helper
cd /opt/Server-Helper

# Create the script
sudo tee server_helper_setup.sh > /dev/null << 'EOF'
#!/bin/bash
# (paste entire script here)
EOF

sudo chmod +x server_helper_setup.sh

# First run to create config
sudo ./server_helper_setup.sh

# Edit config with your settings
sudo nano server_helper_setup.conf

# Run full setup
sudo ./server_helper_setup.sh

# Enable auto-start on boot
sudo ./server_helper_setup.sh enable-autostart
```

### **File Structure:**

```
/opt/Server-Helper/
├── server_helper_setup.sh          # Main script (executable)
└── server_helper_setup.conf        # Configuration file (chmod 600)

/opt/dockge/               # Dockge installation
├── docker-compose.yml
├── data/
└── stacks/

/mnt/nas/                  # NAS mount point
└── dockge_backups/        # Backups location
```

### **Running the Script:**

Once installed in `/opt/Server-Helper/`:

```bash
# Direct execution
sudo /opt/Server-Helper/server_helper_setup.sh [command]

# Or create a symlink for easier access
sudo ln -s /opt/Server-Helper/server_helper_setup.sh /usr/local/bin/Server-Helper
# Then run from anywhere:
sudo Server-Helper [command]
```

### **For Systemd Service:**

The systemd service will automatically use the correct path when you run:
```bash
sudo /opt/Server-Helper/server_helper_setup.sh enable-autostart
```

The service file stores the absolute path, so it works regardless of where you run it from.

### **Security Note:**

The config file (`server_helper_setup.conf`) contains sensitive credentials, so:
- Keep it in `/opt/Server-Helper/` with 600 permissions
- Don't commit it to git (add `*.conf` to `.gitignore`)
- Back it up securely separately from the script

**Recommended: `/opt/Server-Helper/`** for production use!

## 📋 Complete Command List

### **🔧 Configuration Management**
sudo ./nas-dockge.sh edit-config            # Edit configuration file
sudo ./nas-dockge.sh show-config            # Show config (secrets masked)
sudo ./nas-dockge.sh validate-config        # Validate configuration

### **🚀 Setup & Monitoring**
sudo ./nas-dockge.sh                        # Full setup (interactive)
sudo ./nas-dockge.sh monitor                # Run monitoring manually (foreground)

### **⚙️ Auto-Start Management**
sudo ./nas-dockge.sh enable-autostart       # Create systemd service for boot
sudo ./nas-dockge.sh disable-autostart      # Remove systemd service
sudo ./nas-dockge.sh service-status         # Check service status
sudo ./nas-dockge.sh start                  # Start service
sudo ./nas-dockge.sh stop                   # Stop service
sudo ./nas-dockge.sh restart                # Restart service
sudo ./nas-dockge.sh logs                   # View live service logs

### **💾 Backup & Restore**
sudo ./nas-dockge.sh backup                 # Create manual backup
sudo ./nas-dockge.sh restore                # Restore from backup (interactive)
sudo ./nas-dockge.sh list-backups           # List all available backups

### **🖥️ System Management**
sudo ./nas-dockge.sh set-hostname <name>    # Set system hostname
sudo ./nas-dockge.sh show-hostname          # Show current hostname

### **🧹 Disk Management**
sudo ./nas-dockge.sh clean-disk             # Run disk cleanup manually
sudo ./nas-dockge.sh disk-space             # Show disk usage information

### **🔄 System Updates**
sudo ./nas-dockge.sh update                 # Update system packages
sudo ./nas-dockge.sh full-upgrade           # Full system upgrade (interactive)
sudo ./nas-dockge.sh check-updates          # Check for available updates
sudo ./nas-dockge.sh update-status          # Show update status
sudo ./nas-dockge.sh schedule-reboot        # Schedule reboot (uses config time)
sudo ./nas-dockge.sh schedule-reboot 02:30  # Schedule reboot at specific time

### **🔒 Security & Compliance**
sudo ./nas-dockge.sh security-audit         # Run complete security audit
sudo ./nas-dockge.sh security-status        # Show detailed security status
sudo ./nas-dockge.sh security-harden        # Apply all security hardening
sudo ./nas-dockge.sh setup-fail2ban         # Install/configure fail2ban
sudo ./nas-dockge.sh setup-ufw              # Setup UFW firewall
sudo ./nas-dockge.sh harden-ssh             # Harden SSH configuration

## 📊 Command Categories Summary

| Category | Commands |
|----------|----------|
| **Configuration** | `edit-config`, `show-config`, `validate-config` |
| **Setup** | `(no args)`, `monitor` |
| **Service** | `enable-autostart`, `disable-autostart`, `start`, `stop`, `restart`, `service-status`, `logs` |
| **Backup** | `backup`, `restore`, `list-backups` |
| **System** | `set-hostname`, `show-hostname` |
| **Disk** | `clean-disk`, `disk-space` |
| **Updates** | `update`, `full-upgrade`, `check-updates`, `update-status`, `schedule-reboot` |
| **Security** | `security-audit`, `security-status`, `security-harden`, `setup-fail2ban`, `setup-ufw`, `harden-ssh` |

## 🎯 Quick Start Workflow

# 1. Initial Setup
sudo ./nas-dockge.sh                    # Creates config file
sudo ./nas-dockge.sh edit-config        # Edit with your settings
sudo ./nas-dockge.sh validate-config    # Verify config
sudo ./nas-dockge.sh                    # Run full setup

# 2. Enable Auto-Start
sudo ./nas-dockge.sh enable-autostart   # Start on boot

# 3. Daily Operations
sudo ./nas-dockge.sh service-status     # Check status
sudo ./nas-dockge.sh logs               # View logs
sudo ./nas-dockge.sh backup             # Manual backup

# Check everything is running
sudo ./nas-dockge.sh service-status

# View live logs
sudo ./nas-dockge.sh logs

# Manual backup
sudo ./nas-dockge.sh backup

# Check for updates
sudo ./nas-dockge.sh check-updates

# Run security audit
sudo ./nas-dockge.sh security-audit

# Clean disk space
sudo ./nas-dockge.sh clean-disk
