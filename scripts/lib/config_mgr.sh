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
# Auto-Detection Functions
# =============================================================================

# Auto-detect primary IP address (for control node)
config_detect_ip() {
    local ip=""

    # Try to get IP from default route interface
    if command -v ip &>/dev/null; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)
    fi

    # Fallback: try hostname -I
    if [[ -z "$ip" ]] && command -v hostname &>/dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi

    # Fallback: check common interfaces
    if [[ -z "$ip" ]]; then
        for iface in eth0 ens18 ens192 enp0s3; do
            if ip addr show "$iface" &>/dev/null; then
                ip=$(ip addr show "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
                [[ -n "$ip" ]] && break
            fi
        done
    fi

    echo "${ip:-192.168.1.10}"
}

# Auto-detect system timezone
config_detect_timezone() {
    local tz=""

    # Try timedatectl (systemd)
    if command -v timedatectl &>/dev/null; then
        tz=$(timedatectl show --property=Timezone --value 2>/dev/null)
    fi

    # Fallback: /etc/timezone
    if [[ -z "$tz" ]] && [[ -f /etc/timezone ]]; then
        tz=$(cat /etc/timezone 2>/dev/null)
    fi

    # Fallback: readlink /etc/localtime
    if [[ -z "$tz" ]] && [[ -L /etc/localtime ]]; then
        tz=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
    fi

    echo "${tz:-UTC}"
}

# Auto-detect current username for ansible
config_detect_user() {
    echo "${SUDO_USER:-${USER:-ansible}}"
}

