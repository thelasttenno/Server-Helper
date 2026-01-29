#!/usr/bin/env bash
#
# Server Helper v2.0.0 - Target Node Bootstrap Script
# ====================================================
# This script prepares a fresh Ubuntu server to be managed by Ansible.
# Run this ONCE on each new target node before adding it to your inventory.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | sudo bash
#   OR
#   sudo ./bootstrap-target.sh
#
# What this does:
#   1. Detects virtualization type (VM vs LXC container)
#   2. Installs Python 3 (required by Ansible)
#   3. Expands LVM to use full disk (skipped for LXC)
#   4. Creates 2GB swap file (skipped for LXC)
#   5. Creates an admin user with sudo privileges
#   6. Adds your SSH public key for passwordless authentication
#   7. Installs QEMU Guest Agent (if running as VM)
#   8. Hardens SSH configuration
#   9. Updates system packages
#
# After running this, add the node to your inventory on the command node.
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

VERSION="2.0.0"
SWAP_SIZE_GB=2
DEFAULT_ADMIN_USER="ansible"

# =============================================================================
# COLOR OUTPUT
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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

print_step() {
    echo -e "\n${CYAN}${BOLD}>>> $1${NC}\n"
}

print_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   Server Helper v${VERSION} - Target Node Bootstrap            ║"
    echo "║   Prepare node for Ansible management                         ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
    fi
    print_success "Running as root"
}

# Detect OS type and version
detect_os() {
    print_step "Detecting Operating System"

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_PRETTY=$PRETTY_NAME
    else
        print_error "Cannot detect OS version (/etc/os-release not found)"
        exit 1
    fi

    print_info "Detected OS: $OS_PRETTY"

    # Check for supported OS
    case "$OS" in
        ubuntu)
            if [[ "${OS_VERSION%%.*}" -lt 20 ]]; then
                print_warning "Ubuntu version $OS_VERSION may not be fully supported"
                print_info "Recommended: Ubuntu 22.04 LTS or 24.04 LTS"
            fi
            ;;
        debian)
            if [[ "${OS_VERSION%%.*}" -lt 11 ]]; then
                print_warning "Debian version $OS_VERSION may not be fully supported"
            fi
            ;;
        *)
            print_warning "This script is designed for Ubuntu/Debian"
            print_warning "Detected: $OS $OS_VERSION"
            read -p "Continue anyway? (y/N): " -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

# Detect virtualization type (VM, LXC, or bare metal)
detect_virtualization() {
    print_step "Detecting Virtualization Type"

    IS_LXC=false
    IS_VM=false
    IS_BAREMETAL=false
    VIRT_TYPE="unknown"

    # Method 1: Check /proc/1/environ for container=lxc
    if [[ -f /proc/1/environ ]] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        IS_LXC=true
        VIRT_TYPE="lxc"
    # Method 2: Use systemd-detect-virt if available
    elif command -v systemd-detect-virt &>/dev/null; then
        local virt_result
        virt_result=$(systemd-detect-virt 2>/dev/null || echo "none")

        case "$virt_result" in
            lxc|lxc-libvirt)
                IS_LXC=true
                VIRT_TYPE="lxc"
                ;;
            none)
                IS_BAREMETAL=true
                VIRT_TYPE="bare-metal"
                ;;
            kvm|qemu|vmware|oracle|xen|microsoft|parallels)
                IS_VM=true
                VIRT_TYPE="$virt_result"
                ;;
            *)
                IS_VM=true
                VIRT_TYPE="$virt_result"
                ;;
        esac
    # Method 3: Check for container-specific files
    elif [[ -f /.dockerenv ]]; then
        print_error "Docker containers are not supported as target nodes"
        exit 1
    elif [[ -d /proc/vz ]] && [[ ! -d /proc/bc ]]; then
        IS_LXC=true
        VIRT_TYPE="openvz"
    else
        # Assume VM if we can't detect
        IS_VM=true
        VIRT_TYPE="unknown-vm"
    fi

    print_info "Virtualization type: $VIRT_TYPE"

    if [[ "$IS_LXC" == true ]]; then
        print_warning "Running in LXC container - LVM and swap operations will be skipped"
    elif [[ "$IS_VM" == true ]]; then
        print_info "Running as virtual machine - all features enabled"
    else
        print_info "Running on bare metal - all features enabled"
    fi
}

# =============================================================================
# SYSTEM UPDATES
# =============================================================================

update_system() {
    print_step "Updating System Packages"

    # Update package lists
    print_info "Updating package lists..."
    apt-get update -qq

    # Upgrade packages
    print_info "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

    print_success "System packages updated"
}

# =============================================================================
# PYTHON INSTALLATION
# =============================================================================

