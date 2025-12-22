# Server Helper Changelog

## Version 0.2.2 - Enhanced Debug Edition (2024-12-22)

### New Features
- ✨ **Enhanced Debug Mode**: Added comprehensive debug logging to all functions
  - Function entry/exit tracking
  - Variable state logging
  - File operation tracking
  - Network operation monitoring
  - Command execution details
  
### Improvements
- 📝 All library modules now include detailed debug statements
- 🔍 Improved troubleshooting capabilities with granular logging
- 📚 Enhanced README with debug mode documentation and examples
- 🏷️ Standardized version numbering using Semantic Versioning (SemVer)
- 💡 Added debug mode examples to help documentation

### Updated Modules
- `core.sh`: Enhanced with debug logging for all utility functions
- `config.sh`: Added debug tracking for configuration operations
- `validation.sh`: Debug logging for validation checks
- `nas.sh`: Detailed NAS mount operation debugging
- `docker.sh`: Docker and Dockge operation tracking
- `backup.sh`: Comprehensive backup/restore debugging
- `disk.sh`: Disk operation monitoring
- `updates.sh`: System update process tracking
- `security.sh`: Security operation debugging
- `service.sh`: Service management debugging
- `menu.sh`: Menu operation tracking
- `uninstall.sh`: Uninstallation process debugging

### Usage
Enable debug mode by setting the DEBUG environment variable:

```bash
DEBUG=true sudo ./server_helper_setup.sh <command>
```

Or enable it permanently in the configuration file:

```bash
DEBUG="true"
```

### Documentation
- 📖 Comprehensive README update with debug mode section
- 🔧 Added troubleshooting examples using debug mode
- 📋 Updated command reference with debug examples

### Version Numbering
- Adopted Semantic Versioning (Major.Minor.Patch)
- Current version: 0.2.2
  - Major: 0 (Pre-release)
  - Minor: 2 (Feature updates)
  - Patch: 2 (Bug fixes and enhancements)

---

## Version 0.2.1 - Config Backup Edition

### Features
- 💾 Added configuration file backup functionality
- 📦 Enhanced backup manifest with detailed file listings
- 🔄 Automatic config backup with Dockge backups
- 📁 Separate config backup directory structure

### Backup Files Included
- System configuration (/etc/fstab, /etc/hosts, /etc/hostname)
- SSH configuration (/etc/ssh/sshd_config)
- Security configuration (fail2ban, UFW)
- Server Helper configuration
- NAS credentials
- Docker configuration
- systemd service files

---

## Version 0.2.0 - Modular Architecture

### Major Changes
- 🏗️ Restructured entire codebase into modular library system
- 📁 Organized functionality into separate modules
- 🔧 Improved maintainability and code organization
- 📚 Enhanced documentation

### Module Structure
- Core utilities (`core.sh`)
- Configuration management (`config.sh`)
- Input validation (`validation.sh`)
- NAS management (`nas.sh`)
- Docker & Dockge (`docker.sh`)
- Backup & restore (`backup.sh`)
- Disk management (`disk.sh`)
- System updates (`updates.sh`)
- Security features (`security.sh`)
- Service management (`service.sh`)
- Interactive menu (`menu.sh`)
- Uninstallation (`uninstall.sh`)

---

## Installation & Upgrade

### New Installation
```bash
sudo git clone https://github.com/thelasttenno/Server-Helper.git /opt/Server-Helper
cd /opt/Server-Helper
sudo chmod +x server_helper_setup.sh
sudo ./server_helper_setup.sh
```

### Upgrading from Previous Version
```bash
# Backup your current configuration
sudo cp /opt/Server-Helper/server-helper.conf /tmp/server-helper.conf.backup

# Pull latest version
cd /opt/Server-Helper
sudo git pull

# Make scripts executable
sudo chmod +x server_helper_setup.sh
sudo chmod +x lib/*.sh

# Restore your configuration
sudo cp /tmp/server-helper.conf.backup /opt/Server-Helper/server-helper.conf

# Run setup to apply any updates
sudo ./server_helper_setup.sh setup
```

---

## Breaking Changes
None in this release. All updates are backward compatible.

---

## Known Issues
None reported.

---

## Future Roadmap

### Planned for v0.3.0 (Minor Version)
- Enhanced multi-NAS support
- Web-based configuration interface
- Email notification system
- Improved backup compression options
- Additional security hardening options

### Planned for v1.0.0 (Major Release)
- Stable production release
- Complete test coverage
- Professional documentation
- Enterprise features

---

## Support & Feedback
For issues, suggestions, or contributions, please enable debug mode when reporting:

```bash
DEBUG=true sudo ./server_helper_setup.sh <failing-command>
```

Include the debug output when seeking support.
