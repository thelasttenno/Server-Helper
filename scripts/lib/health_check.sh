#!/usr/bin/env bash
# =============================================================================
# health_check.sh — SSH connectivity, Docker daemon, disk/memory checks
# =============================================================================

# =============================================================================
# FULL HEALTH CHECK
# =============================================================================
run_health_check() {
    print_header "Fleet Health Check"
    echo ""

    check_ssh_connectivity
    echo ""
    check_docker_status
    echo ""
    check_disk_space
    echo ""
    check_memory
    echo ""

    print_success "Health check complete"
}

# =============================================================================
# SSH CONNECTIVITY
# =============================================================================
check_ssh_connectivity() {
    print_info "SSH Connectivity:"

    local result
    result=$(ansible -i "$PROJECT_ROOT/inventory/hosts.yml" all -m ping -o 2>/dev/null || true)

    echo "$result" | while IFS= read -r line; do
        if echo "$line" | grep -q "SUCCESS"; then
            local host
            host=$(echo "$line" | awk '{print $1}')
            print_success "$host — reachable"
        elif echo "$line" | grep -q "UNREACHABLE"; then
            local host
            host=$(echo "$line" | awk '{print $1}')
            print_error "$host — unreachable"
        fi
    done
}

# =============================================================================
# DOCKER STATUS
# =============================================================================
check_docker_status() {
    print_info "Docker Daemon Status:"

    ansible -i "$PROJECT_ROOT/inventory/hosts.yml" all \
        -m command -a "systemctl is-active docker" \
        -o 2>/dev/null | while IFS= read -r line; do
        local host status
        host=$(echo "$line" | awk '{print $1}')
        if echo "$line" | grep -q "active"; then
            print_success "$host — Docker active"
        else
            print_error "$host — Docker inactive"
        fi
    done
}

# =============================================================================
# DISK SPACE
# =============================================================================
check_disk_space() {
    print_info "Disk Space (root partition):"

    ansible -i "$PROJECT_ROOT/inventory/hosts.yml" all \
        -m command -a "df -h / --output=pcent,avail" \
        -o 2>/dev/null | while IFS= read -r line; do
        local host
        host=$(echo "$line" | awk '{print $1}')
        local usage
        usage=$(echo "$line" | grep -oP '\d+%' | head -1 || echo "N/A")
        local used_num=${usage%%%}

        if [[ "$used_num" -gt 90 ]]; then
            print_error "$host — ${usage} used (CRITICAL)"
        elif [[ "$used_num" -gt 80 ]]; then
            print_warning "$host — ${usage} used (WARNING)"
        else
            print_success "$host — ${usage} used"
        fi
    done
}

# =============================================================================
# MEMORY
# =============================================================================
check_memory() {
    print_info "Memory Usage:"

    ansible -i "$PROJECT_ROOT/inventory/hosts.yml" all \
        -m command -a "free -m" \
        -o 2>/dev/null | while IFS= read -r line; do
        local host
        host=$(echo "$line" | awk '{print $1}')
        local mem_info
        mem_info=$(echo "$line" | grep -oP 'Mem:\s+\K\d+' | head -1 || echo "")
        if [[ -n "$mem_info" ]]; then
            print_success "$host — ${mem_info}MB total"
        fi
    done
}

# =============================================================================
# VALIDATE FLEET (comprehensive)
# =============================================================================
validate_fleet() {
    print_header "Fleet Validation"
    echo ""

    run_health_check

    echo ""
    print_info "Service Health (control node):"
    ansible -i "$PROJECT_ROOT/inventory/hosts.yml" control \
        -m uri \
        -a "url=http://localhost:3000/api/health method=GET timeout=5" \
        -o 2>/dev/null && print_success "Grafana — healthy" || print_warning "Grafana — check required"

    ansible -i "$PROJECT_ROOT/inventory/hosts.yml" control \
        -m uri \
        -a "url=http://localhost:3100/ready method=GET timeout=5" \
        -o 2>/dev/null && print_success "Loki — healthy" || print_warning "Loki — check required"
}
