#!/usr/bin/env bash
# =============================================================================
# upgrade.sh — Docker image upgrades per-service
# =============================================================================

upgrade_menu() {
    while true; do
        clear
        print_header "Docker Image Upgrades"
        echo ""
        echo "  ${CYAN}1)${NC}  Upgrade all services (rolling)"
        echo "  ${CYAN}2)${NC}  Upgrade specific service"
        echo "  ${CYAN}3)${NC}  Cleanup unused images"
        echo "  ${CYAN}0)${NC}  Back"
        echo ""
        echo -n "  Select option: "
        local choice
        read -r choice
        case $choice in
            1) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/upgrade.yml'" ;;
            2)
                local service
                service=$(prompt_input "Service name (e.g. grafana)")
                log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/upgrade.yml' -e 'target_service=$service'"
                ;;
            3) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/upgrade.yml' --tags cleanup" ;;
            0) return ;;
            *) print_error "Invalid option" ; sleep 1 ;;
        esac

        echo ""
        echo "  Press Enter to continue..."
        read -r
    done
}
