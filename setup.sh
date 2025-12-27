#!/usr/bin/env bash
#
# Server Helper v1.0.0 - Automated Setup Script
# ==============================================
# This script installs all dependencies and runs the Ansible playbook
# with interactive configuration prompts.
#
# Usage: ./setup.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Log file
LOG_FILE="${SCRIPT_DIR}/setup.log"

# Function to print colored messages
print_header() {
    echo -e "\n${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║  Server Helper v1.0.0 Setup            ║${NC}"
    echo -e "${BLUE}${BOLD}║  Ansible + Docker + Monitoring         ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to log and execute commands
log_exec() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root"
        print_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
}

# Check if user has sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_info "This script requires sudo privileges"
        sudo -v || exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS version"
        exit 1
    fi

    print_info "Detected OS: $OS $OS_VERSION"

    if [[ "$OS" != "ubuntu" ]]; then
        print_warning "This script is designed for Ubuntu 24.04 LTS"
        print_warning "Detected: $OS $OS_VERSION"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install system dependencies
install_system_deps() {
    print_header
    print_info "Installing system dependencies..."

    log_exec sudo apt-get update -qq

    # Check if packages are already installed
    local packages=("ansible" "python3-pip" "git" "curl" "wget" "sshpass")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "Installing packages: ${to_install[*]}"
        log_exec sudo apt-get install -y -qq "${to_install[@]}"
    else
        print_success "All system packages already installed"
    fi

    # Verify Ansible installation
    if command -v ansible >/dev/null 2>&1; then
        ANSIBLE_VERSION=$(ansible --version | head -n1)
        print_success "Ansible installed: $ANSIBLE_VERSION"
    else
        print_error "Ansible installation failed"
        exit 1
    fi
}

# Install Python dependencies
install_python_deps() {
    print_info "Installing Python dependencies..."

    if [[ -f requirements.txt ]]; then
        log_exec pip3 install --user -q -r requirements.txt
        print_success "Python dependencies installed"
    else
        print_warning "requirements.txt not found, skipping Python dependencies"
    fi
}

# Install Ansible Galaxy requirements
install_galaxy_deps() {
    print_info "Installing Ansible Galaxy collections and roles..."

    if [[ -f requirements.yml ]]; then
        log_exec ansible-galaxy install -r requirements.yml
        print_success "Ansible Galaxy dependencies installed"
    else
        print_error "requirements.yml not found"
        exit 1
    fi
}

