#!/usr/bin/env bash
#
# Server Helper - Extras Menu Library Module
# ==========================================
# Functions for the Extras menu: upgrade services, add server,
# open UIs, validate fleet, and run tests.
#
# This module provides all the "Extras" functionality that can be
# called from setup.sh or other scripts.
#
# Usage:
#   source scripts/lib/menu_extras.sh
#
# Dependencies:
#   - scripts/lib/ui_utils.sh (required)
#   - scripts/lib/security.sh (required)
#   - scripts/lib/upgrade.sh (optional, for upgrade functions)
#   - scripts/lib/inventory_mgr.sh (optional, for inventory functions)
#   - scripts/lib/health_check.sh (optional, for health checks)
#

# Prevent multiple inclusion
[[ -n "${_MENU_EXTRAS_LOADED:-}" ]] && return 0
readonly _MENU_EXTRAS_LOADED=1

# Verify required dependencies
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: menu_extras.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

if [[ -z "${_SECURITY_LOADED:-}" ]]; then
    echo "ERROR: menu_extras.sh requires security.sh to be sourced first" >&2
    return 1
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get script directory (caller should set SCRIPT_DIR before sourcing)
_EXTRAS_SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_EXTRAS_LIB_DIR="${_EXTRAS_SCRIPT_DIR}/scripts/lib"

# =============================================================================
# ADD SERVER
# =============================================================================

