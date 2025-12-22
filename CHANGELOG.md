# Changelog

All notable changes to Server Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2024-12-21

### Added
- **Pre-Installation Detection System** (`lib/preinstall.sh`)
  - Automatic detection of existing systemd services
  - Detection of existing NAS mounts and credentials
  - Detection of existing Dockge installations
  - Detection of existing Docker installations
  - Detection of existing configuration files
  - Detection of existing backup directories
  - Interactive cleanup options with 4 modes:
    1. Continue with existing (skip setup)
    2. Complete removal (clean slate)
    3. Selective cleanup (choose components)
    4. Cancel and exit
  - Emergency backups created before removal
  - `check-install` command for manual pre-check
  - `remove-install` command for component removal

- **Comprehensive Debug Logging**
  - Debug mode for all library functions
  - Function entry/exit logging
  - Variable state tracking
  - Decision point logging
  - File operation tracking
  - Network call monitoring
  - Command execution visibility
  - Enhanced error context
  - Debug logs saved to `/var/log/server-helper/server-helper.log`
  - `DEBUG=true` environment variable support

- **Configuration File Backup**
  - Automatic backup of critical system files:
    - `/etc/fstab`, `/etc/hosts`, `/etc/hostname`
    - `/etc/ssh/sshd_config`
    - `/etc/fail2ban/jail.local`
    - `/etc/ufw/ufw.conf`
    - `/etc/systemd/system/server-helper.service`
  - Automatic backup of configuration directories:
    - `/etc/docker/`
    - `/etc/apt/sources.list.d/`
  - NAS credential file backup
  - Server Helper config file backup
  - Backup manifest generation with file listing
  - `backup-config` command for manual config backup
  - `restore-config` command for config restoration
  - Emergency backup creation before restoration
  - Configuration backups stored in `$BACKUP_DIR/config/`
  - Config backup automatically included with Dockge backups

- **Backup Manifest System**
  - `show-manifest` command to view backup contents
  - Manifest includes:
    - Creation date and time
    - Hostname and kernel version
    - OS version
    - File count
    - Complete file listing
  - Manifest embedded in config backups

- **Enhanced Commands**
  - `backup-all` - Explicit command to backup everything
  - `show-manifest <file>` - Show backup contents
  - `check-install` - Check for existing installation
  - `remove-install` - Remove existing components

### Changed
- **Module Loading Order**
  - Added `preinstall` module after `validation`
  - Ensures proper dependency resolution
  - Documented in ORDERING_ANALYSIS.md

- **main_setup() Function**
  - Now calls `pre_installation_check()` first
  - Only proceeds with setup after user confirmation
  - Creates initial config backup after successful setup

- **backup_dockge() Function**
  - Now automatically calls `backup_config_files()`
  - Ensures config is always backed up with Dockge data

- **Enhanced Logging**
  - All core functions now include debug logging
  - Function parameters logged in debug mode
  - Return values and exit codes logged
  - File size information in log output

- **Version Information**
  - Updated to v2.2.0
  - Enhanced version display with feature list

- **Help Documentation**
  - Updated help text with new commands
  - Added pre-installation detection section
  - Added debug mode documentation
  - Added examples for new features

### Fixed
- **Array Handling**
  - `NAS_ARRAY` properly initialized as global array
  - Prevents "unbound variable" errors
  - Safe array checks: `[ -n "${NAS_ARRAY+x}" ] && [ ${#NAS_ARRAY[@]} -gt 0 ]`
  - Applied to nas.sh, backup.sh, uninstall.sh

- **Config Loading**
  - Config loading skipped for help/version commands
  - Prevents errors when no config file exists
  - Safe fallback behavior

- **Error Handling**
  - Improved error context in debug mode
  - Better error messages with line numbers
  - Trap handler preserves error context