# Prompt for configuration values
prompt_config() {
    print_header
    print_info "Configuration Setup"
    print_info "Press Enter to use default values shown in [brackets]"
    echo

    # System configuration
    echo -e "${BOLD}System Configuration:${NC}"
    read -p "Server hostname [server-01]: " HOSTNAME
    HOSTNAME=${HOSTNAME:-server-01}

    read -p "Timezone [America/New_York]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-America/New_York}

    # NAS configuration
    echo
    echo -e "${BOLD}NAS Configuration:${NC}"
    read -p "Enable NAS mounts? (y/N): " -n 1 -r ENABLE_NAS
    echo
    ENABLE_NAS=${ENABLE_NAS:-n}

    if [[ $ENABLE_NAS =~ ^[Yy]$ ]]; then
        read -p "NAS IP address [192.168.1.100]: " NAS_IP
        NAS_IP=${NAS_IP:-192.168.1.100}

        read -p "NAS share name [backup]: " NAS_SHARE
        NAS_SHARE=${NAS_SHARE:-backup}

        read -p "NAS mount point [/mnt/nas/backup]: " NAS_MOUNT
        NAS_MOUNT=${NAS_MOUNT:-/mnt/nas/backup}

        read -p "NAS username: " NAS_USER
        read -sp "NAS password: " NAS_PASS
        echo
    fi

    # Backup configuration
    echo
    echo -e "${BOLD}Backup Configuration:${NC}"
    read -p "Enable backups (Restic)? (Y/n): " -n 1 -r ENABLE_BACKUPS
    echo
    ENABLE_BACKUPS=${ENABLE_BACKUPS:-y}

    if [[ $ENABLE_BACKUPS =~ ^[Yy]$ ]]; then
        read -p "Backup schedule (cron format) [0 2 * * *]: " BACKUP_SCHEDULE
        BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-0 2 * * *}

        read -p "Enable NAS backup destination? (Y/n): " -n 1 -r BACKUP_NAS
        echo
        BACKUP_NAS=${BACKUP_NAS:-y}

        if [[ $BACKUP_NAS =~ ^[Yy]$ ]]; then
            read -sp "Restic NAS repository password: " RESTIC_NAS_PASS
            echo
        fi

        read -p "Enable local backup destination? (Y/n): " -n 1 -r BACKUP_LOCAL
        echo
        BACKUP_LOCAL=${BACKUP_LOCAL:-y}

        if [[ $BACKUP_LOCAL =~ ^[Yy]$ ]]; then
            read -sp "Restic local repository password: " RESTIC_LOCAL_PASS
            echo
        fi

        read -p "Enable S3 backup destination? (y/N): " -n 1 -r BACKUP_S3
        echo
        BACKUP_S3=${BACKUP_S3:-n}

        if [[ $BACKUP_S3 =~ ^[Yy]$ ]]; then
            read -p "S3 bucket name: " S3_BUCKET
            read -p "S3 region [us-east-1]: " S3_REGION
            S3_REGION=${S3_REGION:-us-east-1}
            read -p "AWS access key ID: " AWS_ACCESS_KEY
            read -sp "AWS secret access key: " AWS_SECRET_KEY
            echo
            read -sp "Restic S3 repository password: " RESTIC_S3_PASS
            echo
        fi
    fi

    # Monitoring configuration
    echo
    echo -e "${BOLD}Monitoring Configuration:${NC}"
    read -p "Enable Netdata? (Y/n): " -n 1 -r ENABLE_NETDATA
    echo
    ENABLE_NETDATA=${ENABLE_NETDATA:-y}

    if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]]; then
        read -p "Netdata port [19999]: " NETDATA_PORT
        NETDATA_PORT=${NETDATA_PORT:-19999}

        read -p "Netdata Cloud claim token (optional): " NETDATA_CLAIM_TOKEN
    fi

    read -p "Enable Uptime Kuma? (Y/n): " -n 1 -r ENABLE_UPTIME_KUMA
    echo
    ENABLE_UPTIME_KUMA=${ENABLE_UPTIME_KUMA:-y}

    if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then
        read -p "Uptime Kuma port [3001]: " UPTIME_KUMA_PORT
        UPTIME_KUMA_PORT=${UPTIME_KUMA_PORT:-3001}
    fi

    # Container management
    echo
    echo -e "${BOLD}Container Management:${NC}"
    read -p "Enable Dockge? (Y/n): " -n 1 -r ENABLE_DOCKGE
    echo
    ENABLE_DOCKGE=${ENABLE_DOCKGE:-y}

    if [[ $ENABLE_DOCKGE =~ ^[Yy]$ ]]; then
        read -p "Dockge port [5001]: " DOCKGE_PORT
        DOCKGE_PORT=${DOCKGE_PORT:-5001}
    fi

    # Security configuration
    echo
    echo -e "${BOLD}Security Configuration:${NC}"
    read -p "Enable fail2ban? (Y/n): " -n 1 -r ENABLE_FAIL2BAN
    echo
    ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN:-y}

    read -p "Enable UFW firewall? (Y/n): " -n 1 -r ENABLE_UFW
    echo
    ENABLE_UFW=${ENABLE_UFW:-y}

    read -p "Enable SSH hardening? (Y/n): " -n 1 -r ENABLE_SSH_HARDENING
    echo
    ENABLE_SSH_HARDENING=${ENABLE_SSH_HARDENING:-y}

    if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]$ ]]; then
        read -p "SSH port [22]: " SSH_PORT
        SSH_PORT=${SSH_PORT:-22}

        read -p "Disable SSH password authentication? (Y/n): " -n 1 -r SSH_NO_PASSWORD
        echo
        SSH_NO_PASSWORD=${SSH_NO_PASSWORD:-y}

        read -p "Disable SSH root login? (Y/n): " -n 1 -r SSH_NO_ROOT
        echo
        SSH_NO_ROOT=${SSH_NO_ROOT:-y}
    fi

    read -p "Enable Lynis security scanning? (Y/n): " -n 1 -r ENABLE_LYNIS
    echo
    ENABLE_LYNIS=${ENABLE_LYNIS:-y}

    # Inventory configuration
    echo
    echo -e "${BOLD}Target Server Configuration:${NC}"
    read -p "Target server IP/hostname [localhost]: " TARGET_HOST
    TARGET_HOST=${TARGET_HOST:-localhost}

    read -p "SSH username for target server [$USER]: " TARGET_USER
    TARGET_USER=${TARGET_USER:-$USER}

    echo
    print_success "Configuration complete!"
}

