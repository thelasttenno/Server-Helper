#!/usr/bin/env bash
# =============================================================================
# secrets_mgr.sh — Server Helper v0.4.0 Secrets Managementeractive prompts, vault generation
# =============================================================================

# =============================================================================
# GENERATE SECURE PASSWORD (256-bit hex by default)
# =============================================================================
generate_password() {
    local length="${1:-64}"
    openssl rand -hex "$((length / 2))" 2>/dev/null || \
        python3 -c "import secrets; print(secrets.token_hex($((length / 2))))"
}

generate_uuid() {
    python3 -c "import uuid; print(uuid.uuid4())"
}

# =============================================================================
# GENERATE SECRETS — fresh or idempotent mode
# =============================================================================
generate_secrets() {
    local mode="${1:-idempotent}"  # "fresh" or "idempotent"
    local vault_file="$PROJECT_ROOT/group_vars/vault.yml"
    local vault_example="$PROJECT_ROOT/group_vars/vault.example.yml"

    print_header "Secrets Generation ($mode mode)"
    echo ""

    if [[ "$mode" == "fresh" ]]; then
        print_warning "FRESH mode will regenerate ALL secrets!"
        if ! confirm "Continue?"; then
            return
        fi
    fi

    # Check if vault.yml exists for idempotent mode
    local existing_secrets=""
    if [[ "$mode" == "idempotent" && -f "$vault_file" ]]; then
        # Try to decrypt if encrypted
        if head -1 "$vault_file" | grep -q '$ANSIBLE_VAULT'; then
            print_info "Vault is encrypted. Decrypting to check existing secrets..."
            local tmpdir
            tmpdir=$(get_secure_tmpdir)
            if ansible-vault decrypt --output "$tmpdir/vault_plain.yml" "$vault_file" 2>/dev/null; then
                existing_secrets=$(cat "$tmpdir/vault_plain.yml")
            else
                print_error "Could not decrypt vault. Generating as fresh."
                mode="fresh"
            fi
        else
            existing_secrets=$(cat "$vault_file")
        fi
    fi

    # Generate all secrets
    local restic_pw authentik_secret authentik_bootstrap authentik_pg authentik_redis
    local grafana_admin grafana_secret step_ca_pw pihole_pw netdata_stream
    local traefik_user traefik_pw admin_pw

    print_step "Generating passwords..."

    restic_pw=$(get_or_generate "vault_restic_credentials.password" "$existing_secrets" "$mode")
    authentik_secret=$(get_or_generate "vault_authentik_credentials.secret_key" "$existing_secrets" "$mode")
    authentik_bootstrap=$(get_or_generate "vault_authentik_credentials.bootstrap_password" "$existing_secrets" "$mode" 32)
    authentik_pg=$(get_or_generate "vault_authentik_credentials.postgres_password" "$existing_secrets" "$mode")
    authentik_redis=$(get_or_generate "vault_authentik_credentials.redis_password" "$existing_secrets" "$mode")
    grafana_admin=$(get_or_generate "vault_grafana_credentials.admin_password" "$existing_secrets" "$mode" 32)
    grafana_secret=$(get_or_generate "vault_grafana_credentials.secret_key" "$existing_secrets" "$mode")
    step_ca_pw=$(get_or_generate "vault_step_ca_credentials.password" "$existing_secrets" "$mode" 32)
    pihole_pw=$(get_or_generate "vault_pihole_password" "$existing_secrets" "$mode" 32)
    netdata_stream=$(get_or_generate "vault_netdata_stream_api_key" "$existing_secrets" "$mode" "uuid")
    traefik_pw=$(get_or_generate "vault_traefik_dashboard.password" "$existing_secrets" "$mode" 32)
    admin_pw=$(get_or_generate "vault_system_users.admin_password" "$existing_secrets" "$mode" 32)

    # Interactive prompts for external service credentials
    echo ""
    local netdata_claim_token="" netdata_claim_room=""
    if confirm "Configure Netdata Cloud (optional)?"; then
        netdata_claim_token=$(prompt_secret "  Netdata claim token")
        netdata_claim_room=$(prompt_input "  Netdata claim room")
    fi

    # Write vault file to secure tmpdir first, then move to final path
    print_step "Writing vault file..."
    local secure_dir
    secure_dir=$(get_secure_tmpdir)
    local tmp_vault="$secure_dir/vault_new.yml"
    cat > "$tmp_vault" << VAULT
---
# =============================================================================
# Server Helper v2.0 — Ansible Vault Secrets
# =============================================================================
# ENCRYPT THIS FILE: ansible-vault encrypt group_vars/vault.yml

# TIER 1: Foundation
vault_restic_credentials:
  password: "$restic_pw"

# TIER 2: Target Agents
vault_netdata_credentials:
  claim_token: "${netdata_claim_token}"
  claim_room: "${netdata_claim_room}"
vault_netdata_stream_api_key: "$netdata_stream"

# TIER 3: Control - Critical
vault_authentik_credentials:
  secret_key: "$authentik_secret"
  bootstrap_password: "$authentik_bootstrap"
  postgres_password: "$authentik_pg"
  redis_password: "$authentik_redis"
vault_grafana_credentials:
  admin_password: "$grafana_admin"
  secret_key: "$grafana_secret"
vault_step_ca_credentials:
  password: "$step_ca_pw"
vault_traefik_dashboard:
  username: "admin"
  password: "$traefik_pw"
vault_pihole_password: "$pihole_pw"

# TIER 3: Control - Integration (configure after initial deploy)
vault_grafana_oidc:
  client_id: ""
  client_secret: ""
vault_uptime_kuma_credentials:
  username: "admin"
  password: ""
vault_uptime_kuma_push_urls:
  nas: ""
  dockge: ""
  system: ""
  backup: ""
  security: ""
  update: ""

# Notifications (optional)
vault_smtp_credentials:
  host: ""
  port: 587
  username: ""
  password: ""
  from: ""
  to: []
vault_discord_webhook: ""
vault_telegram_credentials:
  bot_token: ""
  chat_id: ""
vault_slack_webhook: ""

# System
vault_system_users:
  admin_password: "$admin_pw"
  admin_ssh_key: ""
VAULT

    chmod 600 "$tmp_vault"

    # Unset plaintext secrets from shell memory
    unset existing_secrets 2>/dev/null || true

    # Encrypt and move to final path
    echo ""
    if confirm "Encrypt vault now?"; then
        # Ensure vault password file exists
        local vault_pw_file="$PROJECT_ROOT/.vault_password"
        if [[ ! -f "$vault_pw_file" ]]; then
            print_warning "No vault password file found at $vault_pw_file"
            echo ""
            if confirm "Generate a random vault password?"; then
                openssl rand -hex 32 > "$vault_pw_file"
                chmod 600 "$vault_pw_file"
                print_success "Vault password generated and saved to .vault_password"
                print_warning "Back up this file! If you lose it, you cannot decrypt your vault."
            else
                local vault_pw
                vault_pw=$(prompt_secret "Enter vault password")
                echo "$vault_pw" > "$vault_pw_file"
                chmod 600 "$vault_pw_file"
                print_success "Vault password saved to .vault_password"
            fi
        fi

        ansible-vault encrypt "$tmp_vault" && \
            mv -f "$tmp_vault" "$vault_file" && \
            chmod 600 "$vault_file" && \
            print_success "Vault encrypted and saved: $vault_file"
    else
        mv -f "$tmp_vault" "$vault_file"
        chmod 600 "$vault_file"
        print_success "Vault file generated: $vault_file"
        print_warning "Remember to encrypt before committing: ansible-vault encrypt group_vars/vault.yml"
    fi
}

