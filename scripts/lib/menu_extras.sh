#!/usr/bin/env bash
# =============================================================================
# menu_extras.sh — Extras menu: open UIs, validate fleet, etc.
# =============================================================================

open_service_ui() {
    local domain
    domain=$(yaml_read "$PROJECT_ROOT/group_vars/all.yml" "target_domain" 2>/dev/null || echo "example.com")
    print_header "Service URLs"
    echo ""
    echo "  Traefik:     https://traefik.$domain"
    echo "  Grafana:     https://grafana.$domain"
    echo "  Netdata:     https://netdata.$domain"
    echo "  Uptime Kuma: https://status.$domain"
    echo "  Pi-hole:     https://pihole.$domain"
    echo "  Authentik:   https://auth.$domain"
    echo "  Step-CA:     https://step-ca.$domain"
    echo "  Dockge:      https://dockge.$domain"
}

extras_menu() {
    while true; do
        clear
        print_header "Extras"
        echo ""
        echo "  ${CYAN}1)${NC}  Add new server"
        echo "  ${CYAN}2)${NC}  Open service UIs"
        echo "  ${CYAN}3)${NC}  Validate fleet"
        echo "  ${CYAN}4)${NC}  Run linting"
        echo "  ${CYAN}5)${NC}  View project version"
        echo "  ${CYAN}6)${NC}  Ansible Galaxy install"
        echo "  ${CYAN}0)${NC}  Back"
        echo ""
        echo -n "  Select option: "

        local choice
        read -r choice
        case $choice in
            1) add_host ;;
            2) open_service_ui ;;
            3) validate_fleet ;;
            4) log_exec "ansible-lint '$PROJECT_ROOT/playbooks/'" ;;
            5) print_info "Server Helper v$(cat "$PROJECT_ROOT/VERSION")" ;;
            6) log_exec "ansible-galaxy collection install -r '$PROJECT_ROOT/requirements.yml' --force" ;;
            0) return ;;
            *) print_error "Invalid option" ; sleep 1 ;;
        esac

        echo ""
        echo "  Press Enter to continue..."
        read -r
    done
}