# Create inventory file
create_inventory() {
    print_info "Creating inventory file..."

    local inventory_file="inventory/hosts.yml"

    cat > "$inventory_file" <<EOF
# Server Helper Inventory
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

---
all:
  hosts:
    ${HOSTNAME}:
      ansible_host: ${TARGET_HOST}
      ansible_user: ${TARGET_USER}
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3

  children:
    servers:
      hosts:
        ${HOSTNAME}:

  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

    print_success "Inventory file created: $inventory_file"
}

# Create main configuration file
create_config() {
    print_info "Creating configuration file..."

    local config_file="group_vars/all.yml"

    cat > "$config_file" <<EOF
# Server Helper Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

---
# System Configuration
hostname: "${HOSTNAME}"
timezone: "${TIMEZONE}"
locale: "en_US.UTF-8"
base_install_dir: "/opt"

# NAS Configuration
nas_mounts:
  enabled: $(if [[ $ENABLE_NAS =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $ENABLE_NAS =~ ^[Yy]$ ]]; then cat <<EON

nas:
  enabled: true
  shares:
    - ip: "${NAS_IP}"
      share: "${NAS_SHARE}"
      mount: "${NAS_MOUNT}"
      username: "{{ vault_nas_credentials[0].username }}"
      password: "{{ vault_nas_credentials[0].password }}"
      options: "vers=3.0,_netdev,nofail"
EON
fi)

# Backup Configuration
backups:
  enabled: $(if [[ $ENABLE_BACKUPS =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)

$(if [[ $ENABLE_BACKUPS =~ ^[Yy]$ ]]; then cat <<EOB
restic:
  enabled: true
  schedule: "${BACKUP_SCHEDULE}"

  retention:
    keep_daily: 7
    keep_weekly: 4
    keep_monthly: 6
    keep_yearly: 2

  destinations:
    nas:
      enabled: $(if [[ $BACKUP_NAS =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
      path: "${NAS_MOUNT}/restic"
      password: "{{ vault_restic_passwords.nas }}"

    local:
      enabled: $(if [[ $BACKUP_LOCAL =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
      path: "/opt/backups/restic"
      password: "{{ vault_restic_passwords.local }}"

    s3:
      enabled: $(if [[ $BACKUP_S3 =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $BACKUP_S3 =~ ^[Yy]$ ]]; then cat <<EOS3
      bucket: "${S3_BUCKET}"
      endpoint: "s3.amazonaws.com"
      region: "${S3_REGION}"
      access_key: "{{ vault_aws_credentials.access_key }}"
      secret_key: "{{ vault_aws_credentials.secret_key }}"
      password: "{{ vault_restic_passwords.s3 }}"
EOS3
fi)

    b2:
      enabled: false

  backup_paths:
    - /opt/dockge/stacks
    - /opt/dockge/data
    - /etc
    - /home

  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - ".cache"
    - "__pycache__"

  uptime_kuma_push_url: ""
EOB
fi)

# Monitoring Configuration
monitoring:
  enabled: $(if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]] || [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)

$(if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]]; then cat <<EON
  netdata:
    enabled: true
    port: ${NETDATA_PORT}
    claim_token: "${NETDATA_CLAIM_TOKEN}"
    claim_rooms: ""

    alarms:
      enabled: true
      cpu_warning: 80
      cpu_critical: 95
      ram_warning: 80
      ram_critical: 95
      disk_warning: 80
      disk_critical: 90
EON
else
echo "  netdata:"
echo "    enabled: false"
fi)

$(if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then cat <<EOK
  uptime_kuma:
    enabled: true
    port: ${UPTIME_KUMA_PORT}
    admin_username: "admin"
    admin_password: "{{ vault_uptime_kuma_credentials.password }}"

    monitors:
      - name: "Netdata Health"
        type: "http"
        url: "http://localhost:${NETDATA_PORT}/api/v1/info"
        interval: 60

      - name: "Dockge Health"
        type: "http"
        url: "http://localhost:${DOCKGE_PORT}"
        interval: 60
EOK
else
echo "  uptime_kuma:"
echo "    enabled: false"
fi)

# Container Management
dockge:
  enabled: $(if [[ $ENABLE_DOCKGE =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
  port: ${DOCKGE_PORT:-5001}
  stacks_dir: "/opt/dockge/stacks"
  data_dir: "/opt/dockge/data"
  admin_username: "admin"
  admin_password: "{{ vault_dockge_credentials.password }}"

# Security Configuration
security:
  fail2ban_enabled: $(if [[ $ENABLE_FAIL2BAN =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
  fail2ban_bantime: 3600
  fail2ban_maxretry: 5

  ufw_enabled: $(if [[ $ENABLE_UFW =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
  ufw_default_policy: "deny"
  ufw_allowed_ports:
    - ${SSH_PORT:-22}
$(if [[ $ENABLE_DOCKGE =~ ^[Yy]$ ]]; then echo "    - ${DOCKGE_PORT}"; fi)
$(if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]]; then echo "    - ${NETDATA_PORT}"; fi)
$(if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then echo "    - ${UPTIME_KUMA_PORT}"; fi)

  ssh_hardening: $(if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
  ssh_port: ${SSH_PORT:-22}
  ssh_password_authentication: $(if [[ $SSH_NO_PASSWORD =~ ^[Yy]$ ]]; then echo "false"; else echo "true"; fi)
  ssh_permit_root_login: $(if [[ $SSH_NO_ROOT =~ ^[Yy]$ ]]; then echo "false"; else echo "true"; fi)
  ssh_max_auth_tries: 3
  ssh_client_alive_interval: 300

  lynis_enabled: $(if [[ $ENABLE_LYNIS =~ ^[Yy]$ ]]; then echo "true"; else echo "false"; fi)
  lynis_schedule: "0 3 * * 0"
  lynis_uptime_kuma_push_url: ""

  unattended_upgrades: true
  auto_reboot: false
  auto_reboot_time: "03:00"

# Optional Services
watchtower:
  enabled: false
  schedule: "0 4 * * *"
  cleanup: true
  monitor_only: false

reverse_proxy:
  enabled: false

# Self-Update Configuration
self_update:
  enabled: true
  schedule: "0 5 * * *"
  git_repo: "https://github.com/thelasttenno/Server-Helper.git"
  branch: "main"
  version: "v1.0.0"
  playbook: "playbooks/setup.yml"
  log_file: "/var/log/ansible-pull.log"
  check_only: false

# Docker Configuration
docker:
  edition: "ce"
  compose_version: "2.23.0"
  daemon_config:
    log_driver: "json-file"
    log_opts:
      max_size: "10m"
      max_file: "3"
    storage_driver: "overlay2"

  networks:
    - name: "monitoring"
      driver: "bridge"
    - name: "proxy"
      driver: "bridge"

# Notifications
notifications:
  email:
    enabled: false
  discord:
    enabled: false
  telegram:
    enabled: false

# Logging
logging:
  level: "INFO"
  retention_days: 30

# Performance
performance:
  max_parallel_tasks: 10
  connection_timeout: 30

# Feature flags
features:
  experimental: false
  debug_mode: false
EOF

    print_success "Configuration file created: $config_file"
}

# Create vault file with secrets
create_vault() {
    print_info "Creating Ansible Vault for secrets..."

    # Generate vault password
    local vault_password_file=".vault_password"
    if [[ ! -f "$vault_password_file" ]]; then
        openssl rand -base64 32 > "$vault_password_file"
        chmod 600 "$vault_password_file"
        print_success "Generated vault password: $vault_password_file"
    else
        print_info "Using existing vault password file"
    fi

    local vault_file="group_vars/vault.yml"

    # Create temporary unencrypted vault file
    local temp_vault="/tmp/vault_temp_$$.yml"

    cat > "$temp_vault" <<EOF
---
# Ansible Vault - Encrypted Secrets
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# NAS Credentials
$(if [[ $ENABLE_NAS =~ ^[Yy]$ ]]; then cat <<EON
vault_nas_credentials:
  - username: "${NAS_USER}"
    password: "${NAS_PASS}"
EON
else
echo "vault_nas_credentials: []"
fi)

# Restic Passwords
vault_restic_passwords:
$(if [[ $BACKUP_NAS =~ ^[Yy]$ ]]; then echo "  nas: \"${RESTIC_NAS_PASS}\""; else echo "  nas: \"\""; fi)
$(if [[ $BACKUP_LOCAL =~ ^[Yy]$ ]]; then echo "  local: \"${RESTIC_LOCAL_PASS}\""; else echo "  local: \"\""; fi)
$(if [[ $BACKUP_S3 =~ ^[Yy]$ ]]; then echo "  s3: \"${RESTIC_S3_PASS}\""; else echo "  s3: \"\""; fi)
  b2: ""

# Cloud Provider Credentials
$(if [[ $BACKUP_S3 =~ ^[Yy]$ ]]; then cat <<EOS3
vault_aws_credentials:
  access_key: "${AWS_ACCESS_KEY}"
  secret_key: "${AWS_SECRET_KEY}"
EOS3
else
cat <<EOS3
vault_aws_credentials:
  access_key: ""
  secret_key: ""
EOS3
fi)

vault_b2_credentials:
  account_id: ""
  account_key: ""

# Service Admin Credentials
vault_dockge_credentials:
  username: "admin"
  password: "changeme-on-first-login"

vault_uptime_kuma_credentials:
  username: "admin"
  password: "changeme-on-first-login"

# Monitoring & Observability
vault_netdata_claim_token: "${NETDATA_CLAIM_TOKEN}"

vault_uptime_kuma_push_urls:
  nas: ""
  dockge: ""
  system: ""
  backup: ""
  security: ""
  update: ""

# Notification Services
vault_smtp_credentials:
  host: "smtp.gmail.com"
  port: 587
  username: ""
  password: ""
  from_address: ""
  to_addresses: []

vault_discord_webhook: ""

vault_telegram_credentials:
  bot_token: ""
  chat_id: ""

vault_slack_webhook: ""

# Reverse Proxy / SSL
vault_letsencrypt_email: ""

vault_cloudflare_credentials:
  api_token: ""
  zone_id: ""
EOF

    # Encrypt the vault file
    ansible-vault encrypt "$temp_vault" --vault-password-file="$vault_password_file" --output="$vault_file"
    rm -f "$temp_vault"

    print_success "Encrypted vault file created: $vault_file"
    print_warning "Keep your vault password file secure: $vault_password_file"
}

# Run pre-flight checks
preflight_checks() {
    print_header
    print_info "Running pre-flight checks..."

    # Check if ansible.cfg exists
    if [[ ! -f ansible.cfg ]]; then
        print_warning "ansible.cfg not found, using defaults"
    fi

    # Check if inventory exists
    if [[ ! -f inventory/hosts.yml ]]; then
        print_error "Inventory file not found"
        return 1
    fi

    # Check if config exists
    if [[ ! -f group_vars/all.yml ]]; then
        print_error "Configuration file not found"
        return 1
    fi

    # Check if vault exists
    if [[ ! -f group_vars/vault.yml ]]; then
        print_error "Vault file not found"
        return 1
    fi

    # Test Ansible connectivity
    print_info "Testing Ansible connectivity..."
    if ansible all -m ping &>/dev/null; then
        print_success "Ansible connectivity test passed"
    else
        print_warning "Ansible connectivity test failed (this may be normal if target is remote)"
    fi

    print_success "Pre-flight checks complete"
}

# Run Ansible playbook
run_playbook() {
    print_header
    print_info "Running Ansible playbook..."
    echo

    print_warning "This will configure your server with:"
    if [[ $ENABLE_DOCKGE =~ ^[Yy]$ ]]; then echo "  - Dockge (Container Management)"; fi
    if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]]; then echo "  - Netdata (Monitoring)"; fi
    if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then echo "  - Uptime Kuma (Alerting)"; fi
    if [[ $ENABLE_BACKUPS =~ ^[Yy]$ ]]; then echo "  - Restic Backups"; fi
    if [[ $ENABLE_FAIL2BAN =~ ^[Yy]$ ]]; then echo "  - fail2ban (Security)"; fi
    if [[ $ENABLE_UFW =~ ^[Yy]$ ]]; then echo "  - UFW Firewall"; fi
    echo

    read -p "Continue with installation? (yes/no): " -r CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy][Ee][Ss]$ ]]; then
        print_warning "Installation cancelled by user"
        exit 0
    fi

    echo
    print_info "Starting playbook execution..."
    print_info "This may take 10-20 minutes depending on your system"
    echo

    # Run the playbook with verbose output
    if ansible-playbook playbooks/setup.yml -v; then
        print_success "Playbook execution completed successfully!"
        show_completion_message
    else
        print_error "Playbook execution failed"
        print_info "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Show completion message with service URLs
show_completion_message() {
    print_header
    print_success "Server Helper setup complete!"
    echo

    print_info "Access your services:"
    if [[ $ENABLE_DOCKGE =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}Dockge:${NC}      http://${TARGET_HOST}:${DOCKGE_PORT}"
    fi
    if [[ $ENABLE_NETDATA =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}Netdata:${NC}     http://${TARGET_HOST}:${NETDATA_PORT}"
    fi
    if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}Uptime Kuma:${NC} http://${TARGET_HOST}:${UPTIME_KUMA_PORT}"
    fi
    echo

    print_info "Next steps:"
    echo "  1. Change default admin passwords on first login"
    if [[ $ENABLE_UPTIME_KUMA =~ ^[Yy]$ ]]; then
        echo "  2. Configure Uptime Kuma notification endpoints"
    fi
    if [[ $ENABLE_BACKUPS =~ ^[Yy]$ ]]; then
        echo "  3. Verify backup repositories are initialized"
    fi
    echo "  4. Review security settings and firewall rules"
    echo

    print_info "Useful commands:"
    echo "  - View service status: ansible all -m shell -a 'docker ps'"
    echo "  - Run backup manually: ansible-playbook playbooks/backup.yml"
    echo "  - Security audit: ansible-playbook playbooks/security.yml"
    echo "  - Update system: ansible-playbook playbooks/update.yml"
    echo

    print_info "Documentation:"
    echo "  - README: ${SCRIPT_DIR}/README.md"
    echo "  - Vault Guide: ${SCRIPT_DIR}/VAULT_GUIDE.md"
    echo "  - Migration Guide: ${SCRIPT_DIR}/MIGRATION.md"
    echo
}

# Main execution flow
main() {
    print_header

    # Initialize log file
    echo "=== Server Helper Setup Log ===" > "$LOG_FILE"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo >> "$LOG_FILE"

    # Pre-requisite checks
    check_not_root
    check_sudo
    detect_os

    # Install dependencies
    install_system_deps
    install_python_deps
    install_galaxy_deps

    # Configuration
    prompt_config
    create_inventory
    create_config
    create_vault

    # Pre-flight checks
    preflight_checks

    # Run playbook
    run_playbook

    print_success "Setup script completed"
    print_info "Log file: $LOG_FILE"
}

# Run main function
main "$@"
