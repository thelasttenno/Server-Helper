#!/usr/bin/env bash

# ================================================================================
# Server Helper - Add Server Script
# ================================================================================
# Interactive script to add new servers to the Ansible inventory
#
# USAGE:
#   ./scripts/add-server.sh              # Interactive mode (guided prompts)
#   ./scripts/add-server.sh --batch      # Batch mode (add multiple servers)
#   ./scripts/add-server.sh --help       # Show help
#
# FEATURES:
#   - ✅ Interactive prompts for server details
#   - ✅ Validates IP addresses and hostnames
#   - ✅ Tests SSH connectivity before adding
#   - ✅ Supports custom SSH ports and keys
#   - ✅ Creates/updates inventory/hosts.yml
#   - ✅ Automatically organizes servers into groups
#   - ✅ Backup existing inventory before changes
#   - ✅ Batch mode for adding multiple servers
#   - ✅ Colored output for better UX
# ================================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly INVENTORY_FILE="$PROJECT_ROOT/inventory/hosts.yml"
readonly INVENTORY_EXAMPLE="$PROJECT_ROOT/inventory/hosts.example.yml"
readonly BACKUP_DIR="$PROJECT_ROOT/backups/inventory"

# ================================================================================
# Helper Functions
# ================================================================================

print_header() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                 Server Helper - Add Server Tool                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "${MAGENTA}▸${NC} $1"
}

# ================================================================================
# Validation Functions
# ================================================================================

