#!/bin/bash
# Server Helper Setup Script - Main Entry Point
# Version 2.2 - Enhanced with Pre-Installation Detection & Debug Modes

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/server-helper.conf}"

# Logging configuration
LOG_DIR="/var/log/server-helper"
LOG_FILE="$LOG_DIR/server-helper.log"
ERROR_LOG="$LOG_DIR/error.log"
DEBUG="${DEBUG:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Create log directory
mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Core logging functions
log() {
    local msg="$1"
    local ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[$ts]${NC} $msg" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${GREEN}[$ts]${NC} $msg"
}

error() {
    local msg="$1"
    local ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[$ts] ERROR:${NC} $msg" | tee -a "$LOG_FILE" 2>/dev/null >&2 || echo -e "${RED}[$ts] ERROR:${NC} $msg" >&2
    echo "[$ts] ERROR: $msg" >> "$ERROR_LOG" 2>/dev/null || true
}

warning() {
    local msg="$1"
    local ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[$ts] WARNING:${NC} $msg" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}[$ts] WARNING:${NC} $msg"
}

debug() {
    if [ "$DEBUG" = "true" ]; then
        local msg="$1"
        local ts="$(date '+%Y-%m-%d %H:%M:%S')"
        echo -e "${BLUE}[$ts] DEBUG:${NC} $msg" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${BLUE}[$ts] DEBUG:${NC} $msg"
    fi
}

# Error handler
error_handler() {
    local exit_code=$1
    local line_num=$2
    error "Script failed at line $line_num with exit code $exit_code"
    error "Command: $BASH_COMMAND"
}

trap 'error_handler $? $LINENO' ERR

# Check if module directory exists
if [ ! -d "$LIB_DIR" ]; then
    error "Module directory not found: $LIB_DIR"
    error "Please ensure all library files are in the lib/ directory"
    exit 1
fi

# Load modules in order
MODULES=(
    "core"
    "config"
    "validation"
    "preinstall"
    "nas"
    "docker"
    "backup"
    "disk"
    "updates"
    "security"
    "service"
    "menu"
    "uninstall"
)

debug "Loading modules from: $LIB_DIR"

for module in "${MODULES[@]}"; do
    module_file="$LIB_DIR/${module}.sh"
    if [ -f "$module_file" ]; then
        debug "Loading: ${module}.sh"
        source "$module_file"
    else
        error "Required module not found: ${module}.sh"
        error "Please ensure all modules are present in $LIB_DIR/"
        exit 1
    fi
done

log "✓ All modules loaded successfully"

# Initialize
if [ "$DRY_RUN" = "true" ]; then
    warning "DRY-RUN MODE - No changes will be made"
fi

# Load and validate configuration (if not running certain commands)
case "${1:-menu}" in
    help|--help|-h|version|--version|-v)
        # Skip config loading for help/version
        ;;
    *)
        load_config
        set_defaults
        parse_nas_shares
        ;;
esac

# Show version
show_version() {
    echo "Server Helper v2.2.0 - Pre-Installation Detection & Debug Edition"
    echo "For Ubuntu 24.04.3 LTS"
    echo ""
    echo "Features:"
    echo "  • Pre-installation detection"
    echo "  • Configuration file backup"
    echo "  • Comprehensive debug logging"
    echo "  • Selective component removal"
}

# Show help
show_help() {
    cat << 'EOF'
Server Helper - Comprehensive Server Management Tool

USAGE:
    sudo ./server_helper_setup.sh [COMMAND] [OPTIONS]

COMMANDS:
    Configuration:
        edit-config          Edit configuration file
        show-config          Show configuration (passwords masked)
        validate-config      Validate configuration

    Setup & Monitoring:
        setup                Run full setup (includes pre-installation check)
        monitor              Start monitoring services
        menu                 Show interactive menu (default)

    Service Management:
        enable-autostart     Enable systemd auto-start
        disable-autostart    Disable systemd auto-start
        start                Start service
        stop                 Stop service
        restart              Restart service
        service-status       Show service status
        logs                 View live logs

    Backup & Restore:
        backup               Create Dockge backup (includes config backup)
        backup-config        Backup configuration files only
        backup-all           Backup everything (Dockge + config)
        restore              Restore Dockge from backup
        restore-config       Restore configuration files
        list-backups         List all backups
        show-manifest <file> Show backup contents

    NAS Management:
        list-nas             List NAS shares
        mount-nas            Mount NAS shares

    System Management:
        set-hostname <name>  Set system hostname
        show-hostname        Show current hostname
        clean-disk           Clean disk space
        disk-space           Show disk usage

    Updates:
        update               Update system
        full-upgrade         Full system upgrade
        check-updates        Check for updates
        update-status        Show update status
        schedule-reboot      Schedule system reboot

    Security:
        security-audit       Run security audit
        security-status      Show security status
        security-harden      Apply security hardening
        setup-fail2ban       Setup fail2ban
        setup-ufw            Setup UFW firewall
        harden-ssh           Harden SSH

    Installation:
        check-install        Check for existing installation
        remove-install       Remove existing installation

    Other:
        uninstall            Uninstall Server Helper
        help                 Show this help
        version              Show version

ENVIRONMENT VARIABLES:
    DRY_RUN=true         Run in dry-run mode (no changes)
    DEBUG=true           Enable debug logging
    CONFIG_FILE=<path>   Use custom config file

EXAMPLES:
    # Interactive menu
    sudo ./server_helper_setup.sh menu
    
    # Check for existing installation
    sudo ./server_helper_setup.sh check-install
    
    # Run setup with debug logging
    DEBUG=true sudo ./server_helper_setup.sh setup
    
    # Create complete backup
    sudo ./server_helper_setup.sh backup-all
    
    # Dry-run update
    DRY_RUN=true sudo ./server_helper_setup.sh update

PRE-INSTALLATION DETECTION:
    The setup command now automatically detects existing installations:
    - Systemd services
    - NAS mounts
    - Dockge installations
    - Docker installations
    - Configuration files
    - Existing backups
    
    You'll be prompted to:
    1) Keep existing installation
    2) Remove and reinstall (clean slate)
    3) Selective cleanup (choose components)
    4) Cancel and exit

