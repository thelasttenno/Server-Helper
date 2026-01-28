#!/usr/bin/env bash
#
# Server Helper - UI Launcher
# ============================
# Opens web interfaces for Server Helper services in your default browser
#
# Usage:
#   ./scripts/open-ui.sh [SERVICE] [HOST]
#
# Examples:
#   ./scripts/open-ui.sh dockge              # Open Dockge on first host
#   ./scripts/open-ui.sh netdata server-01   # Open Netdata on server-01
#   ./scripts/open-ui.sh all                 # Open all UIs
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "\n${BLUE}${BOLD}Server Helper - UI Launcher${NC}\n"
}

# Get host IP from inventory
get_host_ip() {
    local hostname="$1"
    local inventory_file="$PROJECT_ROOT/inventory/hosts.yml"

    if [[ ! -f "$inventory_file" ]]; then
        print_error "Inventory file not found: $inventory_file"
        return 1
    fi

    # Parse YAML to get ansible_host for the given hostname
    local ip
    ip=$(awk -v host="$hostname:" '
        $0 ~ host {found=1}
        found && /ansible_host:/ {print $2; exit}
    ' "$inventory_file" | tr -d '"' | tr -d "'")

    if [[ -z "$ip" ]]; then
        print_error "Could not find IP for host: $hostname"
        return 1
    fi

    echo "$ip"
}

# Get first host from inventory
get_first_host() {
    local inventory_file="$PROJECT_ROOT/inventory/hosts.yml"

    if [[ ! -f "$inventory_file" ]]; then
        print_error "Inventory file not found: $inventory_file"
        return 1
    fi

    # Get first host under 'all.hosts'
    local first_host
    first_host=$(awk '
        /^  hosts:/ {in_hosts=1; next}
        in_hosts && /^    [a-zA-Z]/ {
            gsub(/:/, "");
            print $1;
            exit
        }
    ' "$inventory_file")

    if [[ -z "$first_host" ]]; then
        print_error "No hosts found in inventory"
        return 1
    fi

    echo "$first_host"
}

# Get port from config
get_port() {
    local service="$1"
    local config_file="$PROJECT_ROOT/group_vars/all.yml"

    if [[ ! -f "$config_file" ]]; then
        # Use defaults
        case "$service" in
            dockge) echo "5001" ;;
            netdata) echo "19999" ;;
            uptime-kuma|uptime_kuma) echo "3001" ;;
            *) echo "" ;;
        esac
        return
    fi

    # Parse config file for port
    local port
    case "$service" in
        dockge)
            port=$(grep -A 5 "^dockge:" "$config_file" | grep "port:" | head -1 | awk '{print $2}')
            echo "${port:-5001}"
            ;;
        netdata)
            port=$(grep -A 10 "^monitoring:" "$config_file" | grep -A 5 "netdata:" | grep "port:" | head -1 | awk '{print $2}')
            echo "${port:-19999}"
            ;;
        uptime-kuma|uptime_kuma)
            port=$(grep -A 10 "^monitoring:" "$config_file" | grep -A 5 "uptime_kuma:" | grep "port:" | head -1 | awk '{print $2}')
            echo "${port:-3001}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Open URL in browser
open_browser() {
    local url="$1"
    local service_name="$2"

    print_info "Opening $service_name..."
    print_success "URL: $url"

    # Detect OS and open browser
    if command -v xdg-open &>/dev/null; then
        # Linux
        xdg-open "$url" &>/dev/null &
    elif command -v open &>/dev/null; then
        # macOS
        open "$url"
    elif command -v start &>/dev/null; then
        # Windows (Git Bash, WSL)
        start "$url" 2>/dev/null || cmd.exe /c start "$url"
    else
        print_error "Could not detect browser opener command"
        print_info "Please open manually: $url"
        return 1
    fi

    sleep 1
}