install_python() {
    print_step "Installing Python 3"

    if command -v python3 &>/dev/null; then
        local python_version
        python_version=$(python3 --version 2>&1)
        print_success "Python already installed: $python_version"
    else
        print_info "Installing Python 3..."
        apt-get install -y -qq python3 python3-apt python3-pip
        print_success "Python 3 installed"
    fi

    # Verify Python version
    local py_major py_minor
    py_major=$(python3 -c "import sys; print(sys.version_info.major)")
    py_minor=$(python3 -c "import sys; print(sys.version_info.minor)")

    if [[ "$py_major" -lt 3 ]] || { [[ "$py_major" -eq 3 ]] && [[ "$py_minor" -lt 8 ]]; }; then
        print_warning "Python 3.8+ recommended for Ansible. Found: Python ${py_major}.${py_minor}"
    fi
}

# =============================================================================
# SSH SERVER
# =============================================================================

install_ssh() {
    print_step "Configuring SSH Server"

    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        print_success "SSH server already running"
    else
        print_info "Installing OpenSSH server..."
        apt-get install -y -qq openssh-server
        systemctl enable ssh
        systemctl start ssh
        print_success "SSH server installed and started"
    fi
}

# =============================================================================
# LVM EXPANSION (Skip for LXC)
# =============================================================================

expand_lvm() {
    print_step "LVM Disk Expansion"

    if [[ "$IS_LXC" == true ]]; then
        print_warning "Skipping LVM expansion (not applicable for LXC containers)"
        return 0
    fi

    # Check if LVM is in use
    if ! command -v lvs &>/dev/null; then
        print_info "LVM not installed, skipping expansion"
        return 0
    fi

    # Find the root logical volume
    local root_lv root_vg free_space
    root_lv=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)

    if [[ -z "$root_lv" ]] || [[ ! "$root_lv" =~ /dev/mapper/ ]]; then
        print_info "Root filesystem is not on LVM, skipping expansion"
        return 0
    fi

    # Extract VG name from the LV path
    root_vg=$(lvs --noheadings -o vg_name "$root_lv" 2>/dev/null | tr -d ' ')

    if [[ -z "$root_vg" ]]; then
        print_warning "Could not determine volume group for root LV"
        return 0
    fi

    # Check for free space in VG
    free_space=$(vgs --noheadings -o vg_free --units g "$root_vg" 2>/dev/null | tr -d ' ' | sed 's/g$//')

    if [[ -z "$free_space" ]] || (( $(echo "$free_space < 0.1" | bc -l 2>/dev/null || echo "1") )); then
        print_info "No free space in volume group $root_vg, skipping expansion"
        return 0
    fi

    print_info "Found ${free_space}G free space in VG $root_vg"
    print_info "Expanding root LV to use all available space..."

    # Extend the logical volume
    if lvextend -l +100%FREE "$root_lv" &>/dev/null; then
        print_success "Logical volume extended"

        # Resize the filesystem
        local fs_type
        fs_type=$(findmnt -n -o FSTYPE / 2>/dev/null)

        case "$fs_type" in
            ext4|ext3|ext2)
                print_info "Resizing ext4 filesystem..."
                resize2fs "$root_lv" &>/dev/null
                ;;
            xfs)
                print_info "Resizing XFS filesystem..."
                xfs_growfs / &>/dev/null
                ;;
            *)
                print_warning "Unknown filesystem type: $fs_type - manual resize may be required"
                ;;
        esac

        print_success "Filesystem expanded to use all available space"
    else
        print_warning "LVM expansion failed (this may be normal if already expanded)"
    fi
}

# =============================================================================
# SWAP CONFIGURATION (Skip for LXC)
# =============================================================================

