#!/usr/bin/env bash
#
# Server Helper v2.0.0 - Setup Script
# ====================================
# Pure Controller: Sources libraries and provides menu orchestration.
#
# This script prepares your COMMAND NODE to manage target servers with Ansible.
# Run this on your laptop/desktop/control machine, NOT on target servers.
#
# What this does:
#   1. Installs Ansible and dependencies on this command node
#   2. Prompts for target server configuration
#   3. Creates inventory file with your target nodes
#   4. Creates configuration and vault files
#   5. Tests connectivity to target nodes
#   6. Runs Ansible playbooks against target servers
#
# For target servers, run bootstrap-target.sh on each node first, OR
# run: ansible-playbook playbooks/bootstrap.yml
#
# Architecture:
#   This script follows the "Pure Controller" pattern:
#   - All logic lives in library modules (scripts/lib/*.sh)
#   - This script ONLY sources libraries and orchestrates menus
#   - No fallback definitions - strict library requirements
#
# Usage: ./setup.sh
#

set -euo pipefail

# =============================================================================
# SCRIPT INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Export for library modules
export SCRIPT_DIR
export LOG_FILE="${SCRIPT_DIR}/setup.log"
export VAULT_PASSWORD_FILE="${SCRIPT_DIR}/.vault_password"

# Configuration paths (exported for libraries)
export INVENTORY_FILE="inventory/hosts.yml"
export CONFIG_FILE="group_vars/all.yml"
export VAULT_FILE="group_vars/vault.yml"

# =============================================================================
# STRICT LIBRARY SOURCING
# =============================================================================
# Libraries are REQUIRED - no fallbacks. Script exits if any are missing.

LIB_DIR="${SCRIPT_DIR}/scripts/lib"

# Source security library FIRST (provides cleanup trap)
if [[ ! -f "${LIB_DIR}/security.sh" ]]; then
    echo "FATAL: Required library not found: ${LIB_DIR}/security.sh" >&2
    exit 1
fi
# shellcheck source=scripts/lib/security.sh
source "${LIB_DIR}/security.sh"

# Register cleanup trap immediately
security_register_cleanup

# Enforce vault password file permissions
security_check_vault_permissions "$VAULT_PASSWORD_FILE"

# Source UI utilities (colors, printing, secure logging)
if [[ ! -f "${LIB_DIR}/ui_utils.sh" ]]; then
    echo "FATAL: Required library not found: ${LIB_DIR}/ui_utils.sh" >&2
    exit 1
fi
# shellcheck source=scripts/lib/ui_utils.sh
source "${LIB_DIR}/ui_utils.sh"

# Source vault manager
if [[ ! -f "${LIB_DIR}/vault_mgr.sh" ]]; then
    echo "FATAL: Required library not found: ${LIB_DIR}/vault_mgr.sh" >&2
    exit 1
fi
# shellcheck source=scripts/lib/vault_mgr.sh
source "${LIB_DIR}/vault_mgr.sh"

# Source extras menu
if [[ ! -f "${LIB_DIR}/menu_extras.sh" ]]; then
    echo "FATAL: Required library not found: ${LIB_DIR}/menu_extras.sh" >&2
    exit 1
fi
# shellcheck source=scripts/lib/menu_extras.sh
source "${LIB_DIR}/menu_extras.sh"

# Source inventory manager (optional - used for setup flow)
if [[ -f "${LIB_DIR}/inventory_mgr.sh" ]]; then
    # shellcheck source=scripts/lib/inventory_mgr.sh
    source "${LIB_DIR}/inventory_mgr.sh"
fi

# Source health check (optional - used for health checks)
if [[ -f "${LIB_DIR}/health_check.sh" ]]; then
    # shellcheck source=scripts/lib/health_check.sh
    source "${LIB_DIR}/health_check.sh"
fi

# Source config manager (optional - used for setup flow)
if [[ -f "${LIB_DIR}/config_mgr.sh" ]]; then
    # shellcheck source=scripts/lib/config_mgr.sh
    source "${LIB_DIR}/config_mgr.sh"
fi

# Source upgrade library (optional - used by extras menu)
if [[ -f "${LIB_DIR}/upgrade.sh" ]]; then
    # shellcheck source=scripts/lib/upgrade.sh
    source "${LIB_DIR}/upgrade.sh"
fi

# Source testing library (optional - used for molecule tests)
if [[ -f "${LIB_DIR}/testing.sh" ]]; then
    # shellcheck source=scripts/lib/testing.sh
    source "${LIB_DIR}/testing.sh"
fi

# =============================================================================
# VERSION INFO
# =============================================================================

readonly VERSION="2.0.0"