# Auto-detect domain from hostname (or use default)
config_detect_domain() {
    local domain=""

    # Try to get domain from hostname -d
    if command -v hostname &>/dev/null; then
        domain=$(hostname -d 2>/dev/null)
    fi

    # Fallback: get FQDN and extract domain
    if [[ -z "$domain" ]] || [[ "$domain" == "(none)" ]]; then
        local fqdn
        fqdn=$(hostname -f 2>/dev/null || echo "")
        if [[ "$fqdn" == *.* ]]; then
            domain=$(echo "$fqdn" | cut -d. -f2-)
        fi
    fi

    # Use local if still empty
    echo "${domain:-local}"
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
# DNS Configuration
# =============================================================================

# Get DNS upstream servers
config_get_dns_servers() {
    config_get "$CONFIG_ALL_YML" "target_dns.upstream_servers"
}

# Set DNS upstream servers (expects YAML list format)
config_set_dns_servers() {
    local servers="$1"

    if [[ -z "$servers" ]]; then
        print_error "DNS servers are required"
        return 1
    fi

    config_set "$CONFIG_ALL_YML" "target_dns.upstream_servers" "$servers"
}

# =============================================================================
# Notification Email Configuration
# =============================================================================

# Get notification email
config_get_notification_email() {
    config_get "$CONFIG_ALL_YML" "target_notification_email"
}

# Set notification email
config_set_notification_email() {
    local email="$1"

    if [[ -z "$email" ]]; then
        print_error "Email is required"
        return 1
    fi

    # Basic email validation
    if ! [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_warning "Email format may be invalid"
    fi

    config_set "$CONFIG_ALL_YML" "target_notification_email" "$email"
}

# =============================================================================
# Backup Destination Configuration
# =============================================================================

# Get backup local path
config_get_backup_local_path() {
    config_get "$CONFIG_TARGETS_YML" "target_restic.destinations.local.path"
}

# Set backup local path
config_set_backup_local_path() {
    local path="$1"

    if [[ -z "$path" ]]; then
        print_error "Backup path is required"
        return 1
    fi

    config_set "$CONFIG_TARGETS_YML" "target_restic.destinations.local.path" "$path"
    config_set "$CONFIG_TARGETS_YML" "target_restic.destinations.local.enabled" "true"
}

# Get backup NAS path
config_get_backup_nas_path() {
    config_get "$CONFIG_TARGETS_YML" "target_restic.destinations.nas.path"
}

# Set backup NAS path
config_set_backup_nas_path() {
    local path="$1"

    if [[ -z "$path" ]]; then
        return 1
    fi

    config_set "$CONFIG_TARGETS_YML" "target_restic.destinations.nas.path" "$path"
    config_set "$CONFIG_TARGETS_YML" "target_restic.destinations.nas.enabled" "true"
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

    local current_domain detected_domain
    current_domain=$(config_get_domain)
    detected_domain=$(config_detect_domain)

    if [[ -n "$current_domain" ]] && [[ "$current_domain" != "example.com" ]]; then
        print_info "Current domain: $current_domain"
    fi

    # Use auto-detection or remembered value
    local auto_value=""
    if [[ -n "$current_domain" ]] && [[ "$current_domain" != "example.com" ]]; then
        auto_value="$current_domain"
    elif [[ -n "$detected_domain" ]] && [[ "$detected_domain" != "local" ]]; then
        auto_value="$detected_domain"
    fi

    local domain
    domain=$(prompt_input_auto "Enter your domain" "$auto_value" "domain" "example.com")

    if [[ -n "$domain" ]]; then
        config_set_domain "$domain"
    fi
}

# Interactive control node setup
config_setup_control() {
    print_section "Control Node Configuration"

    local current_ip detected_ip
    current_ip=$(config_get_control_ip)
    detected_ip=$(config_detect_ip)

    if [[ -n "$current_ip" ]] && [[ "$current_ip" != "192.168.1.10" ]]; then
        print_info "Current control node IP: $current_ip"
    fi

    # Auto-fill from current config or detection
    local auto_value=""
    if [[ -n "$current_ip" ]] && [[ "$current_ip" != "192.168.1.10" ]]; then
        auto_value="$current_ip"
    elif [[ -n "$detected_ip" ]]; then
        auto_value="$detected_ip"
    fi

    local ip
    ip=$(prompt_input_auto "Enter control node IP address" "$auto_value" "" "192.168.1.10")

    if [[ -n "$ip" ]]; then
        config_set_control_ip "$ip"
    fi
}

# Interactive timezone setup
config_setup_timezone() {
    print_section "Timezone Configuration"

    local current_tz detected_tz
    current_tz=$(config_get_timezone)
    detected_tz=$(config_detect_timezone)

    if [[ -n "$current_tz" ]]; then
        print_info "Current timezone: $current_tz"
    fi

    echo "Common timezones: America/New_York, America/Los_Angeles, America/Chicago,"
    echo "                  Europe/London, Europe/Paris, Asia/Tokyo, UTC"
    echo ""

    # Auto-fill from current config or detection
    local auto_value=""
    if [[ -n "$current_tz" ]]; then
        auto_value="$current_tz"
    elif [[ -n "$detected_tz" ]]; then
        auto_value="$detected_tz"
    fi

    local tz
    tz=$(prompt_input_auto "Enter timezone" "$auto_value" "" "America/New_York")

    if [[ -n "$tz" ]]; then
        config_set_timezone "$tz"
    fi
}

# Interactive ansible user setup
config_setup_ansible_user() {
    print_section "Ansible User Configuration"

    local current_user detected_user
    current_user=$(config_get_ansible_user)
    detected_user=$(config_detect_user)

    if [[ -n "$current_user" ]]; then
        print_info "Current ansible user: $current_user"
    fi

    echo "This user must exist on all target nodes and have sudo access."
    echo ""

    # Auto-fill from current config or detection
    local auto_value=""
    if [[ -n "$current_user" ]]; then
        auto_value="$current_user"
    elif [[ -n "$detected_user" ]]; then
        auto_value="$detected_user"
    fi

    local user
    user=$(prompt_input_auto "Enter SSH/Ansible username" "$auto_value" "ssh_user" "ansible")

    if [[ -n "$user" ]]; then
        config_set_ansible_user "$user"
    fi
}

# Interactive DNS setup
config_setup_dns() {
    print_section "DNS Configuration"

    echo "Configure upstream DNS servers for Pi-hole."
    echo "Default uses Cloudflare DNS (1.1.1.1, 1.0.0.1)."
    echo ""
    echo "Options:"
    echo "  1) Cloudflare (1.1.1.1, 1.0.0.1) - Fast, privacy-focused"
    echo "  2) Google (8.8.8.8, 8.8.4.4) - Reliable, widely used"
    echo "  3) Quad9 (9.9.9.9, 149.112.112.112) - Security-focused"
    echo "  4) Custom - Enter your own DNS servers"
    echo ""

    local choice
    choice=$(prompt_input "Choose DNS provider [1-4]" "1")

    local servers
    case "$choice" in
        1)
            servers="[1.1.1.1, 1.0.0.1]"
            print_success "Using Cloudflare DNS"
            ;;
        2)
            servers="[8.8.8.8, 8.8.4.4]"
            print_success "Using Google DNS"
            ;;
        3)
            servers="[9.9.9.9, 149.112.112.112]"
            print_success "Using Quad9 DNS"
            ;;
        4)
            local primary secondary
            primary=$(prompt_input "Enter primary DNS server" "1.1.1.1")
            secondary=$(prompt_input "Enter secondary DNS server" "1.0.0.1")
            servers="[$primary, $secondary]"
            ;;
        *)
            servers="[1.1.1.1, 1.0.0.1]"
            print_info "Using default Cloudflare DNS"
            ;;
    esac

    config_set_dns_servers "$servers"
}