configure_swap() {
    print_step "Swap Configuration"

    if [[ "$IS_LXC" == true ]]; then
        print_warning "Skipping swap configuration (not applicable for LXC containers)"
        return 0
    fi

    local swap_file="/swapfile"
    local swap_size_bytes=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))

    # Check existing swap
    local current_swap
    current_swap=$(free -b | grep Swap | awk '{print $2}')
    local min_swap=$((SWAP_SIZE_GB * 1024 * 1024 * 1024))

    if [[ "$current_swap" -ge "$min_swap" ]]; then
        local swap_gb
        swap_gb=$(echo "scale=1; $current_swap / 1024 / 1024 / 1024" | bc)
        print_success "Sufficient swap already configured: ${swap_gb}GB"
        return 0
    fi

    # Check if swapfile already exists but might be too small
    if [[ -f "$swap_file" ]]; then
        print_info "Removing existing swap file..."
        swapoff "$swap_file" 2>/dev/null || true
        rm -f "$swap_file"
    fi

    print_info "Creating ${SWAP_SIZE_GB}GB swap file..."

    # Create swap file (use fallocate if available, otherwise dd)
    if command -v fallocate &>/dev/null; then
        fallocate -l "${SWAP_SIZE_GB}G" "$swap_file"
    else
        dd if=/dev/zero of="$swap_file" bs=1M count=$((SWAP_SIZE_GB * 1024)) status=progress
    fi

    # Set permissions
    chmod 600 "$swap_file"

    # Format as swap
    mkswap "$swap_file" &>/dev/null

    # Enable swap
    swapon "$swap_file"

    # Add to fstab if not already present
    if ! grep -q "$swap_file" /etc/fstab; then
        echo "$swap_file none swap sw 0 0" >> /etc/fstab
        print_info "Added swap to /etc/fstab for persistence"
    fi

    print_success "Swap file created and enabled: ${SWAP_SIZE_GB}GB"
}

# =============================================================================
# QEMU GUEST AGENT (Only for VMs)
# =============================================================================

install_qemu_agent() {
    print_step "QEMU Guest Agent"

    if [[ "$IS_LXC" == true ]] || [[ "$IS_BAREMETAL" == true ]]; then
        print_info "Skipping QEMU agent (only for VMs)"
        return 0
    fi

    # Only install for KVM/QEMU VMs
    if [[ "$VIRT_TYPE" != "kvm" ]] && [[ "$VIRT_TYPE" != "qemu" ]]; then
        print_info "Skipping QEMU agent (virtualization type: $VIRT_TYPE)"
        return 0
    fi

    if dpkg -l | grep -q "qemu-guest-agent"; then
        print_success "QEMU guest agent already installed"
    else
        print_info "Installing QEMU guest agent..."
        apt-get install -y -qq qemu-guest-agent
        systemctl enable qemu-guest-agent
        systemctl start qemu-guest-agent
        print_success "QEMU guest agent installed and started"
    fi
}

# =============================================================================
# ADMIN USER CREATION
# =============================================================================

create_admin_user() {
    print_step "Admin User Configuration"

    # Prompt for username
    read -p "Enter username for Ansible admin user [$DEFAULT_ADMIN_USER]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-$DEFAULT_ADMIN_USER}

    if id "$ADMIN_USER" &>/dev/null; then
        print_warning "User '$ADMIN_USER' already exists"
        read -p "Reconfigure this user? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing user configuration"
            return 0
        fi
    else
        # Create user with home directory
        print_info "Creating user '$ADMIN_USER'..."
        useradd -m -s /bin/bash "$ADMIN_USER"
        print_success "User '$ADMIN_USER' created"
    fi

    # Add to sudo group
    usermod -aG sudo "$ADMIN_USER"

    # Add to docker group if it exists
    if getent group docker &>/dev/null; then
        usermod -aG docker "$ADMIN_USER"
        print_info "Added '$ADMIN_USER' to docker group"
    fi

    # Configure passwordless sudo
    local sudoers_file="/etc/sudoers.d/$ADMIN_USER"
    echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "$sudoers_file"
    chmod 0440 "$sudoers_file"
    print_success "Passwordless sudo configured for '$ADMIN_USER'"

    # Optional: Set password
    echo
    print_info "Set password for '$ADMIN_USER' (optional, press Enter to skip):"
    print_info "Note: Password is optional if using SSH key authentication"
    if passwd "$ADMIN_USER" 2>/dev/null; then
        print_success "Password set for '$ADMIN_USER'"
    else
        print_info "Password not set (SSH key authentication recommended)"
    fi
}

# =============================================================================
# SSH KEY INJECTION
# =============================================================================