# =============================================================================
# ARRAYS FOR SERVER TRACKING (used by setup flow)
# =============================================================================

EXISTING_HOSTS=()
EXISTING_HOSTNAMES=()
EXISTING_USERS=()
EXISTING_CONFIG_FOUND=false

TARGET_HOSTS=()
TARGET_HOSTNAMES=()
TARGET_USERS=()

# =============================================================================
# PRE-REQUISITE CHECKS
# =============================================================================

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root on the command node"
        print_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_info "This script requires sudo privileges"
        sudo -v || exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS version"
        exit 1
    fi

    print_info "Detected OS: $OS $OS_VERSION"

    if [[ "$OS" != "ubuntu" ]]; then
        print_warning "This script is designed for Ubuntu 24.04 LTS"
        print_warning "Detected: $OS $OS_VERSION"
        if ! prompt_confirm "Continue anyway?"; then
            exit 1
        fi
    fi
}

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================

show_main_menu() {
    while true; do
        clear
        print_header "Server Helper v${VERSION}"
        echo
        echo "What would you like to do?"
        echo
        echo "  1) Setup      - Configure and deploy Server Helper"
        echo "  2) Extras     - Additional tools and utilities"
        echo "  3) Exit"
        echo

        local choice
        choice=$(prompt_input "Choose an option [1-3]")

        case "$choice" in
            1)
                run_setup_flow
                ;;
            2)
                show_extras_menu
                ;;
            3)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_warning "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

show_extras_menu() {
    while true; do
        clear
        print_header "Server Helper v${VERSION} - Extras"
        echo

        echo "  1) Vault Management     - Manage Ansible Vault (encrypt/edit/view)"
        echo "  2) Upgrade Services     - Upgrade Docker images and restart services"
        echo "  3) Add Server           - Add new server to inventory"
        echo "  4) Open Service UIs     - Open web dashboards in browser"
        echo "  5) Validate Fleet       - Check connectivity and service health"
        echo "  6) Test All Roles       - Run Molecule tests for all roles"
        echo "  7) Test Single Role     - Run Molecule test for one role"
        echo "  8) Back to Main Menu"
        echo

        local choice
        choice=$(prompt_input "Choose an option [1-8]")

        case "$choice" in
            1)
                vault_menu_show
                ;;
            2)
                extras_upgrade_services
                read -p "Press Enter to continue..."
                ;;
            3)
                extras_add_server
                read -p "Press Enter to continue..."
                ;;
            4)
                extras_open_ui
                read -p "Press Enter to continue..."
                ;;
            5)
                extras_validate_fleet_menu
                read -p "Press Enter to continue..."
                ;;
            6)
                extras_test_all_roles
                read -p "Press Enter to continue..."
                ;;
            7)
                extras_test_single_role
                read -p "Press Enter to continue..."
                ;;
            8)
                return 0
                ;;
            *)
                print_warning "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# =============================================================================
# SETUP FLOW FUNCTIONS
# =============================================================================

run_setup_flow() {
    # Initialize log file
    echo "=== Server Helper Setup Log ===" > "$LOG_FILE"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo >> "$LOG_FILE"

    # Pre-requisite checks
    check_not_root
    check_sudo
    detect_os

    # Check for existing configuration
    check_existing_config

    # Install dependencies
    install_system_deps
    install_python_deps
    install_galaxy_deps

    # Configuration
    if [[ "${RERUN_EXISTING:-}" != true ]]; then
        if [[ "${USE_EXISTING_CONFIG:-}" != true ]] || [[ "${SETUP_MODE:-}" == "2" ]]; then
            prompt_target_nodes
        fi

        if [[ "${USE_EXISTING_CONFIG:-}" == true ]] && [[ "${SETUP_MODE:-}" == "2" ]]; then
            merge_inventory
        fi

        if [[ "${USE_EXISTING_CONFIG:-}" != true ]]; then
            prompt_config
        fi

        create_inventory
        if [[ "${USE_EXISTING_CONFIG:-}" != true ]]; then
            create_config
            create_vault
        fi
    fi

    preflight_checks

    if [[ "${RERUN_EXISTING:-}" != true ]]; then
        offer_bootstrap
    fi

    run_playbook

    print_success "Setup script completed"
    print_info "Log file: $LOG_FILE"

    read -p "Press Enter to continue..."
}

# =============================================================================
# CONFIGURATION CHECK FUNCTIONS
# =============================================================================