# Add a new server to the inventory
# Prompts user for server details and updates inventory file
extras_add_server() {
    local script_dir="${_EXTRAS_SCRIPT_DIR}"

    print_section "Add Server to Inventory"

    local server_name=""
    local ansible_host=""
    local ansible_user="ansible"
    local ansible_port="22"
    local custom_hostname=""

    # Server name
    while true; do
        server_name=$(prompt_input "Server name (e.g., webserver01)")
        if [[ -z "$server_name" ]]; then
            print_error "Server name cannot be empty"
            continue
        fi
        if [[ ! "$server_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Invalid name. Use only letters, numbers, hyphens, underscores."
            continue
        fi
        break
    done

    # IP/hostname
    while true; do
        ansible_host=$(prompt_input "IP address or hostname")
        if [[ -z "$ansible_host" ]]; then
            print_error "Address cannot be empty"
            continue
        fi
        break
    done

    # SSH user
    local input
    input=$(prompt_input "SSH username" "ansible")
    [[ -n "$input" ]] && ansible_user="$input"

    # SSH port
    input=$(prompt_input "SSH port" "22")
    [[ -n "$input" ]] && ansible_port="$input"

    # Custom hostname
    custom_hostname=$(prompt_input "Custom hostname (leave empty to use '$server_name')")

    # Summary
    echo
    print_section "Summary"
    echo "  Server Name: $server_name"
    echo "  Host:        $ansible_host"
    echo "  User:        $ansible_user"
    echo "  Port:        $ansible_port"
    [[ -n "$custom_hostname" ]] && echo "  Hostname:    $custom_hostname"
    echo

    if ! prompt_confirm "Add this server to inventory?"; then
        print_warning "Cancelled."
        return 1
    fi

    local inventory_file="${script_dir}/inventory/hosts.yml"

    if [[ ! -f "$inventory_file" ]]; then
        print_warning "Inventory file not found. Creating new inventory..."
        mkdir -p "${script_dir}/inventory"

        cat > "$inventory_file" <<EOF
# Server Helper Inventory
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

---
all:
  hosts:
    ${server_name}:
      ansible_host: ${ansible_host}
      ansible_user: ${ansible_user}
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3
EOF
        if [[ "$ansible_port" != "22" ]]; then
            echo "      ansible_port: ${ansible_port}" >> "$inventory_file"
        fi
        if [[ -n "$custom_hostname" ]]; then
            echo "      hostname: \"${custom_hostname}\"" >> "$inventory_file"
        fi

        cat >> "$inventory_file" <<EOF

  children:
    targets:
      hosts:
        ${server_name}:

  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

        print_success "Created inventory file: $inventory_file"
    else
        # Check if server already exists
        if grep -q "^    ${server_name}:" "$inventory_file" 2>/dev/null; then
            print_error "Server '$server_name' already exists in inventory!"
            return 1
        fi

        # Use inventory library function if available
        if declare -F inventory_add_host &>/dev/null; then
            inventory_add_host "$server_name" "$ansible_host" "targets" "$inventory_file" "$ansible_user" "$ansible_port"
            print_success "Server added to inventory using library"
        else
            print_warning "Inventory library not loaded. Manual edit required."
            print_info "Add the server manually to: $inventory_file"
            return 1
        fi
    fi

    # Test SSH connection
    echo
    if prompt_confirm "Test SSH connection to ${ansible_host}?"; then
        print_info "Testing SSH connection to ${ansible_user}@${ansible_host}..."
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$ansible_port" "${ansible_user}@${ansible_host}" "echo 'Connected'" &>/dev/null; then
            print_success "SSH connection successful!"
        else
            print_warning "SSH connection failed. You may need to:"
            echo "  1. Copy SSH key: ssh-copy-id -p $ansible_port ${ansible_user}@${ansible_host}"
            echo "  2. Run bootstrap: ansible-playbook playbooks/bootstrap.yml --limit $server_name -K"
        fi
    fi

    echo
    print_success "Server '$server_name' added successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Verify inventory: ansible-inventory --list"
    echo "  2. Test connection: ansible $server_name -m ping"
    echo "  3. Bootstrap: ansible-playbook playbooks/bootstrap.yml --limit $server_name -K"
    echo "  4. Setup: ansible-playbook playbooks/target.yml --limit $server_name"

    return 0
}

# =============================================================================
# OPEN SERVICE UIs
# =============================================================================

# Open a URL in the default browser (cross-platform)
_extras_open_browser_url() {
    local url="$1"
    local label="${2:-$url}"

    print_info "Opening ${label}: ${url}"

    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$url"
    elif command -v start &>/dev/null; then
        start "$url" 2>/dev/null || cmd.exe /c start "$url" 2>/dev/null
    else
        print_warning "Could not detect browser. Open manually: $url"
    fi
}

# Get configured port for a service from group_vars/all.yml
_extras_get_config_port() {
    local service="$1"
    local default_port="$2"
    local config_file="${_EXTRAS_SCRIPT_DIR}/group_vars/all.yml"

    if [[ ! -f "$config_file" ]]; then
        echo "$default_port"
        return
    fi

    local port=""
    case "$service" in
        dockge)
            port=$(awk '/^target_dockge:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        netdata)
            port=$(awk '/^target_netdata:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        uptime-kuma)
            port=$(awk '/^control_uptime_kuma:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        grafana)
            port=$(awk '/^control_grafana:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
    esac

    echo "${port:-$default_port}"
}

# Parse inventory file for host names and IPs
# Sets _EXTRAS_INV_NAMES and _EXTRAS_INV_IPS arrays
_extras_parse_inventory_hosts() {
    local inventory_file="${_EXTRAS_SCRIPT_DIR}/inventory/hosts.yml"
    _EXTRAS_INV_NAMES=()
    _EXTRAS_INV_IPS=()

    if [[ ! -f "$inventory_file" ]]; then
        return 1
    fi

    local in_hosts=false
    local current_name=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=true
            continue
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            current_name="${BASH_REMATCH[1]}"
            _EXTRAS_INV_NAMES+=("$current_name")
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
            _EXTRAS_INV_IPS+=("${BASH_REMATCH[1]}")
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]{2}[a-z] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]] && [[ ! "$line" =~ ^[[:space:]]*hosts: ]]; then
            in_hosts=false
        fi
    done < "$inventory_file"

    [[ ${#_EXTRAS_INV_NAMES[@]} -gt 0 ]]
}

# Select a host IP from inventory (interactive)
# Sets _EXTRAS_SELECTED_IP
_extras_select_host_ip() {
    _EXTRAS_SELECTED_IP=""

    if ! _extras_parse_inventory_hosts; then
        print_warning "Could not parse inventory."
        _EXTRAS_SELECTED_IP=$(prompt_input "Enter server IP address manually")
        return
    fi

    if [[ ${#_EXTRAS_INV_NAMES[@]} -eq 1 ]]; then
        _EXTRAS_SELECTED_IP="${_EXTRAS_INV_IPS[0]}"
        print_info "Using host: ${_EXTRAS_INV_NAMES[0]} (${_EXTRAS_SELECTED_IP})"
        return
    fi

    print_section "Select a host"
    for idx in "${!_EXTRAS_INV_NAMES[@]}"; do
        echo "  $((idx+1))) ${_EXTRAS_INV_NAMES[$idx]} (${_EXTRAS_INV_IPS[$idx]})"
    done
    echo "  $((${#_EXTRAS_INV_NAMES[@]}+1))) Enter IP manually"
    echo

    local host_num
    host_num=$(prompt_input "Choose host")

    if [[ "$host_num" =~ ^[0-9]+$ ]] && [[ "$host_num" -ge 1 ]] && [[ "$host_num" -le ${#_EXTRAS_INV_NAMES[@]} ]]; then
        _EXTRAS_SELECTED_IP="${_EXTRAS_INV_IPS[$((host_num-1))]}"
        print_info "Using host: ${_EXTRAS_INV_NAMES[$((host_num-1))]} (${_EXTRAS_SELECTED_IP})"
    else
        _EXTRAS_SELECTED_IP=$(prompt_input "Enter server IP address")
    fi
}

# Open service UIs in browser (interactive menu)
extras_open_ui() {
    local script_dir="${_EXTRAS_SCRIPT_DIR}"
    local inventory_file="${script_dir}/inventory/hosts.yml"

    print_section "Open Service UIs"

    if [[ ! -f "$inventory_file" ]]; then
        print_error "No inventory found. Run Setup first."
        return 1
    fi

    _extras_select_host_ip
    local host_ip="$_EXTRAS_SELECTED_IP"

    if [[ -z "$host_ip" ]]; then
        print_error "No host selected."
        return 1
    fi

    local dockge_port netdata_port kuma_port grafana_port
    dockge_port=$(_extras_get_config_port "dockge" "5001")
    netdata_port=$(_extras_get_config_port "netdata" "19999")
    kuma_port=$(_extras_get_config_port "uptime-kuma" "3001")
    grafana_port=$(_extras_get_config_port "grafana" "3000")

    echo
    print_section "Select service to open"
    echo "  1) Dockge            (http://${host_ip}:${dockge_port})"
    echo "  2) Netdata           (http://${host_ip}:${netdata_port})"
    echo "  3) Uptime Kuma       (http://${host_ip}:${kuma_port})"
    echo "  4) Grafana           (http://${host_ip}:${grafana_port})"
    echo "  5) All Services"
    echo "  6) List URLs only"
    echo "  7) Back"
    echo

    local ui_choice
    ui_choice=$(prompt_input "Choose [1-7]")

    case "$ui_choice" in
        1) _extras_open_browser_url "http://${host_ip}:${dockge_port}" "Dockge" ;;
        2) _extras_open_browser_url "http://${host_ip}:${netdata_port}" "Netdata" ;;
        3) _extras_open_browser_url "http://${host_ip}:${kuma_port}" "Uptime Kuma" ;;
        4) _extras_open_browser_url "http://${host_ip}:${grafana_port}" "Grafana" ;;
        5)
            _extras_open_browser_url "http://${host_ip}:${dockge_port}" "Dockge"
            sleep 1
            _extras_open_browser_url "http://${host_ip}:${netdata_port}" "Netdata"
            sleep 1
            _extras_open_browser_url "http://${host_ip}:${kuma_port}" "Uptime Kuma"
            sleep 1
            _extras_open_browser_url "http://${host_ip}:${grafana_port}" "Grafana"
            ;;
        6)
            echo
            print_section "Service URLs for ${host_ip}"
            echo "  Dockge:      http://${host_ip}:${dockge_port}"
            echo "  Netdata:     http://${host_ip}:${netdata_port}"
            echo "  Uptime Kuma: http://${host_ip}:${kuma_port}"
            echo "  Grafana:     http://${host_ip}:${grafana_port}"
            ;;
        7) return 0 ;;
        *) print_warning "Invalid option" ;;
    esac

    return 0
}

# =============================================================================
# FLEET VALIDATION
# =============================================================================

# Run fleet validation
# Args: $1 = mode (full, quick, services)
extras_validate_fleet() {
    local mode="${1:-full}"
    local script_dir="${_EXTRAS_SCRIPT_DIR}"
    local inventory="${script_dir}/inventory/hosts.yml"
    local config="${script_dir}/group_vars/all.yml"

    print_section "Validate Fleet"

    # Use library health check function
    if declare -F health_validate_fleet &>/dev/null; then
        health_validate_fleet "$inventory" "$config" "$mode"
        return $?
    fi

    # Fallback to basic health check
    if declare -F health_check_all &>/dev/null; then
        health_check_all "$inventory"
        return $?
    fi

    print_error "Health check library not loaded"
    return 1
}

# Interactive fleet validation menu
extras_validate_fleet_menu() {
    print_section "Fleet Validation"

    echo "Fleet validation checks connectivity and health across all nodes:"
    echo "  - SSH connectivity to all nodes"
    echo "  - Docker daemon status"
    echo "  - Control node services (Traefik, Grafana, Loki, etc.)"
    echo "  - Target node agents (Netdata, Promtail)"
    echo
    echo "Validation modes:"
    echo "  1) Full validation     - Complete health check"
    echo "  2) Quick ping test     - SSH connectivity only"
    echo "  3) Services only       - Control node services health"
    echo "  4) Back"
    echo

    local choice
    choice=$(prompt_input "Choose [1-4]")

    case "$choice" in
        1) extras_validate_fleet "full" ;;
        2) extras_validate_fleet "quick" ;;
        3) extras_validate_fleet "services" ;;
        4) return 0 ;;
        *)
            print_warning "Invalid option"
            return 1
            ;;
    esac

    return $?
}

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

