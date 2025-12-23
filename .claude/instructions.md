# Server Helper Project Instructions

## Project Overview

Bash-based server management tool for Ubuntu Server 24.04.3 LTS

- Modular architecture with library system
- NAS mounting, Docker/Dockge automation, backups, security

## Version Management

- Use SemVer (Major.Minor.Patch)
- Current version in: `VERSION` file and multiple locations
- Always ask if change is Major, Minor, or Patch before updating

## Code Standards

### 1. Debug Logging

ALL functions must include debug statements:

```bash
function_name() {
    debug "[function_name] Starting with param: $1"
    # ... code ...
    debug "[function_name] Operation complete"
}
```

### 2. Module Loading Order (CRITICAL)

Modules in `lib/` must load in this order:

1. core.sh (base utilities)
2. config.sh (configuration)
3. validation.sh (input validation)
4. preinstall.sh (pre-installation checks)
5. nas.sh (NAS management)
6. docker.sh (Docker/Dockge)
7. backup.sh (backup/restore)
8. disk.sh (disk management)
9. updates.sh (system updates)
10. security.sh (security features)
11. service.sh (systemd service)
12. menu.sh (interactive menu)
13. uninstall.sh (uninstallation)

### 3. Error Handling

- Use `set -euo pipefail` in main script
- All functions should return proper exit codes
- Use error_handler trap for debugging

### 4. Configuration

- All config in `server-helper.conf`
- Use `chmod 600` for security
- Mask passwords in display functions

## File Structure

```
/
├── server_helper_setup.sh    # Main entry point
├── VERSION                   # Version file
├── server-helper.conf        # Configuration (created on first run)
└── lib/                      # All modules here
    ├── core.sh
    ├── config.sh
    └── ...
```

## When Making Changes

### Version Updates

1. Ask: Major, Minor, or Patch?
2. Update these locations:
   - `VERSION` file
   - `server_helper_setup.sh` header
   - `README.md` version
   - `CHANGELOG.md` new entry
   - Menu display in `lib/menu.sh`

### Minor Version Changes

- Check for critical ordering issues in module loading
- Run security audit on changes
- Ensure all new functions have debug logging

### Documentation Updates

- Update README.md with:
  - New commands in command reference
  - New features in features list
  - Setup instructions if changed
- Update CHANGELOG.md:
  - Keep old entries in condensed form
  - Add new version section at top
  - Use format from existing entries

## Security Requirements

- Never expose credentials in logs
- Use credential files with chmod 600
- Validate all user inputs
- Use `sudo` appropriately, not globally

## Testing Checklist

Before committing:

- [ ] All functions have debug logging
- [ ] Module load order maintained
- [ ] Version updated in all locations
- [ ] README command reference updated
- [ ] CHANGELOG updated
- [ ] No credentials exposed
- [ ] Config file permissions correct (600)

## Common Patterns

### Adding New Command

1. Add function to appropriate module
2. Add case statement entry in main script
3. Add menu entry if needed
4. Update README command reference
5. Add help text to show_help()

### Adding New Config Option

1. Add to create_default_config() in config.sh
2. Add to set_defaults() if needed
3. Document in README configuration section
4. Use in relevant functions

## Debug Mode Usage

Enable with: `DEBUG=true sudo ./server_helper_setup.sh <command>`
