# Server Helper v2.2.0 - Quick Start Guide

## 📦 Installation

### 1. Download and Extract

Download all files and extract to your preferred location:
```bash
# Option A: Extract to /opt/Server-Helper (recommended)
sudo mkdir -p /opt/Server-Helper
sudo cp -r * /opt/Server-Helper/
cd /opt/Server-Helper

# Option B: Extract to current directory
cd /path/to/extracted/files
```

### 2. Make Executable

```bash
sudo chmod +x server_helper_setup.sh
```

### 3. First Run (Creates Config)

```bash
sudo ./server_helper_setup.sh
```

This will create `server-helper.conf` with default values.

### 4. Configure

Edit the configuration file:
```bash
sudo nano server-helper.conf
```

**Required Settings:**
```bash
NAS_IP="192.168.1.100"          # Your NAS IP
NAS_SHARE="share"                # Your NAS share name
NAS_USERNAME="your_username"     # NAS username
NAS_PASSWORD="your_password"     # NAS password
```

Save and exit (Ctrl+X, Y, Enter).

### 5. Run Setup

```bash
sudo ./server_helper_setup.sh setup
```

The script will:
- Check for existing installations
- Offer cleanup options if found
- Mount NAS
- Install Docker & Dockge
- Create initial config backup

### 6. Enable Auto-Start (Recommended)

```bash
sudo ./server_helper_setup.sh enable-autostart
sudo ./server_helper_setup.sh start
```

### 7. Verify Installation

```bash
sudo ./server_helper_setup.sh service-status
```

---

## 🎯 Quick Commands

### Daily Operations
```bash
# Check status
sudo ./server_helper_setup.sh service-status

# View live logs
sudo ./server_helper_setup.sh logs

# Create backup
sudo ./server_helper_setup.sh backup

# Check for updates
sudo ./server_helper_setup.sh check-updates
```

### With Debug Mode
```bash
# Any command can use debug mode
DEBUG=true sudo ./server_helper_setup.sh <command>

# Examples:
DEBUG=true sudo ./server_helper_setup.sh setup
DEBUG=true sudo ./server_helper_setup.sh backup
DEBUG=true sudo ./server_helper_setup.sh security-audit
```

---

## 🆕 New Features in v2.2.0

### Pre-Installation Detection
Automatically detects existing installations and offers cleanup:
```bash
# Check what's installed
sudo ./server_helper_setup.sh check-install

# Remove components
sudo ./server_helper_setup.sh remove-install
```

### Configuration Backup
Backs up all system config files:
```bash
# Backup config only
sudo ./server_helper_setup.sh backup-config

# Restore config
sudo ./server_helper_setup.sh restore-config

# View backup contents
sudo ./server_helper_setup.sh show-manifest /path/to/backup.tar.gz
```

### Debug Mode
Comprehensive debug logging:
```bash
DEBUG=true sudo ./server_helper_setup.sh <any_command>
```

---

## 📂 File Structure

```
Server-Helper/
├── server_helper_setup.sh          # Main script
├── server-helper.conf              # Configuration (create first)
├── lib/                            # Library modules
│   ├── core.sh                    # Core utilities
│   ├── config.sh                  # Configuration
│   ├── validation.sh              # Validation
│   ├── preinstall.sh              # Pre-install detection (NEW)
│   ├── nas.sh                     # NAS management
│   ├── docker.sh                  # Docker/Dockge
│   ├── backup.sh                  # Backup/restore (enhanced)
│   ├── disk.sh                    # Disk management
│   ├── updates.sh                 # System updates
│   ├── security.sh                # Security features
│   ├── service.sh                 # Systemd service
│   ├── menu.sh                    # Interactive menu
│   └── uninstall.sh               # Uninstallation
├── README.md                       # Full documentation
├── CHANGELOG.md                    # Version history
├── ORDERING_ANALYSIS.md            # Technical analysis
├── IMPLEMENTATION_SUMMARY.md       # Development summary
└── LICENSE                         # GPL v3 License
```

---

## 📖 Documentation

- **README.md** - Complete documentation with all features
- **CHANGELOG.md** - Version history and changes
- **ORDERING_ANALYSIS.md** - Technical dependency analysis
- **IMPLEMENTATION_SUMMARY.md** - Development notes

---

## 🔍 Troubleshooting

### Enable Debug Mode
For any issue, enable debug mode first:
```bash
DEBUG=true sudo ./server_helper_setup.sh <command>
```

### Check Logs
```bash
# View live logs
tail -f /var/log/server-helper/server-helper.log

# View error logs
tail -f /var/log/server-helper/error.log
```

### Common Issues

**Config file not found:**
```bash
sudo ./server_helper_setup.sh
# This creates the config file
```

**NAS won't mount:**
```bash
DEBUG=true sudo ./server_helper_setup.sh mount-nas
# Check output for specific error
```

**Service won't start:**
```bash
sudo ./server_helper_setup.sh service-status
sudo journalctl -u server-helper -n 50
```

---

## ✅ What's Included

### Core Files
- ✅ Main script (server_helper_setup.sh)
- ✅ All 13 library modules
- ✅ Complete documentation (4 files)
- ✅ License file

### Features
- ✅ Pre-installation detection
- ✅ Debug mode in all functions
- ✅ Configuration backup system
- ✅ NAS management
- ✅ Docker & Dockge automation
- ✅ Monitoring & auto-recovery
- ✅ Backup & restore (enhanced)
- ✅ Security hardening
- ✅ System updates
- ✅ Disk management

---

## 🎓 Next Steps

1. **Read README.md** - Full feature documentation
2. **Configure your settings** - Edit server-helper.conf
3. **Run setup** - `sudo ./server_helper_setup.sh setup`
4. **Enable auto-start** - `sudo ./server_helper_setup.sh enable-autostart`
5. **Start monitoring** - `sudo ./server_helper_setup.sh start`

---

## 📞 Support

- Enable debug mode: `DEBUG=true`
- Check logs: `/var/log/server-helper/`
- View status: `sudo ./server_helper_setup.sh service-status`
- Read docs: `README.md`, `CHANGELOG.md`

---

## 🚀 You're Ready!

Server Helper v2.2.0 is ready to deploy. All features tested and documented.

**Happy Server Managing! 🎉**
