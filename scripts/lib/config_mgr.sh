#!/usr/bin/env bash
#
# Server Helper - Configuration Manager
# ======================================
# Manages configuration files and settings.
#
# Usage:
#   source scripts/lib/config_mgr.sh
#
# Security:
#   - Does not store secrets in plain text
#   - Uses vault for sensitive configuration
#   - Validates file permissions
#

# Prevent multiple sourcing
[[ -n "${_CONFIG_MGR_LOADED:-}" ]] && return 0
readonly _CONFIG_MGR_LOADED=1

# Require ui_utils
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: config_mgr.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

# Check for Python and PyYAML (used by config_get/config_set)
_CONFIG_HAS_PYTHON=0
if command -v python3 &>/dev/null && python3 -c "import yaml" &>/dev/null; then
    _CONFIG_HAS_PYTHON=1
fi

# =============================================================================
# Configuration Paths
# =============================================================================
readonly CONFIG_GROUP_VARS_DIR="group_vars"
readonly CONFIG_HOST_VARS_DIR="host_vars"
readonly CONFIG_ALL_YML="${CONFIG_GROUP_VARS_DIR}/all.yml"
readonly CONFIG_ALL_EXAMPLE="${CONFIG_GROUP_VARS_DIR}/all.example.yml"
readonly CONFIG_VAULT_YML="${CONFIG_GROUP_VARS_DIR}/vault.yml"
readonly CONFIG_VAULT_EXAMPLE="${CONFIG_GROUP_VARS_DIR}/vault.example.yml"
readonly CONFIG_CONTROL_YML="${CONFIG_GROUP_VARS_DIR}/control.yml"
readonly CONFIG_TARGETS_YML="${CONFIG_GROUP_VARS_DIR}/targets.yml"

# =============================================================================
# Configuration File Operations
# =============================================================================

# Check if all required configuration files exist
config_check_files() {
    local missing=0

    print_info "Checking configuration files..."

    # Required files
    local required_files=(
        "$CONFIG_ALL_YML"
        "$CONFIG_VAULT_YML"
    )

    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
        else
            print_warning "Missing: $file"
            ((missing++))
        fi
    done

    # Optional files
    local optional_files=(
        "$CONFIG_CONTROL_YML"
        "$CONFIG_TARGETS_YML"
    )

    for file in "${optional_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
        else
            print_debug "Optional: $file (not found)"
        fi
    done

    return $missing
}

# Initialize configuration from examples
config_init() {
    print_header "Configuration Setup"

    # Create directories
    mkdir -p "$CONFIG_GROUP_VARS_DIR"
    mkdir -p "$CONFIG_HOST_VARS_DIR"

    # Copy example files
    if [[ -f "$CONFIG_ALL_EXAMPLE" ]] && [[ ! -f "$CONFIG_ALL_YML" ]]; then
        print_info "Creating all.yml from example..."
        cp "$CONFIG_ALL_EXAMPLE" "$CONFIG_ALL_YML"
        print_success "Created: $CONFIG_ALL_YML"
    fi

    if [[ -f "$CONFIG_VAULT_EXAMPLE" ]] && [[ ! -f "$CONFIG_VAULT_YML" ]]; then
        print_info "Creating vault.yml from example..."
        cp "$CONFIG_VAULT_EXAMPLE" "$CONFIG_VAULT_YML"
        print_success "Created: $CONFIG_VAULT_YML"
    fi

    print_success "Configuration initialized"
}

# =============================================================================
# YAML Value Operations
# =============================================================================

# Get a value from a YAML file
config_get() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if [[ "$_CONFIG_HAS_PYTHON" -ne 1 ]]; then
        # Fallback: simple grep for top-level keys
        grep "^${key}:" "$file" 2>/dev/null | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | tr -d '"'
        return $?
    fi

    # Use Python for reliable YAML parsing
    python3 -c "
import yaml
import sys

with open('$file', 'r') as f:
    data = yaml.safe_load(f)

keys = '$key'.split('.')
value = data
for k in keys:
    if isinstance(value, dict) and k in value:
        value = value[k]
    else:
        sys.exit(1)

print(value if value is not None else '')
" 2>/dev/null
}

# Set a value in a YAML file (simple top-level only)
config_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if [[ "$_CONFIG_HAS_PYTHON" -ne 1 ]]; then
        print_error "Python3 with PyYAML required for config_set"
        return 1
    fi

    # Use Python for reliable YAML modification
    python3 -c "