# Run tests for all roles
extras_test_all_roles() {
    print_section "Test All Ansible Roles"

    # Use library testing function
    if declare -F testing_run_all &>/dev/null; then
        testing_run_all
        return $?
    fi

    print_error "Testing library not loaded"
    return 1
}

# Run tests for a single role
# Args: $1 = role name (optional, prompts if not provided)
extras_test_single_role() {
    local role_name="${1:-}"

    print_section "Test Single Ansible Role"

    # Use library testing function
    if declare -F testing_test_single_interactive &>/dev/null; then
        if [[ -n "$role_name" ]]; then
            testing_run_role "$role_name"
        else
            testing_test_single_interactive
        fi
        return $?
    fi

    print_error "Testing library not loaded"
    return 1
}

# =============================================================================
# UPGRADE SERVICES
# =============================================================================

# Perform upgrade on a single service
_extras_do_upgrade_service() {
    local service="$1"
    local host="$2"
    local dry_run="$3"

    # Use library function if available
    if declare -F upgrade_service &>/dev/null; then
        upgrade_service "$service" "$host" "false" "$dry_run"
        return $?
    fi

    # Fallback implementation
    local compose_dir=""
    case "$service" in
        dockge) compose_dir="/opt/dockge" ;;
        netdata) compose_dir="/opt/dockge/stacks/netdata" ;;
        uptime-kuma) compose_dir="/opt/dockge/stacks/uptime-kuma" ;;
        grafana) compose_dir="/opt/dockge/stacks/grafana" ;;
        loki) compose_dir="/opt/dockge/stacks/loki" ;;
        promtail) compose_dir="/opt/dockge/stacks/promtail" ;;
        traefik) compose_dir="/opt/dockge/stacks/traefik" ;;
        watchtower) compose_dir="/opt/dockge/stacks/watchtower" ;;
        *)
            print_warning "Unknown service: $service"
            return 1
            ;;
    esac

    echo
    print_section "Upgrading: $service"

    # Check if deployed
    if ! ansible "$host" -m stat -a "path=${compose_dir}/docker-compose.yml" 2>/dev/null | grep -q "exists.*true"; then
        print_warning "$service not found on $host, skipping"
        return 0
    fi

    # Pull images
    print_info "Pulling images for $service..."
    if [[ "$dry_run" == "true" ]]; then
        print_info "[DRY RUN] Would pull images"
    else
        if ansible "$host" -m shell -a "cd ${compose_dir} && docker compose pull" 2>/dev/null; then
            print_success "Images pulled"
        else
            print_error "Failed to pull images"
            return 1
        fi
    fi

    # Restart
    print_info "Restarting $service..."
    if [[ "$dry_run" == "true" ]]; then
        print_info "[DRY RUN] Would restart service"
    else
        if ansible "$host" -m shell -a "cd ${compose_dir} && docker compose up -d --remove-orphans" 2>/dev/null; then
            print_success "$service restarted"
        else
            print_error "Failed to restart $service"
            return 1
        fi
    fi

    return 0
}