add_ssh_key() {
    print_step "SSH Key Configuration"

    echo
    echo "Paste your SSH public key (from command node ~/.ssh/id_rsa.pub):"
    echo "Or press Enter to skip and configure manually later."
    echo
    read -r SSH_KEY

    if [[ -n "$SSH_KEY" ]]; then
        # Validate SSH key format
        if [[ ! "$SSH_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
            print_warning "Key doesn't appear to be a valid SSH public key"
            read -p "Add anyway? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "SSH key not added"
                return 0
            fi
        fi

        # Create .ssh directory
        local ssh_dir="/home/$ADMIN_USER/.ssh"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"

        # Add public key (avoid duplicates)
        local auth_keys="$ssh_dir/authorized_keys"
        if [[ -f "$auth_keys" ]] && grep -qF "$SSH_KEY" "$auth_keys"; then
            print_info "SSH key already exists in authorized_keys"
        else
            echo "$SSH_KEY" >> "$auth_keys"
            print_success "SSH key added to $auth_keys"
        fi

        chmod 600 "$auth_keys"
        chown -R "$ADMIN_USER:$ADMIN_USER" "$ssh_dir"

    else
        print_warning "SSH key not added. You'll need to use password authentication."
        echo
        print_info "To add key later, run on command node:"
        print_info "  ssh-copy-id $ADMIN_USER@$(hostname -I | awk '{print $1}')"
    fi
}

# =============================================================================
# SSH HARDENING
# =============================================================================

harden_ssh() {
    print_step "SSH Hardening"

    local sshd_config="/etc/ssh/sshd_config"
    local sshd_config_dir="/etc/ssh/sshd_config.d"
    local hardening_file="$sshd_config_dir/99-server-helper.conf"

    # Create config directory if it doesn't exist
    mkdir -p "$sshd_config_dir"

    # Create hardening configuration
    cat > "$hardening_file" <<'EOF'
# Server Helper SSH Hardening
# Generated by bootstrap-target.sh

# Disable root login (use sudo instead)
PermitRootLogin no

# Enable public key authentication
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Disable X11 forwarding (reduce attack surface)
X11Forwarding no

# Set login grace time
LoginGraceTime 60

# Limit authentication attempts
MaxAuthTries 3

# Enable strict mode
StrictModes yes

# Disable TCP forwarding by default (can be enabled per-user if needed)
# AllowTcpForwarding no

# Log level for auditing
LogLevel VERBOSE
EOF

    chmod 600 "$hardening_file"

    # Test SSH configuration
    if sshd -t &>/dev/null; then
        print_success "SSH hardening configuration applied"

        # Reload SSH daemon
        if systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null; then
            print_success "SSH daemon reloaded"
        else
            print_warning "Could not reload SSH daemon - changes will apply on next restart"
        fi
    else
        print_error "SSH configuration test failed, removing hardening file"
        rm -f "$hardening_file"
    fi
}

# =============================================================================
# COMPLETION
# =============================================================================

show_completion() {
    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')

    echo
    echo -e "${GREEN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   Target Node Bootstrap Complete!                             ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${BOLD}Node Information:${NC}"
    echo "  Hostname:        $(hostname)"
    echo "  IP Address:      $ip_address"
    echo "  Admin User:      $ADMIN_USER"
    echo "  Python:          $(python3 --version 2>&1)"
    echo "  Virtualization:  $VIRT_TYPE"
    echo

    if [[ "$IS_LXC" != true ]]; then
        echo -e "${BOLD}System Status:${NC}"
        echo "  Swap:            $(free -h | grep Swap | awk '{print $2}')"
        echo "  Root Disk:       $(df -h / | tail -1 | awk '{print $2 " total, " $4 " free"}')"
        echo
    fi

    echo -e "${BOLD}Next Steps on your COMMAND NODE:${NC}"
    echo
    echo "  1. Run the setup script to add this server:"
    echo "     ${CYAN}./setup.sh${NC}"
    echo
    echo "  2. Or manually add to inventory/hosts.yml:"
    echo
    echo "     ${CYAN}$(hostname):${NC}"
    echo "       ${CYAN}ansible_host: $ip_address${NC}"
    echo "       ${CYAN}ansible_user: $ADMIN_USER${NC}"
    echo "       ${CYAN}ansible_become: yes${NC}"
    echo "       ${CYAN}ansible_python_interpreter: /usr/bin/python3${NC}"
    echo
    echo "  3. Test connectivity:"
    echo "     ${CYAN}ansible $(hostname) -m ping${NC}"
    echo
    echo "  4. Run the setup playbook:"
    echo "     ${CYAN}ansible-playbook playbooks/setup-targets.yml --limit $(hostname)${NC}"
    echo

    print_warning "Important: Keep the '$ADMIN_USER' user credentials secure!"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header

    # System checks
    check_root
    detect_os
    detect_virtualization

    echo
    read -p "Continue with bootstrap? (Y/n): " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Bootstrap cancelled"
        exit 0
    fi

    # System preparation
    update_system
    install_python
    install_ssh

    # Storage configuration (skipped for LXC)
    expand_lvm
    configure_swap

    # VM-specific configuration
    install_qemu_agent

    # User configuration
    create_admin_user
    add_ssh_key

    # Security hardening
    harden_ssh

    # Show completion message
    show_completion
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Server Helper - Target Node Bootstrap Script v${VERSION}"
        echo
        echo "Usage: sudo $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version"
        echo
        echo "This script prepares a target node for Ansible management."
        echo "Run as root on the target server."
        exit 0
        ;;
    --version|-v)
        echo "Server Helper Bootstrap v${VERSION}"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
