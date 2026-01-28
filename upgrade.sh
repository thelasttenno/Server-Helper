#!/usr/bin/env bash
#
# Server Helper v1.0.0 - Upgrade Script
# ======================================
# This script upgrades Docker images and restarts services across all managed servers.
#
# Usage:
#   ./upgrade.sh [OPTIONS]
#
# Options:
#   --all                Upgrade all services on all hosts (default)
#   --host <hostname>    Upgrade services on specific host
#   --service <name>     Upgrade specific service only
#   --pull-only          Pull images but don't restart services
#   --dry-run            Show what would be upgraded
#   --help               Show this help message
#
# Examples:
#   ./upgrade.sh                              # Upgrade all services on all hosts
#   ./upgrade.sh --host server-01             # Upgrade all services on server-01
#   ./upgrade.sh --service netdata            # Upgrade netdata on all hosts
#   ./upgrade.sh --host server-01 --service dockge  # Upgrade dockge on server-01
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Default values
TARGET_HOST="all"
TARGET_SERVICE="all"
PULL_ONLY=false
DRY_RUN=false
VERBOSE=false

# Function to print colored messages
print_header() {
    echo -e "\n${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║  Server Helper - Upgrade Manager      ║${NC}"
    echo -e "${BLUE}${BOLD}║  Docker Images & Service Restart      ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${CYAN}${BOLD}▶${NC} $1"
}

# Show usage
show_usage() {
    cat << EOF
Server Helper - Upgrade Script

Usage: $0 [OPTIONS]

Options:
  --all                Upgrade all services on all hosts (default)
  --host <hostname>    Upgrade services on specific host
  --service <name>     Upgrade specific service (dockge, netdata, uptime-kuma)
  --pull-only          Pull images but don't restart services
  --dry-run            Show what would be upgraded without making changes
  --verbose            Show detailed output
  --help               Show this help message

Examples:
  $0                                    # Upgrade everything
  $0 --host server-01                   # Upgrade all services on server-01
  $0 --service netdata                  # Upgrade netdata on all hosts
  $0 --host server-01 --service dockge  # Upgrade dockge on server-01
  $0 --dry-run                          # Preview what would be upgraded
  $0 --pull-only                        # Only pull new images, don't restart

Services:
  - dockge        Container management platform
  - netdata       System monitoring
  - uptime-kuma   Uptime monitoring and alerting
  - all           All services (default)

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                TARGET_HOST="all"
                TARGET_SERVICE="all"
                shift
                ;;
            --host)
                TARGET_HOST="$2"
                shift 2
                ;;
            --service)
                TARGET_SERVICE="$2"
                shift 2
                ;;
            --pull-only)
                PULL_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prereqs() {
    print_step "Checking prerequisites..."

    # Check if ansible is installed
    if ! command -v ansible >/dev/null 2>&1; then
        print_error "Ansible is not installed"
        print_info "Please install Ansible first"
        exit 1
    fi

    # Check if inventory exists
    if [[ ! -f "inventory/hosts.yml" ]]; then
        print_error "Inventory file not found: inventory/hosts.yml"
        print_info "Please create inventory file first"
        exit 1
    fi

    # Check if vault password file exists
    if [[ ! -f ".vault_password" ]]; then
        print_warning "Vault password file not found (may cause issues with encrypted variables)"
    fi

    print_success "Prerequisites check passed"
}

# List available hosts
list_hosts() {
    print_step "Available hosts:"
    ansible all --list-hosts 2>/dev/null | grep -v "hosts (" | sed 's/^/  /'
    echo
}

# Verify target host exists
verify_host() {
    if [[ "$TARGET_HOST" != "all" ]]; then
        if ! ansible "$TARGET_HOST" --list-hosts &>/dev/null; then
            print_error "Host '$TARGET_HOST' not found in inventory"
            list_hosts
            exit 1
        fi
    fi
}

# Build Ansible command
build_ansible_cmd() {
    local cmd="ansible-playbook"

    # Add verbosity
    if [[ "$VERBOSE" == true ]]; then
        cmd="$cmd -vv"
    fi

    # Add check mode for dry run
    if [[ "$DRY_RUN" == true ]]; then
        cmd="$cmd --check --diff"
    fi

    # Add host limit
    if [[ "$TARGET_HOST" != "all" ]]; then
        cmd="$cmd --limit $TARGET_HOST"
    fi

    echo "$cmd"
}

# Upgrade Docker images using Ansible ad-hoc commands
upgrade_docker_images() {
    local service="$1"
    local ansible_cmd=$(build_ansible_cmd)
    local host_limit=""

    if [[ "$TARGET_HOST" != "all" ]]; then
        host_limit="--limit $TARGET_HOST"
    fi

    print_step "Upgrading Docker images for: $service"

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo
    fi

    case "$service" in
        dockge)
            upgrade_service "dockge" "/opt/dockge" "$host_limit"
            ;;
        netdata)
            upgrade_service "netdata" "/opt/dockge/stacks/netdata" "$host_limit"
            ;;
        uptime-kuma)
            upgrade_service "uptime-kuma" "/opt/dockge/stacks/uptime-kuma" "$host_limit"
            ;;
        all)
            print_info "Upgrading all services..."
            echo
            upgrade_service "dockge" "/opt/dockge" "$host_limit"
            upgrade_service "netdata" "/opt/dockge/stacks/netdata" "$host_limit"
            upgrade_service "uptime-kuma" "/opt/dockge/stacks/uptime-kuma" "$host_limit"
            ;;
        *)
            print_error "Unknown service: $service"
            print_info "Available services: dockge, netdata, uptime-kuma, all"
            exit 1
            ;;
    esac
}

