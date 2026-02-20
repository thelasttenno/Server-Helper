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
    echo "America/Vancouver"
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

    # SSH Key Auto-Detection
    echo ""
    local ssh_pub=""
    if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        ssh_pub="$HOME/.ssh/id_ed25519.pub"
    elif [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        ssh_pub="$HOME/.ssh/id_rsa.pub"
    fi

    if [[ -n "$ssh_pub" ]]; then
        if confirm "Found SSH key ($ssh_pub). Add this key to vault for admin access?"; then
            export SETUP_ADMIN_SSH_KEY=$(cat "$ssh_pub")
        fi
    fi

    print_success "Configuration updated: $all_vars"

    # Advanced settings
    echo ""
    if confirm "Configure advanced settings (DNS, Docker, swap)?"; then
        echo ""
        local dns_servers docker_path swap_size

        dns_servers=$(prompt_input "DNS upstream servers (comma-separated)" "1.1.1.1,8.8.8.8")
        docker_path=$(prompt_input "Docker stack path" "/opt/stacks")
        swap_size=$(prompt_input "Swap size in GB" "2")

        # Write DNS servers as a YAML list
        python3 -c "
import yaml
with open('$all_vars') as f:
    data = yaml.safe_load(f) or {}
dns = data.setdefault('target_dns', {})
dns['upstream_servers'] = [s.strip() for s in '$dns_servers'.split(',') if s.strip()]
dns['search_domain'] = '{{ target_domain }}'
with open('$all_vars', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
" 2>/dev/null

        yaml_write "$all_vars" "docker_stack_path" "$docker_path"
        yaml_write "$all_vars" "swap_size_gb" "$swap_size"

        if confirm "Auto-upgrade system packages on deploy?"; then
            yaml_write "$all_vars" "common_upgrade_packages" "true"
        else
            yaml_write "$all_vars" "common_upgrade_packages" "false"
        fi

        print_success "Advanced settings updated"
    fi

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

    # Chat Notifications
    echo ""
    configure_chat_notifications

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
    local smtp_pass=""
    if [[ -n "$smtp_user" ]]; then
        smtp_pass=$(prompt_secret "SMTP password / App Password")
    fi

    # Export for secrets_mgr.sh
    export SETUP_SMTP_HOST="$smtp_host"
    export SETUP_SMTP_PORT="$smtp_port"
    export SETUP_SMTP_USER="$smtp_user"
    export SETUP_SMTP_FROM="$smtp_from"
    export SETUP_SMTP_PASS="$smtp_pass"
}

# =============================================================================
# CHAT NOTIFICATIONS CONFIG
# =============================================================================
configure_chat_notifications() {
    if confirm "Configure Discord notifications?"; then
        export SETUP_DISCORD_WEBHOOK=$(prompt_secret "Discord Webhook URL")
    fi
    if confirm "Configure Slack notifications?"; then
        export SETUP_SLACK_WEBHOOK=$(prompt_secret "Slack Webhook URL")
    fi
    if confirm "Configure Telegram notifications?"; then
        export SETUP_TELEGRAM_TOKEN=$(prompt_secret "Telegram Bot Token")
        export SETUP_TELEGRAM_CHATID=$(prompt_input "Telegram Chat ID")
    fi
    if confirm "Configure Watchtower updates via webhook?"; then
        export SETUP_WATCHTOWER_URL=$(prompt_secret "Watchtower Notification URL (e.g. discord://token@id)")
    fi
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
            export SETUP_S3_ACCESS=$(prompt_input "S3 Access Key")
            export SETUP_S3_SECRET=$(prompt_secret "S3 Secret Key")
            print_info "Set restic_destinations.type=s3 in group_vars/targets.yml"
            ;;
        3)
            local nas_path
            nas_path=$(prompt_input "NAS mount path" "/mnt/nas/backups")
            export SETUP_NAS_USER=$(prompt_input "NAS username")
            export SETUP_NAS_PASS=$(prompt_secret "NAS password")
            print_info "Set restic_destinations.type=nas and path=$nas_path in group_vars/targets.yml"
            ;;
    esac
}