validate_ip() {
    local ip="$1"

    # Check if it's a valid IPv4 address or hostname
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Validate each octet
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ "$i" -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    elif [[ "$ip" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        # Valid hostname
        return 0
    else
        return 1
    fi
}

validate_hostname() {
    local hostname="$1"

    # Check hostname format (RFC 952/1123)
    if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port="$1"

    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

validate_server_name() {
    local name="$1"

    # Check if name is valid for Ansible inventory (alphanumeric, hyphens, underscores)
    if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# ================================================================================
# Connectivity Testing
# ================================================================================

test_ssh_connection() {
    local host="$1"
    local port="${2:-22}"
    local user="${3:-ansible}"
    local key="${4:-}"

    print_step "Testing SSH connection to $user@$host:$port..."

    local ssh_cmd="ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no"

    if [[ -n "$key" ]]; then
        ssh_cmd="$ssh_cmd -i $key"
    fi

    ssh_cmd="$ssh_cmd -p $port $user@$host echo 2>&1"

    if eval "$ssh_cmd" > /dev/null; then
        print_success "SSH connection successful!"
        return 0
    else
        print_warning "SSH connection failed. You may need to bootstrap this server first."
        print_info "Run: ansible-playbook playbooks/bootstrap.yml --limit <server-name>"
        return 1
    fi
}

# ================================================================================
# Inventory Management
# ================================================================================

backup_inventory() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_info "No existing inventory file to backup"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/hosts.yml.backup.$timestamp"

    cp "$INVENTORY_FILE" "$backup_file"
    print_success "Backed up inventory to: $backup_file"
}

create_inventory_from_example() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        if [[ -f "$INVENTORY_EXAMPLE" ]]; then
            print_step "Creating new inventory file from example..."
            cp "$INVENTORY_EXAMPLE" "$INVENTORY_FILE"
            print_success "Created inventory file: $INVENTORY_FILE"
        else
            print_error "Example inventory file not found: $INVENTORY_EXAMPLE"
            exit 1
        fi
    fi
}

check_server_exists() {
    local server_name="$1"

    if [[ -f "$INVENTORY_FILE" ]]; then
        if grep -q "^  *$server_name:" "$INVENTORY_FILE"; then
            return 0
        fi
    fi
    return 1
}

add_server_to_inventory() {
    local server_name="$1"
    local ansible_host="$2"
    local ansible_user="$3"
    local ansible_port="${4:-22}"
    local custom_hostname="${5:-}"
    local ssh_key="${6:-}"
    local server_group="${7:-servers}"
    local timezone="${8:-}"

    print_step "Adding server '$server_name' to inventory..."

    # Prepare server block
    local server_block="  $server_name:\n"
    server_block+="    ansible_host: $ansible_host\n"
    server_block+="    ansible_user: $ansible_user\n"
    server_block+="    ansible_become: yes\n"
    server_block+="    ansible_python_interpreter: /usr/bin/python3\n"

    if [[ "$ansible_port" != "22" ]]; then
        server_block+="    ansible_port: $ansible_port\n"
    fi

    if [[ -n "$custom_hostname" ]]; then
        server_block+="    hostname: \"$custom_hostname\"\n"
    fi

    if [[ -n "$ssh_key" ]]; then
        server_block+="    ansible_ssh_private_key_file: $ssh_key\n"
    fi

    if [[ -n "$timezone" ]]; then
        server_block+="    timezone: \"$timezone\"\n"
    fi

    # Create temporary file with updated inventory
    local temp_file=$(mktemp)

    # Read the inventory file and add the new server
    awk -v server_block="$server_block" -v server_name="$server_name" '
        /^  hosts:/ {
            print
            in_hosts = 1
            next
        }
        in_hosts && /^  [a-z]/ && !/^  *#/ {
            # First non-comment, non-indented line after hosts section
            printf "%b\n", server_block
            in_hosts = 0
        }
        { print }
    ' "$INVENTORY_FILE" > "$temp_file"

    # Replace original file
    mv "$temp_file" "$INVENTORY_FILE"

    # Add to server group
    add_to_group "$server_name" "$server_group"

    print_success "Server '$server_name' added to inventory"
}

add_to_group() {
    local server_name="$1"
    local group_name="$2"

    # Add server to the specified group in children section
    local temp_file=$(mktemp)

    awk -v server_name="$server_name" -v group_name="$group_name" '
        /^  children:/ {
            print
            in_children = 1
            next
        }
        in_children && $0 ~ "^    " group_name ":" {
            print
            in_group = 1
            next
        }
        in_group && /^      hosts:/ {
            print
            print "        " server_name ":"
            in_group = 0
            in_children = 0
            next
        }
        { print }
    ' "$INVENTORY_FILE" > "$temp_file"

    mv "$temp_file" "$INVENTORY_FILE"
    print_success "Added '$server_name' to group '$group_name'"
}

# ================================================================================
# Interactive Prompts
# ================================================================================

prompt_server_details() {
    local server_name=""
    local ansible_host=""
    local ansible_user="ansible"
    local ansible_port="22"
    local custom_hostname=""
    local ssh_key=""
    local server_group="servers"
    local timezone=""
    local test_connection="y"

    echo
    print_header
    echo
    print_info "This wizard will guide you through adding a new server to the inventory."
    echo

    # Server name
    while true; do
        echo -e "${CYAN}Server Name${NC} (e.g., webserver01, db-prod-01):"
        read -r server_name

        if [[ -z "$server_name" ]]; then
            print_error "Server name cannot be empty"
            continue
        fi

        if ! validate_server_name "$server_name"; then
            print_error "Invalid server name. Use only letters, numbers, hyphens, and underscores."
            continue
        fi

        if check_server_exists "$server_name"; then
            print_error "Server '$server_name' already exists in inventory"
            echo -e "${YELLOW}Choose a different name or edit the existing entry manually${NC}"
            continue
        fi

        break
    done

    # IP address or hostname
    while true; do
        echo -e "${CYAN}IP Address or Hostname${NC} (e.g., 192.168.1.100 or server.local):"
        read -r ansible_host

        if [[ -z "$ansible_host" ]]; then
            print_error "IP address or hostname cannot be empty"
            continue
        fi

        if ! validate_ip "$ansible_host"; then
            print_error "Invalid IP address or hostname format"
            continue
        fi

        break
    done

    # SSH username
    echo -e "${CYAN}SSH Username${NC} [default: ansible]:"
    read -r input
    if [[ -n "$input" ]]; then
        ansible_user="$input"
    fi

    # SSH port
    while true; do
        echo -e "${CYAN}SSH Port${NC} [default: 22]:"
        read -r input

        if [[ -z "$input" ]]; then
            break
        fi

        if ! validate_port "$input"; then
            print_error "Invalid port number (1-65535)"
            continue
        fi

        ansible_port="$input"
        break
    done

    # Custom hostname
    echo -e "${CYAN}Custom Hostname${NC} (leave empty to use server name '$server_name'):"
    read -r custom_hostname

    if [[ -n "$custom_hostname" ]] && ! validate_hostname "$custom_hostname"; then
        print_warning "Invalid hostname format, using server name instead"
        custom_hostname=""
    fi

    # SSH private key
    echo -e "${CYAN}SSH Private Key Path${NC} (leave empty for default ~/.ssh/id_rsa):"
    read -r ssh_key

    if [[ -n "$ssh_key" ]] && [[ ! -f "$ssh_key" ]]; then
        print_warning "SSH key file not found: $ssh_key"
        echo -e "${YELLOW}Continuing anyway - make sure to add the key before running playbooks${NC}"
    fi

    # Server group
    echo -e "${CYAN}Server Group${NC} [default: servers]:"
    echo "  Common groups: servers, production, development, webservers, databases"
    read -r input
    if [[ -n "$input" ]]; then
        server_group="$input"
    fi

    # Timezone
    echo -e "${CYAN}Timezone${NC} (leave empty for default in group_vars/all.yml):"
    echo "  Examples: America/New_York, Europe/London, Asia/Tokyo"
    read -r timezone

    # Test connection
    echo
    echo -e "${CYAN}Test SSH Connection?${NC} [Y/n]:"
    read -r input
    if [[ "$input" =~ ^[Nn] ]]; then
        test_connection="n"
    fi

    # Summary
    echo
    print_step "Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${CYAN}Server Name:${NC}    $server_name"
    echo -e "  ${CYAN}Host:${NC}           $ansible_host"
    echo -e "  ${CYAN}User:${NC}           $ansible_user"
    echo -e "  ${CYAN}Port:${NC}           $ansible_port"
    [[ -n "$custom_hostname" ]] && echo -e "  ${CYAN}Hostname:${NC}       $custom_hostname"
    [[ -n "$ssh_key" ]] && echo -e "  ${CYAN}SSH Key:${NC}        $ssh_key"
    echo -e "  ${CYAN}Group:${NC}          $server_group"
    [[ -n "$timezone" ]] && echo -e "  ${CYAN}Timezone:${NC}       $timezone"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Confirm
    echo -e "${CYAN}Add this server to inventory?${NC} [Y/n]:"
    read -r confirm

    if [[ "$confirm" =~ ^[Nn] ]]; then
        print_warning "Cancelled by user"
        return 1
    fi

    # Test connection if requested
    if [[ "$test_connection" == "y" ]]; then
        test_ssh_connection "$ansible_host" "$ansible_port" "$ansible_user" "$ssh_key" || true
        echo
    fi

    # Backup and add
    backup_inventory
    create_inventory_from_example
    add_server_to_inventory "$server_name" "$ansible_host" "$ansible_user" "$ansible_port" \
                            "$custom_hostname" "$ssh_key" "$server_group" "$timezone"

    echo
    print_success "Server added successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Verify inventory: ansible-inventory --list"
    echo "  2. Test connection: ansible $server_name -m ping"
    echo "  3. Bootstrap server: ansible-playbook playbooks/bootstrap.yml --limit $server_name -K"
    echo "  4. Setup server: ansible-playbook playbooks/setup-targets.yml --limit $server_name"
    echo

    return 0
}

# ================================================================================
# Batch Mode
# ================================================================================

batch_mode() {
    print_header
    echo
    print_info "Batch mode: Add multiple servers"
    echo

    local servers_added=0

    while true; do
        if prompt_server_details; then
            ((servers_added++))
        fi

        echo
        echo -e "${CYAN}Add another server?${NC} [y/N]:"
        read -r another

        if [[ ! "$another" =~ ^[Yy] ]]; then
            break
        fi

        echo
    done

    echo
    print_success "Added $servers_added server(s) to inventory"
    echo

    if [[ $servers_added -gt 0 ]]; then
        print_info "To setup all new servers at once:"
        echo "  ansible-playbook playbooks/setup-targets.yml"
        echo
    fi
}

# ================================================================================
# Main Script
# ================================================================================

show_help() {
    cat << EOF
Server Helper - Add Server Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -b, --batch         Batch mode (add multiple servers)
    -t, --test-only     Only test connection, don't add to inventory

EXAMPLES:
    # Interactive mode (guided prompts)
    $0

    # Batch mode (add multiple servers)
    $0 --batch

    # Show help
    $0 --help

DESCRIPTION:
    This script helps you add new servers to the Ansible inventory with
    an interactive wizard. It validates inputs, tests SSH connectivity,
    and automatically updates the inventory file.

FEATURES:
    - ✅ Interactive prompts for server details
    - ✅ Validates IP addresses, hostnames, and ports
    - ✅ Tests SSH connectivity before adding
    - ✅ Supports custom SSH ports and keys
    - ✅ Automatically creates/updates inventory/hosts.yml
    - ✅ Organizes servers into groups
    - ✅ Backs up inventory before changes
    - ✅ Batch mode for adding multiple servers

SEE ALSO:
    - inventory/hosts.example.yml - Example inventory with all options
    - docs/guides/command-node.md - Multi-server setup guide
    - ansible-playbook playbooks/bootstrap.yml - Bootstrap new servers

EOF
}

main() {
    local batch_mode_enabled=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--batch)
                batch_mode_enabled=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run '$0 --help' for usage information"
                exit 1
                ;;
        esac
    done

    # Check if running from correct directory
    if [[ ! -d "$PROJECT_ROOT/inventory" ]]; then
        print_error "This script must be run from the Server-Helper repository"
        exit 1
    fi

    # Run in appropriate mode
    if [[ "$batch_mode_enabled" == true ]]; then
        batch_mode
    else
        prompt_server_details
    fi
}

# Run main function
main "$@"