# Interactive notification email setup
config_setup_notification_email() {
    print_section "Notification Email Configuration"

    local current_email remembered_email current_domain
    current_email=$(config_get_notification_email)
    remembered_email=$(prefs_get "email")
    current_domain=$(config_get_domain)

    if [[ -n "$current_email" ]]; then
        print_info "Current notification email: $current_email"
    fi

    echo "This email receives security alerts from fail2ban and other services."
    echo ""

    # Determine auto-fill value (prioritize: current > remembered > derived)
    local auto_value=""
    if [[ -n "$current_email" ]]; then
        auto_value="$current_email"
    elif [[ -n "$remembered_email" ]]; then
        auto_value="$remembered_email"
    fi

    local fallback_email="admin@${current_domain:-example.com}"
    local email
    email=$(prompt_input_auto "Enter notification email" "$auto_value" "email" "$fallback_email")

    if [[ -n "$email" ]]; then
        config_set_notification_email "$email"
    fi
}

# =============================================================================
# Service Presets (reduces form fatigue)
# =============================================================================

# Apply a service preset
# Usage: config_apply_preset "preset_name"
config_apply_preset() {
    local preset="$1"

    # First disable all optional services
    config_disable_feature "control_traefik.enabled"
    config_disable_feature "control_authentik.enabled"
    config_disable_feature "control_grafana.enabled"
    config_disable_feature "control_loki.enabled"
    config_disable_feature "control_netdata.enabled"
    config_disable_feature "control_step_ca.enabled"
    config_disable_feature "control_dns.enabled"
    config_disable_feature "control_uptime_kuma.enabled"
    config_disable_feature "target_netdata.enabled"
    config_disable_feature "target_dockge.enabled"
    config_disable_feature "target_promtail.enabled"

    case "$preset" in
        full)
            # Everything enabled
            config_enable_feature "control_traefik.enabled"
            config_enable_feature "control_authentik.enabled"
            config_enable_feature "control_grafana.enabled"
            config_enable_feature "control_loki.enabled"
            config_enable_feature "control_netdata.enabled"
            config_enable_feature "control_step_ca.enabled"
            config_enable_feature "control_dns.enabled"
            config_enable_feature "control_uptime_kuma.enabled"
            config_enable_feature "target_netdata.enabled"
            config_enable_feature "target_dockge.enabled"
            config_enable_feature "target_promtail.enabled"
            ;;
        homelab)
            # Balanced for typical home server
            config_enable_feature "control_traefik.enabled"
            config_enable_feature "control_grafana.enabled"
            config_enable_feature "control_netdata.enabled"
            config_enable_feature "control_uptime_kuma.enabled"
            config_enable_feature "target_netdata.enabled"
            config_enable_feature "target_dockge.enabled"
            ;;
        monitoring)
            # Observability focus, no public exposure
            config_enable_feature "control_grafana.enabled"
            config_enable_feature "control_loki.enabled"
            config_enable_feature "control_netdata.enabled"
            config_enable_feature "target_netdata.enabled"
            config_enable_feature "target_promtail.enabled"
            config_enable_feature "target_dockge.enabled"
            ;;
        minimal)
            # Just container management basics
            config_enable_feature "target_dockge.enabled"
            ;;
        production)
            # Full stack for business/VPS (no Pi-hole)
            config_enable_feature "control_traefik.enabled"
            config_enable_feature "control_authentik.enabled"
            config_enable_feature "control_grafana.enabled"
            config_enable_feature "control_loki.enabled"
            config_enable_feature "control_netdata.enabled"
            config_enable_feature "control_step_ca.enabled"
            config_enable_feature "control_uptime_kuma.enabled"
            config_enable_feature "target_netdata.enabled"
            config_enable_feature "target_dockge.enabled"
            config_enable_feature "target_promtail.enabled"
            ;;
    esac
}

