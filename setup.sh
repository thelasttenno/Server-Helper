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

# Existing configuration files
INVENTORY_FILE="inventory/hosts.yml"
CONFIG_FILE="group_vars/all.yml"
VAULT_FILE="group_vars/vault.yml"

# Arrays for existing and new servers
EXISTING_HOSTS=()
EXISTING_HOSTNAMES=()
EXISTING_USERS=()
EXISTING_CONFIG_FOUND=false

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

# Check for existing configuration
check_existing_config() {
    print_header
    print_info "Checking for existing configuration..."

    if [[ -f "$INVENTORY_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
        EXISTING_CONFIG_FOUND=true
        print_success "Existing configuration found!"
        echo

        # Parse existing inventory to get servers
        parse_existing_inventory

        if [[ ${#EXISTING_HOSTNAMES[@]} -gt 0 ]]; then
            echo -e "${BOLD}Configured servers:${NC}"
            for i in "${!EXISTING_HOSTNAMES[@]}"; do
                echo "  - ${EXISTING_HOSTNAMES[$i]} (${EXISTING_HOSTS[$i]})"
            done
            echo

            # Offer options
            echo -e "${BOLD}What would you like to do?${NC}"
            echo "  1) Health check existing servers"
            echo "  2) Add new servers to existing configuration"
            echo "  3) Re-run setup on existing servers"
            echo "  4) Start fresh (backup and recreate all config)"
            echo
            read -p "Choose an option [1-4]: " -r SETUP_MODE
            echo

            case "$SETUP_MODE" in
                1)
                    health_check_servers
                    exit 0
                    ;;
                2)
                    # Keep existing config, add new servers
                    USE_EXISTING_CONFIG=true
                    print_info "Will add new servers to existing configuration"
                    ;;
                3)
                    # Use existing servers, re-run playbook
                    USE_EXISTING_CONFIG=true
                    RERUN_EXISTING=true
                    TARGET_HOSTS=("${EXISTING_HOSTS[@]}")
                    TARGET_HOSTNAMES=("${EXISTING_HOSTNAMES[@]}")
                    TARGET_USERS=("${EXISTING_USERS[@]}")
                    print_info "Will re-run setup on ${#TARGET_HOSTS[@]} existing server(s)"
                    ;;
                4)
                    # Backup and start fresh
                    backup_existing_config
                    USE_EXISTING_CONFIG=false
                    print_info "Starting fresh configuration"
                    ;;
                *)
                    print_warning "Invalid option, defaulting to health check"
                    health_check_servers
                    exit 0
                    ;;
            esac
        fi
    else
        print_info "No existing configuration found, starting fresh setup"
        USE_EXISTING_CONFIG=false
    fi
}

