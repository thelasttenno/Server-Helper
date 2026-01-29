#!/usr/bin/env bash
#
# Server Helper - Inventory Manager
# ==================================
# Manages Ansible inventory files and host operations.
#
# Usage:
#   source scripts/lib/inventory_mgr.sh
#
# Security:
#   - No temp files left in /tmp
#   - Uses secure temp directory for intermediate operations
#   - Cleans up all temporary files on completion
#

# Prevent multiple sourcing
[[ -n "${_INVENTORY_MGR_LOADED:-}" ]] && return 0
readonly _INVENTORY_MGR_LOADED=1

# Require ui_utils
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: inventory_mgr.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

# =============================================================================
# Configuration
# =============================================================================
readonly INVENTORY_FILE="${INVENTORY_FILE:-inventory/hosts.yml}"
readonly INVENTORY_EXAMPLE="inventory/hosts.example.yml"

# Track temp files for cleanup
declare -a _INVENTORY_TEMP_FILES=()

# Register cleanup function
_inventory_cleanup() {
    local temp_file
    for temp_file in "${_INVENTORY_TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file" 2>/dev/null
        fi
        if [[ -d "$temp_file" ]]; then
            rm -rf "$temp_file" 2>/dev/null
        fi
    done
    _INVENTORY_TEMP_FILES=()
}

# Create a tracked temp file
_inventory_temp_file() {
    local prefix="${1:-inventory}"
    local temp_file

    # Use secure temp location
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        temp_file=$(mktemp "/dev/shm/${prefix}.XXXXXX")
    elif [[ -d "/run/user/$(id -u)" ]]; then
        temp_file=$(mktemp "/run/user/$(id -u)/${prefix}.XXXXXX")
    else
        temp_file=$(mktemp "/tmp/${prefix}.XXXXXX")
    fi

    chmod 600 "$temp_file"
    _INVENTORY_TEMP_FILES+=("$temp_file")
    echo "$temp_file"
}

# =============================================================================
# Inventory Validation
# =============================================================================

# Check if inventory file exists
inventory_exists() {
    [[ -f "$INVENTORY_FILE" ]]
}

# Validate inventory file syntax
inventory_validate() {
    local inventory="${1:-$INVENTORY_FILE}"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    print_info "Validating inventory syntax..."

    if ansible-inventory -i "$inventory" --list >/dev/null 2>&1; then
        print_success "Inventory syntax is valid"
        return 0
    else
        print_error "Inventory has syntax errors"
        return 1
    fi
}

# =============================================================================
# Inventory Parsing
# =============================================================================

# Get all hosts from inventory
inventory_list_hosts() {
    local inventory="${1:-$INVENTORY_FILE}"
    local group="${2:-all}"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    ansible-inventory -i "$inventory" --list 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
group = '$group'
if group in data:
    hosts = data[group].get('hosts', [])
    for h in hosts:
        print(h)
elif '_meta' in data and 'hostvars' in data['_meta']:
    for h in data['_meta']['hostvars'].keys():
        print(h)
" 2>/dev/null
}

# Get host variable
inventory_get_host_var() {
    local host="$1"
    local var="$2"
    local inventory="${3:-$INVENTORY_FILE}"

    ansible-inventory -i "$inventory" --host "$host" 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('$var', ''))
" 2>/dev/null
}

# Parse existing inventory into arrays
inventory_parse() {
    local inventory="${1:-$INVENTORY_FILE}"

    # These are set as global arrays by the caller
    # CONTROL_HOSTS, TARGET_HOSTS

    if [[ ! -f "$inventory" ]]; then
        return 1
    fi

    # Parse control hosts
    mapfile -t CONTROL_HOSTS < <(inventory_list_hosts "$inventory" "control")

    # Parse target hosts
    mapfile -t TARGET_HOSTS < <(inventory_list_hosts "$inventory" "targets")

    return 0
}

# =============================================================================
# Host Management
# =============================================================================