# Interactive service preset selection
config_setup_services_preset() {
    print_section "Service Configuration"

    echo "Choose a service preset or customize individually:"
    echo ""
    print_menu_item "1" "Full" "All services (Traefik, Authentik, Grafana, Netdata, Pi-hole, etc.)"
    print_menu_item "2" "Homelab" "Traefik + Monitoring + Uptime Kuma + Dockge (Recommended)"
    print_menu_item "3" "Monitoring" "Grafana + Netdata + Loki (no reverse proxy)"
    print_menu_item "4" "Minimal" "Docker + Security + Dockge only"
    print_menu_item "5" "Production" "Full stack without Pi-hole (for VPS/cloud)"
    print_menu_item "6" "Custom" "Choose each service individually"
    echo ""

    local choice
    choice=$(prompt_input "Choose preset [1-6]" "2")

    case "$choice" in
        1)
            print_info "Applying Full preset..."
            config_apply_preset "full"
            _show_preset_summary "full"
            ;;
        2)
            print_info "Applying Homelab preset..."
            config_apply_preset "homelab"
            _show_preset_summary "homelab"
            ;;
        3)
            print_info "Applying Monitoring preset..."
            config_apply_preset "monitoring"
            _show_preset_summary "monitoring"
            ;;
        4)
            print_info "Applying Minimal preset..."
            config_apply_preset "minimal"
            _show_preset_summary "minimal"
            ;;
        5)
            print_info "Applying Production preset..."
            config_apply_preset "production"
            _show_preset_summary "production"
            ;;
        6)
            _config_setup_services_custom
            ;;
        *)
            print_info "Defaulting to Homelab preset..."
            config_apply_preset "homelab"
            _show_preset_summary "homelab"
            ;;
    esac
}

# Show summary of what a preset enables
_show_preset_summary() {
    local preset="$1"
    echo ""
    print_section "Enabled Services"

    case "$preset" in
        full)
            echo "  ${GREEN}✓${NC} Traefik (reverse proxy + SSL)"
            echo "  ${GREEN}✓${NC} Authentik (SSO/identity)"
            echo "  ${GREEN}✓${NC} Step-CA (internal certificates)"
            echo "  ${GREEN}✓${NC} Pi-hole (DNS + ad blocking)"
            echo "  ${GREEN}✓${NC} Netdata (real-time monitoring)"
            echo "  ${GREEN}✓${NC} Grafana + Loki (dashboards + logs)"
            echo "  ${GREEN}✓${NC} Uptime Kuma (status page)"
            echo "  ${GREEN}✓${NC} Dockge (container management)"
            echo "  ${GREEN}✓${NC} Promtail (log shipping)"
            ;;
        homelab)
            echo "  ${GREEN}✓${NC} Traefik (reverse proxy + SSL)"
            echo "  ${GREEN}✓${NC} Netdata (real-time monitoring)"
            echo "  ${GREEN}✓${NC} Grafana (dashboards)"
            echo "  ${GREEN}✓${NC} Uptime Kuma (status page)"
            echo "  ${GREEN}✓${NC} Dockge (container management)"
            echo "  ${DIM}○ Authentik (add later with Full preset)${NC}"
            echo "  ${DIM}○ Pi-hole (add later with Full preset)${NC}"
            ;;
        monitoring)
            echo "  ${GREEN}✓${NC} Netdata (real-time monitoring)"
            echo "  ${GREEN}✓${NC} Grafana (dashboards)"
            echo "  ${GREEN}✓${NC} Loki (log aggregation)"
            echo "  ${GREEN}✓${NC} Promtail (log shipping)"
            echo "  ${GREEN}✓${NC} Dockge (container management)"
            echo "  ${DIM}○ No reverse proxy (internal only)${NC}"
            ;;
        minimal)
            echo "  ${GREEN}✓${NC} Docker + Security hardening"
            echo "  ${GREEN}✓${NC} Watchtower (auto-updates)"
            echo "  ${GREEN}✓${NC} Dockge (container management)"
            echo "  ${DIM}○ No monitoring services${NC}"
            echo "  ${DIM}○ No reverse proxy${NC}"
            ;;
        production)
            echo "  ${GREEN}✓${NC} Traefik (reverse proxy + SSL)"
            echo "  ${GREEN}✓${NC} Authentik (SSO/identity)"
            echo "  ${GREEN}✓${NC} Step-CA (internal certificates)"
            echo "  ${GREEN}✓${NC} Netdata (real-time monitoring)"
            echo "  ${GREEN}✓${NC} Grafana + Loki (dashboards + logs)"
            echo "  ${GREEN}✓${NC} Uptime Kuma (status page)"
            echo "  ${GREEN}✓${NC} Dockge (container management)"
            echo "  ${DIM}○ No Pi-hole (use external DNS)${NC}"
            ;;
    esac
    echo ""
}