import yaml
import sys

with open('$file', 'r') as f:
    data = yaml.safe_load(f) or {}

keys = '$key'.split('.')
target = data
for k in keys[:-1]:
    if k not in target:
        target[k] = {}
    target = target[k]

# Attempt to parse value as YAML for proper typing
try:
    target[keys[-1]] = yaml.safe_load('$value')
except:
    target[keys[-1]] = '$value'

with open('$file', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        print_success "Set $key in $file"
        return 0
    else
        print_error "Failed to set $key in $file"
        return 1
    fi
}

# =============================================================================
# Domain Configuration
# =============================================================================

# Get current domain
config_get_domain() {
    config_get "$CONFIG_ALL_YML" "target_domain"
}

# Set domain
config_set_domain() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        print_error "Domain is required"
        return 1
    fi

    config_set "$CONFIG_ALL_YML" "target_domain" "$domain"
}

# =============================================================================
# Control Node Configuration
# =============================================================================

# Get control node IP
config_get_control_ip() {
    config_get "$CONFIG_ALL_YML" "control_node_ip"
}

# Set control node IP
config_set_control_ip() {
    local ip="$1"

    if [[ -z "$ip" ]]; then
        print_error "IP address is required"
        return 1
    fi

    # Validate IP format
    if ! [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid IP address format"
        return 1
    fi

    config_set "$CONFIG_ALL_YML" "control_node_ip" "$ip"
}

# =============================================================================
# Timezone Configuration
# =============================================================================

# Get current timezone
config_get_timezone() {
    config_get "$CONFIG_ALL_YML" "target_timezone"
}

# Set timezone
config_set_timezone() {
    local timezone="$1"

    if [[ -z "$timezone" ]]; then
        print_error "Timezone is required"
        return 1
    fi

    # Basic validation - check format like "America/Vancouver"
    if ! [[ "$timezone" =~ ^[A-Za-z_]+/[A-Za-z_]+$ ]] && [[ "$timezone" != "UTC" ]]; then
        print_warning "Timezone format may be invalid. Use format: Region/City (e.g., America/New_York)"
    fi

    config_set "$CONFIG_ALL_YML" "target_timezone" "$timezone"
}

# =============================================================================
# Ansible User Configuration
# =============================================================================

# Get ansible user
config_get_ansible_user() {
    config_get "$CONFIG_ALL_YML" "ansible_user"
}

# Set ansible user
config_set_ansible_user() {
    local user="$1"

    if [[ -z "$user" ]]; then
        print_error "User is required"
        return 1
    fi

    # Basic validation - alphanumeric, underscore, hyphen
    if ! [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid username format. Use lowercase letters, numbers, underscores, hyphens."
        return 1
    fi

    config_set "$CONFIG_ALL_YML" "ansible_user" "$user"
}

# =============================================================================
# Feature Toggles
# =============================================================================

# Check if a feature is enabled
config_feature_enabled() {
    local feature="$1"
    local file="${2:-$CONFIG_ALL_YML}"

    local value
    value=$(config_get "$file" "$feature")

    [[ "$value" == "true" ]] || [[ "$value" == "True" ]] || [[ "$value" == "yes" ]]
}

# Enable a feature
config_enable_feature() {
    local feature="$1"
    local file="${2:-$CONFIG_ALL_YML}"

    config_set "$file" "$feature" "true"
}

# Disable a feature
config_disable_feature() {
    local feature="$1"
    local file="${2:-$CONFIG_ALL_YML}"

    config_set "$file" "$feature" "false"
}

# =============================================================================
# Interactive Configuration
# =============================================================================

# Interactive domain setup
config_setup_domain() {
    print_section "Domain Configuration"

    local current_domain
    current_domain=$(config_get_domain)

    if [[ -n "$current_domain" ]]; then
        print_info "Current domain: $current_domain"
    fi

    local domain
    domain=$(prompt_input "Enter your domain" "${current_domain:-example.com}")

    if [[ -n "$domain" ]]; then
        config_set_domain "$domain"
    fi
}

# Interactive control node setup
config_setup_control() {
    print_section "Control Node Configuration"

    local current_ip
    current_ip=$(config_get_control_ip)

    if [[ -n "$current_ip" ]]; then
        print_info "Current control node IP: $current_ip"
    fi

    local ip
    ip=$(prompt_input "Enter control node IP address" "${current_ip:-192.168.1.10}")

    if [[ -n "$ip" ]]; then
        config_set_control_ip "$ip"
    fi
}

# Interactive timezone setup
config_setup_timezone() {
    print_section "Timezone Configuration"

    local current_tz
    current_tz=$(config_get_timezone)

    if [[ -n "$current_tz" ]]; then
        print_info "Current timezone: $current_tz"
    fi

    echo "Common timezones: America/New_York, America/Los_Angeles, America/Chicago,"
    echo "                  Europe/London, Europe/Paris, Asia/Tokyo, UTC"
    echo ""

    local tz
    tz=$(prompt_input "Enter timezone" "${current_tz:-America/New_York}")

    if [[ -n "$tz" ]]; then
        config_set_timezone "$tz"
    fi
}

# Interactive ansible user setup
config_setup_ansible_user() {
    print_section "Ansible User Configuration"

    local current_user
    current_user=$(config_get_ansible_user)

    if [[ -n "$current_user" ]]; then
        print_info "Current ansible user: $current_user"
    fi

    echo "This user must exist on all target nodes and have sudo access."
    echo ""

    local user
    user=$(prompt_input "Enter SSH/Ansible username" "${current_user:-ansible}")

    if [[ -n "$user" ]]; then
        config_set_ansible_user "$user"
    fi
}

# Full interactive setup wizard
config_wizard() {
    print_header "Configuration Wizard"

    # Initialize if needed
    if ! config_check_files; then
        if prompt_confirm "Initialize configuration from examples?"; then
            config_init
        else
            print_error "Cannot continue without configuration files"
            return 1
        fi
    fi

    # Infrastructure settings
    print_section "Infrastructure Settings"
    echo "These settings are required for all deployments."
    echo ""

    # Domain
    config_setup_domain

    # Control node
    config_setup_control

    # System settings
    print_section "System Settings"

    # Timezone
    config_setup_timezone

    # Ansible user
    config_setup_ansible_user

    # Service configuration
    print_section "Service Configuration"

    echo "Which services would you like to enable?"
    echo ""

    # Traefik
    if prompt_confirm "Enable Traefik (reverse proxy)?"; then
        config_enable_feature "control_traefik.enabled"
    fi

    # Authentik
    if prompt_confirm "Enable Authentik (SSO)?"; then
        config_enable_feature "control_authentik.enabled"
    fi

    # Netdata
    if prompt_confirm "Enable Netdata (monitoring)?"; then
        config_enable_feature "target_netdata.enabled"
    fi

    # Grafana
    if prompt_confirm "Enable Grafana (dashboards)?"; then
        config_enable_feature "control_grafana.enabled"
    fi

    # Vault reminder
    echo ""
    print_section "Vault Configuration"
    print_warning "Vault secrets must be configured manually for security."
    echo "Required secrets include:"
    echo "  - vault_netdata_stream_api_key (for metrics streaming)"
    echo "  - vault_step_ca_password (for certificate authority)"
    echo "  - vault_control_grafana_password (for Grafana admin)"
    echo "  - vault_authentik_credentials (for SSO)"
    echo ""
    print_info "Edit group_vars/vault.yml and run: ./scripts/vault.sh encrypt"

    print_success "Configuration complete!"
    print_info "Run 'make deploy' to apply the configuration"
}

# =============================================================================
# Secrets Configuration (Vault Prompts)
# =============================================================================

# Generate a random password
_generate_password() {
    local length="${1:-32}"
    openssl rand -base64 "$length" 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c "$length"
}

# Get a vault value (decrypted)
_vault_get() {
    local key="$1"
    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"

    if [[ ! -f "$password_file" ]]; then
        return 1
    fi

    if [[ ! -f "$CONFIG_VAULT_YML" ]]; then
        return 1
    fi

    # Check if encrypted
    if head -1 "$CONFIG_VAULT_YML" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
        ansible-vault view "$CONFIG_VAULT_YML" --vault-password-file="$password_file" 2>/dev/null | \
            python3 -c "
import yaml
import sys
data = yaml.safe_load(sys.stdin)
keys = '$key'.split('.')
value = data
for k in keys:
    if isinstance(value, dict) and k in value:
        value = value[k]
    else:
        sys.exit(1)
print(value if value is not None else '')
" 2>/dev/null
    else
        config_get "$CONFIG_VAULT_YML" "$key"
    fi
}

# Check if a vault value is still a placeholder
_vault_is_placeholder() {
    local value="$1"
    [[ "$value" == CHANGE_ME* ]] || [[ -z "$value" ]]
}

# Prompt for a secret value with option to auto-generate
config_prompt_secret() {
    local name="$1"
    local description="$2"
    local current_value="$3"
    local can_generate="${4:-true}"

    echo ""
    print_info "$description"

    if [[ -n "$current_value" ]] && ! _vault_is_placeholder "$current_value"; then
        print_success "  Currently set (not showing for security)"
        if ! prompt_confirm "  Change this value?"; then
            return 1
        fi
    fi

    local value=""
    if [[ "$can_generate" == "true" ]]; then
        echo "  1) Enter manually"
        echo "  2) Auto-generate secure password"
        echo "  3) Skip"
        local choice
        choice=$(prompt_input "  Choose [1-3]")

        case "$choice" in
            1)
                value=$(prompt_password "  Enter $name")
                ;;
            2)
                value=$(_generate_password 24)
                print_success "  Generated: $value"
                print_warning "  Save this password securely!"
                ;;
            3)
                return 1
                ;;
        esac
    else
        value=$(prompt_input "  Enter $name")
    fi

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    fi
    return 1
}