# Add a new host to inventory
inventory_add_host() {
    local hostname="$1"
    local ip_address="$2"
    local group="${3:-targets}"
    local inventory="${4:-$INVENTORY_FILE}"
    local ssh_user="${5:-}"
    local ssh_port="${6:-22}"

    if [[ -z "$hostname" ]] || [[ -z "$ip_address" ]]; then
        print_error "Hostname and IP address are required"
        return 1
    fi

    # Validate IP address format and range (0-255 per octet)
    if ! [[ "$ip_address" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid IP address format: $ip_address"
        return 1
    fi
    local IFS='.'
    read -ra octets <<< "$ip_address"
    for octet in "${octets[@]}"; do
        if (( octet < 0 || octet > 255 )); then
            print_error "Invalid IP address (octet out of range): $ip_address"
            return 1
        fi
    done

    # Check if inventory exists
    if [[ ! -f "$inventory" ]]; then
        print_info "Creating new inventory file..."
        inventory_init "$inventory"
    fi

    # Check if host already exists
    if grep -q "^[[:space:]]*${hostname}:" "$inventory" 2>/dev/null; then
        print_warning "Host already exists: $hostname"
        if ! prompt_confirm "Update existing host?"; then
            return 0
        fi
        # Remove existing entry for update
        inventory_remove_host "$hostname" "$inventory"
    fi

    print_info "Adding host: $hostname ($ip_address) to group: $group"

    # Build host entry
    local host_entry="      ${hostname}:"
    host_entry+="\n        ansible_host: ${ip_address}"

    if [[ -n "$ssh_user" ]]; then
        host_entry+="\n        ansible_user: ${ssh_user}"
    fi

    if [[ "$ssh_port" != "22" ]]; then
        host_entry+="\n        ansible_port: ${ssh_port}"
    fi

    # Find the group section and add host
    # Create temp file for processing
    local temp_file
    temp_file=$(_inventory_temp_file "inventory_add")

    local in_group=0
    local in_hosts=0
    local added=0

    while IFS= read -r line; do
        echo "$line" >> "$temp_file"

        # Check if we're in the target group
        if [[ "$line" =~ ^[[:space:]]*${group}:[[:space:]]*$ ]]; then
            in_group=1
        elif [[ $in_group -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=1
        elif [[ $in_group -eq 1 ]] && [[ $in_hosts -eq 1 ]] && [[ $added -eq 0 ]]; then
            # Add the new host after "hosts:"
            echo -e "$host_entry" >> "$temp_file"
            added=1
        fi

        # Reset if we hit a new top-level key
        if [[ "$line" =~ ^[a-z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            if [[ ! "$line" =~ ^${group}: ]]; then
                in_group=0
                in_hosts=0
            fi
        fi
    done < "$inventory"

    if [[ $added -eq 1 ]]; then
        mv "$temp_file" "$inventory"
        print_success "Host added successfully"
        _inventory_cleanup
        return 0
    else
        print_error "Failed to add host - group '$group' not found"
        _inventory_cleanup
        return 1
    fi
}

# Remove a host from inventory
inventory_remove_host() {
    local hostname="$1"
    local inventory="${2:-$INVENTORY_FILE}"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    if ! grep -q "^[[:space:]]*${hostname}:" "$inventory"; then
        print_warning "Host not found: $hostname"
        return 1
    fi

    print_info "Removing host: $hostname"

    # Create temp file for processing
    local temp_file
    temp_file=$(_inventory_temp_file "inventory_remove")

    local skip_until_next=0
    local host_indent=""

    while IFS= read -r line; do
        # Check if this is the host to remove
        if [[ "$line" =~ ^([[:space:]]*)${hostname}:[[:space:]]*$ ]]; then
            host_indent="${BASH_REMATCH[1]}"
            skip_until_next=1
            continue
        fi

        # Skip host variables (more indented than host name)
        if [[ $skip_until_next -eq 1 ]]; then
            local current_indent="${line%%[^[:space:]]*}"
            if [[ ${#current_indent} -gt ${#host_indent} ]] && [[ -n "$line" ]]; then
                continue
            else
                skip_until_next=0
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$inventory"

    mv "$temp_file" "$inventory"
    print_success "Host removed successfully"
    _inventory_cleanup
    return 0
}

# =============================================================================
# Inventory Initialization
# =============================================================================

# Initialize inventory from example
inventory_init() {
    local inventory="${1:-$INVENTORY_FILE}"

    if [[ -f "$inventory" ]]; then
        if ! prompt_confirm "Inventory already exists. Overwrite?"; then
            return 0
        fi
    fi

    # Create directory if needed
    local inventory_dir
    inventory_dir=$(dirname "$inventory")
    if [[ ! -d "$inventory_dir" ]]; then
        mkdir -p "$inventory_dir"
    fi

    if [[ -f "$INVENTORY_EXAMPLE" ]]; then
        print_info "Copying example inventory..."
        cp "$INVENTORY_EXAMPLE" "$inventory"
        print_success "Inventory initialized from example"
    else
        print_info "Creating minimal inventory..."
        cat > "$inventory" << 'EOF'
---
# Server Helper Inventory
# =======================
# Define your servers here

all:
  children:
    control:
      hosts:
        # control-node:
        #   ansible_host: 192.168.1.10
        #   ansible_user: ubuntu

    targets:
      hosts:
        # target-01:
        #   ansible_host: 192.168.1.11
        #   ansible_user: ubuntu
        # target-02:
        #   ansible_host: 192.168.1.12
        #   ansible_user: ubuntu
EOF
        print_success "Minimal inventory created"
    fi

    return 0
}

# =============================================================================
# Interactive Host Addition
# =============================================================================

# Interactive wizard to add a new server
inventory_add_host_interactive() {
    local inventory="${1:-$INVENTORY_FILE}"

    print_header "Add New Server"

    # Get hostname
    local hostname
    hostname=$(prompt_input "Hostname (e.g., server-01)")

    if [[ -z "$hostname" ]]; then
        print_error "Hostname is required"
        return 1
    fi

    # Validate hostname format
    if ! [[ "$hostname" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        print_error "Invalid hostname format. Use letters, numbers, hyphens, underscores."
        return 1
    fi

    # Get IP address
    local ip_address
    ip_address=$(prompt_input "IP address")

    if [[ -z "$ip_address" ]]; then
        print_error "IP address is required"
        return 1
    fi

    # Select group
    echo ""
    echo "Select server group:"
    print_menu_item "1" "targets" "Target servers (monitoring agents)"
    print_menu_item "2" "control" "Control node (central services)"
    echo ""

    local group_choice
    read -rp "$(echo -e "${BLUE}?${NC} Group [1]: ")" group_choice
    group_choice="${group_choice:-1}"

    local group
    case "$group_choice" in
        1) group="targets" ;;
        2) group="control" ;;
        *) group="targets" ;;
    esac

    # Get SSH user
    local ssh_user
    ssh_user=$(prompt_input "SSH user" "ubuntu")

    # Get SSH port
    local ssh_port
    ssh_port=$(prompt_input "SSH port" "22")

    # Confirm
    echo ""
    print_section "Summary"
    echo "  Hostname: $hostname"
    echo "  IP:       $ip_address"
    echo "  Group:    $group"
    echo "  SSH User: $ssh_user"
    echo "  SSH Port: $ssh_port"
    echo ""

    if prompt_confirm "Add this server?"; then
        inventory_add_host "$hostname" "$ip_address" "$group" "$inventory" "$ssh_user" "$ssh_port"
    else
        print_info "Cancelled"
        return 0
    fi
}

# =============================================================================
# Connectivity Testing
# =============================================================================

# Test SSH connectivity to a host
inventory_test_host() {
    local host="$1"
    local inventory="${2:-$INVENTORY_FILE}"
    local timeout="${3:-5}"

    local ip
    ip=$(inventory_get_host_var "$host" "ansible_host" "$inventory")

    if [[ -z "$ip" ]]; then
        print_error "Could not get IP for host: $host"
        return 1
    fi

    local user
    user=$(inventory_get_host_var "$host" "ansible_user" "$inventory")
    user="${user:-ubuntu}"

    local port
    port=$(inventory_get_host_var "$host" "ansible_port" "$inventory")
    port="${port:-22}"

    print_info "Testing connection to $host ($ip)..."

    if ssh -o ConnectTimeout="$timeout" -o BatchMode=yes -o StrictHostKeyChecking=no \
        -p "$port" "${user}@${ip}" "echo ok" >/dev/null 2>&1; then
        print_success "Connection successful: $host"
        return 0
    else
        print_error "Connection failed: $host"
        return 1
    fi
}

# Test connectivity to all hosts
inventory_test_all() {
    local inventory="${1:-$INVENTORY_FILE}"
    local passed=0
    local failed=0

    print_header "Testing Host Connectivity"

    local hosts
    mapfile -t hosts < <(inventory_list_hosts "$inventory" "all")

    if [[ ${#hosts[@]} -eq 0 ]]; then
        print_warning "No hosts found in inventory"
        return 0
    fi

    for host in "${hosts[@]}"; do
        if inventory_test_host "$host" "$inventory"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    print_section "Results"
    echo "  Passed: $passed"
    echo "  Failed: $failed"
    echo "  Total:  $((passed + failed))"

    return $failed
}

# Use Ansible ping module
inventory_ping() {
    local inventory="${1:-$INVENTORY_FILE}"
    local pattern="${2:-all}"

    print_info "Pinging hosts with Ansible..."
    ansible "$pattern" -i "$inventory" -m ping
}
