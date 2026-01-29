#!/usr/bin/env bash
#
# Server Helper - Upgrade Library Module
# =======================================
# Functions for upgrading Docker services across managed servers.
#
# This module provides:
#   - Docker image pulling
#   - Service restart operations
#   - Cleanup of unused Docker resources
#   - Upgrade verification
#
# Usage:
#   source scripts/lib/upgrade.sh
#   upgrade_service "dockge" "/opt/dockge" "server-01"
#
# Dependencies:
#   - Ansible installed on command node
#   - SSH access to target servers
#   - Docker installed on target servers
#

# Prevent multiple inclusion
[[ -n "${_UPGRADE_LOADED:-}" ]] && return 0
_UPGRADE_LOADED=1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default service paths
declare -A UPGRADE_SERVICE_PATHS=(
    [dockge]="/opt/dockge"
    [netdata]="/opt/dockge/stacks/netdata"
    [uptime-kuma]="/opt/dockge/stacks/uptime-kuma"
    [grafana]="/opt/dockge/stacks/grafana"
    [loki]="/opt/dockge/stacks/loki"
    [promtail]="/opt/dockge/stacks/promtail"
    [traefik]="/opt/dockge/stacks/traefik"
    [watchtower]="/opt/dockge/stacks/watchtower"
)

# Track upgrade results
_UPGRADE_PASSED=()
_UPGRADE_FAILED=()
_UPGRADE_SKIPPED=()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Get compose directory for a service
# Args: $1 = service name
# Returns: compose directory path
upgrade_get_service_path() {
    local service="$1"
    echo "${UPGRADE_SERVICE_PATHS[$service]:-}"
}

# Check if a service is deployed on target
# Args: $1 = host, $2 = compose_dir
# Returns: 0 if deployed, 1 otherwise
upgrade_check_deployed() {
    local host="$1"
    local compose_dir="$2"

    local result
    result=$(ansible "$host" -m stat -a "path=${compose_dir}/docker-compose.yml" 2>/dev/null)

    if echo "$result" | grep -q "exists.*true"; then
        return 0
    fi
    return 1
}

# =============================================================================
# CORE UPGRADE FUNCTIONS
# =============================================================================

# Pull latest Docker images for a service
# Args: $1 = service_name, $2 = compose_dir, $3 = host (default: all), $4 = dry_run (default: false)
# Returns: 0 on success, 1 on failure
upgrade_pull_images() {
    local service_name="$1"
    local compose_dir="$2"
    local host="${3:-all}"
    local dry_run="${4:-false}"

    if [[ "$dry_run" == "true" ]]; then
        if declare -F print_info &>/dev/null; then
            print_info "[DRY RUN] Would pull images for $service_name on $host"
        fi
        return 0
    fi

    local pull_cmd="ansible ${host} -m shell -a 'cd ${compose_dir} && docker compose pull' 2>/dev/null"

    if eval "$pull_cmd"; then
        if declare -F print_success &>/dev/null; then
            print_success "Images pulled for $service_name"
        fi
        return 0
    else
        if declare -F print_error &>/dev/null; then
            print_error "Failed to pull images for $service_name"
        fi
        return 1
    fi
}

# Restart a Docker Compose service
# Args: $1 = service_name, $2 = compose_dir, $3 = host (default: all), $4 = dry_run (default: false)
# Returns: 0 on success, 1 on failure
upgrade_restart_service() {
    local service_name="$1"
    local compose_dir="$2"
    local host="${3:-all}"
    local dry_run="${4:-false}"

    if [[ "$dry_run" == "true" ]]; then
        if declare -F print_info &>/dev/null; then
            print_info "[DRY RUN] Would restart $service_name on $host"
        fi
        return 0
    fi

    local restart_cmd="ansible ${host} -m shell -a 'cd ${compose_dir} && docker compose up -d --remove-orphans' 2>/dev/null"

    if eval "$restart_cmd"; then
        if declare -F print_success &>/dev/null; then
            print_success "$service_name restarted"
        fi
        return 0
    else
        if declare -F print_error &>/dev/null; then
            print_error "Failed to restart $service_name"
        fi
        return 1
    fi
}

# Verify service is running after upgrade
# Args: $1 = service_name, $2 = compose_dir, $3 = host (default: all)
# Returns: 0 if running, 1 otherwise
upgrade_verify_service() {
    local service_name="$1"
    local compose_dir="$2"
    local host="${3:-all}"

    local verify_cmd="ansible ${host} -m shell -a 'cd ${compose_dir} && docker compose ps' 2>/dev/null"

    if eval "$verify_cmd" | grep -q "Up"; then
        if declare -F print_success &>/dev/null; then
            print_success "$service_name is running"
        fi
        return 0
    else
        if declare -F print_warning &>/dev/null; then
            print_warning "$service_name may not be running properly"
        fi
        return 1
    fi
}