# =============================================================================
# HELPER: Get existing value or generate new
# =============================================================================
get_or_generate() {
    local key="$1"
    local existing="$2"
    local mode="$3"
    local length_or_type="${4:-64}"

    # In fresh mode, always generate
    if [[ "$mode" == "fresh" ]]; then
        if [[ "$length_or_type" == "uuid" ]]; then
            generate_uuid
        else
            generate_password "$length_or_type"
        fi
        return
    fi

    # In idempotent mode, try to extract existing
    if [[ -n "$existing" ]]; then
        local existing_val
        existing_val=$(echo "$existing" | python3 -c "
import yaml, sys
data = yaml.safe_load(sys.stdin)
keys = '$key'.split('.')
val = data
for k in keys:
    if val is None or not isinstance(val, dict):
        val = None
        break
    val = val.get(k)
if val and str(val).strip():
    print(val)
" 2>/dev/null)
        if [[ -n "$existing_val" ]]; then
            echo "$existing_val"
            return
        fi
    fi

    # Generate new
    if [[ "$length_or_type" == "uuid" ]]; then
        generate_uuid
    else
        generate_password "$length_or_type"
    fi
}

# =============================================================================
# PRE-FLIGHT VALIDATION
# =============================================================================
validate_secrets() {
    local vault_file="$PROJECT_ROOT/group_vars/vault.yml"

    if [[ ! -f "$vault_file" ]]; then
        print_error "vault.yml not found. Run secrets generation first."
        return 1
    fi

    print_step "Validating vault structure..."

    # Check if encrypted
    if head -1 "$vault_file" | grep -q '$ANSIBLE_VAULT'; then
        print_success "Vault is encrypted"
    else
        print_warning "Vault is NOT encrypted!"
    fi

    print_success "Secrets validation complete"
}