# Custom service selection (original behavior)
_config_setup_services_custom() {
    print_section "Custom Service Selection"
    echo "Enable or disable each service individually:"
    echo ""

    # Core services
    if prompt_confirm "Enable Traefik (reverse proxy + automatic SSL)?"; then
        config_enable_feature "control_traefik.enabled"
    fi

    if prompt_confirm "Enable Authentik (SSO/identity provider)?"; then
        config_enable_feature "control_authentik.enabled"
    fi

    if prompt_confirm "Enable Step-CA (internal certificate authority)?"; then
        config_enable_feature "control_step_ca.enabled"
    fi

    # DNS
    if prompt_confirm "Enable Pi-hole (DNS + ad blocking)?"; then
        config_enable_feature "control_dns.enabled"
    fi

    # Monitoring
    if prompt_confirm "Enable Netdata (real-time monitoring)?"; then
        config_enable_feature "control_netdata.enabled"
        config_enable_feature "target_netdata.enabled"
    fi

    if prompt_confirm "Enable Grafana (dashboards)?"; then
        config_enable_feature "control_grafana.enabled"
    fi

    if prompt_confirm "Enable Loki + Promtail (log aggregation)?"; then
        config_enable_feature "control_loki.enabled"
        config_enable_feature "target_promtail.enabled"
    fi

    # Utilities
    if prompt_confirm "Enable Uptime Kuma (status page)?"; then
        config_enable_feature "control_uptime_kuma.enabled"
    fi

    if prompt_confirm "Enable Dockge (container management UI)?"; then
        config_enable_feature "target_dockge.enabled"
    fi

    print_success "Custom service configuration complete"
}

# Interactive backup destination setup
config_setup_backup_destination() {
    print_section "Backup Destination Configuration"

    echo "Configure where backups will be stored."
    echo ""
    echo "Options:"
    echo "  1) Local only - Store backups on each server locally"
    echo "  2) NAS/S3 - Store backups on a NAS or S3-compatible storage"
    echo "  3) Both - Local + NAS for redundancy"
    echo ""

    local choice
    choice=$(prompt_input "Choose backup destination [1-3]" "1")

    case "$choice" in
        1)
            local local_path
            local_path=$(prompt_input "Enter local backup path" "/opt/server-helper/backups/restic")
            config_set_backup_local_path "$local_path"
            print_success "Local backups enabled at: $local_path"
            ;;
        2)
            print_info "NAS/S3 backup requires additional configuration."
            local nas_path
            nas_path=$(prompt_input "Enter NAS/S3 repository URL" "s3:http://nas.local:9000/backups")
            if [[ -n "$nas_path" ]]; then
                config_set_backup_nas_path "$nas_path"
                print_success "NAS backups enabled"
                print_warning "Remember to configure vault_nas_credentials and vault_restic_passwords.nas"
            fi
            ;;
        3)
            local local_path
            local_path=$(prompt_input "Enter local backup path" "/opt/server-helper/backups/restic")
            config_set_backup_local_path "$local_path"
            print_success "Local backups enabled at: $local_path"

            local nas_path
            nas_path=$(prompt_input "Enter NAS/S3 repository URL" "s3:http://nas.local:9000/backups")
            if [[ -n "$nas_path" ]]; then
                config_set_backup_nas_path "$nas_path"
                print_success "NAS backups enabled"
                print_warning "Remember to configure vault_nas_credentials and vault_restic_passwords.nas"
            fi
            ;;
        *)
            print_info "Using default local backup path"
            config_set_backup_local_path "/opt/server-helper/backups/restic"
            ;;
    esac
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

    # Network settings
    print_section "Network Settings"

    # DNS configuration
    if prompt_confirm "Configure DNS servers for Pi-hole?"; then
        config_setup_dns
    else
        print_info "Using default DNS (Cloudflare: 1.1.1.1, 1.0.0.1)"
    fi

    # Notification email
    if prompt_confirm "Configure notification email for security alerts?"; then
        config_setup_notification_email
    fi

    # Backup settings
    print_section "Backup Settings"

    if prompt_confirm "Configure backup destinations?"; then
        config_setup_backup_destination
    else
        print_info "Using default local backup path"
    fi

    # Service configuration (using presets to reduce form fatigue)
    config_setup_services_preset

    # Vault reminder
    echo ""
    print_section "Vault Configuration"
    print_warning "Vault secrets must be configured manually for security."
    echo "Required secrets include:"
    echo "  - vault_netdata_stream_api_key (for metrics streaming)"
    echo "  - vault_step_ca_password (for certificate authority)"
    echo "  - vault_control_grafana_password (for Grafana admin)"
    echo "  - vault_authentik_credentials (for SSO)"
    echo "  - vault_restic_passwords (for backups)"
    echo ""
    print_info "Edit group_vars/vault.yml and run: ./scripts/vault.sh encrypt"
    print_info "Or use: Extras menu -> Configure Secrets"

    print_success "Configuration complete!"
    print_info "Run 'make deploy' to apply the configuration"
}

