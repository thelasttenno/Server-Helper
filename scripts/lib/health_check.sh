#!/usr/bin/env bash
#
# Server Helper - Health Check
# =============================
# Provides health checking functions for servers and services.
#
# Usage:
#   source scripts/lib/health_check.sh
#
# Security:
#   - No credentials stored in temp files
#   - Uses secure temp directory when needed
#   - Cleans up after execution
#

# Prevent multiple sourcing
[[ -n "${_HEALTH_CHECK_LOADED:-}" ]] && return 0
readonly _HEALTH_CHECK_LOADED=1

# Require ui_utils
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: health_check.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

# =============================================================================
# Configuration
# =============================================================================
readonly HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"
readonly HEALTH_CHECK_SSH_TIMEOUT="${HEALTH_CHECK_SSH_TIMEOUT:-5}"

# =============================================================================
# Basic Connectivity Checks
# =============================================================================

# Check if a host is reachable via ping
health_ping() {
    local host="$1"
    local count="${2:-1}"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"

    if ping -c "$count" -W "$timeout" "$host" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if a port is open
health_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-$HEALTH_CHECK_TIMEOUT}"

    if command -v nc >/dev/null 2>&1; then
        if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
            return 0
        fi
    elif command -v timeout >/dev/null 2>&1; then
        if timeout "$timeout" bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            return 0
        fi
    else
        # Fallback using bash
        if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Check SSH connectivity
health_ssh() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"
    local timeout="${4:-$HEALTH_CHECK_SSH_TIMEOUT}"

    if ssh -o ConnectTimeout="$timeout" \
           -o BatchMode=yes \
           -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null \
           -o LogLevel=ERROR \
           -p "$port" \
           "${user}@${host}" "echo ok" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Service Health Checks
# =============================================================================

# Check if Docker is running on a host
health_docker() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    local result
    result=$(ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
                 -o BatchMode=yes \
                 -o StrictHostKeyChecking=no \
                 -o LogLevel=ERROR \
                 -p "$port" \
                 "${user}@${host}" "docker info >/dev/null 2>&1 && echo ok" 2>/dev/null)

    [[ "$result" == "ok" ]]
}

# Check if a container is running
health_container() {
    local host="$1"
    local container="$2"
    local user="${3:-ubuntu}"
    local port="${4:-22}"

    local result
    result=$(ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
                 -o BatchMode=yes \
                 -o StrictHostKeyChecking=no \
                 -o LogLevel=ERROR \
                 -p "$port" \
                 "${user}@${host}" "docker ps --format '{{.Names}}' | grep -q '^${container}$' && echo ok" 2>/dev/null)

    [[ "$result" == "ok" ]]
}

# Get list of running containers on a host
health_list_containers() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        -p "$port" \
        "${user}@${host}" "docker ps --format '{{.Names}}\t{{.Status}}'" 2>/dev/null
}

# Check HTTP endpoint
health_http() {
    local url="$1"
    local timeout="${2:-$HEALTH_CHECK_TIMEOUT}"
    local expected_code="${3:-200}"

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" \
                       --connect-timeout "$timeout" \
                       --max-time "$((timeout * 2))" \
                       "$url" 2>/dev/null)

    [[ "$status_code" == "$expected_code" ]]
}

# =============================================================================
# System Health Checks
# =============================================================================

# Get disk usage on a host
health_disk_usage() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"
    local path="${4:-/}"

    ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        -p "$port" \
        "${user}@${host}" "df -h '$path' | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null
}

# Check if disk usage is below threshold
health_disk_ok() {
    local host="$1"
    local threshold="${2:-90}"
    local user="${3:-ubuntu}"
    local port="${4:-22}"

    local usage
    usage=$(health_disk_usage "$host" "$user" "$port")

    if [[ -n "$usage" ]] && [[ "$usage" =~ ^[0-9]+$ ]]; then
        [[ "$usage" -lt "$threshold" ]]
    else
        return 1
    fi
}

# Get memory usage on a host
health_memory_usage() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        -p "$port" \
        "${user}@${host}" "free | grep Mem | awk '{printf \"%.0f\", \$3/\$2 * 100}'" 2>/dev/null
}