# Interactive vault secrets setup
config_setup_secrets() {
    print_header "Secrets Configuration"

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"

    # Check if vault password file exists
    if [[ ! -f "$password_file" ]]; then
        print_warning "Vault password file not found."
        print_info "Run 'Initialize Vault' from the Vault menu first."
        return 1
    fi

    # Check if vault.yml exists
    if [[ ! -f "$CONFIG_VAULT_YML" ]]; then
        print_warning "Vault file not found: $CONFIG_VAULT_YML"
        return 1
    fi

    print_info "This wizard helps you configure service passwords."
    print_info "Passwords with CHANGE_ME placeholders need to be set."
    echo ""

    # Track changes
    local changes_made=false
    local temp_values=""

    # Netdata Stream API Key
    print_section "Netdata Streaming"
    local netdata_key
    netdata_key=$(_vault_get "vault_netdata_stream_api_key")
    if _vault_is_placeholder "$netdata_key"; then
        print_warning "Netdata stream key needs configuration"
        if new_value=$(config_prompt_secret "Netdata API Key" "Used for parent-child streaming" "" "true"); then
            temp_values+="netdata_key=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Netdata stream key: configured"
    fi

    # Grafana Password
    print_section "Grafana"
    local grafana_pass
    grafana_pass=$(_vault_get "vault_control_grafana_password")
    if _vault_is_placeholder "$grafana_pass"; then
        print_warning "Grafana admin password needs configuration"
        if new_value=$(config_prompt_secret "Grafana Password" "Admin password for Grafana" "" "true"); then
            temp_values+="grafana_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Grafana password: configured"
    fi

    # Pi-hole Password
    print_section "Pi-hole"
    local pihole_pass
    pihole_pass=$(_vault_get "vault_pihole_password")
    if _vault_is_placeholder "$pihole_pass"; then
        print_warning "Pi-hole web password needs configuration"
        if new_value=$(config_prompt_secret "Pi-hole Password" "Web interface password" "" "true"); then
            temp_values+="pihole_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Pi-hole password: configured"
    fi

    # Traefik Dashboard
    print_section "Traefik Dashboard"
    local traefik_pass
    traefik_pass=$(_vault_get "vault_traefik_dashboard.password")
    if _vault_is_placeholder "$traefik_pass"; then
        print_warning "Traefik dashboard password needs configuration"
        if new_value=$(config_prompt_secret "Traefik Password" "Dashboard authentication" "" "true"); then
            temp_values+="traefik_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Traefik password: configured"
    fi

    # Dockge Credentials
    print_section "Dockge"
    local dockge_pass
    dockge_pass=$(_vault_get "vault_dockge_credentials.password")
    if _vault_is_placeholder "$dockge_pass"; then
        print_warning "Dockge password needs configuration"
        if new_value=$(config_prompt_secret "Dockge Password" "Container manager password" "" "true"); then
            temp_values+="dockge_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Dockge password: configured"
    fi

    # Uptime Kuma
    print_section "Uptime Kuma"
    local uk_pass
    uk_pass=$(_vault_get "vault_uptime_kuma_credentials.password")
    if _vault_is_placeholder "$uk_pass"; then
        print_warning "Uptime Kuma password needs configuration"
        if new_value=$(config_prompt_secret "Uptime Kuma Password" "Monitoring dashboard password" "" "true"); then
            temp_values+="uptime_kuma_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Uptime Kuma password: configured"
    fi

    # Restic Backup Password
    print_section "Restic Backups"
    local restic_pass
    restic_pass=$(_vault_get "vault_restic_passwords.local")
    if _vault_is_placeholder "$restic_pass"; then
        print_warning "Restic backup password needs configuration"
        if new_value=$(config_prompt_secret "Restic Password" "Encryption password for backups" "" "true"); then
            temp_values+="restic_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Restic password: configured"
    fi

    # Step-CA Password
    print_section "Step-CA (Certificate Authority)"
    local stepca_pass
    stepca_pass=$(_vault_get "vault_step_ca_password")
    if _vault_is_placeholder "$stepca_pass"; then
        print_warning "Step-CA password needs configuration"
        if new_value=$(config_prompt_secret "Step-CA Password" "CA provisioner password" "" "true"); then
            temp_values+="stepca_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Step-CA password: configured"
    fi

    # Authentik
    print_section "Authentik (SSO)"
    local auth_pass
    auth_pass=$(_vault_get "vault_authentik_credentials.admin_password")
    if _vault_is_placeholder "$auth_pass"; then
        print_warning "Authentik passwords need configuration"
        if new_value=$(config_prompt_secret "Authentik Admin Password" "SSO admin password" "" "true"); then
            temp_values+="authentik_admin=$new_value\n"
            changes_made=true
        fi
        # Also generate secret key and postgres password
        local secret_key
        local pg_pass
        secret_key=$(_generate_password 64)
        pg_pass=$(_generate_password 24)
        temp_values+="authentik_secret=$secret_key\n"
        temp_values+="authentik_pg=$pg_pass\n"
        print_success "Generated Authentik secret key and database password"
    else
        print_success "Authentik passwords: configured"
    fi

    echo ""

    if [[ "$changes_made" == "true" ]]; then
        print_section "Applying Changes"
        print_warning "To apply these changes, edit vault.yml with the new values."
        print_info "Run: ./scripts/vault.sh edit"
        echo ""
        print_info "New values to set (copy these):"
        echo "─────────────────────────────────────────"

        # Display the values that need to be set
        echo -e "$temp_values" | while IFS='=' read -r key value; do
            if [[ -n "$key" ]]; then
                case "$key" in
                    netdata_key) echo "vault_netdata_stream_api_key: \"$value\"" ;;
                    grafana_pass) echo "vault_control_grafana_password: \"$value\"" ;;
                    pihole_pass) echo "vault_pihole_password: \"$value\"" ;;
                    traefik_pass) echo "vault_traefik_dashboard.password: \"$value\"" ;;
                    dockge_pass) echo "vault_dockge_credentials.password: \"$value\"" ;;
                    uptime_kuma_pass) echo "vault_uptime_kuma_credentials.password: \"$value\"" ;;
                    restic_pass) echo "vault_restic_passwords.local: \"$value\"" ;;
                    stepca_pass) echo "vault_step_ca_password: \"$value\"" ;;
                    authentik_admin) echo "vault_authentik_credentials.admin_password: \"$value\"" ;;
                    authentik_secret) echo "vault_authentik_credentials.secret_key: \"$value\"" ;;
                    authentik_pg) echo "vault_authentik_credentials.postgres_password: \"$value\"" ;;
                esac
            fi
        done
        echo "─────────────────────────────────────────"

        if prompt_confirm "Open vault file in editor now?"; then
            export EDITOR="${EDITOR:-nano}"
            ansible-vault edit "$CONFIG_VAULT_YML" --vault-password-file="$password_file"
        fi
    else
        print_success "All secrets are already configured!"
    fi
}

