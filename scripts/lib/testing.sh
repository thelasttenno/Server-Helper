#!/usr/bin/env bash
# =============================================================================
# testing.sh — Molecule test runner
# =============================================================================

testing_menu() {
    while true; do
        clear
        print_header "Testing"
        echo ""
        echo "  ${CYAN}1)${NC}  Test all roles"
        echo "  ${CYAN}2)${NC}  Test specific role"
        echo "  ${CYAN}3)${NC}  Syntax check only"
        echo "  ${CYAN}4)${NC}  Lint check"
        echo "  ${CYAN}0)${NC}  Back"
        echo ""
        echo -n "  Select option: "
        local choice
        read -r choice
        case $choice in
            1) test_all_roles ;;
            2)
                local role
                role=$(prompt_input "Role name")
                test_role "$role"
                ;;
            3) log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/site.yml' --syntax-check" ;;
            4) log_exec "yamllint -c '$PROJECT_ROOT/.yamllint' '$PROJECT_ROOT/'" ;;
            0) return ;;
            *) print_error "Invalid option" ; sleep 1 ;;
        esac

        echo ""
        echo "  Press Enter to continue..."
        read -r
    done
}

test_all_roles() {
    print_header "Testing All Roles"
    check_molecule_deps
    local roles_dir="$PROJECT_ROOT/roles"
    local passed=0 failed=0 skipped=0
    for role_dir in "$roles_dir"/*/; do
        local role_name
        role_name=$(basename "$role_dir")
        if [[ -d "$role_dir/molecule" ]]; then
            print_step "Testing: $role_name"
            if (cd "$role_dir" && molecule test 2>&1); then
                print_success "$role_name — PASSED"
                ((passed++))
            else
                print_error "$role_name — FAILED"
                ((failed++))
            fi
        else
            print_warning "$role_name — No molecule tests (skipped)"
            ((skipped++))
        fi
    done
    echo ""
    print_info "Results: $passed passed, $failed failed, $skipped skipped"
}

test_role() {
    local role="$1"
    local role_dir="$PROJECT_ROOT/roles/$role"
    if [[ ! -d "$role_dir" ]]; then
        print_error "Role not found: $role"
        return 1
    fi
    if [[ ! -d "$role_dir/molecule" ]]; then
        print_warning "No molecule tests for $role"
        return 1
    fi
    check_molecule_deps
    print_step "Testing role: $role"
    (cd "$role_dir" && molecule test)
}

check_molecule_deps() {
    if ! command -v molecule >/dev/null 2>&1; then
        print_error "molecule not installed"
        if confirm "Install molecule?"; then
            log_exec "pip3 install molecule molecule-plugins[docker]"
        else
            return 1
        fi
    fi
}
