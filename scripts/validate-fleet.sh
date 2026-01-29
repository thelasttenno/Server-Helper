#!/usr/bin/env bash
#
# Server Helper - Fleet Validation Script
# ========================================
# Validates connectivity and health across all managed nodes.
#
# Checks performed:
#   - SSH connectivity to all nodes
#   - Docker daemon status on all nodes
#   - Control node service health (Traefik, Grafana, Loki, etc.)
#   - Target node agent connectivity (Netdata streaming, Promtail)
#   - Docker Socket Proxy accessibility from control node
#
# Usage:
#   ./scripts/validate-fleet.sh              # Full validation
#   ./scripts/validate-fleet.sh --quick      # Quick ping test only
#   ./scripts/validate-fleet.sh --services   # Control services only
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
INVENTORY_FILE="${PROJECT_DIR}/inventory/hosts.yml"
CONFIG_FILE="${PROJECT_DIR}/group_vars/all.yml"

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Parse command line arguments
QUICK_MODE=false
SERVICES_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --services|-s)
            SERVICES_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --quick, -q      Quick ping test only"
            echo "  --services, -s   Control services health check only"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Output functions
print_header() {
    echo -e "\n${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║            Server Helper Fleet Validation                   ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

check_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
    ((TOTAL_CHECKS++))
}

check_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

# Parse inventory to get hosts
parse_inventory() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        echo "ERROR: Inventory file not found: $INVENTORY_FILE"
        exit 1
    fi

    # Extract control node
    CONTROL_HOST=$(grep -A1 "control:" "$INVENTORY_FILE" 2>/dev/null | grep "ansible_host:" | head -1 | awk '{print $2}' || echo "")

    # Extract target nodes
    TARGET_HOSTS=()
    TARGET_NAMES=()

    local in_targets=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*targets: ]]; then
            in_targets=true
            continue
        fi
        if [[ "$in_targets" == true ]]; then
            if [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+): ]]; then
                TARGET_NAMES+=("${BASH_REMATCH[1]}")
            fi
            if [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
                TARGET_HOSTS+=("${BASH_REMATCH[1]}")
            fi
            # Exit targets section
            if [[ "$line" =~ ^[[:space:]]{0,2}[a-z]+: ]] && [[ ! "$line" =~ ansible_ ]] && [[ ! "$line" =~ hosts: ]]; then
                in_targets=false
            fi
        fi
    done < "$INVENTORY_FILE"
}

# Get control node IP from config
get_control_ip() {
    if [[ -f "$CONFIG_FILE" ]]; then
        CONTROL_IP=$(grep "control_node_ip:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}' | tr -d '"' || echo "")
    fi
    CONTROL_IP="${CONTROL_IP:-$CONTROL_HOST}"
}

# Check SSH connectivity
check_ssh() {
    local host=$1
    local name=$2

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$host" "echo ok" &>/dev/null; then
        check_pass "$name ($host): SSH OK"
        return 0
    else
        check_fail "$name ($host): SSH FAILED"
        return 1
    fi
}

# Check if Docker is running
check_docker() {
    local host=$1
    local name=$2

    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$host" "docker info &>/dev/null" &>/dev/null; then
        check_pass "$name: Docker running"
        return 0
    else
        check_fail "$name: Docker NOT running"
        return 1
    fi
}

# Check HTTP endpoint
check_http() {
    local url=$1
    local name=$2
    local expected_codes=${3:-200}

    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null || echo "000")

    if [[ "$expected_codes" == *"$status_code"* ]]; then
        check_pass "$name: HTTP $status_code"
        return 0
    else
        check_fail "$name: HTTP $status_code (expected $expected_codes)"
        return 1
    fi
}

# Check Docker Socket Proxy from control
check_docker_proxy() {
    local target_host=$1
    local target_name=$2

    # Check if control can reach target's Docker proxy
    local result
    result=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$CONTROL_IP" \
        "curl -s --connect-timeout 3 http://${target_host}:2375/_ping" 2>/dev/null || echo "failed")

    if [[ "$result" == "OK" ]]; then
        check_pass "$target_name: Docker Socket Proxy accessible from control"
        return 0
    else
        check_warn "$target_name: Docker Socket Proxy not accessible (may not be deployed yet)"
        return 1
    fi
}

# Check Netdata streaming
check_netdata_streaming() {
    local target_host=$1
    local target_name=$2

    # Check if target's Netdata is streaming to parent
    local result
    result=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$target_host" \
        "curl -s --connect-timeout 3 http://localhost:19999/api/v1/info 2>/dev/null | grep -q 'streaming' && echo 'streaming'" 2>/dev/null || echo "")

    if [[ -n "$result" ]]; then
        check_pass "$target_name: Netdata streaming configured"
    else
        check_warn "$target_name: Netdata streaming status unknown"
    fi
}

# Check Promtail connectivity
check_promtail() {
    local target_host=$1
    local target_name=$2

    local result
    result=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$target_host" \
        "curl -s --connect-timeout 3 http://localhost:9080/ready" 2>/dev/null || echo "")

    if [[ "$result" == "Ready" ]]; then
        check_pass "$target_name: Promtail ready"
    else
        check_warn "$target_name: Promtail not responding"
    fi
}

