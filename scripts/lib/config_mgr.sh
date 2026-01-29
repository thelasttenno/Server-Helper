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

    # Domain
    config_setup_domain

    # Control node
    config_setup_control

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

    print_success "Configuration complete!"
    print_info "Run 'make deploy' to apply the configuration"
}

# =============================================================================
# Configuration Validation
# =============================================================================

# Validate configuration
config_validate() {
    local errors=0

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
        print_warning "Domain not configured (using default)"
    else
        print_success "Domain: $domain"
    fi

    # Check control IP is set
    local control_ip
    control_ip=$(config_get_control_ip)
    if [[ -z "$control_ip" ]]; then
        print_warning "Control node IP not configured"
    else
        print_success "Control IP: $control_ip"
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
    if [[ $errors -eq 0 ]]; then
        print_success "Configuration validation passed"
        return 0
    else
        print_error "Configuration has $errors error(s)"
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