# Open specific service UI
open_service() {
    local service="$1"
    local hostname="${2:-}"

    # Get hostname if not specified
    if [[ -z "$hostname" ]]; then
        hostname=$(get_first_host)
        print_info "Using first host from inventory: $hostname"
    fi

    # Get host IP
    local host_ip
    host_ip=$(get_host_ip "$hostname")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Get service port
    local port
    port=$(get_port "$service")
    if [[ -z "$port" ]]; then
        print_error "Unknown service: $service"
        return 1
    fi

    # Construct URL
    local url="http://${host_ip}:${port}"

    # Service-specific paths
    case "$service" in
        netdata)
            url="${url}/#menu_system_submenu_overview;theme=slate"
            ;;
        uptime-kuma|uptime_kuma)
            url="${url}/dashboard"
            ;;
    esac

    # Open in browser
    open_browser "$url" "$service ($hostname)"
}

# Open all UIs
open_all() {
    local hostname="${1:-}"

    # Get hostname if not specified
    if [[ -z "$hostname" ]]; then
        hostname=$(get_first_host)
        print_info "Using first host from inventory: $hostname"
    fi

    print_header
    print_info "Opening all service UIs for host: $hostname"
    echo

    # Open each service
    open_service "dockge" "$hostname"
    sleep 2
    open_service "netdata" "$hostname"
    sleep 2
    open_service "uptime-kuma" "$hostname"

    echo
    print_success "All UIs opened!"
}

# List available services
list_services() {
    local hostname="${1:-}"

    # Get hostname if not specified
    if [[ -z "$hostname" ]]; then
        hostname=$(get_first_host)
    fi

    # Get host IP
    local host_ip
    host_ip=$(get_host_ip "$hostname")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    print_header
    print_info "Available services on $hostname ($host_ip):"
    echo

    local dockge_port netdata_port uptime_port
    dockge_port=$(get_port "dockge")
    netdata_port=$(get_port "netdata")
    uptime_port=$(get_port "uptime-kuma")

    echo -e "  ${BOLD}Dockge${NC} (Container Management)"
    echo "    http://${host_ip}:${dockge_port}"
    echo

    echo -e "  ${BOLD}Netdata${NC} (System Monitoring)"
    echo "    http://${host_ip}:${netdata_port}"
    echo

    echo -e "  ${BOLD}Uptime Kuma${NC} (Uptime Monitoring)"
    echo "    http://${host_ip}:${uptime_port}"
    echo

    print_info "Usage:"
    echo "  $0 <service> [$hostname]"
    echo "  $0 all [$hostname]"
    echo "  $0 list [$hostname]"
    echo
}

# Show usage
show_usage() {
    cat << EOF
Server Helper - UI Launcher

Opens web interfaces for Server Helper services in your default browser

Usage:
  $0 [SERVICE] [HOST]

Services:
  dockge        Container management platform
  netdata       System monitoring dashboard
  uptime-kuma   Uptime monitoring and alerting
  all           Open all service UIs
  list          List available services and URLs

Arguments:
  SERVICE       Service to open (optional, defaults to 'list')
  HOST          Target hostname from inventory (optional, uses first host)

Examples:
  $0                          # List all available services
  $0 dockge                   # Open Dockge on first host
  $0 netdata server-01        # Open Netdata on server-01
  $0 uptime-kuma server-02    # Open Uptime Kuma on server-02
  $0 all                      # Open all UIs for first host
  $0 all server-01            # Open all UIs for server-01
  $0 list server-01           # List services on server-01

EOF
}

# Main
main() {
    local service="${1:-list}"
    local hostname="${2:-}"

    case "$service" in
        -h|--help|help)
            show_usage
            ;;
        list|ls)
            list_services "$hostname"
            ;;
        all)
            open_all "$hostname"
            ;;
        dockge|netdata|uptime-kuma|uptime_kuma)
            print_header
            open_service "$service" "$hostname"
            echo
            ;;
        *)
            print_error "Unknown service: $service"
            echo
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