# Quick setup for essential secrets only
config_setup_essential_secrets() {
    print_section "Essential Secrets Setup"

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"

    if [[ ! -f "$password_file" ]]; then
        print_warning "Vault password file not found."
        return 1
    fi

    print_info "Setting up minimum required secrets..."
    echo ""

    # Generate all essential secrets automatically
    local netdata_key
    local grafana_pass
    local restic_pass
    netdata_key=$(_generate_password 32)
    grafana_pass=$(_generate_password 16)
    restic_pass=$(_generate_password 32)

    print_success "Generated secrets:"
    echo "─────────────────────────────────────────"
    echo "vault_netdata_stream_api_key: \"$netdata_key\""
    echo "vault_control_grafana_password: \"$grafana_pass\""
    echo "vault_restic_passwords:"
    echo "  local: \"$restic_pass\""
    echo "─────────────────────────────────────────"
    echo ""
    print_warning "Copy these to your vault.yml file!"
    print_info "Run: ./scripts/vault.sh edit"
}

# =============================================================================
# Configuration Validation
# =============================================================================

# Validate configuration
config_validate() {
    local errors=0
    local warnings=0

    print_header "Configuration Validation"

    # Check required files exist
    if [[ ! -f "$CONFIG_ALL_YML" ]]; then
        print_error "Missing: $CONFIG_ALL_YML"
        ((errors++))
    fi

    # Check domain is set
    local domain
    domain=$(config_get_domain)
    if [[ -z "$domain" ]] || [[ "$domain" == "example.com" ]]; then
        print_warning "Domain not configured (using default 'example.com')"
        ((warnings++))
    else
        print_success "Domain: $domain"
    fi

    # Check control IP is set
    local control_ip
    control_ip=$(config_get_control_ip)
    if [[ -z "$control_ip" ]] || [[ "$control_ip" == "192.168.1.10" ]]; then
        print_warning "Control node IP may need configuration (currently: ${control_ip:-not set})"
        ((warnings++))
    else
        print_success "Control IP: $control_ip"
    fi

    # Check timezone
    local timezone
    timezone=$(config_get_timezone)
    if [[ -z "$timezone" ]]; then
        print_warning "Timezone not configured"
        ((warnings++))
    else
        print_success "Timezone: $timezone"
    fi

    # Check ansible user
    local ansible_user
    ansible_user=$(config_get_ansible_user)
    if [[ -z "$ansible_user" ]]; then
        print_warning "Ansible user not configured"
        ((warnings++))
    else
        print_success "Ansible user: $ansible_user"
    fi

    # Validate YAML syntax
    print_info "Validating YAML syntax..."

    for file in "$CONFIG_ALL_YML" "$CONFIG_VAULT_YML" "$CONFIG_CONTROL_YML" "$CONFIG_TARGETS_YML"; do
        if [[ -f "$file" ]]; then
            if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                print_success "Valid: $file"
            else
                print_error "Invalid YAML: $file"
                ((errors++))
            fi
        fi
    done

    echo ""
    if [[ $errors -eq 0 ]] && [[ $warnings -eq 0 ]]; then
        print_success "Configuration validation passed"
        return 0
    elif [[ $errors -eq 0 ]]; then
        print_warning "Configuration has $warnings warning(s) - review before deployment"
        return 0
    else
        print_error "Configuration has $errors error(s) and $warnings warning(s)"
        return 1
    fi
}