DEBUG MODE:
    Enable comprehensive debug logging:
        DEBUG=true sudo ./server_helper_setup.sh <command>
    
    Debug logs show:
    - Function entry/exit
    - Variable values
    - Decision points
    - File operations
    - Network calls

LOG FILES:
    /var/log/server-helper/server-helper.log
    /var/log/server-helper/error.log

EOF
}

# Main setup with pre-installation check
main_setup() {
    log "Starting Server Helper setup..."
    debug "main_setup() - Begin"
    
    # Run pre-installation check
    pre_installation_check
    
    log "Running full setup..."
    
    [ -n "$NEW_HOSTNAME" ] && set_hostname "$NEW_HOSTNAME"
    
    mount_nas || [ "$NAS_MOUNT_REQUIRED" = "true" ] && { error "NAS required but failed"; return 1; }
    
    install_docker
    install_dockge
    start_dockge
    
    # Create initial config backup after setup
    backup_config_files
    
    show_setup_complete
    
    debug "main_setup() - Completed"
}

show_setup_complete() {
    echo ""
    log "═══════════════════════════════════════"
    log "        Setup Complete!"
    log "═══════════════════════════════════════"
    log "Hostname: $(hostname)"
    log "Dockge: http://localhost:$DOCKGE_PORT"
    list_nas_shares
    echo ""
    log "Next steps:"
    log "  1. Enable auto-start: sudo ./server_helper_setup.sh enable-autostart"
    log "  2. Start monitoring: sudo ./server_helper_setup.sh start"
    log "  3. View status: sudo ./server_helper_setup.sh service-status"
    echo ""
}

# Handle command-line arguments
case "${1:-menu}" in
    setup) main_setup ;;
    monitor) monitor_services ;;
    
    # Backup commands
    backup) backup_dockge ;;
    backup-config) backup_config_files ;;
    backup-all) backup_all ;;
    
    # Restore commands
    restore) restore_dockge ;;
    restore-config) restore_config_files ;;
    
    # Backup utilities
    list-backups) list_backups ;;
    show-manifest) show_backup_manifest "${2:-}" ;;
    
    # System management
    set-hostname) set_hostname "${2:-}" ;;
    show-hostname) show_hostname ;;
    clean-disk) clean_disk ;;
    disk-space) show_disk_space ;;
    
    # Updates
    update) update_system ;;
    full-upgrade) full_upgrade ;;
    check-updates) check_updates; show_update_status ;;
    update-status) show_update_status ;;
    schedule-reboot) schedule_reboot "${2:-}" ;;
    
    # Security
    security-audit) security_audit ;;
    security-status) show_security_status ;;
    security-harden) apply_security_hardening ;;
    setup-fail2ban) setup_fail2ban ;;
    setup-ufw) setup_ufw ;;
    harden-ssh) harden_ssh ;;
    
    # Service management
    enable-autostart) create_systemd_service ;;
    disable-autostart) remove_systemd_service ;;
    service-status) show_service_status ;;
    start) start_service_now ;;
    stop) stop_service ;;
    restart) restart_service ;;
    logs) show_logs ;;
    
    # Configuration
    edit-config) edit_config ;;
    show-config) show_config ;;
    validate-config) validate_config ;;
    
    # NAS
    list-nas) list_nas_shares ;;
    mount-nas) mount_nas ;;
    
    # Installation management
    check-install) pre_installation_check ;;
    remove-install) 
        detect_existing_service && cleanup_existing_service
        detect_existing_dockge && cleanup_existing_dockge
        detect_existing_mounts && cleanup_existing_mounts
        detect_existing_docker && cleanup_existing_docker
        log "✓ Installation removal complete"
        ;;
    
    # Other
    uninstall) uninstall_server_helper ;;
    menu) show_menu ;;
    help|--help|-h) show_help ;;
    version|--version|-v) show_version ;;
    
    *) show_menu ;;
esac