# Upgrade services (interactive menu)
extras_upgrade_services() {
    local script_dir="${_EXTRAS_SCRIPT_DIR}"
    local lib_dir="${_EXTRAS_LIB_DIR}"

    print_section "Upgrade Services"

    # Source upgrade library if available
    if [[ -f "${lib_dir}/upgrade.sh" ]] && [[ -z "${_UPGRADE_LOADED:-}" ]]; then
        # shellcheck source=/dev/null
        source "${lib_dir}/upgrade.sh"
    fi

    # Check prerequisites
    if ! command -v ansible >/dev/null 2>&1; then
        print_error "Ansible is not installed"
        return 1
    fi

    if [[ ! -f "${script_dir}/inventory/hosts.yml" ]]; then
        print_error "Inventory file not found. Run Setup first."
        return 1
    fi

    echo "Upgrade Options:"
    echo "  1) Upgrade all services on all hosts"
    echo "  2) Upgrade specific host"
    echo "  3) Upgrade specific service"
    echo "  4) Dry run (preview only)"
    echo "  5) Back"
    echo

    local upgrade_choice
    upgrade_choice=$(prompt_input "Choose [1-5]")

    local target_host="all"
    local target_service="all"
    local dry_run="false"

    case "$upgrade_choice" in
        1)
            target_host="all"
            target_service="all"
            ;;
        2)
            echo
            print_info "Available hosts:"
            ansible all --list-hosts 2>/dev/null | grep -v "hosts (" | sed 's/^/  /'
            echo
            target_host=$(prompt_input "Enter hostname")
            if [[ -z "$target_host" ]]; then
                print_warning "No host specified"
                return 1
            fi
            ;;
        3)
            echo
            echo "Available services:"
            echo "  - dockge"
            echo "  - netdata"
            echo "  - uptime-kuma"
            echo "  - grafana"
            echo "  - loki"
            echo "  - promtail"
            echo "  - traefik"
            echo "  - watchtower"
            echo
            target_service=$(prompt_input "Enter service name")
            if [[ -z "$target_service" ]]; then
                print_warning "No service specified"
                return 1
            fi
            ;;
        4)
            dry_run="true"
            ;;
        5)
            return 0
            ;;
        *)
            print_warning "Invalid option"
            return 1
            ;;
    esac

    echo
    print_info "Upgrade configuration:"
    echo "  Host: $target_host"
    echo "  Service: $target_service"
    echo "  Dry run: $dry_run"
    echo

    if [[ "$dry_run" == "false" ]]; then
        if ! prompt_confirm "Continue with upgrade?"; then
            print_info "Upgrade cancelled"
            return 0
        fi
    fi

    # Reset tracking if using library
    if declare -F upgrade_reset_tracking &>/dev/null; then
        upgrade_reset_tracking
    fi

    # Perform upgrades
    if [[ "$target_service" == "all" ]]; then
        local services=("dockge" "netdata" "uptime-kuma" "grafana" "loki" "promtail" "traefik" "watchtower")
        for svc in "${services[@]}"; do
            _extras_do_upgrade_service "$svc" "$target_host" "$dry_run"
        done
    else
        _extras_do_upgrade_service "$target_service" "$target_host" "$dry_run"
    fi

    # Show summary if using library
    if declare -F upgrade_print_summary &>/dev/null; then
        echo
        upgrade_print_summary
    fi

    echo
    print_success "Upgrade process completed!"

    return 0
}

# =============================================================================
# EXTRAS MENU (Main Entry Point)
# =============================================================================

# Show the extras menu and handle selection
# Args: $1 = callback function to return to (optional)
extras_show_menu() {
    local return_callback="${1:-}"

    while true; do
        clear
        print_header "Server Helper v2.0.0 - Extras"
        echo

        echo "  1) Vault Management     - Manage Ansible Vault (encrypt/decrypt/edit)"
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
                # Vault Management - caller should provide this
                if declare -F show_vault_menu &>/dev/null; then
                    show_vault_menu
                elif declare -F vault_menu_show &>/dev/null; then
                    vault_menu_show
                else
                    print_warning "Vault menu not available"
                    read -p "Press Enter to continue..."
                fi
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
                if [[ -n "$return_callback" ]] && declare -F "$return_callback" &>/dev/null; then
                    "$return_callback"
                fi
                return 0
                ;;
            *)
                print_warning "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}