# =============================================================================
# Host Variables
# =============================================================================

# Create host_vars file for a specific host
config_create_host_vars() {
    local hostname="$1"
    local file="${CONFIG_HOST_VARS_DIR}/${hostname}.yml"

    if [[ -f "$file" ]]; then
        print_warning "Host vars already exist: $file"
        if ! prompt_confirm "Overwrite?"; then
            return 0
        fi
    fi

    mkdir -p "$CONFIG_HOST_VARS_DIR"

    cat > "$file" << EOF
---
# Host-specific variables for $hostname
# ======================================
# Override group_vars settings for this host

# Timezone override
# timezone: "America/New_York"

# LXC container flags (skip certain roles)
# lvm_skip: true
# swap_skip: true
# qemu_agent_skip: true

# Backup configuration override
# restic_backup_paths:
#   - /opt/stacks

# Netdata thresholds override
# netdata_disk_warning: 80
# netdata_disk_critical: 90
EOF

    print_success "Created: $file"
    print_info "Edit this file to customize settings for $hostname"
}

# List all host_vars files
config_list_host_vars() {
    print_section "Host Variables"

    if [[ ! -d "$CONFIG_HOST_VARS_DIR" ]]; then
        print_info "No host_vars directory"
        return 0
    fi

    local files
    mapfile -t files < <(find "$CONFIG_HOST_VARS_DIR" -name "*.yml" -type f 2>/dev/null)

    if [[ ${#files[@]} -eq 0 ]]; then
        print_info "No host variable files found"
        return 0
    fi

    for file in "${files[@]}"; do
        local hostname
        hostname=$(basename "$file" .yml)
        echo "  - $hostname"
    done
}