# Upgrade a complete service (pull, restart, verify)
# Args: $1 = service_name, $2 = host (default: all), $3 = pull_only (default: false), $4 = dry_run (default: false)
# Returns: 0 on success, 1 on failure
upgrade_service() {
    local service_name="$1"
    local host="${2:-all}"
    local pull_only="${3:-false}"
    local dry_run="${4:-false}"

    local compose_dir
    compose_dir=$(upgrade_get_service_path "$service_name")

    if [[ -z "$compose_dir" ]]; then
        if declare -F print_error &>/dev/null; then
            print_error "Unknown service: $service_name"
        fi
        _UPGRADE_FAILED+=("$service_name")
        return 1
    fi

    # Check if service is deployed
    if ! upgrade_check_deployed "$host" "$compose_dir"; then
        if declare -F print_warning &>/dev/null; then
            print_warning "$service_name not deployed on $host, skipping"
        fi
        _UPGRADE_SKIPPED+=("$service_name")
        return 0
    fi

    # Pull images
    if ! upgrade_pull_images "$service_name" "$compose_dir" "$host" "$dry_run"; then
        _UPGRADE_FAILED+=("$service_name")
        return 1
    fi

    # Restart if not pull-only mode
    if [[ "$pull_only" == "false" ]]; then
        if ! upgrade_restart_service "$service_name" "$compose_dir" "$host" "$dry_run"; then
            _UPGRADE_FAILED+=("$service_name")
            return 1
        fi

        # Wait for service to stabilize
        if [[ "$dry_run" == "false" ]]; then
            sleep 5
            upgrade_verify_service "$service_name" "$compose_dir" "$host"
        fi
    fi

    _UPGRADE_PASSED+=("$service_name")
    return 0
}

# Upgrade all known services
# Args: $1 = host (default: all), $2 = pull_only (default: false), $3 = dry_run (default: false)
upgrade_all_services() {
    local host="${1:-all}"
    local pull_only="${2:-false}"
    local dry_run="${3:-false}"

    local services=("dockge" "netdata" "uptime-kuma" "grafana" "loki" "promtail" "traefik" "watchtower")

    for service in "${services[@]}"; do
        upgrade_service "$service" "$host" "$pull_only" "$dry_run"
    done
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

# Clean up unused Docker resources
# Args: $1 = host (default: all), $2 = dry_run (default: false), $3 = include_volumes (default: false)
# Returns: 0 on success, 1 on failure
upgrade_docker_cleanup() {
    local host="${1:-all}"
    local dry_run="${2:-false}"
    local include_volumes="${3:-false}"

    local prune_opts="-f"
    if [[ "$include_volumes" == "true" ]]; then
        prune_opts="$prune_opts --volumes"
    fi

    if [[ "$dry_run" == "true" ]]; then
        if declare -F print_info &>/dev/null; then
            print_info "[DRY RUN] Would clean up Docker resources on $host"
        fi
        return 0
    fi

    local cleanup_cmd="ansible ${host} -m shell -a 'docker system prune ${prune_opts}' 2>/dev/null"

    if eval "$cleanup_cmd"; then
        if declare -F print_success &>/dev/null; then
            print_success "Docker cleanup completed on $host"
        fi
        return 0
    else
        if declare -F print_warning &>/dev/null; then
            print_warning "Docker cleanup failed on $host (non-critical)"
        fi
        return 1
    fi
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

# Get upgrade results
upgrade_get_passed() { echo "${_UPGRADE_PASSED[*]}"; }
upgrade_get_failed() { echo "${_UPGRADE_FAILED[*]}"; }
upgrade_get_skipped() { echo "${_UPGRADE_SKIPPED[*]}"; }
upgrade_get_passed_count() { echo "${#_UPGRADE_PASSED[@]}"; }
upgrade_get_failed_count() { echo "${#_UPGRADE_FAILED[@]}"; }
upgrade_get_skipped_count() { echo "${#_UPGRADE_SKIPPED[@]}"; }

# Reset upgrade tracking
upgrade_reset_tracking() {
    _UPGRADE_PASSED=()
    _UPGRADE_FAILED=()
    _UPGRADE_SKIPPED=()
}

# Print upgrade summary
upgrade_print_summary() {
    echo
    echo "Upgrade Summary:"
    echo "  Passed:  ${#_UPGRADE_PASSED[@]}"
    echo "  Failed:  ${#_UPGRADE_FAILED[@]}"
    echo "  Skipped: ${#_UPGRADE_SKIPPED[@]}"

    if [[ ${#_UPGRADE_PASSED[@]} -gt 0 ]]; then
        echo
        echo "Upgraded services:"
        for svc in "${_UPGRADE_PASSED[@]}"; do
            echo "  - $svc"
        done
    fi

    if [[ ${#_UPGRADE_FAILED[@]} -gt 0 ]]; then
        echo
        echo "Failed services:"
        for svc in "${_UPGRADE_FAILED[@]}"; do
            echo "  - $svc"
        done
    fi

    if [[ ${#_UPGRADE_SKIPPED[@]} -gt 0 ]]; then
        echo
        echo "Skipped services:"
        for svc in "${_UPGRADE_SKIPPED[@]}"; do
            echo "  - $svc"
        done
    fi
}
