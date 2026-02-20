#!/usr/bin/env bash
# =============================================================================
# vault_mgr.sh — Ansible Vault operations (encrypt/edit/view/rekey)
# =============================================================================

VAULT_FILE="$PROJECT_ROOT/group_vars/vault.yml"

# =============================================================================
# VAULT OPERATIONS
# =============================================================================
vault_encrypt() {
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "vault.yml not found"
        return 1
    fi

    if head -1 "$VAULT_FILE" | grep -q '$ANSIBLE_VAULT'; then
        print_info "Vault is already encrypted"
        return 0
    fi

    print_step "Encrypting vault..."
    ansible-vault encrypt "$VAULT_FILE"
    print_success "Vault encrypted"
}

vault_edit() {
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "vault.yml not found"
        return 1
    fi

    print_step "Opening vault for editing..."
    ansible-vault edit "$VAULT_FILE"
    print_success "Vault saved"
}

vault_view() {
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "vault.yml not found"
        return 1
    fi

    if head -1 "$VAULT_FILE" | grep -q '$ANSIBLE_VAULT'; then
        ansible-vault view "$VAULT_FILE"
    else
        print_warning "Vault is not encrypted — showing raw content"
        cat "$VAULT_FILE"
    fi
}

vault_rekey() {
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "vault.yml not found"
        return 1
    fi

    print_step "Re-keying vault..."
    ansible-vault rekey "$VAULT_FILE"
    print_success "Vault re-keyed with new password"
}

vault_validate() {
    if [[ ! -f "$VAULT_FILE" ]]; then
        print_error "vault.yml not found"
        return 1
    fi

    print_step "Validating vault..."

    # Check file permissions
    local perms
    perms=$(stat -c '%a' "$VAULT_FILE" 2>/dev/null || stat -f '%Lp' "$VAULT_FILE" 2>/dev/null)
    if [[ "$perms" == "600" ]]; then
        print_success "File permissions: $perms (correct)"
    else
        print_warning "File permissions: $perms (should be 600)"
    fi

    # Check encryption status
    if head -1 "$VAULT_FILE" | grep -q '$ANSIBLE_VAULT'; then
        print_success "Encryption: Active"

        # Try to decrypt and validate structure
        local tmpdir
        tmpdir=$(get_secure_tmpdir)
        if ansible-vault decrypt --output "$tmpdir/vault_check.yml" "$VAULT_FILE" 2>/dev/null; then
            print_success "Decryption: Successful"

            # Check required keys exist
            local required_keys=(
                "vault_restic_credentials"
                "vault_authentik_credentials"
                "vault_grafana_credentials"
                "vault_step_ca_credentials"
                "vault_pihole_password"
                "vault_netdata_stream_api_key"
                "vault_system_users"
            )
            for key in "${required_keys[@]}"; do
                if grep -q "$key" "$tmpdir/vault_check.yml"; then
                    print_success "  Key present: $key"
                else
                    print_warning "  Key MISSING: $key"
                fi
            done

            rm -f "$tmpdir/vault_check.yml"
        else
            print_error "Decryption: Failed (wrong password?)"
        fi
    else
        print_warning "Encryption: NOT encrypted"
    fi
}

# =============================================================================
# VAULT INTERACTIVE MENU
# =============================================================================
vault_menu() {
    while true; do
        clear
        print_header "Vault Operations"
        echo ""
        echo "  ${CYAN}1)${NC}  Encrypt vault"
        echo "  ${CYAN}2)${NC}  Edit vault"
        echo "  ${CYAN}3)${NC}  View vault"
        echo "  ${CYAN}4)${NC}  Re-key vault"
        echo "  ${CYAN}5)${NC}  Validate vault"
        echo "  ${CYAN}0)${NC}  Back"
        echo ""
        echo -n "  Select option: "

        local choice
        read -r choice
        case $choice in
            1) vault_encrypt ;;
            2) vault_edit ;;
            3) vault_view ;;
            4) vault_rekey ;;
            5) vault_validate ;;
            0) return ;;
            *) print_error "Invalid option" ; sleep 1 ;;
        esac

        echo ""
        echo "  Press Enter to continue..."
        read -r
    done
}
