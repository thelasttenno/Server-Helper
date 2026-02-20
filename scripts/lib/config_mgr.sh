#!/usr/bin/env bash
# =============================================================================
# config_mgr.sh — YAML read/write, auto-detection, quick setup wizard
# =============================================================================

# =============================================================================
# YAML HELPERS (via Python for reliability)
# =============================================================================
yaml_read() {
    local file="$1"
    local key="$2"
    python3 -c "
import yaml, sys
with open('$file') as f:
    data = yaml.safe_load(f)
keys = '$key'.split('.')
val = data
for k in keys:
    if val is None:
        break
    val = val.get(k) if isinstance(val, dict) else None
print(val if val is not None else '')
" 2>/dev/null
}

yaml_write() {
    local file="$1"
    local key="$2"
    local value="$3"
    python3 -c "
import yaml, sys
with open('$file') as f:
    data = yaml.safe_load(f) or {}
keys = '$key'.split('.')
d = data
for k in keys[:-1]:
    d = d.setdefault(k, {})
d[keys[-1]] = '$value'
with open('$file', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
" 2>/dev/null
}

# =============================================================================
# AUTO-DETECTION
# =============================================================================
detect_ip() {
    # Detect primary IP address
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
}

detect_timezone() {
    timedatectl show --property=Timezone --value 2>/dev/null || \
        cat /etc/timezone 2>/dev/null || \
        echo "UTC"
}

detect_user() {
    echo "${SUDO_USER:-$USER}"
}

detect_domain() {
    hostname -d 2>/dev/null || echo ""
}

# =============================================================================
# QUICK SETUP WIZARD
# =============================================================================
quick_setup_wizard() {
    clear
    print_header "Quick Setup Wizard"
    echo ""

    local all_vars="$PROJECT_ROOT/group_vars/all.yml"
    local vault_file="$PROJECT_ROOT/group_vars/vault.yml"

    # Auto-detect values
    local detected_ip detected_tz detected_user detected_domain
    detected_ip=$(detect_ip)
    detected_tz=$(detect_timezone)
    detected_user=$(detect_user)
    detected_domain=$(detect_domain)

    print_info "Auto-detected values:"
    echo "    IP: $detected_ip"
    echo "    Timezone: $detected_tz"
    echo "    User: $detected_user"
    echo "    Domain: $detected_domain"
    echo ""

    # Prompt for values
    local domain ip timezone admin_user
    domain=$(prompt_input "Domain name" "$detected_domain")
    ip=$(prompt_input "Control node IP" "$detected_ip")
    timezone=$(prompt_input "Timezone" "$detected_tz")
    admin_user=$(prompt_input "Admin user" "$detected_user")

    echo ""
    print_step "Updating configuration..."

    # Write to group_vars/all.yml
    yaml_write "$all_vars" "target_domain" "$domain"
    yaml_write "$all_vars" "target_control_ip" "$ip"
    yaml_write "$all_vars" "target_timezone" "$timezone"
    yaml_write "$all_vars" "target_admin_user" "$admin_user"

    print_success "Configuration updated: $all_vars"

    # DNS configuration
    echo ""
    if confirm "Configure custom DNS records?"; then
        configure_dns "$all_vars" "$ip" "$domain"
    fi

    # Email configuration
    echo ""
    if confirm "Configure email notifications (SMTP)?"; then
        configure_email
    fi

    # Backup configuration
    echo ""
    if confirm "Configure backup destinations?"; then
        configure_backup
    fi

    # Secrets generation
    echo ""
    if confirm "Generate secrets now?"; then
        generate_secrets "fresh"
    fi

    echo ""
    echo ""
    print_success "Quick setup complete!"
    print_info "Review files in group_vars/ before deploying."
    
    echo ""
    if confirm "Ready to deploy infrastructure now?"; then
        echo ""
        log_exec "ansible-playbook -i '$PROJECT_ROOT/inventory/hosts.yml' '$PROJECT_ROOT/playbooks/site.yml'"
    else
        print_info "Next step: make deploy"
    fi
}

# =============================================================================
# DNS CONFIG
# =============================================================================
configure_dns() {
    local all_vars="$1"
    local ip="$2"
    local domain="$3"

    print_info "Standard DNS records will point *.${domain} → ${ip}"
    print_info "These are managed via Pi-hole custom DNS once deployed."
}

# =============================================================================
# EMAIL CONFIG
# =============================================================================
configure_email() {
    local smtp_host smtp_port smtp_user smtp_from

    smtp_host=$(prompt_input "SMTP host" "smtp.gmail.com")
    smtp_port=$(prompt_input "SMTP port" "587")
    smtp_user=$(prompt_input "SMTP username" "")
    smtp_from=$(prompt_input "From address" "$smtp_user")

    print_info "SMTP password should be added to vault.yml under vault_smtp_credentials"
    print_step "Run: make vault-edit"
}

# =============================================================================
# BACKUP CONFIG
# =============================================================================
configure_backup() {
    echo ""
    echo "  Backup destination type:"
    echo "  ${CYAN}1)${NC}  Local directory"
    echo "  ${CYAN}2)${NC}  S3/MinIO"
    echo "  ${CYAN}3)${NC}  NFS/NAS mount"
    echo ""
    echo -n "  Select: "
    local bchoice
    read -r bchoice

    case $bchoice in
        1)
            local backup_path
            backup_path=$(prompt_input "Backup path" "/mnt/backups")
            print_info "Set restic_destinations.type=local and path=$backup_path in group_vars/targets.yml"
            ;;
        2)
            print_info "Set restic_destinations.type=s3 in group_vars/targets.yml"
            print_info "Add S3 credentials to vault.yml under vault_restic_credentials"
            ;;
        3)
            local nas_path
            nas_path=$(prompt_input "NAS mount path" "/mnt/nas/backups")
            print_info "Set restic_destinations.type=nas and path=$nas_path in group_vars/targets.yml"
            ;;
    esac
}