check_existing_config() {
    print_header "Server Helper v${VERSION}"
    print_info "Checking for existing configuration..."

    if [[ -f "$INVENTORY_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
        EXISTING_CONFIG_FOUND=true
        print_success "Existing configuration found!"
        echo

        parse_existing_inventory

        if [[ ${#EXISTING_HOSTNAMES[@]} -gt 0 ]]; then
            print_section "Configured servers"
            for i in "${!EXISTING_HOSTNAMES[@]}"; do
                echo "  - ${EXISTING_HOSTNAMES[$i]} (${EXISTING_HOSTS[$i]})"
            done
            echo

            echo "What would you like to do?"
            echo "  1) Health check existing servers"
            echo "  2) Add new servers to existing configuration"
            echo "  3) Re-run setup on existing servers"
            echo "  4) Start fresh (backup and recreate all config)"
            echo

            SETUP_MODE=$(prompt_input "Choose an option [1-4]")

            case "$SETUP_MODE" in
                1)
                    health_check_servers
                    read -p "Press Enter to continue..."
                    show_main_menu
                    ;;
                2)
                    USE_EXISTING_CONFIG=true
                    print_info "Will add new servers to existing configuration"
                    ;;
                3)
                    USE_EXISTING_CONFIG=true
                    RERUN_EXISTING=true
                    TARGET_HOSTS=("${EXISTING_HOSTS[@]}")
                    TARGET_HOSTNAMES=("${EXISTING_HOSTNAMES[@]}")
                    TARGET_USERS=("${EXISTING_USERS[@]}")
                    print_info "Will re-run setup on ${#TARGET_HOSTS[@]} existing server(s)"
                    ;;
                4)
                    backup_existing_config
                    USE_EXISTING_CONFIG=false
                    print_info "Starting fresh configuration"
                    ;;
                *)
                    print_warning "Invalid option, defaulting to health check"
                    health_check_servers
                    read -p "Press Enter to continue..."
                    show_main_menu
                    ;;
            esac
        fi
    else
        print_info "No existing configuration found, starting fresh setup"
        USE_EXISTING_CONFIG=false
    fi
}