### Security
- **Configuration Backup**
  - SSH configuration backed up
  - Firewall rules backed up
  - fail2ban configuration backed up
  - NAS credentials backed up securely
  - Emergency backups before restoration

### Documentation
- **README.md** - Completely rewritten with:
  - Pre-installation detection documentation
  - Debug mode usage guide
  - Configuration backup feature documentation
  - Enhanced troubleshooting section
  - Complete command reference update
  - New examples and use cases
  - Version 2.2 feature highlights

- **ORDERING_ANALYSIS.md** - New document
  - Module loading order analysis
  - Dependency validation
  - Function call chain documentation
  - No critical issues found

- **CHANGELOG.md** - This file
  - Comprehensive version history
  - Detailed change tracking

## [2.1.0] - 2024-12-20

### Added
- Configuration file backup to Dockge backups
- Backup manifest generation
- Enhanced backup/restore documentation

### Changed
- Backup retention handling
- Backup directory structure

### Fixed
- Backup reliability improvements
- Error handling in backup operations

## [2.0.0] - 2024-12-15

### Added
- Modular architecture with separate library files
- Interactive menu system
- Comprehensive monitoring system
- Systemd service integration
- Auto-recovery for NAS and Dockge
- Disk cleanup automation
- Security audit and hardening
- Update management
- Uptime Kuma integration

### Changed
- Complete rewrite from monolithic to modular
- Enhanced error handling
- Improved logging system

## [1.0.0] - 2024-12-01

### Added
- Initial release
- Basic NAS mounting
- Docker and Dockge installation
- Simple backup functionality

---

## Version History Summary

- **v2.2.0** (Current) - Pre-installation detection, debug mode, config backups
- **v2.1.0** - Configuration backup enhancements
- **v2.0.0** - Modular rewrite with comprehensive features
- **v1.0.0** - Initial release

---

## Upgrade Notes

### Upgrading to 2.2.0 from 2.1.0 or earlier

1. **Backup your current installation:**
   ```bash
   sudo ./server_helper_setup.sh backup-all
   ```

2. **Stop the service if running:**
   ```bash
   sudo systemctl stop server-helper
   ```

3. **Update the scripts:**
   ```bash
   cd /opt/Server-Helper
   git pull origin main
   # Or manually copy new files
   ```

4. **Verify module files:**
   ```bash
   ls lib/
   # Should include: preinstall.sh and updated core.sh, backup.sh
   ```

5. **Run pre-installation check:**
   ```bash
   sudo ./server_helper_setup.sh check-install
   ```

6. **Restart service:**
   ```bash
   sudo systemctl start server-helper
   ```

7. **Test new features:**
   ```bash
   # Test debug mode
   DEBUG=true sudo ./server_helper_setup.sh service-status
   
   # Test config backup
   sudo ./server_helper_setup.sh backup-config
   
   # Test backup manifest
   sudo ./server_helper_setup.sh list-backups
   ```

### Breaking Changes

**None.** Version 2.2.0 is fully backward compatible with 2.1.0 and 2.0.0.

### New Requirements

- **Module Files:** Ensure `lib/preinstall.sh` exists
- **Enhanced Modules:** Updated `lib/core.sh` and `lib/backup.sh`
- **No additional system packages required**

---

## Future Roadmap

### Planned for 2.3.0
- Web-based dashboard
- Email notifications
- Advanced monitoring metrics
- Container health checks
- Network monitoring
- Custom backup schedules

### Planned for 3.0.0
- Multi-server management
- Cluster support
- Advanced security features
- Plugin system
- API access

---

## Contributing

When contributing, please:
1. Update this CHANGELOG
2. Follow semantic versioning
3. Add debug logging to new functions
4. Update README.md with new features
5. Test with DEBUG=true mode

---

## Links

- [Repository](https://github.com/thelasttenno/Server-Helper)
- [Documentation](README.md)
- [Ordering Analysis](ORDERING_ANALYSIS.md)
- [License](LICENSE)
