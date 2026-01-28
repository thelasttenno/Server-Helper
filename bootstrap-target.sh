#!/usr/bin/env bash
#
# Server Helper v1.0.0 - Target Node Bootstrap Script
# ====================================================
# This script prepares a fresh Ubuntu server to be managed by Ansible.
# Run this ONCE on each new target node before adding it to your inventory.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/yourusername/Server-Helper/main/bootstrap-target.sh | bash
#   OR
#   ./bootstrap-target.sh
#
# What this does:
#   1. Installs Python 3 (required by Ansible)
#   2. Creates an admin user with sudo privileges
#   3. Adds your SSH public key for passwordless authentication
#   4. Updates system packages
#   5. Enables SSH server
#
# After running this, add the node to your inventory on the command node.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to print colored messages
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

print_header() {
    echo -e "\n${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║  Server Helper - Target Bootstrap     ║${NC}"
    echo -e "${BLUE}${BOLD}║  Prepare node for Ansible mgmt        ║${NC}"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}\n"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Please run: sudo $0"
        exit 1
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
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Update system packages
update_system() {
    print_info "Updating system packages..."
    apt-get update -qq
    apt-get upgrade -y -qq
    print_success "System packages updated"
}

# Install Python 3
install_python() {
    print_info "Installing Python 3..."

    if command -v python3 >/dev/null 2>&1; then
        PYTHON_VERSION=$(python3 --version)
        print_success "Python already installed: $PYTHON_VERSION"
    else
        apt-get install -y -qq python3 python3-apt
        print_success "Python 3 installed"
    fi
}

# Install OpenSSH server
install_ssh() {
    print_info "Ensuring SSH server is installed..."

    if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
        print_success "SSH server already running"
    else
        apt-get install -y -qq openssh-server
        systemctl enable ssh
        systemctl start ssh
        print_success "SSH server installed and started"
    fi
}

# Create admin user
create_admin_user() {
    print_info "Creating admin user for Ansible..."

    read -p "Enter username for Ansible admin user [ansible]: " ADMIN_USER
    ADMIN_USER=${ADMIN_USER:-ansible}

    if id "$ADMIN_USER" &>/dev/null; then
        print_warning "User '$ADMIN_USER' already exists"
    else
        # Create user with home directory
        useradd -m -s /bin/bash "$ADMIN_USER"
        print_success "User '$ADMIN_USER' created"
    fi

    # Add to sudo group
    usermod -aG sudo "$ADMIN_USER"

    # Configure passwordless sudo
    echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$ADMIN_USER"
    chmod 0440 "/etc/sudoers.d/$ADMIN_USER"
    print_success "Passwordless sudo configured for '$ADMIN_USER'"

    # Set password
    print_info "Set password for '$ADMIN_USER' (optional, press Enter to skip):"
    passwd "$ADMIN_USER" || true
}

# Add SSH key
add_ssh_key() {
    print_info "Adding SSH public key for passwordless authentication..."

    echo
    echo "Paste your SSH public key (from command node ~/.ssh/id_rsa.pub):"
    echo "Or press Enter to skip and configure manually later."
    read -r SSH_KEY

    if [[ -n "$SSH_KEY" ]]; then
        # Create .ssh directory
        mkdir -p "/home/$ADMIN_USER/.ssh"
        chmod 700 "/home/$ADMIN_USER/.ssh"

        # Add public key
        echo "$SSH_KEY" >> "/home/$ADMIN_USER/.ssh/authorized_keys"
        chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
        chown -R "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh"

        print_success "SSH key added to /home/$ADMIN_USER/.ssh/authorized_keys"
    else
        print_warning "SSH key not added. You'll need to use password authentication."
        print_info "To add key later, run on command node:"
        print_info "  ssh-copy-id $ADMIN_USER@$(hostname -I | awk '{print $1}')"
    fi
}

# Display completion message
show_completion() {
    print_header
    print_success "Target node bootstrap complete!"
    echo

    print_info "Node Information:"
    echo "  Hostname: $(hostname)"
    echo "  IP Address: $(hostname -I | awk '{print $1}')"
    echo "  Admin User: $ADMIN_USER"
    echo "  Python: $(python3 --version)"
    echo

    print_info "Next steps on your COMMAND NODE:"
    echo "  1. Add this node to inventory/hosts.yml:"
    echo
    echo "     $(hostname):"
    echo "       ansible_host: $(hostname -I | awk '{print $1}')"
    echo "       ansible_user: $ADMIN_USER"
    echo "       ansible_become: yes"
    echo
    echo "  2. Test connectivity:"
    echo "     ansible $(hostname) -m ping"
    echo
    echo "  3. Run the setup playbook:"
    echo "     ansible-playbook playbooks/setup.yml"
    echo

    print_warning "Important: Keep the '$ADMIN_USER' user credentials secure!"
}

# Main execution
main() {
    print_header

    check_root
    detect_os
    update_system
    install_python
    install_ssh
    create_admin_user
    add_ssh_key

    show_completion
}

# Run main
main "$@"