# Parse existing inventory file to extract servers
parse_existing_inventory() {
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        return
    fi

    # Reset arrays
    EXISTING_HOSTS=()
    EXISTING_HOSTNAMES=()
    EXISTING_USERS=()

    # Parse YAML inventory (simple parsing for our format)
    local in_hosts=false
    local current_host=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if we're in the hosts section
        if [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=true
            continue
        fi

        # Check if we've left the hosts section
        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]*[a-z]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ansible_ ]]; then
            if [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
                in_hosts=false
                continue
            fi
        fi

        if [[ "$in_hosts" == true ]]; then
            # Match host definition (4 spaces + hostname + colon)
            if [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
                current_host="${BASH_REMATCH[1]}"
                EXISTING_HOSTNAMES+=("$current_host")
            fi

            # Match ansible_host
            if [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
                EXISTING_HOSTS+=("${BASH_REMATCH[1]}")
            fi

            # Match ansible_user
            if [[ "$line" =~ ansible_user:[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
                EXISTING_USERS+=("${BASH_REMATCH[1]}")
            fi
        fi
    done < "$INVENTORY_FILE"

    # Ensure arrays are same length (fill missing users with default)
    while [[ ${#EXISTING_USERS[@]} -lt ${#EXISTING_HOSTNAMES[@]} ]]; do
        EXISTING_USERS+=("ansible")
    done
}

# Health check all configured servers
health_check_servers() {
    print_header
    print_info "Running health checks on configured servers..."
    echo

    local healthy=0
    local unhealthy=0

    for i in "${!EXISTING_HOSTNAMES[@]}"; do
        local hostname="${EXISTING_HOSTNAMES[$i]}"
        local host="${EXISTING_HOSTS[$i]}"
        local user="${EXISTING_USERS[$i]}"

        echo -e "${BOLD}Checking ${hostname} (${host})...${NC}"

        # SSH connectivity check
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${host}" "echo 'ok'" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} SSH connectivity: OK"

            # Check Docker
            if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "docker ps" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Docker: Running"
            else
                echo -e "  ${YELLOW}⚠${NC} Docker: Not running or not installed"
            fi

            # Check Netdata
            if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "curl -s http://localhost:19999/api/v1/info" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Netdata: Running"
            else
                echo -e "  ${YELLOW}⚠${NC} Netdata: Not accessible"
            fi

            # Check Dockge
            if ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "curl -s http://localhost:5001" &>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Dockge: Running"
            else
                echo -e "  ${YELLOW}⚠${NC} Dockge: Not accessible"
            fi

            # Check disk space
            local disk_usage
            disk_usage=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "df -h / | tail -1 | awk '{print \$5}'" 2>/dev/null | tr -d '%')
            if [[ -n "$disk_usage" ]]; then
                if [[ "$disk_usage" -gt 90 ]]; then
                    echo -e "  ${RED}✗${NC} Disk usage: ${disk_usage}% (CRITICAL)"
                elif [[ "$disk_usage" -gt 80 ]]; then
                    echo -e "  ${YELLOW}⚠${NC} Disk usage: ${disk_usage}% (Warning)"
                else
                    echo -e "  ${GREEN}✓${NC} Disk usage: ${disk_usage}%"
                fi
            fi

            # Check memory
            local mem_usage
            mem_usage=$(ssh -o BatchMode=yes -o ConnectTimeout=10 "${user}@${host}" "free | grep Mem | awk '{print int(\$3/\$2 * 100)}'" 2>/dev/null)
            if [[ -n "$mem_usage" ]]; then
                if [[ "$mem_usage" -gt 90 ]]; then
                    echo -e "  ${RED}✗${NC} Memory usage: ${mem_usage}% (CRITICAL)"
                elif [[ "$mem_usage" -gt 80 ]]; then
                    echo -e "  ${YELLOW}⚠${NC} Memory usage: ${mem_usage}% (Warning)"
                else
                    echo -e "  ${GREEN}✓${NC} Memory usage: ${mem_usage}%"
                fi
            fi

            ((healthy++))
        else
            echo -e "  ${RED}✗${NC} SSH connectivity: FAILED"
            ((unhealthy++))
        fi
        echo
    done

    echo -e "${BOLD}Summary:${NC}"
    echo -e "  ${GREEN}Healthy:${NC} ${healthy}"
    echo -e "  ${RED}Unhealthy:${NC} ${unhealthy}"
    echo

    if [[ $unhealthy -gt 0 ]]; then
        print_warning "Some servers failed health checks"
        read -p "Would you like to re-run setup on failed servers? (y/N): " -r
        echo
        if [[ $REPLY =~ ^[Yy]([Ee][Ss])?$ ]]; then
            print_info "Run: ansible-playbook playbooks/setup-targets.yml --limit <hostname>"
        fi
    else
        print_success "All servers are healthy!"
    fi
}

# Backup existing configuration
backup_existing_config() {
    local backup_dir="backups/config_$(date +%Y%m%d_%H%M%S)"
    print_info "Backing up existing configuration to ${backup_dir}..."

    mkdir -p "$backup_dir"

    if [[ -f "$INVENTORY_FILE" ]]; then
        cp "$INVENTORY_FILE" "$backup_dir/"
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$backup_dir/"
    fi

    if [[ -f "$VAULT_FILE" ]]; then
        cp "$VAULT_FILE" "$backup_dir/"
    fi

    if [[ -f ".vault_password" ]]; then
        cp ".vault_password" "$backup_dir/"
    fi

    print_success "Configuration backed up to ${backup_dir}"
}

# Merge new servers with existing inventory
merge_inventory() {
    if [[ "$USE_EXISTING_CONFIG" != true ]] || [[ ! -f "$INVENTORY_FILE" ]]; then
        return
    fi

    print_info "Merging new servers with existing inventory..."

    # Capture new server count before merge
    local new_count=${#TARGET_HOSTS[@]}
    local existing_count=${#EXISTING_HOSTNAMES[@]}

    # Combine existing and new servers
    local all_hosts=("${EXISTING_HOSTS[@]}" "${TARGET_HOSTS[@]}")
    local all_hostnames=("${EXISTING_HOSTNAMES[@]}" "${TARGET_HOSTNAMES[@]}")
    local all_users=("${EXISTING_USERS[@]}" "${TARGET_USERS[@]}")

    # Update TARGET arrays with combined values
    TARGET_HOSTS=("${all_hosts[@]}")
    TARGET_HOSTNAMES=("${all_hostnames[@]}")
    TARGET_USERS=("${all_users[@]}")

    print_success "Merged ${existing_count} existing + ${new_count} new = ${#all_hostnames[@]} total servers"
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

    # Check if adding to existing config
    if [[ "${USE_EXISTING_CONFIG:-}" == true ]] && [[ ${#EXISTING_HOSTNAMES[@]} -gt 0 ]]; then
        print_info "Adding New Servers"
        print_info "You already have ${#EXISTING_HOSTNAMES[@]} server(s) configured:"
        echo
        echo -e "${BOLD}Currently managed servers:${NC}"
        for i in "${!EXISTING_HOSTNAMES[@]}"; do
            echo "  - ${EXISTING_HOSTNAMES[$i]} (${EXISTING_HOSTS[$i]})"
        done
        echo
        print_info "Now let's add your new servers"
    else
        print_info "Server Setup"
        print_info "Tell us about the servers you want to manage"
    fi
    echo

    # Initialize arrays for NEW servers only
    TARGET_HOSTS=()
    TARGET_HOSTNAMES=()
    TARGET_USERS=()

    # Prompt for number of targets
    if [[ "${USE_EXISTING_CONFIG:-}" == true ]]; then
        read -p "How many new servers do you want to add? [1]: " NUM_TARGETS
    else
        read -p "How many servers do you want to manage? [1]: " NUM_TARGETS
    fi
    NUM_TARGETS=${NUM_TARGETS:-1}

    # Allow 0 if just re-running on existing
    if [[ "$NUM_TARGETS" == "0" ]] && [[ "${USE_EXISTING_CONFIG:-}" == true ]]; then
        print_info "No new servers to add"
        return
    fi

    # SSH authentication method
    echo
    echo -e "${BOLD}How to Connect to Servers:${NC}"
    echo "  SSH keys are like a secure digital key that lets you connect without typing"
    echo "  a password each time. This is more secure and convenient."
    echo
    read -p "Use secure key-based login? (recommended) (Y/n): " -r USE_SSH_KEYS_INPUT
    echo
    USE_SSH_KEYS=${USE_SSH_KEYS_INPUT:-y}
    USE_SSH_KEYS=$(echo "$USE_SSH_KEYS" | tr '[:upper:]' '[:lower:]')

    if [[ "$USE_SSH_KEYS" =~ ^[yY]([eE][sS])?$ ]]; then
        USE_SSH_KEYS="yes"
        print_success "Using secure key-based login"

        # Check if SSH key exists
        if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
            print_warning "No SSH key found on this computer"
            read -p "Create a new SSH key now? (Y/n): " -r GEN_KEY
            echo
            if [[ ! $GEN_KEY =~ ^[Nn]$ ]]; then
                ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
                print_success "SSH key created"
            fi
        fi
    else
        USE_SSH_KEYS="no"
        print_warning "Password login will be used (less secure, you'll type password each time)"
    fi

    # Collect target server details
    for ((i=0; i<NUM_TARGETS; i++)); do
        echo
        echo -e "${BOLD}Target Server $((i+1)) of ${NUM_TARGETS}:${NC}"

        # Hostname
        read -p "Friendly name for this server (used in dashboards) [server-$(printf "%02d" $((i+1)))]: " TARGET_HOSTNAME
        TARGET_HOSTNAME=${TARGET_HOSTNAME:-server-$(printf "%02d" $((i+1)))}
        TARGET_HOSTNAMES+=("$TARGET_HOSTNAME")

        # IP/Hostname
        read -p "Server address (IP like 192.168.1.10 or domain name): " TARGET_HOST
        while [[ -z "$TARGET_HOST" ]]; do
            print_error "Server address is required"
            read -p "Server address (IP like 192.168.1.10 or domain name): " TARGET_HOST
        done
        TARGET_HOSTS+=("$TARGET_HOST")

        # SSH user
        read -p "Username to log into this server [ansible]: " TARGET_USER
        TARGET_USER=${TARGET_USER:-ansible}
        TARGET_USERS+=("$TARGET_USER")

        # Test SSH connectivity and copy keys if needed
        print_info "Testing connection to ${TARGET_HOST}..."
        if [[ "$USE_SSH_KEYS" == "yes" ]]; then
            if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_HOST}" "echo 'Connected'" &>/dev/null; then
                print_success "Can connect to ${TARGET_HOSTNAME} without password"
            else
                print_warning "Cannot connect to ${TARGET_HOSTNAME} yet - need to set up SSH key"
                read -p "Set up passwordless login to ${TARGET_HOST} now? (you'll enter password once) (Y/n): " -r COPY_KEY
                echo
                if [[ ! $COPY_KEY =~ ^[Nn]$ ]]; then
                    print_info "Setting up secure login to ${TARGET_USER}@${TARGET_HOST}..."
                    print_info "Enter the password for ${TARGET_USER} on ${TARGET_HOST} when prompted:"
                    if ssh-copy-id -o StrictHostKeyChecking=no "${TARGET_USER}@${TARGET_HOST}"; then
                        print_success "Passwordless login configured for ${TARGET_HOSTNAME}"
                    else
                        print_error "Could not set up passwordless login to ${TARGET_HOSTNAME}"
                        print_info "Possible fixes:"
                        print_info "  1. Make sure the server allows password login temporarily"
                        print_info "  2. Check that ${TARGET_USER} exists on the server"
                        print_info "  3. Manually run: ssh-copy-id ${TARGET_USER}@${TARGET_HOST}"
                    fi
                else
                    print_warning "Skipping SSH key setup for ${TARGET_HOSTNAME}"
                    print_info "You can set it up later with: ssh-copy-id ${TARGET_USER}@${TARGET_HOST}"
                fi
            fi
        else
            print_warning "Skipping connection test (using password login mode)"
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
    echo -e "${BOLD}Basic Settings:${NC}"
    echo "  Server names will start with this prefix (e.g., 'web' gives web-01, web-02)"
    read -p "Server name prefix [server]: " HOSTNAME_PREFIX
    HOSTNAME_PREFIX=${HOSTNAME_PREFIX:-server}

    echo
    echo "  Your timezone for logs and scheduled tasks (e.g., America/Los_Angeles, Europe/London)"
    read -p "Timezone [America/Vancouver]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-America/Vancouver}

    # NAS configuration
    echo
    echo -e "${BOLD}Network Storage (NAS):${NC}"
    echo "  A NAS is a network-attached storage device (like a Synology or QNAP)"
    echo "  that can store backups and shared files on your local network."
    echo
    read -p "Do you have a NAS to connect to? (y/N): " -r ENABLE_NAS
    echo
    ENABLE_NAS=${ENABLE_NAS:-n}

    if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "NAS address (IP like 192.168.1.100) [192.168.1.100]: " NAS_IP
        NAS_IP=${NAS_IP:-192.168.1.100}

        read -p "Shared folder name on the NAS [backup]: " NAS_SHARE
        NAS_SHARE=${NAS_SHARE:-backup}

        read -p "Where to access NAS files on your server [/mnt/nas/backup]: " NAS_MOUNT
        NAS_MOUNT=${NAS_MOUNT:-/mnt/nas/backup}

        read -p "NAS login username: " NAS_USER
        read -sp "NAS login password: " NAS_PASS
        echo
    fi

    # Backup configuration
    echo
    echo -e "${BOLD}Automatic Backups:${NC}"
    echo "  Restic creates encrypted, deduplicated backups of your important files."
    echo "  Backups can be stored locally, on NAS, or in cloud storage (AWS S3)."
    echo
    read -p "Enable automatic backups? (Y/n): " -r ENABLE_BACKUPS
    echo
    ENABLE_BACKUPS=${ENABLE_BACKUPS:-y}

    if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  When should backups run? Default is 2:00 AM daily."
        echo "  Format: minute hour day month weekday (cron format)"
        echo "  Examples: '0 2 * * *' = 2:00 AM daily, '0 3 * * 0' = 3:00 AM Sundays"
        read -p "Backup schedule [0 2 * * *]: " BACKUP_SCHEDULE
        BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-0 2 * * *}

        echo
        read -p "Save backups to your NAS? (Y/n): " -r BACKUP_NAS
        echo
        BACKUP_NAS=${BACKUP_NAS:-y}

        if [[ $BACKUP_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  Create a password to encrypt your NAS backups (remember this!):"
            read -sp "Backup encryption password for NAS: " RESTIC_NAS_PASS
            echo
        fi

        read -p "Save backups on the server itself? (Y/n): " -r BACKUP_LOCAL
        echo
        BACKUP_LOCAL=${BACKUP_LOCAL:-y}

        if [[ $BACKUP_LOCAL =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  Create a password to encrypt your local backups (remember this!):"
            read -sp "Backup encryption password for local storage: " RESTIC_LOCAL_PASS
            echo
        fi

        echo
        echo "  AWS S3 provides offsite cloud backup storage (requires AWS account)."
        read -p "Save backups to Amazon S3 cloud storage? (y/N): " -r BACKUP_S3
        echo
        BACKUP_S3=${BACKUP_S3:-n}

        if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -p "S3 bucket name (the storage container name in AWS): " S3_BUCKET
            read -p "AWS region where bucket is located [us-east-1]: " S3_REGION
            S3_REGION=${S3_REGION:-us-east-1}
            read -p "AWS Access Key ID (from your AWS account): " AWS_ACCESS_KEY
            read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
            echo
            echo "  Create a password to encrypt your cloud backups (remember this!):"
            read -sp "Backup encryption password for S3: " RESTIC_S3_PASS
            echo
        fi
    fi

    # Monitoring configuration
    echo
    echo -e "${BOLD}Server Monitoring (Netdata):${NC}"
    echo "  Netdata shows real-time CPU, memory, disk, and network usage in a"
    echo "  beautiful web dashboard. Great for spotting problems before they happen."
    echo
    read -p "Enable server monitoring dashboard? (Y/n): " -r ENABLE_NETDATA
    echo
    ENABLE_NETDATA=${ENABLE_NETDATA:-y}

    if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  Port number for the monitoring dashboard (access via http://server:PORT)"
        read -p "Monitoring dashboard port [19999]: " NETDATA_PORT
        NETDATA_PORT=${NETDATA_PORT:-19999}

        echo
        echo "  Netdata Cloud lets you view all servers from app.netdata.cloud (optional)"
        echo "  Get a claim token from https://app.netdata.cloud (leave empty to skip)"
        read -p "Netdata Cloud token (press Enter to skip): " NETDATA_CLAIM_TOKEN
    fi

    # Logging configuration
    echo
    echo -e "${BOLD}Log Collection (Promtail):${NC}"
    echo "  Promtail collects logs from your containers and system,"
    echo "  then streams them to the central Loki server on your control node."
    echo "  View all logs in the centralized Grafana dashboard."
    echo
    read -p "Enable log collection? (Y/n): " -r ENABLE_LOGGING
    echo
    ENABLE_LOGGING=${ENABLE_LOGGING:-y}

    # Note: Centralized monitoring (Uptime Kuma, central Grafana/Loki/Netdata)
    # is installed on command node via setup-control.yml after target setup

    # Note: DNS (Pi-hole + Unbound) is a centralized service
    # and will be configured in the control node setup phase

    # Container management
    echo
    echo -e "${BOLD}Docker Container Manager (Dockge):${NC}"
    echo "  Dockge is a simple web interface to manage your Docker containers."
    echo "  Start, stop, view logs, and deploy new apps - all from your browser."
    echo
    read -p "Enable container management dashboard? (Y/n): " -r ENABLE_DOCKGE
    echo
    ENABLE_DOCKGE=${ENABLE_DOCKGE:-y}

    if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then
        read -p "Container manager port [5001]: " DOCKGE_PORT
        DOCKGE_PORT=${DOCKGE_PORT:-5001}

        echo "  Set a password for the Dockge admin account (username: admin)"
        read -sp "Dockge admin password [auto-generate]: " DOCKGE_ADMIN_PASSWORD
        echo
        if [[ -z "$DOCKGE_ADMIN_PASSWORD" ]]; then
            DOCKGE_ADMIN_PASSWORD=$(openssl rand -base64 16)
            print_info "Generated Dockge admin password (will be shown at end)"
        fi
    fi

    # Security configuration
    echo
    echo -e "${BOLD}Security Settings:${NC}"
    echo
    echo "  Fail2ban automatically blocks IP addresses that try to break into your server"
    echo "  (e.g., after too many failed login attempts)."
    read -p "Enable automatic intrusion blocking? (Y/n): " -r ENABLE_FAIL2BAN
    echo
    ENABLE_FAIL2BAN=${ENABLE_FAIL2BAN:-y}

    echo "  UFW (Uncomplicated Firewall) blocks unwanted network connections and only"
    echo "  allows traffic to services you've enabled (SSH, web dashboards, etc.)."
    read -p "Enable firewall protection? (Y/n): " -r ENABLE_UFW
    echo
    ENABLE_UFW=${ENABLE_UFW:-y}

    echo "  SSH hardening makes remote login more secure by disabling weak options."
    read -p "Enable secure remote login settings? (Y/n): " -r ENABLE_SSH_HARDENING
    echo
    ENABLE_SSH_HARDENING=${ENABLE_SSH_HARDENING:-y}

    if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  Port 22 is the default. Changing it can reduce automated attacks,"
        echo "  but you'll need to remember to use the new port when connecting."
        read -p "Remote login (SSH) port [22]: " SSH_PORT
        SSH_PORT=${SSH_PORT:-22}

        echo
        echo "  Disabling password login means only SSH keys can be used (more secure)."
        echo "  Make sure your SSH key is working before enabling this!"
        read -p "Require key-based login only (disable passwords)? (Y/n): " -r SSH_NO_PASSWORD
        echo
        SSH_NO_PASSWORD=${SSH_NO_PASSWORD:-y}

        echo "  Disabling root login forces users to log in with a regular account first."
        read -p "Block direct root login? (Y/n): " -r SSH_NO_ROOT
        echo
        SSH_NO_ROOT=${SSH_NO_ROOT:-y}
    fi

    echo "  Lynis scans your server for security issues and gives recommendations."
    read -p "Enable weekly security scans? (Y/n): " -r ENABLE_LYNIS
    echo
    ENABLE_LYNIS=${ENABLE_LYNIS:-y}

    # Advanced Services Section
    echo
    echo -e "${BOLD}Advanced Services (Optional):${NC}"
    echo "  These are optional advanced services. Press Enter to skip if unsure."
    echo

    # System Users Configuration
    echo -e "${BOLD}System User Management:${NC}"
    echo "  Create a dedicated admin user on target servers for better security."
    echo "  This user will have sudo access and can be used instead of the default"
    echo "  user (e.g., 'ubuntu' or 'root') for everyday administration."
    read -p "Create a dedicated admin user? (y/N): " -r ENABLE_SYSTEM_USERS
    echo
    ENABLE_SYSTEM_USERS=${ENABLE_SYSTEM_USERS:-n}

    if [[ $ENABLE_SYSTEM_USERS =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  Username for the new admin account:"
        read -p "Admin username [admin]: " ADMIN_USERNAME
        ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

        echo
        echo "  Set a password for this admin user (used for sudo and console login):"
        read -sp "Admin password: " ADMIN_PASSWORD
        echo

        echo
        echo "  Optional: Add an SSH public key for passwordless login to this user."
        echo "  You can find your public key in ~/.ssh/id_rsa.pub on your computer."
        echo "  Format: ssh-rsa AAAA... user@host"
        read -p "Admin SSH public key (press Enter to skip): " ADMIN_SSH_KEY
    fi

    # LVM Configuration
    echo
    echo -e "${BOLD}Disk Management (LVM):${NC}"
    echo "  LVM (Logical Volume Manager) is used by Ubuntu to manage disk partitions."
    echo "  Ubuntu often doesn't use all available disk space by default."
    echo "  This option automatically extends the root partition to use the full disk."
    read -p "Enable auto LVM extension? (Y/n): " -r ENABLE_LVM_CONFIG
    echo
    ENABLE_LVM_CONFIG=${ENABLE_LVM_CONFIG:-y}

    # Self-Update (Ansible Pull)
    echo
    echo -e "${BOLD}Self-Update (Ansible Pull):${NC}"
    echo "  Automatically keep your server configuration up to date by pulling"
    echo "  from a Git repository. Uses 'ansible-pull' to fetch and run playbooks."
    echo "  This ensures your servers stay in sync with your infrastructure-as-code."
    read -p "Enable automatic self-updates? (Y/n): " -r ENABLE_SELF_UPDATE
    echo
    ENABLE_SELF_UPDATE=${ENABLE_SELF_UPDATE:-y}

    if [[ $ENABLE_SELF_UPDATE =~ ^[Yy]([Ee][Ss])?$ ]]; then
        echo "  Git repository URL containing your Server-Helper configuration."
        echo "  This can be a public GitHub URL or a private repo with SSH access."
        echo "  Example: https://github.com/yourusername/Server-Helper.git"
        read -p "Git repository URL: " SELF_UPDATE_REPO_URL
        while [[ -z "$SELF_UPDATE_REPO_URL" ]]; do
            print_warning "Repository URL is required for self-updates"
            read -p "Git repository URL: " SELF_UPDATE_REPO_URL
        done

        echo
        echo "  Branch to pull updates from (usually 'main' or 'master')"
        read -p "Git branch [main]: " SELF_UPDATE_BRANCH
        SELF_UPDATE_BRANCH=${SELF_UPDATE_BRANCH:-main}

        echo
        echo "  When should self-updates run? Uses cron format."
        echo "  Default: 5:00 AM daily (0 5 * * *)"
        read -p "Update schedule [0 5 * * *]: " SELF_UPDATE_SCHEDULE
        SELF_UPDATE_SCHEDULE=${SELF_UPDATE_SCHEDULE:-0 5 * * *}

        echo
        echo "  Check-only mode tests if changes would be applied without actually"
        echo "  making them. Useful for reviewing updates before deployment."
        read -p "Check only (don't apply changes)? (y/N): " -r SELF_UPDATE_CHECK_ONLY
        SELF_UPDATE_CHECK_ONLY=${SELF_UPDATE_CHECK_ONLY:-n}
    fi

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
#
# This file contains configuration for BOTH target nodes and control node.
# Variables are organized with prefixes:
#   - target_*: Services deployed on managed servers (setup-targets.yml)
#   - control_*: Centralized services on control node (setup-control.yml)

---
# =============================================================================
# TARGET NODE CONFIGURATION
# =============================================================================

# Target: System Settings
target_hostname: "${HOSTNAME_PREFIX}"
target_timezone: "${TIMEZONE}"
target_locale: "en_US.UTF-8"

# Target: Base Directories
target_base_dir: "/opt/server-helper"
target_dockge_base_dir: "/opt/dockge"
target_dockge_stacks_dir: "{{ target_dockge_base_dir }}/stacks"
target_dockge_data_dir: "{{ target_dockge_base_dir }}/data"

# Target: NAS Mounts
target_nas_mounts:
  enabled: $(if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $ENABLE_NAS =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EON
  shares:
    - name: "primary"
      ip: "${NAS_IP}"
      share_name: "${NAS_SHARE}"
      mount_point: "${NAS_MOUNT}"
      username: "{{ vault_nas_credentials[0].username }}"
      password: "{{ vault_nas_credentials[0].password }}"
      smb_version: "3.0"
      options: "_netdev,nofail"
EON
fi)

# Target: LVM Configuration
target_lvm_config:
  enabled: $(if [[ ${ENABLE_LVM_CONFIG:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  auto_extend_ubuntu: true
  custom_lvs: []
  create_lvs: []

# Target: System Users
target_system_users:
  create_admin_user: $(if [[ ${ENABLE_SYSTEM_USERS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ ${ENABLE_SYSTEM_USERS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOUSERS
  admin_user: "${ADMIN_USERNAME:-admin}"
  admin_password: "{{ vault_system_users.admin_password }}"
  admin_groups:
    - sudo
    - docker
  admin_passwordless_sudo: true
  admin_ssh_key: "{{ vault_system_users.admin_ssh_key }}"
EOUSERS
fi)
  disable_root_password: true
  additional_users: []

# Target: Dockge (Container Management)
target_dockge:
  enabled: $(if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  port: ${DOCKGE_PORT:-5001}
  version: "1"

# Target: Netdata (System Monitoring)
target_netdata:
  enabled: $(if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  port: ${NETDATA_PORT:-19999}
  version: "latest"
  claim_token: "${NETDATA_CLAIM_TOKEN:-}"
  claim_rooms: ""
  alarms:
    enabled: true
    cpu_warning: 80
    cpu_critical: 95
    ram_warning: 80
    ram_critical: 95
    disk_warning: 80
    disk_critical: 90
    check_interval_minutes: 5
  uptime_kuma_push_urls:
    cpu: ""
    ram: ""
    disk: ""
    system: ""

# Target: Restic (Encrypted Backups)
target_restic:
  enabled: $(if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOB
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
    local:
      enabled: $(if [[ $BACKUP_LOCAL =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
      path: "/opt/backups/restic"
    s3:
      enabled: $(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ $BACKUP_S3 =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOS3
      bucket: "${S3_BUCKET}"
      endpoint: "s3.amazonaws.com"
      region: "${S3_REGION}"
EOS3
fi)
    b2:
      enabled: false
  include_paths:
    - "{{ target_dockge_stacks_dir }}"
    - "{{ target_dockge_data_dir }}"
    - "/etc"
    - "/root"
    - "/home"
  exclude_patterns:
    - "*.tmp"
    - "*.log"
    - "cache"
    - "*.cache"
EOB
fi)

# Target: Security
target_security:
  basic_hardening: true
  lynis:
    enabled: $(if [[ $ENABLE_LYNIS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    schedule: "0 3 * * 0"
  fail2ban:
    enabled: $(if [[ $ENABLE_FAIL2BAN =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    sshd_maxretry: 3
    sshd_bantime: 86400
  ufw:
    enabled: $(if [[ $ENABLE_UFW =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    default_incoming: deny
    default_outgoing: allow
  ssh_hardening:
    enabled: $(if [[ $ENABLE_SSH_HARDENING =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    permit_root_login: $(if [[ $SSH_NO_ROOT =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "false"; else echo "true"; fi)
    password_authentication: $(if [[ $SSH_NO_PASSWORD =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "false"; else echo "true"; fi)
    pubkey_authentication: true
    max_auth_tries: 3

# Target: Logging (Promtail only - streams to central Loki)
target_logging:
  promtail:
    enabled: $(if [[ $ENABLE_LOGGING =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    additional_jobs: []

# Target: Reverse Proxy (Optional)
target_reverse_proxy:
  enabled: true
  traefik:
    port: 80
    dashboard_port: 8080
    https_port: 443
    version: "v3.0"

# Target: Watchtower (Container Auto-Updates)
target_watchtower:
  enabled: false
  schedule: "0 4 * * *"
  cleanup: true

# Target: Docker Configuration
target_docker:
  version: "latest"
  compose_version: "v2"
  storage_driver: "overlay2"
  log_driver: "json-file"
  log_max_size: "10m"
  log_max_file: "3"

# Target: System Maintenance
target_maintenance:
  auto_cleanup:
    enabled: true
    disk_threshold: 80
    schedule: "0 5 * * 0"
  auto_updates:
    enabled: false
    schedule: "0 6 * * 0"
    auto_reboot: false
    reboot_time: "03:00"

# Target: Ansible Pull (Self-Update)
# Automatically pulls and applies configuration from a Git repository
target_ansible_pull:
  enabled: $(if [[ ${ENABLE_SELF_UPDATE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
$(if [[ ${ENABLE_SELF_UPDATE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then cat <<EOAP
  repo_url: "${SELF_UPDATE_REPO_URL}"
  branch: "${SELF_UPDATE_BRANCH:-main}"
  schedule: "${SELF_UPDATE_SCHEDULE:-0 5 * * *}"
  check_only: $(if [[ ${SELF_UPDATE_CHECK_ONLY:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  playbook: "playbooks/setup-targets.yml"
  log_file: "/var/log/ansible-pull.log"
EOAP
fi)

# Target: Virtualization
target_virtualization:
  qemu_guest_agent: false

# Target: Performance Tuning
target_performance:
  tuning_enabled: false

# =============================================================================
# CONTROL NODE CONFIGURATION
# =============================================================================

control_node_install_dir: "/opt/control-node"

# Control: Uptime Kuma (Centralized Monitoring)
control_uptime_kuma:
  enabled: true
  port: 3001
  version: "1"

# Control: Grafana (Centralized Dashboards)
control_grafana:
  enabled: true
  port: 3000
  version: "latest"
  admin_user: "admin"

# Control: Loki (Centralized Log Aggregation)
control_loki:
  enabled: true
  port: 3100
  version: "latest"
  retention_period: "744h"

# Control: Netdata Parent (Centralized Metrics)
control_netdata:
  enabled: true
  port: 19999
  version: "latest"
  stream_api_key: "{{ vault_netdata_stream_api_key | default('changeme') }}"

# Control: Scanopy/Trivy (Container Security)
control_scanopy:
  enabled: true
  port: 8080
  trivy_version: "latest"

# Control: PruneMate (Docker Cleanup)
control_prunemate:
  enabled: true
  schedule: "0 3 * * 0"

# =============================================================================
# SERVICE DISCOVERY & AUTO-REGISTRATION
# =============================================================================
# When enabled, services automatically register with the control node.

control_node_ip: ""  # Set during control node setup

service_discovery:
  enabled: false  # Enabled after control node setup
  netdata_streaming:
    enabled: false
    api_key: "{{ control_netdata.stream_api_key }}"
  log_aggregation:
    enabled: false
    extra_labels:
      environment: "production"
  uptime_monitoring:
    enabled: false
    monitored_services:
      - name: "Dockge"
        type: "http"
        port: "{{ target_dockge.port }}"
      - name: "Netdata"
        type: "http"
        port: "{{ target_netdata.port }}"
      - name: "SSH"
        type: "port"
        port: 22
  dns_registration:
    enabled: false
    domain: "internal"

# =============================================================================
# DEBUG & FEATURE FLAGS
# =============================================================================
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
  password: "${DOCKGE_ADMIN_PASSWORD:-changeme-on-first-login}"

vault_uptime_kuma_credentials:
  username: "admin"
  password: "changeme-on-first-login"

# Monitoring & Observability
vault_netdata_claim_token: "${NETDATA_CLAIM_TOKEN}"
vault_netdata_stream_api_key: "${NETDATA_STREAM_API_KEY:-11111111-2222-3333-4444-555555555555}"

# Control Node Grafana (for centralized monitoring)
vault_control_grafana_password: "${CONTROL_GRAFANA_PASSWORD:-admin}"

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

# System Users
vault_system_users:
  admin_password: "${ADMIN_PASSWORD:-}"
  admin_ssh_key: "${ADMIN_SSH_KEY:-}"

# Note: DNS, Traefik, Watchtower, Authentik, Step-CA, and Semaphore secrets
# are added during control node setup via update_vault_for_control_services()
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

    print_warning "This will configure ${#TARGET_HOSTS[@]} target server(s)"

    # Show service list if we have config variables (fresh install)
    if [[ -n "${ENABLE_DOCKGE:-}" ]]; then
        echo "Services to be configured:"
        if [[ $ENABLE_DOCKGE =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Dockge (Container Management)"; fi
        if [[ $ENABLE_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Netdata (Monitoring)"; fi
        if [[ $ENABLE_LOGGING =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Promtail (Log Collection)"; fi
        if [[ $ENABLE_BACKUPS =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Restic Backups"; fi
        if [[ $ENABLE_FAIL2BAN =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - fail2ban (Security)"; fi
        if [[ $ENABLE_UFW =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - UFW Firewall"; fi
        if [[ ${ENABLE_SYSTEM_USERS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - System Users (Admin Account)"; fi
        if [[ ${ENABLE_LVM_CONFIG:-y} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - LVM Config (Disk Management)"; fi
        if [[ ${ENABLE_NAS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - NAS Mounts (Network Storage)"; fi
        if [[ ${ENABLE_SELF_UPDATE:-y} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "  - Self-Update (Ansible Pull)"; fi
    elif [[ "${RERUN_EXISTING:-}" == true ]]; then
        echo "(Re-running with existing configuration from group_vars/all.yml)"
    fi
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

        # Offer to install control node services (skip for re-runs unless adding servers)
        if [[ "${RERUN_EXISTING:-}" != true ]]; then
            offer_control_node_setup
        fi

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
    echo "  ${BOLD}Centralized Monitoring Stack:${NC}"
    echo "  - Uptime Kuma: Monitor ALL target servers from a single dashboard"
    echo "  - Grafana: Central dashboards for logs and metrics"
    echo "  - Loki: Aggregate logs from all target Promtail instances"
    echo "  - Netdata Parent: Aggregate metrics from all target Netdata instances"
    echo
    echo "  ${BOLD}Centralized Infrastructure Services:${NC}"
    echo "  - DNS (Pi-hole + Unbound): Network-wide ad-blocking and DNS"
    echo "  - Traefik: Reverse proxy with automatic SSL certificates"
    echo "  - Watchtower: Auto-update Docker containers across all servers"
    echo "  - Authentik: Single Sign-On (SSO) for all your apps"
    echo "  - Step-CA: Internal Certificate Authority for HTTPS"
    echo "  - Semaphore: Web UI for running Ansible playbooks"
    echo
    echo "  ${BOLD}Target Server Streaming:${NC}"
    echo "  - Targets can stream metrics/logs to this control node"
    echo "  - All data visible in central Grafana"
    echo

    read -p "Install central monitoring dashboard on this computer? (Y/n): " -r INSTALL_CONTROL
    echo

    if [[ ! $INSTALL_CONTROL =~ ^[Nn]$ ]]; then
        # Get control node IP for target streaming config
        local control_ip
        control_ip=$(hostname -I | awk '{print $1}')
        echo "  This is the IP address that target servers will send data to:"
        read -p "This computer's IP address [${control_ip}]: " CONTROL_NODE_IP
        CONTROL_NODE_IP=${CONTROL_NODE_IP:-$control_ip}

        echo
        echo "  Centralized log collection streams all server logs (Docker, system, apps)"
        echo "  to Loki on this control node. View all logs in one Grafana dashboard."
        read -p "Enable centralized log collection? (Y/n): " -r ENABLE_CENTRAL_LOKI
        ENABLE_CENTRAL_LOKI=${ENABLE_CENTRAL_LOKI:-y}

        echo
        echo "  Centralized metrics streaming sends CPU, memory, disk, and network data"
        echo "  from all servers to a parent Netdata on this control node. View all"
        echo "  server health metrics in one dashboard."
        read -p "Enable centralized metrics dashboard? (Y/n): " -r ENABLE_CENTRAL_NETDATA
        ENABLE_CENTRAL_NETDATA=${ENABLE_CENTRAL_NETDATA:-y}

        # Generate Netdata stream API key for centralized metrics
        if [[ $ENABLE_CENTRAL_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then
            NETDATA_STREAM_API_KEY=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
            print_info "Generated Netdata stream API key for secure metrics streaming"
        fi

        # Generate control node Grafana password
        echo
        echo "  Grafana is your central dashboard for viewing logs and metrics from all servers."
        echo "  Set a password for the admin account (username: admin)."
        echo "  Press Enter to auto-generate a secure password."
        read -sp "Central Grafana admin password [auto-generate]: " CONTROL_GRAFANA_PASSWORD
        echo
        if [[ -z "$CONTROL_GRAFANA_PASSWORD" ]]; then
            CONTROL_GRAFANA_PASSWORD=$(openssl rand -base64 16)
            print_info "Generated central Grafana admin password (will be shown at end)"
        fi

        # Centralized Services Section
        echo
        echo -e "${BOLD}Additional Centralized Services (Optional):${NC}"
        echo

        # Authentik (Identity Provider) - Control Node
        echo -e "${BOLD}Authentik (Single Sign-On):${NC}"
        echo "  Centralized identity management and SSO for all your applications."
        echo "  Requires more resources (2GB+ RAM recommended)."
        read -p "Enable Authentik identity provider? (y/N): " -r ENABLE_AUTHENTIK
        echo
        ENABLE_AUTHENTIK=${ENABLE_AUTHENTIK:-n}

        if [[ $ENABLE_AUTHENTIK =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -p "Authentik web port [9000]: " AUTHENTIK_PORT
            AUTHENTIK_PORT=${AUTHENTIK_PORT:-9000}

            read -p "Admin email: " AUTHENTIK_ADMIN_EMAIL
            echo "  Set Authentik admin password:"
            read -sp "Admin password: " AUTHENTIK_ADMIN_PASSWORD
            echo
        fi

        # Step-CA (Certificate Authority) - Control Node
        echo
        echo -e "${BOLD}Step-CA (Internal Certificate Authority):${NC}"
        echo "  Centralized CA to issue SSL certificates for all internal services."
        read -p "Enable internal certificate authority? (y/N): " -r ENABLE_STEP_CA
        echo
        ENABLE_STEP_CA=${ENABLE_STEP_CA:-n}

        if [[ $ENABLE_STEP_CA =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -p "CA name [Server-Helper Internal CA]: " STEP_CA_NAME
            STEP_CA_NAME=${STEP_CA_NAME:-Server-Helper Internal CA}

            read -p "Step-CA port [9000]: " STEP_CA_PORT
            STEP_CA_PORT=${STEP_CA_PORT:-9000}

            echo "  Set password for CA (used to sign certificates):"
            read -sp "CA password: " STEP_CA_PASSWORD
            echo
        fi

        # Semaphore (Ansible UI) - Control Node
        echo
        echo -e "${BOLD}Semaphore (Ansible Web UI):${NC}"
        echo "  Web interface to run Ansible playbooks against your targets."
        read -p "Enable Semaphore Ansible UI? (y/N): " -r ENABLE_SEMAPHORE
        echo
        ENABLE_SEMAPHORE=${ENABLE_SEMAPHORE:-n}

        if [[ $ENABLE_SEMAPHORE =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -p "Semaphore web port [3000]: " SEMAPHORE_PORT
            SEMAPHORE_PORT=${SEMAPHORE_PORT:-3000}

            read -p "Admin username [admin]: " SEMAPHORE_ADMIN_USER
            SEMAPHORE_ADMIN_USER=${SEMAPHORE_ADMIN_USER:-admin}

            read -p "Admin email: " SEMAPHORE_ADMIN_EMAIL
            echo "  Set Semaphore admin password:"
            read -sp "Admin password: " SEMAPHORE_ADMIN_PASSWORD
            echo

            # Generate encryption key for Semaphore
            SEMAPHORE_ACCESS_KEY_ENCRYPTION=$(openssl rand -base64 32)
        fi

        # DNS (Pi-hole + Unbound) - Control Node
        echo
        echo -e "${BOLD}DNS Server (Pi-hole + Unbound):${NC}"
        echo "  Centralized ad-blocking and DNS for your entire network."
        echo "  Point your router/devices to this server for network-wide ad-blocking."
        read -p "Enable centralized DNS server? (y/N): " -r ENABLE_DNS
        echo
        ENABLE_DNS=${ENABLE_DNS:-n}

        if [[ $ENABLE_DNS =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  Port for Pi-hole web dashboard"
            read -p "Pi-hole dashboard port [8080]: " PIHOLE_PORT
            PIHOLE_PORT=${PIHOLE_PORT:-8080}

            echo "  Domain name for your internal network (e.g., 'home' or 'internal')"
            read -p "Private domain [internal]: " DNS_PRIVATE_DOMAIN
            DNS_PRIVATE_DOMAIN=${DNS_PRIVATE_DOMAIN:-internal}

            echo "  Create a password for the Pi-hole admin dashboard:"
            read -sp "Pi-hole admin password: " PIHOLE_PASSWORD
            echo

            echo
            echo "  Unbound can forward to public DNS or resolve directly (more private)"
            read -p "Use direct DNS resolution (no forwarding to Google/Cloudflare)? (Y/n): " -r DNS_DIRECT_RESOLVE
            DNS_DIRECT_RESOLVE=${DNS_DIRECT_RESOLVE:-y}
        fi

        # Traefik (Reverse Proxy) - Control Node
        echo
        echo -e "${BOLD}Reverse Proxy (Traefik):${NC}"
        echo "  Centralized HTTPS/SSL termination and routing for all services."
        echo "  Automatically obtains Let's Encrypt certificates for your domains."
        read -p "Enable centralized reverse proxy? (y/N): " -r ENABLE_REVERSE_PROXY
        echo
        ENABLE_REVERSE_PROXY=${ENABLE_REVERSE_PROXY:-n}

        if [[ $ENABLE_REVERSE_PROXY =~ ^[Yy]([Ee][Ss])?$ ]]; then
            read -p "Your domain name (e.g., example.com): " TRAEFIK_DOMAIN

            read -p "Email for Let's Encrypt certificates: " TRAEFIK_ACME_EMAIL

            read -p "Traefik dashboard port [8080]: " TRAEFIK_DASHBOARD_PORT
            TRAEFIK_DASHBOARD_PORT=${TRAEFIK_DASHBOARD_PORT:-8080}

            echo "  Use Cloudflare for DNS challenge (recommended for wildcard certs)?"
            read -p "Enable Cloudflare DNS challenge? (y/N): " -r TRAEFIK_CLOUDFLARE
            TRAEFIK_CLOUDFLARE=${TRAEFIK_CLOUDFLARE:-n}

            if [[ $TRAEFIK_CLOUDFLARE =~ ^[Yy]([Ee][Ss])?$ ]]; then
                read -p "Cloudflare API token: " CF_API_TOKEN
                read -p "Cloudflare Zone ID: " CF_ZONE_ID
            fi
        fi

        # Watchtower (Auto Container Updates) - Control Node
        echo
        echo -e "${BOLD}Watchtower (Auto Container Updates):${NC}"
        echo "  Centralized auto-update for Docker containers on control node."
        echo "  Can monitor and update containers automatically."
        read -p "Enable Watchtower auto-updates? (y/N): " -r ENABLE_WATCHTOWER
        echo
        ENABLE_WATCHTOWER=${ENABLE_WATCHTOWER:-n}

        if [[ $ENABLE_WATCHTOWER =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  When should Watchtower check for updates?"
            echo "  Format: cron expression (default: 4:00 AM daily)"
            read -p "Update schedule [0 4 * * *]: " WATCHTOWER_SCHEDULE
            WATCHTOWER_SCHEDULE=${WATCHTOWER_SCHEDULE:-0 4 * * *}

            read -p "Monitor only (notify but don't update)? (y/N): " -r WATCHTOWER_MONITOR_ONLY
            WATCHTOWER_MONITOR_ONLY=${WATCHTOWER_MONITOR_ONLY:-n}

            read -p "Remove old images after update? (Y/n): " -r WATCHTOWER_CLEANUP
            WATCHTOWER_CLEANUP=${WATCHTOWER_CLEANUP:-y}
        fi

        # Write control node service configs to all.yml
        update_config_for_control_services

        # Update vault with control node service secrets
        update_vault_for_control_services

        print_info "Installing control node services..."

        # Run control node playbook
        if ansible-playbook playbooks/setup-control.yml -v; then
            print_success "Control node services installed!"
            echo
            print_info "Access centralized services:"
            echo "  - Grafana:       http://${CONTROL_NODE_IP}:3000 (admin/admin)"
            echo "  - Uptime Kuma:   http://${CONTROL_NODE_IP}:3001"
            echo "  - Loki:          http://${CONTROL_NODE_IP}:3100"
            echo "  - Netdata:       http://${CONTROL_NODE_IP}:19999"
            echo

            # Update config with streaming settings if enabled
            if [[ $ENABLE_CENTRAL_LOKI =~ ^[Yy]([Ee][Ss])?$ ]] || [[ $ENABLE_CENTRAL_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then
                print_info "Updating target configuration for centralized streaming..."
                update_config_for_streaming
                print_success "Target streaming configuration updated"
                echo
                print_warning "Re-run setup on targets to enable streaming:"
                print_info "  ansible-playbook playbooks/setup-targets.yml"
            fi

            # Offer to run service auto-registration
            echo
            read -p "Auto-register all target services with Uptime Kuma? (Y/n): " -r RUN_REGISTRATION
            RUN_REGISTRATION=${RUN_REGISTRATION:-y}

            if [[ $RUN_REGISTRATION =~ ^[Yy]([Ee][Ss])?$ ]]; then
                print_info "Registering target services with Uptime Kuma..."
                if ansible-playbook playbooks/register-services.yml -v; then
                    print_success "Services auto-registered with Uptime Kuma!"
                    echo
                    print_info "All target services are now monitored in Uptime Kuma:"
                    echo "  http://${CONTROL_NODE_IP}:3001"
                else
                    print_warning "Service registration had issues (non-critical)"
                    print_info "You can run it manually later with:"
                    print_info "  ansible-playbook playbooks/register-services.yml"
                fi
            else
                print_info "Skipping auto-registration"
                print_info "You can register services later with:"
                print_info "  ansible-playbook playbooks/register-services.yml"
            fi
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

# Update config file with streaming settings
update_config_for_streaming() {
    local config_file="group_vars/all.yml"

    # Append service discovery and streaming configuration
    cat >> "$config_file" <<EOF

# =============================================================================
# SERVICE DISCOVERY & CENTRALIZED MONITORING
# =============================================================================
# Added by setup.sh for centralized monitoring
# This enables target nodes to stream metrics/logs to control node

control_node_ip: "${CONTROL_NODE_IP}"

# Service Discovery Configuration
service_discovery:
  enabled: true

  # Netdata parent-child streaming
  netdata_streaming:
    enabled: $(if [[ $ENABLE_CENTRAL_NETDATA =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

  # Promtail -> Central Loki log aggregation
  log_aggregation:
    enabled: $(if [[ $ENABLE_CENTRAL_LOKI =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
    extra_labels: {}

  # Auto-register targets with Uptime Kuma
  uptime_monitoring:
    enabled: true

  # Register targets in Pi-hole DNS
  dns_registration:
    enabled: $(if [[ ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

# Control Node Service Configuration
control_loki:
  enabled: true
  port: 3100

control_netdata:
  enabled: true
  port: 19999
  stream_api_key: "{{ vault_netdata_stream_api_key }}"

control_grafana:
  enabled: true
  port: 3000

control_uptime_kuma:
  enabled: true
  port: 3001
EOF
}

# Update config file with control node services
update_config_for_control_services() {
    local config_file="group_vars/all.yml"

    # Only add if any control-node-only services are enabled
    if [[ ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || \
       [[ ${ENABLE_REVERSE_PROXY:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || \
       [[ ${ENABLE_WATCHTOWER:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || \
       [[ ${ENABLE_AUTHENTIK:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || \
       [[ ${ENABLE_STEP_CA:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || \
       [[ ${ENABLE_SEMAPHORE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then

        cat >> "$config_file" <<EOF

# =============================================================================
# CENTRALIZED INFRASTRUCTURE SERVICES (Control Node Only)
# =============================================================================
# Added by setup.sh for control node services

EOF

        # Authentik configuration
        if [[ ${ENABLE_AUTHENTIK:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# Authentik (Identity Provider)
authentik:
  enabled: true
  version: "2024.12"
  http_port: ${AUTHENTIK_PORT:-9000}
  https_port: 9443
  db_user: authentik
  db_name: authentik
  email:
    enabled: false

EOF
        fi

        # Step-CA configuration
        if [[ ${ENABLE_STEP_CA:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# Step-CA (Certificate Authority)
step_ca:
  enabled: true
  name: "${STEP_CA_NAME:-Server-Helper Internal CA}"
  port: ${STEP_CA_PORT:-9000}
  provisioner_name: "admin"
  default_cert_duration: "720h"
  max_cert_duration: "2160h"
  acme:
    enabled: true

EOF
        fi

        # Semaphore configuration
        if [[ ${ENABLE_SEMAPHORE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# Semaphore (Ansible UI)
semaphore:
  enabled: true
  port: ${SEMAPHORE_PORT:-3000}
  database:
    dialect: postgres
    host: semaphore-db
    port: 5432
    name: semaphore
    user: semaphore
  admin:
    username: "${SEMAPHORE_ADMIN_USER:-admin}"
    email: "${SEMAPHORE_ADMIN_EMAIL:-admin@example.com}"

EOF
        fi

        # DNS (Pi-hole + Unbound) configuration
        if [[ ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# DNS (Pi-hole + Unbound) - Centralized
dns:
  enabled: true
  stack_dir: /opt/dockge/stacks/dns
  network_name: dns
  private_domain: "${DNS_PRIVATE_DOMAIN:-internal}"
  local_domain: local

  pihole:
    version: latest
    port: ${PIHOLE_PORT:-8080}
    theme: default-dark

  unbound:
    version: latest
    forward_zone: $(if [[ ${DNS_DIRECT_RESOLVE:-y} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "false"; else echo "true"; fi)

EOF
        fi

        # Traefik (Reverse Proxy) configuration
        if [[ ${ENABLE_REVERSE_PROXY:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# Reverse Proxy (Traefik) - Centralized
reverse_proxy:
  enabled: true
  domain: "${TRAEFIK_DOMAIN:-}"
  acme_email: "${TRAEFIK_ACME_EMAIL:-}"
  dashboard_port: ${TRAEFIK_DASHBOARD_PORT:-8080}
  cloudflare:
    enabled: $(if [[ ${TRAEFIK_CLOUDFLARE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

EOF
        fi

        # Watchtower configuration
        if [[ ${ENABLE_WATCHTOWER:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            cat >> "$config_file" <<EOF
# Watchtower (Auto Container Updates) - Centralized
watchtower:
  enabled: true
  schedule: "${WATCHTOWER_SCHEDULE:-0 4 * * *}"
  cleanup: $(if [[ ${WATCHTOWER_CLEANUP:-y} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)
  monitor_only: $(if [[ ${WATCHTOWER_MONITOR_ONLY:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then echo "true"; else echo "false"; fi)

EOF
        fi
    fi
}

# Update vault file with control node service secrets
update_vault_for_control_services() {
    local vault_file="group_vars/vault.yml"
    local vault_password_file=".vault_password"

    # Only proceed if any control node services or centralized monitoring is enabled
    if [[ ! ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_REVERSE_PROXY:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_AUTHENTIK:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_STEP_CA:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_SEMAPHORE:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_CENTRAL_NETDATA:-n} =~ ^[Yy]([Ee][Ss])?$ ]] && \
       [[ ! ${ENABLE_CENTRAL_LOKI:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        return 0
    fi

    # Check if vault password file exists
    if [[ ! -f "$vault_password_file" ]]; then
        print_warning "Vault password file not found, skipping vault update"
        return 1
    fi

    # Decrypt vault to temp file
    local temp_vault
    temp_vault=$(mktemp)

    if ! ansible-vault decrypt "$vault_file" --vault-password-file="$vault_password_file" --output="$temp_vault" 2>/dev/null; then
        print_warning "Failed to decrypt vault, skipping vault update"
        rm -f "$temp_vault"
        return 1
    fi

    # Append control node service secrets
    cat >> "$temp_vault" <<EOF

# =============================================================================
# CONTROL NODE SERVICE SECRETS
# =============================================================================
# Added by setup.sh for control node services

EOF

    # Authentik secrets
    if [[ ${ENABLE_AUTHENTIK:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        cat >> "$temp_vault" <<EOF
vault_authentik_credentials:
  admin_email: "${AUTHENTIK_ADMIN_EMAIL}"
  admin_password: "${AUTHENTIK_ADMIN_PASSWORD}"
  secret_key: "$(openssl rand -base64 32)"
  postgres_password: "$(openssl rand -base64 16)"

EOF
    fi

    # Step-CA secrets
    if [[ ${ENABLE_STEP_CA:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        cat >> "$temp_vault" <<EOF
vault_step_ca_password: "${STEP_CA_PASSWORD}"
vault_step_ca_provisioner_password: "${STEP_CA_PASSWORD}"

EOF
    fi

    # Semaphore secrets
    if [[ ${ENABLE_SEMAPHORE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        cat >> "$temp_vault" <<EOF
vault_semaphore_db_password: "$(openssl rand -base64 16)"
vault_semaphore_admin_password: "${SEMAPHORE_ADMIN_PASSWORD}"
vault_semaphore_access_key_encryption: "${SEMAPHORE_ACCESS_KEY_ENCRYPTION:-$(openssl rand -base64 32)}"

EOF
    fi

    # DNS secrets
    if [[ ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        cat >> "$temp_vault" <<EOF
vault_dns:
  pihole_password: "${PIHOLE_PASSWORD}"

EOF
    fi

    # Traefik/Cloudflare secrets
    if [[ ${ENABLE_REVERSE_PROXY:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
        cat >> "$temp_vault" <<EOF
vault_letsencrypt_email: "${TRAEFIK_ACME_EMAIL:-}"

vault_cloudflare_credentials:
  api_token: "${CF_API_TOKEN:-}"
  zone_id: "${CF_ZONE_ID:-}"

EOF
    fi

    # Centralized monitoring secrets (Netdata streaming, Grafana)
    if [[ ${ENABLE_CENTRAL_NETDATA:-n} =~ ^[Yy]([Ee][Ss])?$ ]] || [[ -n "${NETDATA_STREAM_API_KEY:-}" ]]; then
        cat >> "$temp_vault" <<EOF
# Netdata Stream API Key - used for parent-child streaming
# Target Netdata instances use this key to authenticate when streaming to the control node
vault_netdata_stream_api_key: "${NETDATA_STREAM_API_KEY}"

EOF
    fi

    if [[ -n "${CONTROL_GRAFANA_PASSWORD:-}" ]]; then
        cat >> "$temp_vault" <<EOF
# Central Grafana admin password (overrides the default from initial setup)
vault_control_grafana_password: "${CONTROL_GRAFANA_PASSWORD}"

EOF
    fi

    # Re-encrypt the vault
    if ansible-vault encrypt "$temp_vault" --vault-password-file="$vault_password_file" --output="$vault_file"; then
        print_success "Vault updated with control node service secrets"
    else
        print_warning "Failed to re-encrypt vault"
    fi

    rm -f "$temp_vault"
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

        # For re-runs or when config variables exist, show service URLs
        if [[ "${RERUN_EXISTING:-}" == true ]]; then
            # Use default ports for re-runs
            echo -e "  ${GREEN}Dockge:${NC}      http://${host_ip}:5001"
            echo -e "  ${GREEN}Netdata:${NC}     http://${host_ip}:19999"
        else
            if [[ ${ENABLE_DOCKGE:-} =~ ^[Yy]([Ee][Ss])?$ ]]; then
                echo -e "  ${GREEN}Dockge:${NC}      http://${host_ip}:${DOCKGE_PORT:-5001}"
            fi
            if [[ ${ENABLE_NETDATA:-} =~ ^[Yy]([Ee][Ss])?$ ]]; then
                echo -e "  ${GREEN}Netdata:${NC}     http://${host_ip}:${NETDATA_PORT:-19999}"
            fi
            if [[ ${ENABLE_LOGGING:-} =~ ^[Yy]([Ee][Ss])?$ ]]; then
                echo -e "  ${GREEN}Promtail:${NC}    (streaming logs to control node)"
            fi
        fi
        echo
    done

    # Show control node services if installed
    if [[ -n "${CONTROL_NODE_IP:-}" ]]; then
        echo -e "${BOLD}Control Node (${CONTROL_NODE_IP}):${NC}"
        echo -e "  ${GREEN}Grafana:${NC}     http://${CONTROL_NODE_IP}:3000 (admin/admin)"
        echo -e "  ${GREEN}Uptime Kuma:${NC} http://${CONTROL_NODE_IP}:3001"
        echo -e "  ${GREEN}Loki:${NC}        http://${CONTROL_NODE_IP}:3100"
        echo -e "  ${GREEN}Netdata:${NC}     http://${CONTROL_NODE_IP}:19999"
        if [[ ${ENABLE_AUTHENTIK:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Authentik:${NC}   http://${CONTROL_NODE_IP}:${AUTHENTIK_PORT:-9000}"
        fi
        if [[ ${ENABLE_STEP_CA:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Step-CA:${NC}     https://${CONTROL_NODE_IP}:${STEP_CA_PORT:-9000}"
        fi
        if [[ ${ENABLE_SEMAPHORE:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Semaphore:${NC}   http://${CONTROL_NODE_IP}:${SEMAPHORE_PORT:-3000}"
        fi
        if [[ ${ENABLE_DNS:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Pi-hole:${NC}     http://${CONTROL_NODE_IP}:${PIHOLE_PORT:-8080}/admin"
        fi
        if [[ ${ENABLE_REVERSE_PROXY:-n} =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo -e "  ${GREEN}Traefik:${NC}     http://${CONTROL_NODE_IP}:${TRAEFIK_DASHBOARD_PORT:-8080}"
        fi
        echo
    fi

    # Show generated passwords if any
    if [[ -n "${DOCKGE_ADMIN_PASSWORD:-}" ]] || [[ -n "${CONTROL_GRAFANA_PASSWORD:-}" ]]; then
        echo -e "${BOLD}Generated Credentials (save these!):${NC}"
        if [[ -n "${DOCKGE_ADMIN_PASSWORD:-}" ]]; then
            echo -e "  ${YELLOW}Dockge:${NC}          admin / ${DOCKGE_ADMIN_PASSWORD}"
        fi
        if [[ -n "${CONTROL_GRAFANA_PASSWORD:-}" ]]; then
            echo -e "  ${YELLOW}Grafana:${NC}         admin / ${CONTROL_GRAFANA_PASSWORD}"
        fi
        echo
        print_warning "These passwords are stored encrypted in group_vars/vault.yml"
        echo
    fi

    print_info "Next steps:"
    echo "  1. Save the generated credentials shown above"
    if [[ -z "${CONTROL_NODE_IP:-}" ]]; then
        echo "  2. Run setup-control.yml to install centralized monitoring"
    else
        echo "  2. Configure Grafana dashboards and Uptime Kuma monitors"
    fi
    if [[ ${ENABLE_BACKUPS:-} =~ ^[Yy]([Ee][Ss])?$ ]] || [[ "${RERUN_EXISTING:-}" == true ]]; then
        echo "  3. Verify backup repositories are initialized"
    fi
    echo "  4. Review security settings and firewall rules"
    echo

    # Show streaming info if enabled
    if [[ "${ENABLE_CENTRAL_LOKI:-}" =~ ^[Yy]([Ee][Ss])?$ ]] || [[ "${ENABLE_CENTRAL_NETDATA:-}" =~ ^[Yy]([Ee][Ss])?$ ]]; then
        print_info "Centralized Monitoring:"
        if [[ "${ENABLE_CENTRAL_LOKI:-}" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  - Promtail on targets → Loki at ${CONTROL_NODE_IP}:3100"
        fi
        if [[ "${ENABLE_CENTRAL_NETDATA:-}" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "  - Netdata on targets → Parent at ${CONTROL_NODE_IP}:19999"
        fi
        echo
        print_warning "Re-run on targets to enable streaming:"
        echo "  ansible-playbook playbooks/setup-targets.yml"
        echo
    fi

    print_info "Useful commands (from command node):"
    echo "  - View service status: ansible all -m shell -a 'docker ps'"
    echo "  - Run backup manually: ansible-playbook playbooks/backup.yml"
    echo "  - Security audit: ansible-playbook playbooks/security.yml"
    echo "  - Update system: ansible-playbook playbooks/update.yml"
    echo "  - Add more nodes: Edit inventory/hosts.yml and re-run playbook"
    echo

    print_info "Documentation:"
    echo "  - README: ${SCRIPT_DIR}/README.md"
    echo "  - Quick Reference: ${SCRIPT_DIR}/docs/quick-reference.md"
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

    # Check for existing configuration (health check, add servers, re-run, or fresh)
    check_existing_config

    # Install dependencies on COMMAND NODE
    install_system_deps
    install_python_deps
    install_galaxy_deps

    # Configuration - skip if re-running on existing servers
    if [[ "${RERUN_EXISTING:-}" != true ]]; then
        # Prompt for new target servers (unless using existing only)
        if [[ "${USE_EXISTING_CONFIG:-}" != true ]] || [[ "${SETUP_MODE:-}" == "2" ]]; then
            prompt_target_nodes
        fi

        # Merge with existing if adding servers
        if [[ "${USE_EXISTING_CONFIG:-}" == true ]] && [[ "${SETUP_MODE:-}" == "2" ]]; then
            merge_inventory
        fi

        # Prompt for service configuration (skip if using existing config for re-run)
        if [[ "${USE_EXISTING_CONFIG:-}" != true ]]; then
            prompt_config
        fi

        # Create/update inventory and config files
        create_inventory
        if [[ "${USE_EXISTING_CONFIG:-}" != true ]]; then
            create_config
            create_vault
        fi
    fi

    # Pre-flight checks
    preflight_checks

    # Offer to run bootstrap playbook (skip for re-runs)
    if [[ "${RERUN_EXISTING:-}" != true ]]; then
        offer_bootstrap
    fi

    # Run playbook
    run_playbook

    print_success "Setup script completed"
    print_info "Log file: $LOG_FILE"
}

# Run main function
main "$@"