# =============================================================================
# Quick Setup (Minimal Interaction)
# =============================================================================

# Quick setup with auto-detection and sensible defaults
# Only requires: domain and target server IPs
config_quick_setup() {
    print_header "Quick Setup (Auto-Configuration)"

    # Initialize config files if needed
    if ! config_check_files &>/dev/null; then
        config_init
    fi

    print_info "Auto-detecting system configuration..."
    echo ""

    # Auto-detect settings
    local detected_ip detected_tz detected_user detected_domain
    detected_ip=$(config_detect_ip)
    detected_tz=$(config_detect_timezone)
    detected_user=$(config_detect_user)
    detected_domain=$(config_detect_domain)

    print_success "Detected Control Node IP: $detected_ip"
    print_success "Detected Timezone: $detected_tz"
    print_success "Detected User: $detected_user"
    print_success "Detected Domain: $detected_domain"
    echo ""

    # Only prompt for domain (most likely to need customization)
    print_section "Domain Configuration"
    local domain
    domain=$(prompt_input "Enter your domain (or press Enter to accept)" "${detected_domain}")
    domain="${domain:-$detected_domain}"

    # Apply all settings
    print_section "Applying Configuration"

    # Check for remembered email, otherwise derive from domain
    local notification_email
    notification_email=$(prefs_get "email")
    if [[ -z "$notification_email" ]]; then
        notification_email="admin@${domain}"
    fi

    config_set_domain "$domain"
    config_set_control_ip "$detected_ip"
    config_set_timezone "$detected_tz"
    config_set_ansible_user "$detected_user"
    config_set_dns_servers "[1.1.1.1, 1.0.0.1]"
    config_set_notification_email "$notification_email"
    config_set_backup_local_path "/opt/server-helper/backups/restic"

    # Remember these values for future runs
    prefs_set "domain" "$domain"
    prefs_set "email" "$notification_email"

    # Service preset selection (quick but allows customization)
    print_section "Service Preset"
    echo "Quick setup uses the Homelab preset by default."
    echo "Presets: Full, Homelab, Monitoring, Minimal, Production"
    echo ""

    local preset_choice
    preset_choice=$(prompt_input_auto "Preset" "" "service_preset" "homelab")
    preset_choice=$(echo "$preset_choice" | tr '[:upper:]' '[:lower:]')

    # Validate preset choice
    case "$preset_choice" in
        full|homelab|monitoring|minimal|production)
            config_apply_preset "$preset_choice"
            prefs_set "service_preset" "$preset_choice"
            ;;
        *)
            print_warning "Unknown preset '$preset_choice', using homelab"
            preset_choice="homelab"
            config_apply_preset "homelab"
            ;;
    esac

    _show_preset_summary "$preset_choice"

    # Auto-generate secrets
    if prompt_confirm "Auto-generate all service passwords?"; then
        config_auto_generate_secrets
    fi

    echo ""
    print_success "Quick setup complete!"
    print_info "Configuration summary:"
    echo "  Domain:     $domain"
    echo "  Control IP: $detected_ip"
    echo "  Timezone:   $detected_tz"
    echo "  User:       $detected_user"
    echo ""
}

