#!/usr/bin/env bash
# =============================================================================
# inventory_mgr.sh — Parse, add/remove hosts, validate inventory
# =============================================================================

INVENTORY_FILE="$PROJECT_ROOT/inventory/hosts.yml"

# =============================================================================
# LIST HOSTS
# =============================================================================
list_inventory() {
    print_header "Current Inventory"

    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found: $INVENTORY_FILE"
        return 1
    fi

    echo ""
    print_info "Control nodes:"
    python3 -c "
import yaml
with open('$INVENTORY_FILE') as f:
    data = yaml.safe_load(f)
control = data.get('all', {}).get('children', {}).get('control', {}).get('hosts', {})
for host, vars in (control or {}).items():
    ip = (vars or {}).get('ansible_host', 'N/A')
    print(f'    {host} → {ip}')
" 2>/dev/null

    echo ""
    print_info "Target nodes:"
    python3 -c "
import yaml
with open('$INVENTORY_FILE') as f:
    data = yaml.safe_load(f)
targets = data.get('all', {}).get('children', {}).get('targets', {}).get('hosts', {})
for host, vars in (targets or {}).items():
    ip = (vars or {}).get('ansible_host', 'N/A')
    print(f'    {host} → {ip}')
" 2>/dev/null
}

# =============================================================================
# ADD HOST
# =============================================================================
add_host() {
    local hostname ip group

    hostname=$(prompt_input "Hostname")
    ip=$(prompt_input "IP address")
    group=$(prompt_input "Group (control/targets)" "targets")

    if [[ "$group" != "control" && "$group" != "targets" ]]; then
        print_error "Invalid group. Must be 'control' or 'targets'."
        return 1
    fi

    print_step "Adding $hostname ($ip) to $group..."

    python3 -c "
import yaml
with open('$INVENTORY_FILE') as f:
    data = yaml.safe_load(f)
hosts = data['all']['children']['$group'].setdefault('hosts', {})
hosts['$hostname'] = {'ansible_host': '$ip'}
with open('$INVENTORY_FILE', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
" 2>/dev/null

    print_success "Added $hostname to inventory"

    if [[ "$group" == "targets" ]]; then
        if confirm "Bootstrap this host now?"; then
            log_exec "ansible-playbook -i '$INVENTORY_FILE' '$PROJECT_ROOT/playbooks/add-target.yml' --limit '$hostname'"
        fi
    fi
}

# =============================================================================
# REMOVE HOST
# =============================================================================
remove_host() {
    local hostname
    hostname=$(prompt_input "Hostname to remove")

    if ! confirm "Remove $hostname from inventory?"; then
        return
    fi

    python3 -c "
import yaml
with open('$INVENTORY_FILE') as f:
    data = yaml.safe_load(f)
for group in ['control', 'targets']:
    hosts = data['all']['children'][group].get('hosts', {})
    if '$hostname' in hosts:
        del hosts['$hostname']
        print(f'Removed from {group}')
with open('$INVENTORY_FILE', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
" 2>/dev/null

    print_success "Removed $hostname from inventory"
}

# =============================================================================
# VALIDATE INVENTORY
# =============================================================================
validate_inventory() {
    print_header "Inventory Validation"

    if [[ ! -f "$INVENTORY_FILE" ]]; then
        print_error "Inventory file not found"
        return 1
    fi

    # YAML validity
    if python3 -c "import yaml; yaml.safe_load(open('$INVENTORY_FILE'))" 2>/dev/null; then
        print_success "YAML syntax valid"
    else
        print_error "YAML syntax invalid"
        return 1
    fi

    # Required groups
    python3 -c "
import yaml
with open('$INVENTORY_FILE') as f:
    data = yaml.safe_load(f)
children = data.get('all', {}).get('children', {})
for group in ['control', 'targets']:
    if group in children:
        hosts = children[group].get('hosts', {})
        count = len(hosts) if hosts else 0
        print(f'  ✓ Group \"{group}\": {count} hosts')
    else:
        print(f'  ✗ Group \"{group}\": MISSING')
" 2>/dev/null
}

# =============================================================================
# FLEET MANAGEMENT MENU
# =============================================================================
fleet_management_menu() {
    clear
    print_header "Fleet Management"
    echo ""
    echo "  ${CYAN}1)${NC}  List inventory"
    echo "  ${CYAN}2)${NC}  Add host"
    echo "  ${CYAN}3)${NC}  Remove host"
    echo "  ${CYAN}4)${NC}  Validate inventory"
    echo "  ${CYAN}5)${NC}  Ping all hosts"
    echo "  ${CYAN}6)${NC}  Docker status (all hosts)"
    echo "  ${CYAN}0)${NC}  Back"
    echo ""
    echo -n "  Select option: "

    local choice
    read -r choice
    case $choice in
        1) list_inventory ;;
        2) add_host ;;
        3) remove_host ;;
        4) validate_inventory ;;
        5) log_exec "ansible -i '$INVENTORY_FILE' all -m ping" ;;
        6) log_exec "ansible -i '$INVENTORY_FILE' all -m command -a 'docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\"'" ;;
        0) return ;;
    esac
}