# Get system load
health_load() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o LogLevel=ERROR \
        -p "$port" \
        "${user}@${host}" "cat /proc/loadavg | awk '{print \$1}'" 2>/dev/null
}

# =============================================================================
# Comprehensive Health Checks
# =============================================================================

# Full health check for a single host
health_check_host() {
    local host="$1"
    local ip="$2"
    local user="${3:-ubuntu}"
    local port="${4:-22}"

    local checks_passed=0
    local checks_total=0

    echo ""
    print_section "Health Check: $host ($ip)"

    # Ping check
    ((checks_total++))
    printf "  %-25s" "Ping:"
    if health_ping "$ip"; then
        echo -e "${GREEN}OK${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}FAILED${NC}"
    fi

    # SSH check
    ((checks_total++))
    printf "  %-25s" "SSH ($port):"
    if health_ssh "$ip" "$user" "$port"; then
        echo -e "${GREEN}OK${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}FAILED${NC}"
        # Can't continue without SSH
        echo "  (Skipping remaining checks - SSH required)"
        echo ""
        echo "  Result: ${checks_passed}/${checks_total} checks passed"
        return 1
    fi

    # Docker check
    ((checks_total++))
    printf "  %-25s" "Docker:"
    if health_docker "$ip" "$user" "$port"; then
        echo -e "${GREEN}OK${NC}"
        ((checks_passed++))
    else
        echo -e "${YELLOW}NOT RUNNING${NC}"
    fi

    # Disk check
    ((checks_total++))
    printf "  %-25s" "Disk usage:"
    local disk_usage
    disk_usage=$(health_disk_usage "$ip" "$user" "$port")
    if [[ -n "$disk_usage" ]]; then
        if [[ "$disk_usage" -lt 80 ]]; then
            echo -e "${GREEN}${disk_usage}%${NC}"
            ((checks_passed++))
        elif [[ "$disk_usage" -lt 90 ]]; then
            echo -e "${YELLOW}${disk_usage}% (warning)${NC}"
            ((checks_passed++))
        else
            echo -e "${RED}${disk_usage}% (critical)${NC}"
        fi
    else
        echo -e "${RED}FAILED${NC}"
    fi

    # Memory check
    ((checks_total++))
    printf "  %-25s" "Memory usage:"
    local mem_usage
    mem_usage=$(health_memory_usage "$ip" "$user" "$port")
    if [[ -n "$mem_usage" ]]; then
        if [[ "$mem_usage" -lt 80 ]]; then
            echo -e "${GREEN}${mem_usage}%${NC}"
            ((checks_passed++))
        elif [[ "$mem_usage" -lt 90 ]]; then
            echo -e "${YELLOW}${mem_usage}% (warning)${NC}"
            ((checks_passed++))
        else
            echo -e "${RED}${mem_usage}% (critical)${NC}"
        fi
    else
        echo -e "${RED}FAILED${NC}"
    fi

    # Load check
    printf "  %-25s" "System load:"
    local load
    load=$(health_load "$ip" "$user" "$port")
    if [[ -n "$load" ]]; then
        echo -e "${GREEN}${load}${NC}"
    else
        echo -e "${DIM}N/A${NC}"
    fi

    echo ""
    echo "  Result: ${checks_passed}/${checks_total} checks passed"

    [[ "$checks_passed" -eq "$checks_total" ]]
}