# Auto-generate all secrets and write to vault
config_auto_generate_secrets() {
    print_section "Auto-Generating Secrets"

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"

    # Create vault password if it doesn't exist
    if [[ ! -f "$password_file" ]]; then
        print_info "Creating vault password file..."
        openssl rand -base64 32 > "$password_file"
        chmod 600 "$password_file"
        print_success "Created: $password_file"
    fi

    # Generate all secrets
    local netdata_key grafana_pass pihole_pass traefik_pass dockge_pass
    local uptime_kuma_pass restic_pass stepca_pass
    local authentik_admin authentik_secret authentik_pg

    netdata_key=$(_generate_password 32)
    grafana_pass=$(_generate_password 16)
    pihole_pass=$(_generate_password 16)
    traefik_pass=$(_generate_password 16)
    dockge_pass=$(_generate_password 16)
    uptime_kuma_pass=$(_generate_password 16)
    restic_pass=$(_generate_password 32)
    stepca_pass=$(_generate_password 24)
    authentik_admin=$(_generate_password 16)
    authentik_secret=$(_generate_password 64)
    authentik_pg=$(_generate_password 24)

    # Write to vault file (unencrypted first)
    cat > "$CONFIG_VAULT_YML" << EOF
---
# Server Helper Vault (Auto-generated)
# =====================================
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Encrypt with: ansible-vault encrypt group_vars/vault.yml

# NAS Credentials (configure if using NAS backups)
vault_nas_credentials:
  - username: "backup_user"
    password: ""

# Backup Passwords (Restic)
vault_restic_passwords:
  nas: ""
  local: "$restic_pass"

# Cloud Provider Credentials (optional)
vault_aws_credentials:
  access_key: ""
  secret_key: ""

# Dockge Credentials
vault_dockge_credentials:
  username: "admin"
  password: "$dockge_pass"

# Authentik (SSO/Identity Provider)
vault_authentik_credentials:
  admin_password: "$authentik_admin"
  secret_key: "$authentik_secret"
  postgres_password: "$authentik_pg"

# Grafana OIDC (configure after Authentik setup)
vault_grafana_oidc:
  client_id: "grafana"
  client_secret: ""

# Grafana Admin
vault_control_grafana_password: "$grafana_pass"

# Uptime Kuma
vault_uptime_kuma_credentials:
  username: "admin"
  password: "$uptime_kuma_pass"

# Step-CA (Certificate Authority)
vault_step_ca_password: "$stepca_pass"

# Pi-hole
vault_pihole_password: "$pihole_pass"

# Traefik Dashboard
vault_traefik_dashboard:
  username: "admin"
  password: "$traefik_pass"

# Netdata Streaming API Key
vault_netdata_stream_api_key: "$netdata_key"
EOF

    print_success "Generated all secrets in $CONFIG_VAULT_YML"

    # Encrypt the vault
    print_info "Encrypting vault..."
    if ansible-vault encrypt "$CONFIG_VAULT_YML" --vault-password-file="$password_file" 2>/dev/null; then
        print_success "Vault encrypted successfully"
    else
        print_warning "Could not encrypt vault - please run: ansible-vault encrypt group_vars/vault.yml"
    fi

    # Show generated passwords for user to save
    echo ""
    print_warning "SAVE THESE PASSWORDS SECURELY!"
    echo "─────────────────────────────────────────"
    echo "Grafana Admin:      $grafana_pass"
    echo "Pi-hole:            $pihole_pass"
    echo "Traefik Dashboard:  $traefik_pass"
    echo "Dockge:             $dockge_pass"
    echo "Uptime Kuma:        $uptime_kuma_pass"
    echo "Authentik Admin:    $authentik_admin"
    echo "Step-CA:            $stepca_pass"
    echo "Restic Backup:      $restic_pass"
    echo "─────────────────────────────────────────"
    echo ""

    if prompt_confirm "Save passwords to file? (passwords.txt)"; then
        cat > passwords.txt << EOF
# Server Helper Passwords
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DELETE THIS FILE AFTER SAVING PASSWORDS SECURELY!

Grafana Admin:      $grafana_pass
Pi-hole:            $pihole_pass
Traefik Dashboard:  $traefik_pass
Dockge:             $dockge_pass
Uptime Kuma:        $uptime_kuma_pass
Authentik Admin:    $authentik_admin
Step-CA:            $stepca_pass
Restic Backup:      $restic_pass
Netdata API Key:    $netdata_key
EOF
        chmod 600 passwords.txt
        print_success "Passwords saved to passwords.txt"
        print_warning "DELETE this file after saving passwords to a password manager!"
    fi
}

