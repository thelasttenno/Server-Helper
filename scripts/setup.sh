#!/usr/bin/env bash
# =============================================================================
# Server Helper v2.0 — setup.sh (Interactive Setup & Menu)
# =============================================================================
# Main entry point for the Server Helper CLI.
# Sources library modules from scripts/lib/ and presents an interactive menu.
#
# Strict sourcing: If a required library is missing, exit with FATAL.
# Source order matters: security.sh first, then ui_utils.sh, then the rest.
# =============================================================================

set -euo pipefail

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Export for library modules
export SCRIPT_DIR PROJECT_ROOT LIB_DIR

# =============================================================================
# STRICT SOURCING — order matters!
# =============================================================================
source_lib() {
    local lib_file="$LIB_DIR/$1"
    if [[ ! -f "$lib_file" ]]; then
        echo "FATAL: Required library missing: $lib_file" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$lib_file"
}

# 1. Security MUST be sourced first (registers cleanup trap)
source_lib "security.sh"

# 2. UI utilities next (colors, logging, headers)
source_lib "ui_utils.sh"

# 3. Remaining modules (any order)
source_lib "config_mgr.sh"
source_lib "secrets_mgr.sh"
source_lib "vault_mgr.sh"
source_lib "inventory_mgr.sh"
source_lib "health_check.sh"
source_lib "menu_extras.sh"
source_lib "testing.sh"
source_lib "upgrade.sh"

# =============================================================================
# VERSION
# =============================================================================
VERSION=$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "unknown")

# =============================================================================
# MAIN MENU
# =============================================================================
show_main_menu() {
    clear
    print_header "Server Helper v$VERSION"
    echo ""
    echo "  ${CYAN}1)${NC}  🔧  Quick Setup Wizard"
    echo "  ${CYAN}2)${NC}  🔐  Secrets Management"
    echo "  ${CYAN}3)${NC}  🏗️   Deploy Infrastructure"
    echo "  ${CYAN}4)${NC}  🖥️   Fleet Management"
    echo "  ${CYAN}5)${NC}  🔄  Updates & Upgrades"
    echo "  ${CYAN}6)${NC}  💾  Backup Management"
    echo "  ${CYAN}7)${NC}  🧪  Testing"
    echo "  ${CYAN}8)${NC}  🏥  Health Check"
    echo "  ${CYAN}9)${NC}  📦  Extras"
    echo "  ${CYAN}0)${NC}  🚪  Exit"
    echo ""
    echo -n "  Select option: "
}

# =============================================================================
# DEPLOY MENU
# =============================================================================
show_deploy_menu() {
    clear
    print_header "Deploy Infrastructure"
    echo ""
    echo "  ${CYAN}1)${NC}  Full deployment (site.yml)"
    echo "  ${CYAN}2)${NC}  Control node only"
    echo "  ${CYAN}3)${NC}  Target nodes only"
    echo "  ${CYAN}4)${NC}  Add new server"
    echo "  ${CYAN}5)${NC}  Dry run (check mode)"
    echo "  ${CYAN}0)${NC}  Back"
    echo ""
    echo -n "  Select option: "
}

handle_deploy_menu() {
    local choice
    read -r choice
    case $choice in
        1) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/site.yml'" ;;
        2) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/control.yml'" ;;
        3) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/target.yml'" ;;
        4)
            echo -n "  Hostname (must be in inventory): "
            local host
            read -r host
            log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/add-target.yml' --limit '$host'"
            ;;
        5) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/site.yml' --check --diff" ;;
        0) return ;;
    esac
}

# =============================================================================
# SECRETS MENU
# =============================================================================
show_secrets_menu() {
    clear
    print_header "Secrets Management"
    echo ""
    echo "  ${CYAN}1)${NC}  Generate all secrets (fresh)"
    echo "  ${CYAN}2)${NC}  Generate missing secrets (idempotent)"
    echo "  ${CYAN}3)${NC}  Edit vault"
    echo "  ${CYAN}4)${NC}  View vault"
    echo "  ${CYAN}5)${NC}  Re-key vault"
    echo "  ${CYAN}6)${NC}  Validate vault"
    echo "  ${CYAN}0)${NC}  Back"
    echo ""
    echo -n "  Select option: "
}

handle_secrets_menu() {
    local choice
    read -r choice
    case $choice in
        1) generate_secrets "fresh" ;;
        2) generate_secrets "idempotent" ;;
        3) vault_edit ;;
        4) vault_view ;;
        5) vault_rekey ;;
        6) vault_validate ;;
        0) return ;;
    esac
}

# =============================================================================
# MAIN LOOP
# =============================================================================
main() {
    # Pre-flight checks
    check_requirements

    while true; do
        show_main_menu
        local choice
        read -r choice
        case $choice in
            1) quick_setup_wizard ;;
            2)
                show_secrets_menu
                handle_secrets_menu
                ;;
            3)
                show_deploy_menu
                handle_deploy_menu
                ;;
            4) fleet_management_menu ;;
            5)
                clear
                print_header "Updates & Upgrades"
                echo ""
                echo "  ${CYAN}1)${NC}  System updates (apt)"
                echo "  ${CYAN}2)${NC}  Docker image upgrades"
                echo "  ${CYAN}0)${NC}  Back"
                echo ""
                echo -n "  Select option: "
                local uchoice
                read -r uchoice
                case $uchoice in
                    1) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/update.yml'" ;;
                    2) upgrade_menu ;;
                    0) ;;
                esac
                ;;
            6) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/backup.yml'" ;;
            7) testing_menu ;;
            8) run_health_check ;;
            9) extras_menu ;;
            0)
                echo ""
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac

        echo ""
        echo "  Press Enter to continue..."
        read -r
    done
}

main "$@"