# Health check all servers in inventory
health_check_all() {
    local inventory="${1:-inventory/hosts.yml}"
    local passed=0
    local failed=0

    print_header "Fleet Health Check"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    # Get all hosts
    local hosts
    mapfile -t hosts < <(ansible-inventory -i "$inventory" --list 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
if '_meta' in data and 'hostvars' in data['_meta']:
    for h in data['_meta']['hostvars'].keys():
        print(h)
" 2>/dev/null)

    if [[ ${#hosts[@]} -eq 0 ]]; then
        print_warning "No hosts found in inventory"
        return 0
    fi

    print_info "Found ${#hosts[@]} host(s) in inventory"

    for host in "${hosts[@]}"; do
        # Get host details
        local ip user port
        ip=$(ansible-inventory -i "$inventory" --host "$host" 2>/dev/null | \
            python3 -c "import json,sys; print(json.load(sys.stdin).get('ansible_host',''))" 2>/dev/null)
        user=$(ansible-inventory -i "$inventory" --host "$host" 2>/dev/null | \
            python3 -c "import json,sys; print(json.load(sys.stdin).get('ansible_user','ubuntu'))" 2>/dev/null)
        port=$(ansible-inventory -i "$inventory" --host "$host" 2>/dev/null | \
            python3 -c "import json,sys; print(json.load(sys.stdin).get('ansible_port','22'))" 2>/dev/null)

        if [[ -z "$ip" ]]; then
            print_warning "Skipping $host - no IP address found"
            continue
        fi

        if health_check_host "$host" "$ip" "$user" "$port"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    print_section "Summary"
    echo "  Passed: ${GREEN}$passed${NC}"
    echo "  Failed: ${RED}$failed${NC}"
    echo "  Total:  $((passed + failed))"
    echo ""

    if [[ $failed -eq 0 ]]; then
        print_success "All health checks passed!"
        return 0
    else
        print_error "$failed host(s) failed health checks"
        return 1
    fi
}

# Quick connectivity check (ping + SSH only)
health_check_quick() {
    local inventory="${1:-inventory/hosts.yml}"
    local passed=0
    local failed=0

    print_header "Quick Connectivity Check"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    # Use Ansible ping module for quick check
    print_info "Testing connectivity with Ansible ping..."
    echo ""

    if ansible all -i "$inventory" -m ping 2>/dev/null; then
        print_success "All hosts are reachable"
        return 0
    else
        print_error "Some hosts are unreachable"
        return 1
    fi
}

# Service-specific health check
health_check_service() {
    local service="$1"
    local host="$2"
    local user="${3:-ubuntu}"
    local port="${4:-22}"

    printf "  %-20s" "$service:"

    if health_container "$host" "$service" "$user" "$port"; then
        echo -e "${GREEN}RUNNING${NC}"
        return 0
    else
        echo -e "${RED}NOT RUNNING${NC}"
        return 1
    fi
}

# Check all expected services on a host
health_check_services() {
    local host="$1"
    local ip="$2"
    local services="$3"  # Space-separated list
    local user="${4:-ubuntu}"
    local port="${5:-22}"

    print_section "Services on $host"

    local service
    local passed=0
    local total=0

    for service in $services; do
        ((total++))
        if health_check_service "$service" "$ip" "$user" "$port"; then
            ((passed++))
        fi
    done

    echo ""
    echo "  Services: ${passed}/${total} running"

    [[ "$passed" -eq "$total" ]]
}

# =============================================================================
# Fleet Validation (from validate-fleet.sh)
# =============================================================================

# Check Netdata streaming status on a target node
health_check_netdata_streaming() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    local result
    result=$(ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
                 -o BatchMode=yes \
                 -o StrictHostKeyChecking=no \
                 -o LogLevel=ERROR \
                 -p "$port" \
                 "${user}@${host}" \
                 "curl -s --connect-timeout 3 http://localhost:19999/api/v1/info 2>/dev/null | grep -q 'streaming' && echo 'streaming'" 2>/dev/null)

    [[ -n "$result" ]]
}

# Check Promtail status on a target node
health_check_promtail() {
    local host="$1"
    local user="${2:-ubuntu}"
    local port="${3:-22}"

    local result
    result=$(ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
                 -o BatchMode=yes \
                 -o StrictHostKeyChecking=no \
                 -o LogLevel=ERROR \
                 -p "$port" \
                 "${user}@${host}" \
                 "curl -s --connect-timeout 3 http://localhost:9080/ready" 2>/dev/null)

    [[ "$result" == "Ready" ]]
}

# Check Docker Socket Proxy accessibility from control node
health_check_docker_proxy() {
    local target_host="$1"
    local control_host="$2"
    local user="${3:-ubuntu}"

    local result
    result=$(ssh -o ConnectTimeout="$HEALTH_CHECK_SSH_TIMEOUT" \
                 -o BatchMode=yes \
                 -o StrictHostKeyChecking=no \
                 -o LogLevel=ERROR \
                 "${user}@${control_host}" \
                 "curl -s --connect-timeout 3 http://${target_host}:2375/_ping" 2>/dev/null)

    [[ "$result" == "OK" ]]
}

# Full fleet validation with detailed output
health_validate_fleet() {
    local inventory="${1:-inventory/hosts.yml}"
    local config="${2:-group_vars/all.yml}"
    local mode="${3:-full}"  # full, quick, services

    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warnings=0

    print_header "Fleet Validation"

    if [[ ! -f "$inventory" ]]; then
        print_error "Inventory file not found: $inventory"
        return 1
    fi

    # Parse inventory for control and target hosts
    local control_ip=""
    local -a target_hosts=()
    local -a target_names=()

    # Get control node IP from config
    if [[ -f "$config" ]]; then
        control_ip=$(grep "control_node_ip:" "$config" 2>/dev/null | awk '{print $2}' | tr -d '"')
    fi

    # Parse inventory for hosts
    local in_hosts=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=true
            continue
        fi
        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            target_names+=("${BASH_REMATCH[1]}")
        fi
        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
            target_hosts+=("${BASH_REMATCH[1]}")
            # Use first host as control if not set
            [[ -z "$control_ip" ]] && control_ip="${BASH_REMATCH[1]}"
        fi
    done < "$inventory"

    if [[ -z "$control_ip" ]]; then
        print_error "Could not determine control node IP"
        return 1
    fi

    print_info "Control Node: $control_ip"
    print_info "Target Nodes: ${#target_hosts[@]}"
    echo

    # Quick mode - just ping
    if [[ "$mode" == "quick" ]]; then
        print_section "Quick Connectivity Test"

        printf "  %-30s" "Control ($control_ip):"
        if ping -c 1 -W 2 "$control_ip" &>/dev/null; then
            echo -e "${GREEN}OK${NC}"
            ((passed_checks++))
        else
            echo -e "${RED}FAILED${NC}"
            ((failed_checks++))
        fi
        ((total_checks++))

        for i in "${!target_hosts[@]}"; do
            printf "  %-30s" "${target_names[$i]} (${target_hosts[$i]}):"
            if ping -c 1 -W 2 "${target_hosts[$i]}" &>/dev/null; then
                echo -e "${GREEN}OK${NC}"
                ((passed_checks++))
            else
                echo -e "${RED}FAILED${NC}"
                ((failed_checks++))
            fi
            ((total_checks++))
        done

        _health_print_validation_summary "$total_checks" "$passed_checks" "$failed_checks" "$warnings"
        return $([[ $failed_checks -eq 0 ]])
    fi

    # Services only mode
    if [[ "$mode" == "services" ]]; then
        print_section "Control Node Services"
        _health_check_control_services "$control_ip"
        return $?
    fi

    # Full validation

    # 1. SSH Connectivity
    print_section "SSH Connectivity"

    echo -e "${BOLD}Control Node:${NC}"
    printf "  %-30s" "control ($control_ip):"
    if health_ssh "$control_ip"; then
        echo -e "${GREEN}OK${NC}"
        ((passed_checks++))
    else
        echo -e "${RED}FAILED${NC}"
        ((failed_checks++))
    fi
    ((total_checks++))

    echo -e "\n${BOLD}Target Nodes:${NC}"
    for i in "${!target_hosts[@]}"; do
        printf "  %-30s" "${target_names[$i]} (${target_hosts[$i]}):"
        if health_ssh "${target_hosts[$i]}"; then
            echo -e "${GREEN}OK${NC}"
            ((passed_checks++))
        else
            echo -e "${RED}FAILED${NC}"
            ((failed_checks++))
        fi
        ((total_checks++))
    done

    # 2. Docker Status
    print_section "Docker Status"

    echo -e "${BOLD}Control Node:${NC}"
    printf "  %-30s" "control:"
    if health_docker "$control_ip"; then
        echo -e "${GREEN}RUNNING${NC}"
        ((passed_checks++))
    else
        echo -e "${RED}NOT RUNNING${NC}"
        ((failed_checks++))
    fi
    ((total_checks++))

    echo -e "\n${BOLD}Target Nodes:${NC}"
    for i in "${!target_hosts[@]}"; do
        printf "  %-30s" "${target_names[$i]}:"
        if health_docker "${target_hosts[$i]}"; then
            echo -e "${GREEN}RUNNING${NC}"
            ((passed_checks++))
        else
            echo -e "${RED}NOT RUNNING${NC}"
            ((failed_checks++))
        fi
        ((total_checks++))
    done

    # 3. Control Node Services
    print_section "Control Node Services"
    local services_passed services_failed services_total
    _health_check_control_services "$control_ip"

    # 4. Target Node Agents
    if [[ ${#target_hosts[@]} -gt 0 ]]; then
        print_section "Target Node Agents"

        for i in "${!target_hosts[@]}"; do
            echo -e "${BOLD}${target_names[$i]} (${target_hosts[$i]}):${NC}"

            printf "  %-25s" "Netdata streaming:"
            if health_check_netdata_streaming "${target_hosts[$i]}"; then
                echo -e "${GREEN}CONFIGURED${NC}"
                ((passed_checks++))
            else
                echo -e "${YELLOW}UNKNOWN${NC}"
                ((warnings++))
            fi
            ((total_checks++))

            printf "  %-25s" "Promtail:"
            if health_check_promtail "${target_hosts[$i]}"; then
                echo -e "${GREEN}READY${NC}"
                ((passed_checks++))
            else
                echo -e "${YELLOW}NOT RESPONDING${NC}"
                ((warnings++))
            fi
            ((total_checks++))

            echo
        done
    fi

    # 5. Cross-Node Connectivity
    if [[ ${#target_hosts[@]} -gt 0 ]]; then
        print_section "Cross-Node Connectivity (Docker Socket Proxy)"

        for i in "${!target_hosts[@]}"; do
            printf "  %-30s" "${target_names[$i]}:"
            if health_check_docker_proxy "${target_hosts[$i]}" "$control_ip"; then
                echo -e "${GREEN}ACCESSIBLE${NC}"
                ((passed_checks++))
            else
                echo -e "${YELLOW}NOT ACCESSIBLE${NC}"
                ((warnings++))
            fi
            ((total_checks++))
        done
    fi

    _health_print_validation_summary "$total_checks" "$passed_checks" "$failed_checks" "$warnings"
    return $([[ $failed_checks -eq 0 ]])
}

# Check control node services (helper)
_health_check_control_services() {
    local control_ip="$1"
    local passed=0
    local failed=0

    local -a services=(
        "Traefik API|http://${control_ip}:8080/ping|200"
        "Grafana|http://${control_ip}:3000/api/health|200"
        "Loki|http://${control_ip}:3100/ready|200"
        "Netdata Parent|http://${control_ip}:19999/api/v1/info|200"
        "Uptime Kuma|http://${control_ip}:3001|200 302"
        "Pi-hole|http://${control_ip}:8053/admin/|200 302"
        "Authentik|http://${control_ip}:9000/-/health/ready/|200"
        "Dockge|http://${control_ip}:5001|200 302"
    )

    for service_info in "${services[@]}"; do
        IFS='|' read -r name url expected_codes <<< "$service_info"
        printf "  %-20s" "$name:"

        local status_code
        status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")

        if [[ "$expected_codes" == *"$status_code"* ]]; then
            echo -e "${GREEN}HTTP $status_code${NC}"
            ((passed++))
        else
            echo -e "${RED}HTTP $status_code${NC}"
            ((failed++))
        fi
    done

    echo
    echo "  Services: ${passed}/$((passed + failed)) responding"
    return $([[ $failed -eq 0 ]])
}

# Print validation summary (helper)
_health_print_validation_summary() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local warnings="$4"

    echo
    print_section "Validation Summary"
    echo "  Total Checks:  $total"
    echo -e "  ${GREEN}Passed:${NC}        $passed"
    echo -e "  ${RED}Failed:${NC}        $failed"
    echo -e "  ${YELLOW}Warnings:${NC}      $warnings"
    echo

    if [[ $failed -eq 0 ]]; then
        print_success "All critical checks passed!"
    else
        print_error "Some checks failed - review above for details"
    fi

    if [[ $warnings -gt 0 ]]; then
        print_warning "There are warnings that may need attention"
    fi
}