parse_existing_inventory() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        return
    fi

    EXISTING_HOSTS=()
    EXISTING_HOSTNAMES=()
    EXISTING_USERS=()

    local in_hosts=false
    local current_host=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=true
            continue
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ansible_ ]]; then
            if [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
                in_hosts=false
                continue
            fi
        fi

        if [[ "$in_hosts" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
                current_host="${BASH_REMATCH[1]}"
                EXISTING_HOSTNAMES+=("$current_host")
            fi

            if [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
                EXISTING_HOSTS+=("${BASH_REMATCH[1]}")
            fi

            if [[ "$line" =~ ansible_user:[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
                EXISTING_USERS+=("${BASH_REMATCH[1]}")
            fi
        fi
    done < "$INVENTORY_FILE"

    while [[ ${#EXISTING_USERS[@]} -lt ${#EXISTING_HOSTNAMES[@]} ]]; do
        EXISTING_USERS+=("ansible")
    done
}

health_check_servers() {
    # Use library function if available
    if declare -F health_check_all &>/dev/null; then
        health_check_all "$INVENTORY_FILE"
        return
    fi

    print_header "Health Check"
    print_info "Running health checks on configured servers..."
    echo

    local healthy=0
    local unhealthy=0

    for i in "${!EXISTING_HOSTNAMES[@]}"; do
        local hostname="${EXISTING_HOSTNAMES[$i]}"
        local host="${EXISTING_HOSTS[$i]}"
        local user="${EXISTING_USERS[$i]}"

        print_section "Checking ${hostname} (${host})"

        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${host}" "echo 'ok'" &>/dev/null; then
            print_success "SSH connectivity: OK"

            if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "docker ps" &>/dev/null; then
                print_success "Docker: Running"
            else
                print_warning "Docker: Not running or not installed"
            fi

            ((healthy++))
        else
            print_error "SSH connectivity: FAILED"
            ((unhealthy++))
        fi
    done

    echo
    print_section "Summary"
    echo "  Healthy:   ${healthy}"
    echo "  Unhealthy: ${unhealthy}"
    echo

    if [[ $unhealthy -gt 0 ]]; then
        print_warning "Some servers failed health checks"
    else
        print_success "All servers are healthy!"
    fi
}

backup_existing_config() {
    local backup_dir="backups/config_$(date +%Y%m%d_%H%M%S)"
    print_info "Backing up existing configuration to ${backup_dir}..."

    mkdir -p "$backup_dir"

    [[ -f "$INVENTORY_FILE" ]] && cp "$INVENTORY_FILE" "$backup_dir/"
    [[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "$backup_dir/"
    [[ -f "$VAULT_FILE" ]] && cp "$VAULT_FILE" "$backup_dir/"
    [[ -f ".vault_password" ]] && cp ".vault_password" "$backup_dir/"

    print_success "Configuration backed up to ${backup_dir}"
}

merge_inventory() {
    if [[ "$USE_EXISTING_CONFIG" != true ]] || [[ ! -f "$INVENTORY_FILE" ]]; then
        return
    fi

    print_info "Merging new servers with existing inventory..."

    local new_count=${#TARGET_HOSTS[@]}
    local existing_count=${#EXISTING_HOSTNAMES[@]}

    local all_hosts=("${EXISTING_HOSTS[@]}" "${TARGET_HOSTS[@]}")
    local all_hostnames=("${EXISTING_HOSTNAMES[@]}" "${TARGET_HOSTNAMES[@]}")
    local all_users=("${EXISTING_USERS[@]}" "${TARGET_USERS[@]}")

    TARGET_HOSTS=("${all_hosts[@]}")
    TARGET_HOSTNAMES=("${all_hostnames[@]}")
    TARGET_USERS=("${all_users[@]}")

    print_success "Merged ${existing_count} existing + ${new_count} new = ${#all_hostnames[@]} total servers"
}

# =============================================================================
# DEPENDENCY INSTALLATION
# =============================================================================

install_system_deps() {
    print_section "System Dependencies"
    print_info "Installing system dependencies..."

    log_exec sudo apt-get update -qq

    local packages=("ansible" "python3-pip" "git" "curl" "wget" "sshpass")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "Installing packages: ${to_install[*]}"
        log_exec sudo apt-get install -y -qq "${to_install[@]}"
    else
        print_success "All system packages already installed"
    fi

    if command -v ansible >/dev/null 2>&1; then
        local ANSIBLE_VERSION
        ANSIBLE_VERSION=$(ansible --version | head -n1)
        print_success "Ansible installed: $ANSIBLE_VERSION"
    else
        print_error "Ansible installation failed"
        exit 1
    fi
}

install_python_deps() {
    print_info "Installing Python dependencies..."

    local python_packages=(
        "python3-docker"
        "python3-jmespath"
        "python3-netaddr"
        "python3-requests"
    )

    local to_install=()
    for pkg in "${python_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "Installing Python packages: ${to_install[*]}"
        log_exec sudo apt-get install -y -qq "${to_install[@]}"
    else
        print_success "All Python packages already installed"
    fi
}

install_galaxy_deps() {
    print_info "Installing Ansible Galaxy dependencies..."

    if [[ -f requirements.yml ]]; then
        log_exec ansible-galaxy install -r requirements.yml --force
        print_success "Galaxy dependencies installed"
    else
        print_info "No requirements.yml found, skipping Galaxy dependencies"
    fi
}

# =============================================================================
# SETUP STEP FUNCTIONS (stubs - implement as needed)
# =============================================================================

prompt_target_nodes() {
    print_section "Target Nodes"
    print_info "Configure target server(s)..."
    if type -t inventory_add_host_interactive &>/dev/null; then
        inventory_add_host_interactive "$INVENTORY_FILE"
    else
        print_warning "inventory_mgr.sh not loaded, skipping interactive host setup"
    fi
}

prompt_config() {
    print_section "Configuration"
    print_info "Configure global settings..."
    if type -t config_wizard &>/dev/null; then
        config_wizard "$CONFIG_FILE"
    else
        print_warning "config_mgr.sh not loaded, skipping config wizard"
    fi
}

create_inventory() {
    print_info "Creating inventory file..."
    if [[ ! -f "$INVENTORY_FILE" ]] && type -t inventory_init &>/dev/null; then
        inventory_init "$INVENTORY_FILE"
    fi
}

create_config() {
    print_info "Creating configuration file..."
    if [[ ! -f "$CONFIG_FILE" ]] && type -t config_init &>/dev/null; then
        config_init "$CONFIG_FILE"
    fi
}

create_vault() {
    print_info "Creating vault file..."
    if [[ ! -f "$VAULT_FILE" ]] && type -t vault_init &>/dev/null; then
        vault_init "$VAULT_FILE" "$VAULT_PASSWORD_FILE"
    fi
}

preflight_checks() {
    print_section "Preflight Checks"
    print_info "Running preflight checks..."
    if type -t inventory_test_all &>/dev/null; then
        inventory_test_all "$INVENTORY_FILE" || print_warning "Some hosts unreachable"
    fi
}

offer_bootstrap() {
    print_info "Bootstrap target servers?"
    if prompt_confirm "Run bootstrap playbook on target nodes?"; then
        ansible-playbook playbooks/bootstrap.yml -i "$INVENTORY_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
    fi
}

run_playbook() {
    print_section "Playbook Execution"
    print_info "Running Ansible playbook..."
    ansible-playbook playbooks/site.yml -i "$INVENTORY_FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    show_main_menu
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