# Choose setup mode
config_choose_setup_mode() {
    print_header "Configuration Setup"
    echo ""
    echo "Choose setup mode:"
    echo ""
    echo "  1) Quick Setup    - Auto-detect settings, minimal prompts"
    echo "                      Best for: Getting started quickly"
    echo ""
    echo "  2) Advanced Setup - Step-by-step configuration wizard"
    echo "                      Best for: Customizing every option"
    echo ""

    local choice
    choice=$(prompt_input "Choose setup mode [1-2]" "1")

    case "$choice" in
        1)
            config_quick_setup
            ;;
        2)
            config_wizard
            ;;
        *)
            print_info "Defaulting to quick setup"
            config_quick_setup
            ;;
    esac
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

    # Restic Backup Password (Local)
    print_section "Restic Backups"
    local restic_pass
    restic_pass=$(_vault_get "vault_restic_passwords.local")
    if _vault_is_placeholder "$restic_pass"; then
        print_warning "Restic local backup password needs configuration"
        if new_value=$(config_prompt_secret "Restic Local Password" "Encryption password for local backups" "" "true"); then
            temp_values+="restic_pass=$new_value\n"
            changes_made=true
        fi
    else
        print_success "Restic local password: configured"
    fi

    # Restic NAS Password (optional)
    local restic_nas_pass
    restic_nas_pass=$(_vault_get "vault_restic_passwords.nas")
    if _vault_is_placeholder "$restic_nas_pass"; then
        if prompt_confirm "Configure NAS backup password?"; then
            if new_value=$(config_prompt_secret "Restic NAS Password" "Encryption password for NAS backups" "" "true"); then
                temp_values+="restic_nas_pass=$new_value\n"
                changes_made=true
            fi
        fi
    else
        print_success "Restic NAS password: configured"
    fi

    # NAS Credentials (optional)
    print_section "NAS Credentials (Optional)"
    local nas_user
    nas_user=$(_vault_get "vault_nas_credentials.0.username")
    if [[ -z "$nas_user" ]] || [[ "$nas_user" == "backup_user" ]]; then
        if prompt_confirm "Configure NAS/S3 access credentials?"; then
            local nas_username
            nas_username=$(prompt_input "NAS/S3 username" "backup_user")
            if new_value=$(config_prompt_secret "NAS/S3 Password" "Access password for NAS or S3 storage" "" "true"); then
                temp_values+="nas_user=$nas_username\n"
                temp_values+="nas_pass=$new_value\n"
                changes_made=true
            fi
        fi
    else
        print_success "NAS credentials: configured"
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
                    traefik_pass) echo "vault_traefik_dashboard:" ; echo "  password: \"$value\"" ;;
                    dockge_pass) echo "vault_dockge_credentials:" ; echo "  password: \"$value\"" ;;
                    uptime_kuma_pass) echo "vault_uptime_kuma_credentials:" ; echo "  password: \"$value\"" ;;
                    restic_pass) echo "vault_restic_passwords:" ; echo "  local: \"$value\"" ;;
                    restic_nas_pass) echo "  nas: \"$value\"" ;;
                    nas_user) echo "vault_nas_credentials:" ; echo "  - username: \"$value\"" ;;
                    nas_pass) echo "    password: \"$value\"" ;;
                    stepca_pass) echo "vault_step_ca_password: \"$value\"" ;;
                    authentik_admin) echo "vault_authentik_credentials:" ; echo "  admin_password: \"$value\"" ;;
                    authentik_secret) echo "  secret_key: \"$value\"" ;;
                    authentik_pg) echo "  postgres_password: \"$value\"" ;;
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