# Upgrade a specific service
upgrade_service() {
    local service_name="$1"
    local compose_dir="$2"
    local host_limit="$3"

    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Upgrading: $service_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Check if service exists on target hosts
    print_info "Checking if $service_name is deployed..."

    local check_cmd="ansible ${TARGET_HOST} -m stat -a \"path=$compose_dir/docker-compose.yml\" $host_limit"
    if [[ "$VERBOSE" == true ]]; then
        echo "Command: $check_cmd"
    fi

    if ! eval "$check_cmd" | grep -q "exists.*true"; then
        print_warning "$service_name not found on target host(s), skipping..."
        echo
        return
    fi

    # Pull latest images
    print_info "Pulling latest images for $service_name..."

    local pull_cmd="ansible ${TARGET_HOST} -m shell -a 'cd $compose_dir && docker compose pull' $host_limit"
    if [[ "$VERBOSE" == true ]]; then
        echo "Command: $pull_cmd"
    fi

    if [[ "$DRY_RUN" == false ]]; then
        if eval "$pull_cmd"; then
            print_success "Images pulled successfully"
        else
            print_error "Failed to pull images for $service_name"
            return 1
        fi
    else
        print_info "[DRY RUN] Would pull images for $service_name"
    fi

    # Restart services if not pull-only mode
    if [[ "$PULL_ONLY" == false ]]; then
        print_info "Restarting $service_name..."

        local restart_cmd="ansible ${TARGET_HOST} -m shell -a 'cd $compose_dir && docker compose up -d --remove-orphans' $host_limit"
        if [[ "$VERBOSE" == true ]]; then
            echo "Command: $restart_cmd"
        fi

        if [[ "$DRY_RUN" == false ]]; then
            if eval "$restart_cmd"; then
                print_success "$service_name restarted successfully"
            else
                print_error "Failed to restart $service_name"
                return 1
            fi
        else
            print_info "[DRY RUN] Would restart $service_name"
        fi

        # Wait for service to be healthy
        print_info "Waiting for $service_name to be healthy..."
        sleep 5

        # Verify service is running
        local verify_cmd="ansible ${TARGET_HOST} -m shell -a 'cd $compose_dir && docker compose ps' $host_limit"
        if [[ "$VERBOSE" == true ]]; then
            echo "Command: $verify_cmd"
        fi

        if [[ "$DRY_RUN" == false ]]; then
            if eval "$verify_cmd" | grep -q "Up"; then
                print_success "$service_name is running"
            else
                print_warning "$service_name may not be running properly"
            fi
        else
            print_info "[DRY RUN] Would verify $service_name status"
        fi
    else
        print_info "Skipping restart (pull-only mode)"
    fi

    echo
}

# Clean up unused Docker resources
cleanup_docker() {
    print_step "Cleaning up unused Docker resources..."

    local cleanup_cmd="ansible ${TARGET_HOST} -m shell -a 'docker system prune -f --volumes'"

    if [[ "$TARGET_HOST" != "all" ]]; then
        cleanup_cmd="$cleanup_cmd --limit $TARGET_HOST"
    fi

    if [[ "$VERBOSE" == true ]]; then
        echo "Command: $cleanup_cmd"
    fi

    if [[ "$DRY_RUN" == false ]]; then
        read -p "Clean up unused Docker resources (images, containers, volumes)? (y/N): " -r CONFIRM
        echo
        if [[ $CONFIRM =~ ^[Yy]$ ]]; then
            if eval "$cleanup_cmd"; then
                print_success "Docker cleanup completed"
            else
                print_warning "Docker cleanup failed (non-critical)"
            fi
        else
            print_info "Skipping cleanup"
        fi
    else
        print_info "[DRY RUN] Would clean up unused Docker resources"
    fi
}

# Show upgrade summary
show_summary() {
    print_header
    print_success "Upgrade process completed!"
    echo

    print_info "Summary:"
    echo "  Target Host(s): $TARGET_HOST"
    echo "  Target Service(s): $TARGET_SERVICE"
    echo "  Pull Only: $PULL_ONLY"
    echo "  Dry Run: $DRY_RUN"
    echo

    if [[ "$DRY_RUN" == false ]]; then
        print_info "Next steps:"
        echo "  1. Verify services are running:"
        echo "     ansible ${TARGET_HOST} -m shell -a 'docker ps'"
        echo
        echo "  2. Check service logs if needed:"
        echo "     ansible ${TARGET_HOST} -m shell -a 'docker compose -f /opt/dockge/docker-compose.yml logs --tail=50'"
        echo
        echo "  3. Access web interfaces to verify functionality"
        echo
    else
        print_warning "This was a dry run - no changes were made"
        print_info "Run without --dry-run to apply changes"
    fi
}

# Main execution
main() {
    print_header

    # Parse arguments
    parse_args "$@"

    # Run checks
    check_prereqs
    verify_host

    # Show what we're doing
    print_info "Upgrade configuration:"
    echo "  Host: $TARGET_HOST"
    echo "  Service: $TARGET_SERVICE"
    if [[ "$PULL_ONLY" == true ]]; then
        echo "  Mode: Pull images only (no restart)"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        echo "  Mode: Dry run (preview only)"
    fi
    echo

    # Confirm action
    if [[ "$DRY_RUN" == false ]]; then
        read -p "Continue with upgrade? (y/N): " -r CONFIRM
        echo
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            print_info "Upgrade cancelled"
            exit 0
        fi
    fi

    # Perform upgrade
    upgrade_docker_images "$TARGET_SERVICE"

    # Offer cleanup
    if [[ "$PULL_ONLY" == false && "$DRY_RUN" == false ]]; then
        echo
        cleanup_docker
    fi

    # Show summary
    show_summary
}

# Run main function
main "$@"