# Main validation
main() {
    print_header

    # Parse inventory
    echo -e "${BLUE}Loading inventory...${NC}"
    parse_inventory
    get_control_ip

    if [[ -z "$CONTROL_IP" ]]; then
        echo -e "${RED}ERROR: Could not determine control node IP${NC}"
        exit 1
    fi

    echo -e "  Control Node: ${CONTROL_IP}"
    echo -e "  Target Nodes: ${#TARGET_HOSTS[@]}"

    # Quick mode - just ping
    if [[ "$QUICK_MODE" == true ]]; then
        print_section "Quick Connectivity Test"

        echo -e "${BOLD}Control Node:${NC}"
        ping -c 1 -W 2 "$CONTROL_IP" &>/dev/null && check_pass "Control ($CONTROL_IP): Ping OK" || check_fail "Control ($CONTROL_IP): Ping FAILED"

        echo -e "\n${BOLD}Target Nodes:${NC}"
        for i in "${!TARGET_HOSTS[@]}"; do
            ping -c 1 -W 2 "${TARGET_HOSTS[$i]}" &>/dev/null && check_pass "${TARGET_NAMES[$i]} (${TARGET_HOSTS[$i]}): Ping OK" || check_fail "${TARGET_NAMES[$i]} (${TARGET_HOSTS[$i]}): Ping FAILED"
        done

        print_summary
        exit 0
    fi

    # Services only mode
    if [[ "$SERVICES_ONLY" == true ]]; then
        print_section "Control Node Services"

        check_http "http://${CONTROL_IP}:8080/ping" "Traefik API" "200"
        check_http "http://${CONTROL_IP}:3000/api/health" "Grafana" "200"
        check_http "http://${CONTROL_IP}:3100/ready" "Loki" "200"
        check_http "http://${CONTROL_IP}:19999/api/v1/info" "Netdata Parent" "200"
        check_http "http://${CONTROL_IP}:3001" "Uptime Kuma" "200 302"
        check_http "http://${CONTROL_IP}:8053/admin/" "Pi-hole" "200 302"
        check_http "http://${CONTROL_IP}:9000/-/health/ready/" "Authentik" "200"
        check_http "http://${CONTROL_IP}:5001" "Dockge" "200 302"

        print_summary
        exit 0
    fi

    # Full validation

    # 1. SSH Connectivity
    print_section "SSH Connectivity"

    echo -e "${BOLD}Control Node:${NC}"
    check_ssh "$CONTROL_IP" "control"

    echo -e "\n${BOLD}Target Nodes:${NC}"
    for i in "${!TARGET_HOSTS[@]}"; do
        check_ssh "${TARGET_HOSTS[$i]}" "${TARGET_NAMES[$i]}"
    done

    # 2. Docker Status
    print_section "Docker Status"

    echo -e "${BOLD}Control Node:${NC}"
    check_docker "$CONTROL_IP" "control"

    echo -e "\n${BOLD}Target Nodes:${NC}"
    for i in "${!TARGET_HOSTS[@]}"; do
        check_docker "${TARGET_HOSTS[$i]}" "${TARGET_NAMES[$i]}"
    done

    # 3. Control Node Services
    print_section "Control Node Services"

    check_http "http://${CONTROL_IP}:8080/ping" "Traefik API" "200"
    check_http "http://${CONTROL_IP}:3000/api/health" "Grafana" "200"
    check_http "http://${CONTROL_IP}:3100/ready" "Loki" "200"
    check_http "http://${CONTROL_IP}:19999/api/v1/info" "Netdata Parent" "200"
    check_http "http://${CONTROL_IP}:3001" "Uptime Kuma" "200 302"
    check_http "http://${CONTROL_IP}:8053/admin/" "Pi-hole" "200 302"
    check_http "http://${CONTROL_IP}:9000/-/health/ready/" "Authentik" "200"
    check_http "http://${CONTROL_IP}:5001" "Dockge" "200 302"

    # 4. Target Node Agents
    if [[ ${#TARGET_HOSTS[@]} -gt 0 ]]; then
        print_section "Target Node Agents"

        for i in "${!TARGET_HOSTS[@]}"; do
            echo -e "${BOLD}${TARGET_NAMES[$i]} (${TARGET_HOSTS[$i]}):${NC}"
            check_netdata_streaming "${TARGET_HOSTS[$i]}" "${TARGET_NAMES[$i]}"
            check_promtail "${TARGET_HOSTS[$i]}" "${TARGET_NAMES[$i]}"
            echo ""
        done
    fi

    # 5. Cross-Node Connectivity (Docker Socket Proxy)
    if [[ ${#TARGET_HOSTS[@]} -gt 0 ]]; then
        print_section "Cross-Node Connectivity (Docker Socket Proxy)"

        for i in "${!TARGET_HOSTS[@]}"; do
            check_docker_proxy "${TARGET_HOSTS[$i]}" "${TARGET_NAMES[$i]}"
        done
    fi

    print_summary
}

# Print summary
print_summary() {
    echo -e "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  VALIDATION SUMMARY${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo -e "  Total Checks:  ${TOTAL_CHECKS}"
    echo -e "  ${GREEN}Passed:${NC}        ${PASSED_CHECKS}"
    echo -e "  ${RED}Failed:${NC}        ${FAILED_CHECKS}"
    echo -e "  ${YELLOW}Warnings:${NC}      ${WARNINGS}"
    echo ""

    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "  ${GREEN}${BOLD}✓ All critical checks passed!${NC}"
    else
        echo -e "  ${RED}${BOLD}✗ Some checks failed - review above for details${NC}"
    fi

    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "  ${YELLOW}⚠ There are warnings that may need attention${NC}"
    fi

    echo ""
}

# Run main
main "$@"
