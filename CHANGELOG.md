# Server Helper Changelog

## Version 0.3.0 - Self-Update & Loading Indicators (2025-12-22)

### New Features

- 🆙 **Self-Updater System**: Complete automated update functionality

  - Automatic version checking against GitHub repository
  - One-command update: `sudo ./server_helper_setup.sh self-update`
  - Automatic backup creation before updates
  - Configuration file preservation during updates
  - Service state management (stops before update, restarts after)
  - Rollback capability to previous versions
  - Changelog viewing: `sudo ./server_helper_setup.sh changelog`
  - Optional auto-update checking in monitoring loop (12-hour cycle)
- ⏳ **Loading Indicators**: Visual feedback for long-running operations

  - Spinner animation for background processes
  - Progress bars for multi-step operations
  - Execute-with-spinner wrapper for commands
  - No external dependencies required (pure bash implementation)
- 📡 **Uptime Kuma Integration**: Update notification support

  - Optional heartbeat URL for update notifications
  - Sends notifications when updates are available
  - Configurable via `UPTIME_KUMA_UPDATE_URL` in config

### New Commands

- `check-updates-script` - Check for Server Helper script updates
- `self-update` - Update Server Helper to latest version from GitHub
- `rollback` - Rollback to previous version
- `changelog` - View update changelog from GitHub

### New Module

- `lib/selfupdate.sh` - Complete self-update system
  - `check_for_script_updates()` - Compare local vs GitHub versions
  - `self_update()` - Full 5-step update process with safety checks
  - `rollback_update()` - Restore previous version from backup
  - `auto_update_check()` - Non-intrusive background update checking
  - `show_update_changelog()` - Fetch and display GitHub changelog

### Improvements

- 📋 Enhanced interactive menu with 43 options (up from 38)
- 🎨 New menu section: "Self-Update" with options 39-42
- 🔄 Auto-update check integrated into monitoring service
- 💾 Automatic configuration backup before updates
- 🛡️ Safe update process with rollback capability
- 📦 Backup system creates timestamped backups before updates
- 🔍 Version comparison using curl to GitHub raw content

### Updated Modules

- `core.sh`: Added `show_spinner()`, `show_progress_bar()`, `show_progress()`, `execute_with_spinner()`
- `config.sh`: Added `AUTO_UPDATE_CHECK` and `UPTIME_KUMA_UPDATE_URL` configuration options
- `service.sh`: Integrated auto-update check into monitoring loop (360 cycles = 12 hours)
- `menu.sh`: Updated to v0.3.0, added self-update menu section (options 39-42)
- `server_helper_setup.sh`: Added selfupdate module to loading order, new commands

### Configuration Options

New options added to `server-helper.conf`:

```bash
# Self-Update Configuration (NEW in 0.3.0)
AUTO_UPDATE_CHECK="false"  # Check for script updates during monitoring
UPTIME_KUMA_UPDATE_URL=""  # Optional: Uptime Kuma URL for update notifications
```

### Menu Structure Changes

- Menu items 39-42: Self-Update (NEW)
  - 39: Check for updates
  - 40: Update to latest version
  - 41: Rollback to previous version
  - 42: View changelog
- Menu item 43: Uninstall (shifted from 38)

### Technical Details

**Self-Update Process**:

1. Fetch VERSION file from GitHub raw content
2. Compare with local VERSION file
3. Create timestamped backup in `/opt/Server-Helper-backup-YYYYMMDD_HHMMSS/`
4. Backup current configuration file
5. Clone latest version from GitHub
6. Stop systemd service if running
7. Install update (copy files from temp directory)
8. Restore configuration file
9. Restart service if it was running
10. Clean up temporary files

**Loading Indicators**:

- `show_spinner()`: Animated spinner (|/-\) for background processes
- `show_progress_bar()`: Visual progress bar with percentage
- `execute_with_spinner()`: Wrapper to execute commands with spinner feedback
- All indicators support DEBUG mode for troubleshooting

**Monitoring Integration**:

- Auto-update check runs every 360 cycles (720 minutes = 12 hours)
- Non-intrusive - only logs when updates are available
- Optional Uptime Kuma notifications
- Does not automatically install updates (manual approval required)

### Usage Examples

```bash
# Check for script updates
sudo ./server_helper_setup.sh check-updates-script

# Update to latest version
sudo ./server_helper_setup.sh self-update

# Rollback to previous version
sudo ./server_helper_setup.sh rollback

# View update changelog
sudo ./server_helper_setup.sh changelog

# Enable auto-update checking (edit config)
sudo ./server_helper_setup.sh edit-config
# Set AUTO_UPDATE_CHECK="true"
```

### Breaking Changes

None. All updates are backward compatible with v0.2.x configurations.

### Upgrade Notes

When upgrading from 0.2.x:

- Use the new `self-update` command for automatic updates
- Configuration file is automatically preserved
- Systemd service is managed automatically (stops/restarts)
- Previous manual git pull method still works but not recommended
- New config options are optional with safe defaults

### Known Issues

None reported.

### Dependencies

- `git` - Required for cloning updates from GitHub
- `curl` - Required for fetching VERSION file
- Both are standard on Ubuntu 24.04.3 LTS

---

## Version 0.2.3 - Integration Update (2025-12-22)

### New Features

- ✨ **Pre-Installation Detection**: Integrated existing installation detection system

  - Automatically detects existing Server Helper installations
  - Detects systemd services, NAS mounts, Dockge, Docker, config files, and backups
  - Interactive cleanup options (keep, remove all, selective, or cancel)
  - Runs automatically during `setup` command
  - Available as standalone `check-install` command
- 🚨 **Emergency NAS Unmount**: Integrated emergency unmount functionality

  - Force unmount stuck NAS shares with multiple fallback methods
  - Automatic process detection and optional termination
  - Cleans up fstab entries and credential files
  - Available as `unmount-nas` command and menu option (21)
  - Supports optional mount point parameter
- 🔧 **Installation Management**: New commands and menu section

  - `check-install` - Check for existing installations
  - `clean-install` - Remove existing installation components
  - Menu options 36-37 for installation management

### Improvements

- 📋 Enhanced interactive menu with 38 options (up from 35)
- 🗂️ Reorganized menu with new "Install" section
- 📝 Updated help text with new commands and examples
- 🔍 Better integration of orphaned scripts (preinstall.sh, emergency-unmount-nas.sh)
- 🏗️ Preinstall module now loaded in main script module order

### Updated Modules

- `nas.sh`: Added `emergency_unmount_nas()` function with 4 unmount methods
- `menu.sh`: Updated to v0.2.3, added installation management options
- `server_helper_setup.sh`: Integrated preinstall module, added new commands

### New Commands

- `unmount-nas [mount_point]` - Emergency unmount NAS with force options
- `check-install` - Run pre-installation check
- `clean-install` - Clean existing installation components

### Menu Structure Changes

- Menu item 21: Emergency NAS Unmount
- Menu items 22-24: System (shifted from 21-23)
- Menu items 25-29: Updates (shifted from 24-28)
- Menu items 30-35: Security (shifted from 29-34)
- Menu items 36-37: Installation Management (NEW)
- Menu item 38: Uninstall (shifted from 35)

### Integrated Files

- `lib/preinstall.sh` - Now loaded as module
- `lib/emergency-unmount-nas.sh` - Functionality integrated into nas.sh

### Bug Fixes

- Fixed orphaned preinstall.sh not being used in main script
- Integrated standalone emergency unmount script into main program

---

## Version 0.2.2 - Enhanced Debug Edition (2025-12-22)

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
