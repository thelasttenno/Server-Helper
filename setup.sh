#!/usr/bin/env bash
#
# Server Helper v1.0.0 - Command Node Setup Script
# =================================================
# This script prepares your COMMAND NODE to manage target servers with Ansible.
# Run this on your laptop/desktop/control machine, NOT on target servers.
#
# What this does:
#   1. Installs Ansible and dependencies on this command node
#   2. Prompts for target server configuration
#   3. Creates inventory file with your target nodes
#   4. Creates configuration and vault files
#   5. Tests connectivity to target nodes
#   6. Runs Ansible playbooks against target servers
#
# For target servers, run bootstrap-target.sh on each node first, OR
# run: ansible-playbook playbooks/bootstrap.yml
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
    echo -e "${BLUE}${BOLD}║  Command Node Configuration            ║${NC}"
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
        print_error "This script should NOT be run as root on the command node"
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
        read -p "Continue anyway? (y/N): " -r
        echo
        if [[ ! $REPLY =~ ^[Yy]([Ee][Ss])?$ ]]; then
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
        # Use system packages instead of pip to avoid PEP 668 issues on Debian/Ubuntu
        local python_packages=(
            "python3-docker"
            "python3-jmespath"
            "python3-netaddr"
            "python3-requests"
        )

        local to_install=()
        for pkg in "${python_packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $pkg "; then
                to_install+=("$pkg")
            fi
        done

        if [[ ${#to_install[@]} -gt 0 ]]; then
            print_info "Installing Python packages: ${to_install[*]}"
            log_exec sudo apt-get install -y -qq "${to_install[@]}"
            print_success "Python dependencies installed"
        else
            print_success "All Python dependencies already installed"
        fi
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

# Prompt for target nodes
prompt_target_nodes() {
    print_header
    print_info "Target Server Configuration"
    print_info "Enter details for servers you want to manage with Ansible"
    echo

    # Initialize arrays
    TARGET_HOSTS=()
    TARGET_HOSTNAMES=()
    TARGET_USERS=()

    # Prompt for number of targets
    read -p "How many target servers do you want to configure? [1]: " NUM_TARGETS
    NUM_TARGETS=${NUM_TARGETS:-1}

    # SSH authentication method
    echo
    echo -e "${BOLD}SSH Authentication:${NC}"
    read -p "Use SSH key authentication? (recommended) (Y/n): " -r USE_SSH_KEYS_INPUT
    echo
    USE_SSH_KEYS=${USE_SSH_KEYS_INPUT:-y}
    USE_SSH_KEYS=$(echo "$USE_SSH_KEYS" | tr '[:upper:]' '[:lower:]')

    if [[ "$USE_SSH_KEYS" =~ ^[yY]([eE][sS])?$ ]]; then
        USE_SSH_KEYS="yes"
        print_success "Using SSH key authentication"

        # Check if SSH key exists
        if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
            print_warning "No SSH key found at ~/.ssh/id_rsa.pub"
            read -p "Generate SSH key pair now? (Y/n): " -r GEN_KEY
            echo
            if [[ ! $GEN_KEY =~ ^[Nn]$ ]]; then
                ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
                print_success "SSH key generated"
            fi
        fi
    else
        USE_SSH_KEYS="no"
        print_warning "Password authentication will be used (less secure)"
    fi

    # Collect target server details
    for ((i=0; i<NUM_TARGETS; i++)); do
        echo
        echo -e "${BOLD}Target Server $((i+1)) of ${NUM_TARGETS}:${NC}"

        # Hostname
        read -p "Hostname/identifier [server-$(printf "%02d" $((i+1)))]: " TARGET_HOSTNAME
        TARGET_HOSTNAME=${TARGET_HOSTNAME:-server-$(printf "%02d" $((i+1)))}
        TARGET_HOSTNAMES+=("$TARGET_HOSTNAME")

        # IP/Hostname
        read -p "IP address or DNS name: " TARGET_HOST
        while [[ -z "$TARGET_HOST" ]]; do
            print_error "IP address or DNS name is required"
            read -p "IP address or DNS name: " TARGET_HOST
        done
        TARGET_HOSTS+=("$TARGET_HOST")

        # SSH user
        read -p "SSH username [ansible]: " TARGET_USER
        TARGET_USER=${TARGET_USER:-ansible}
        TARGET_USERS+=("$TARGET_USER")

        # Test SSH connectivity and copy keys if needed
        print_info "Testing SSH connectivity to ${TARGET_HOST}..."
        if [[ "$USE_SSH_KEYS" == "yes" ]]; then
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_HOST}" "echo 'Connected'" &>/dev/null; then
                print_success "SSH key already configured for ${TARGET_HOSTNAME}"
            else
                print_warning "SSH key not configured for ${TARGET_HOSTNAME}"
                read -p "Copy SSH key to ${TARGET_HOST} now? (requires password) (Y/n): " -r COPY_KEY
                echo
                if [[ ! $COPY_KEY =~ ^[Nn]$ ]]; then
                    print_info "Copying SSH key to ${TARGET_USER}@${TARGET_HOST}..."
                    print_info "You will be prompted for the password on ${TARGET_HOST}"
                    if ssh-copy-id -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_HOST}"; then
                        print_success "SSH key copied successfully to ${TARGET_HOSTNAME}"
                    else
                        print_error "Failed to copy SSH key to ${TARGET_HOSTNAME}"
                        print_info "You may need to:"
                        print_info "  1. Enable password auth on target: sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
                        print_info "  2. Or manually copy the key: ssh-copy-id ${TARGET_USER}@${TARGET_HOST}"
                    fi
                else
                    print_warning "Skipping SSH key copy for ${TARGET_HOSTNAME}"
                    print_info "You can manually run: ssh-copy-id ${TARGET_USER}@${TARGET_HOST}"
                fi
            fi
        else
            print_warning "Skipping connectivity test (password auth mode)"
        fi
    done

    echo
    print_success "Target server configuration complete"
    print_info "Configured ${#TARGET_HOSTS[@]} target node(s)"
}

# Prompt for configuration values
prompt_config() {
    print_header
    print_info "Service Configuration"
    print_info "Press Enter to use default values shown in [brackets]"
    echo

    # System configuration
    echo -e "${BOLD}System Configuration:${NC}"
    read -p "Default hostname prefix [server]: " HOSTNAME_PREFIX
    HOSTNAME_PREFIX=${HOSTNAME_PREFIX:-server}

    read -p "Timezone [America/New_York]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-America/New_York}

    # NAS configuration
    echo
    echo -e "${BOLD}NAS Configuration:${NC}"
    read -p "Enable NAS mounts? (y/N): " -r ENABLE_NAS
    echo
    ENABLE_NAS=${ENABLE_NAS:-n}

    if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then
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
    read -p "Enable backups (Restic)? (Y/n): " -r ENABLE_BACKUPS
    echo
    ENABLE_BACKUPS=${ENABLE_BACKUPS:-y}

    if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "Backup schedule (cron format) [0 2 * * *]: " BACKUP_SCHEDULE
        BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-0 2 * * *}

        read -p "Enable NAS backup destination? (Y/n): " -r BACKUP_NAS
        echo
        BACKUP_NAS=${BACKUP_NAS:-y}

        if [[ $BACKUP_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -sp "Restic NAS repository password: " RESTIC_NAS_PASS
            echo
        fi

        read -p "Enable local backup destination? (Y/n): " -r BACKUP_LOCAL
        echo
        BACKUP_LOCAL=${BACKUP_LOCAL:-y}

        if [[ $BACKUP_LOCAL =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -sp "Restic local repository password: " RESTIC_LOCAL_PASS
            echo
        fi

        read -p "Enable S3 backup destination? (y/N): " -r BACKUP_S3
        echo
        BACKUP_S3=${BACKUP_S3:-n}

        if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then
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
    read -p "Enable Netdata? (Y/n): " -r ENABLE_NETDATA
    echo
    ENABLE_NETDATA=${ENABLE_NETDATA:-y}

    if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "Netdata port [19999]: " NETDATA_PORT
        NETDATA_PORT=${NETDATA_PORT:-19999}

        read -p "Netdata Cloud claim token (optional): " NETDATA_CLAIM_TOKEN
    fi

    # Note: Uptime Kuma is installed on command node only via setup-control.yml

    # Container management
    echo
    echo -e "${BOLD}Container Management:${NC}"
    read -p "Enable Dockge? (Y/n): " -r ENABLE_DOCKGE
    echo
    ENABLE_DOCKGE=${ENABLE_DOCKGE:-y}

    if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "Dockge port [5001]: " DOCKGE_PORT
        DOCKGE_PORT=${DOCKGE_PORT:-5001}
    fi

    # Security configuration
    echo
    echo -e "${BOLD}Security Configuration:${NC}"
    read -p "Enable fail2ban? (Y/n): " -r ENABLE_FAIL2BAN
    echo
    ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN:-y}

    read -p "Enable UFW firewall? (Y/n): " -r ENABLE_UFW
    echo
    ENABLE_UFW=${ENABLE_UFW:-y}

    read -p "Enable SSH hardening? (Y/n): " -r ENABLE_SSH_HARDENING
    echo
    ENABLE_SSH_HARDENING=${ENABLE_SSH_HARDENING:-y}

    if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "SSH port [22]: " SSH_PORT
        SSH_PORT=${SSH_PORT:-22}

        read -p "Disable SSH password authentication? (Y/n): " -r SSH_NO_PASSWORD
        echo
        SSH_NO_PASSWORD=${SSH_NO_PASSWORD:-y}

        read -p "Disable SSH root login? (Y/n): " -r SSH_NO_ROOT
        echo
        SSH_NO_ROOT=${SSH_NO_ROOT:-y}
    fi

    read -p "Enable Lynis security scanning? (Y/n): " -r ENABLE_LYNIS
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
EOF

    # Add each target host to inventory
    for i in "${!TARGET_HOSTS[@]}"; do
        local host_name="${TARGET_HOSTNAMES[$i]}"
        local host_ip="${TARGET_HOSTS[$i]}"
        local host_user="${TARGET_USERS[$i]}"

        cat >> "$inventory_file" <<EOF
    ${host_name}:
      ansible_host: ${host_ip}
      ansible_user: ${host_user}
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3

EOF
    done

    # Add children groups
    cat >> "$inventory_file" <<EOF
  children:
    servers:
      hosts:
EOF

    for host_name in "${TARGET_HOSTNAMES[@]}"; do
        echo "        ${host_name}:" >> "$inventory_file"
    done

    cat >> "$inventory_file" <<EOF

  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

    # Add SSH key authentication if using keys
    if [[ "$USE_SSH_KEYS" == "yes" ]]; then
        cat >> "$inventory_file" <<EOF
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
EOF
    fi

    print_success "Inventory file created: $inventory_file"
    print_info "Added ${#TARGET_HOSTS[@]} target node(s) to inventory"
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
# Note: Individual hostnames are configured per-host in inventory
hostname_prefix: "${HOSTNAME_PREFIX}"
timezone: "${TIMEZONE}"
locale: "en_US.UTF-8"
base_install_dir: "/opt"

# NAS Configuration
nas_mounts:
  enabled: $(if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EON

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
  enabled: $(if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

$(if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOB
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
      enabled: $(if [[ $BACKUP_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
      path: "${NAS_MOUNT}/restic"
      password: "{{ vault_restic_passwords.nas }}"

    local:
      enabled: $(if [[ $BACKUP_LOCAL =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
      path: "/opt/backups/restic"
      password: "{{ vault_restic_passwords.local }}"

    s3:
      enabled: $(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOS3
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
  enabled: $(if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

$(if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EON
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

# Uptime Kuma is installed on command node only (setup-control.yml)

# Container Management
dockge:
  enabled: $(if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  port: ${DOCKGE_PORT:-5001}
  stacks_dir: "/opt/dockge/stacks"
  data_dir: "/opt/dockge/data"
  admin_username: "admin"
  admin_password: "{{ vault_dockge_credentials.password }}"

# Security Configuration
security:
  fail2ban_enabled: $(if [[ $ENABLE_FAIL2BAN =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  fail2ban_bantime: 3600
  fail2ban_maxretry: 5

  ufw_enabled: $(if [[ $ENABLE_UFW =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  ufw_default_policy: "deny"
  ufw_allowed_ports:
    - ${SSH_PORT:-22}
$(if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "    - ${DOCKGE_PORT}"; fi)
$(if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "    - ${NETDATA_PORT}"; fi)

  ssh_hardening: $(if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  ssh_port: ${SSH_PORT:-22}
  ssh_password_authentication: $(if [[ $SSH_NO_PASSWORD =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "false"; else echo "true"; fi)
  ssh_permit_root_login: $(if [[ $SSH_NO_ROOT =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "false"; else echo "true"; fi)
  ssh_max_auth_tries: 3
  ssh_client_alive_interval: 300

  lynis_enabled: $(if [[ $ENABLE_LYNIS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
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
$(if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EON
vault_nas_credentials:
  - username: "${NAS_USER}"
    password: "${NAS_PASS}"
EON
else
echo "vault_nas_credentials: []"
fi)

# Restic Passwords
vault_restic_passwords:
$(if [[ $BACKUP_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  nas: \"${RESTIC_NAS_PASS}\""; else echo "  nas: \"\""; fi)
$(if [[ $BACKUP_LOCAL =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  local: \"${RESTIC_LOCAL_PASS}\""; else echo "  local: \"\""; fi)
$(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  s3: \"${RESTIC_S3_PASS}\""; else echo "  s3: \"\""; fi)
  b2: ""

# Cloud Provider Credentials
$(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOS3
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

# Offer to run bootstrap playbook
offer_bootstrap() {
    print_header
    print_info "Target Node Bootstrap Check"
    echo

    print_info "Before running the main setup, target nodes must be bootstrapped with:"
    echo "  - Python 3 installed"
    echo "  - SSH server running"
    echo "  - Admin user with sudo privileges"
    echo "  - SSH key authentication configured"
    echo

    read -p "Have all target nodes been bootstrapped? (y/N): " -r BOOTSTRAPPED
    echo

    if [[ ! $BOOTSTRAPPED =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_warning "Target nodes need to be bootstrapped first"
        echo
        echo "You have two options:"
        echo
        echo "  ${BOLD}Option 1: Manual bootstrap (recommended for initial setup)${NC}"
        echo "  Run this on each target node as root:"
        echo "    curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash"
        echo "  OR copy bootstrap-target.sh to each node and run it"
        echo
        echo "  ${BOLD}Option 2: Ansible bootstrap playbook${NC}"
        echo "  Run this from the command node (requires root SSH access):"
        echo "    ansible-playbook playbooks/bootstrap.yml --ask-become-pass"
        echo

        read -p "Would you like to run the bootstrap playbook now? (y/N): " -r RUN_BOOTSTRAP
        echo

        if [[ $RUN_BOOTSTRAP =~ ^[Yy]([Ee][Ss])?$ ]]; then
            print_info "Running bootstrap playbook..."
            if ansible-playbook playbooks/bootstrap.yml --ask-become-pass; then
                print_success "Bootstrap playbook completed"
            else
                print_error "Bootstrap playbook failed"
                print_info "You may need to bootstrap nodes manually"
                read -p "Continue with main setup anyway? (y/N): " -r CONTINUE
                if [[ ! $CONTINUE =~ ^[Yy]([Ee][Ss])?$ ]]; then
                    exit 1
                fi
            fi
        else
            print_warning "Please bootstrap target nodes before continuing"
            read -p "Continue with main setup anyway? (y/N): " -r CONTINUE
            if [[ ! $CONTINUE =~ ^[Yy]([Ee][Ss])?$ ]]; then
                print_info "Setup paused. Run this script again after bootstrapping target nodes."
                exit 0
            fi
        fi
    else
        print_success "Target nodes confirmed bootstrapped"
    fi
}

# Run Ansible playbook
run_playbook() {
    print_header
    print_info "Running Ansible playbook..."
    echo

    print_warning "This will configure ${#TARGET_HOSTS[@]} target server(s) with:"
    if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Dockge (Container Management)"; fi
    if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Netdata (Monitoring)"; fi
    if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Restic Backups"; fi
    if [[ $ENABLE_FAIL2BAN =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - fail2ban (Security)"; fi
    if [[ $ENABLE_UFW =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - UFW Firewall"; fi
    echo
    print_info "Target servers:"
    for i in "${!TARGET_HOSTS[@]}"; do
        echo "  - ${TARGET_HOSTNAMES[$i]} (${TARGET_HOSTS[$i]})"
    done
    echo

    read -p "Continue with installation? (yes/no): " -r CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_warning "Installation cancelled by user"
        exit 0
    fi

    echo
    print_info "Starting playbook execution..."
    print_info "This may take 10-20 minutes depending on your system"
    echo

    # Run the TARGET playbook with verbose output (excludes Uptime Kuma)
    if ansible-playbook playbooks/setup-targets.yml -v; then
        print_success "Target node playbook completed successfully!"

        # Offer to install control node services
        offer_control_node_setup

        show_completion_message
    else
        print_error "Playbook execution failed"
        print_info "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Offer to install control node services
offer_control_node_setup() {
    echo
    print_header
    print_info "Control Node Services Setup"
    echo

    print_info "Target servers are now configured. You can optionally install"
    print_info "centralized monitoring services on this control node:"
    echo
    echo "  ${BOLD}Centralized Uptime Kuma:${NC}"
    echo "  - Monitor ALL target servers from a single dashboard"
    echo "  - Centralized alerting (email, Discord, Telegram, etc.)"
    echo "  - Recommended for multi-server deployments"
    echo

    read -p "Install centralized monitoring on this control node? (Y/n): " -r INSTALL_CONTROL
    echo

    if [[ ! $INSTALL_CONTROL =~ ^[Nn]$ ]]; then
        print_info "Installing control node services..."

        # Run control node playbook
        if ansible-playbook playbooks/setup-control.yml -v; then
            print_success "Control node services installed!"
            echo
            print_info "Access centralized Uptime Kuma:"
            print_info "  http://localhost:${CONTROL_UPTIME_KUMA_PORT:-3001}"
            echo
            print_info "Configure monitors for your target servers:"
            for i in "${!TARGET_HOSTS[@]}"; do
                local host_ip="${TARGET_HOSTS[$i]}"
                echo "  - Netdata: http://${host_ip}:${NETDATA_PORT}"
                echo "  - Dockge: http://${host_ip}:${DOCKGE_PORT}"
                echo "  - SSH: ${host_ip}:22"
            done
            echo
        else
            print_warning "Control node setup failed (optional)"
            print_info "You can run it manually later with:"
            print_info "  ansible-playbook playbooks/setup-control.yml"
        fi
    else
        print_info "Skipping control node services"
        print_info "You can install them later with:"
        print_info "  ansible-playbook playbooks/setup-control.yml"
    fi
}

# Show completion message with service URLs
show_completion_message() {
    print_header
    print_success "Server Helper setup complete!"
    echo

    print_info "Access your services on target servers:"
    echo

    for i in "${!TARGET_HOSTS[@]}"; do
        local host_name="${TARGET_HOSTNAMES[$i]}"
        local host_ip="${TARGET_HOSTS[$i]}"

        echo -e "${BOLD}${host_name} (${host_ip}):${NC}"
        if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Dockge:${NC}      http://${host_ip}:${DOCKGE_PORT}"
        fi
        if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Netdata:${NC}     http://${host_ip}:${NETDATA_PORT}"
        fi
        echo
    done

    print_info "Next steps:"
    echo "  1. Change default admin passwords on first login"
    echo "  2. Run setup-control.yml to install Uptime Kuma on this command node"
    if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  3. Verify backup repositories are initialized"
    fi
    echo "  4. Review security settings and firewall rules"
    echo

    print_info "Useful commands (from command node):"
    echo "  - View service status: ansible all -m shell -a 'docker ps'"
    echo "  - Run backup manually: ansible-playbook playbooks/backup.yml"
    echo "  - Security audit: ansible-playbook playbooks/security.yml"
    echo "  - Update system: ansible-playbook playbooks/update.yml"
    echo "  - Add more nodes: Edit inventory/hosts.yml and re-run playbook"
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

    # Install dependencies on COMMAND NODE
    install_system_deps
    install_python_deps
    install_galaxy_deps

    # Configuration
    prompt_target_nodes  # NEW: Prompt for target servers first
    prompt_config        # Then prompt for service configuration
    create_inventory     # Create inventory with target nodes
    create_config        # Create service configuration
    create_vault         # Create encrypted vault

    # Pre-flight checks
    preflight_checks

    # Offer to run bootstrap playbook
    offer_bootstrap

    # Run playbook
    run_playbook

    print_success "Setup script completed"
    print_info "Log file: $LOG_FILE"
}

# Run main function
main "$@"
