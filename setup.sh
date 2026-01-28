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

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================

# Show main menu
show_main_menu() {
    clear
    print_header
    echo -e "${BOLD}What would you like to do?${NC}"
    echo
    echo "  1) Setup      - Configure and deploy Server Helper"
    echo "  2) Extras     - Additional tools and utilities"
    echo "  3) Exit"
    echo
    read -p "Choose an option [1-3]: " -r MAIN_CHOICE
    echo

    case "$MAIN_CHOICE" in
        1)
            run_setup_menu
            ;;
        2)
            show_extras_menu
            ;;
        3)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_warning "Invalid option"
            show_main_menu
            ;;
    esac
}

# Show extras menu
show_extras_menu() {
    clear
    print_header
    echo -e "${BOLD}Extras Menu${NC}"
    echo
    echo "  1) Vault Management     - Manage Ansible Vault (encrypt/decrypt/edit)"
    echo "  2) Add Server           - Add new server to inventory"
    echo "  3) Open Service UIs     - Open web dashboards in browser"
    echo "  4) Test All Roles       - Run Molecule tests for all roles"
    echo "  5) Test Single Role     - Run Molecule test for one role"
    echo "  6) Test Remediation     - Test auto-remediation system"
    echo "  7) Back to Main Menu"
    echo
    read -p "Choose an option [1-7]: " -r EXTRAS_CHOICE
    echo

    case "$EXTRAS_CHOICE" in
        1)
            show_vault_menu
            ;;
        2)
            run_add_server
            ;;
        3)
            run_open_ui
            ;;
        4)
            run_test_all_roles
            ;;
        5)
            run_test_single_role
            ;;
        6)
            run_test_remediation
            ;;
        7)
            show_main_menu
            ;;
        *)
            print_warning "Invalid option"
            show_extras_menu
            ;;
    esac
}

# =============================================================================
# VAULT MANAGEMENT FUNCTIONS
# =============================================================================

show_vault_menu() {
    clear
    print_header
    echo -e "${BOLD}Vault Management${NC}"
    echo
    echo "  1) Initialize Vault     - Create vault password and setup"
    echo "  2) Edit Vault           - Edit encrypted vault file (recommended)"
    echo "  3) View Vault           - View encrypted vault file (read-only)"
    echo "  4) Encrypt File         - Encrypt a plain text file"
    echo "  5) Decrypt File         - Decrypt an encrypted file (dangerous!)"
    echo "  6) Re-key Vault         - Change vault password"
    echo "  7) Validate Vault       - Validate vault file(s)"
    echo "  8) Vault Status         - Show vault status"
    echo "  9) Back to Extras Menu"
    echo
    read -p "Choose an option [1-9]: " -r VAULT_CHOICE
    echo

    case "$VAULT_CHOICE" in
        1) vault_init ;;
        2) vault_edit ;;
        3) vault_view ;;
        4) vault_encrypt ;;
        5) vault_decrypt ;;
        6) vault_rekey ;;
        7) vault_validate ;;
        8) vault_status ;;
        9) show_extras_menu ;;
        *)
            print_warning "Invalid option"
            show_vault_menu
            ;;
    esac
}

# Check vault dependencies
check_vault_deps() {
    if ! command -v ansible-vault &> /dev/null; then
        print_error "ansible-vault not found. Please install Ansible first."
        return 1
    fi
    return 0
}

# Get vault password file path
get_vault_password_file() {
    echo "${SCRIPT_DIR}/.vault_password"
}

# Initialize vault setup
vault_init() {
    check_vault_deps || { show_vault_menu; return; }

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Initialize Ansible Vault${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        print_warning "Vault password file already exists: $VAULT_PASSWORD_FILE"
        echo
        read -p "Do you want to create a new one? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing vault password file."
            read -p "Press Enter to continue..."
            show_vault_menu
            return
        fi

        # Backup existing password
        local BACKUP="${VAULT_PASSWORD_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$VAULT_PASSWORD_FILE" "$BACKUP"
        print_info "Backed up existing password to: $BACKUP"
    fi

    print_info "Generating strong vault password..."
    openssl rand -base64 32 > "$VAULT_PASSWORD_FILE"
    chmod 600 "$VAULT_PASSWORD_FILE"
    print_success "Created vault password file: $VAULT_PASSWORD_FILE"

    echo
    print_warning "IMPORTANT: Save this password in a secure location!"
    print_info "You can view it with: cat $VAULT_PASSWORD_FILE"
    echo

    # Check if vault.yml exists
    if [[ ! -f "${SCRIPT_DIR}/group_vars/vault.yml" ]]; then
        echo
        read -p "Do you want to create group_vars/vault.yml now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            mkdir -p "${SCRIPT_DIR}/group_vars"
            if ansible-vault create "${SCRIPT_DIR}/group_vars/vault.yml" --vault-password-file="$VAULT_PASSWORD_FILE"; then
                print_success "Vault file created."
            else
                print_warning "Vault file creation cancelled or failed."
            fi
        fi
    fi

    echo
    print_success "Vault initialization complete!"
    echo
    print_info "Next steps:"
    echo "  1. Save vault password in your password manager"
    echo "  2. Share vault password securely with team (if applicable)"
    echo "  3. Edit vault file from the Vault Management menu"
    echo

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Edit vault file
vault_edit() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_error "Vault password file not found: $VAULT_PASSWORD_FILE"
        print_info "Run 'Initialize Vault' first."
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    echo -e "${BOLD}Available vault files:${NC}"
    echo "  1) group_vars/vault.yml (main secrets)"
    echo "  2) Enter custom path"
    echo
    read -p "Choose [1-2]: " -r FILE_CHOICE

    local FILE
    case "$FILE_CHOICE" in
        1) FILE="${SCRIPT_DIR}/group_vars/vault.yml" ;;
        2)
            read -p "Enter file path: " -r FILE
            ;;
        *)
            print_warning "Invalid option"
            show_vault_menu
            return
            ;;
    esac

    if [[ ! -f "$FILE" ]]; then
        print_warning "File not found: $FILE"
        read -p "Do you want to create a new encrypted file? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$(dirname "$FILE")"
            if ansible-vault create "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
                print_success "Created and encrypted: $FILE"
            else
                print_warning "File creation cancelled or failed."
            fi
        fi
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    print_info "Opening encrypted file in editor: $FILE"
    print_info "The file will be decrypted in-memory only (secure)."
    echo

    if ansible-vault edit "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
        print_success "File edited and saved (still encrypted): $FILE"
    else
        print_warning "Edit cancelled or failed."
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# View vault file
vault_view() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_error "Vault password file not found: $VAULT_PASSWORD_FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    echo -e "${BOLD}Available vault files:${NC}"
    echo "  1) group_vars/vault.yml"
    echo "  2) Enter custom path"
    echo
    read -p "Choose [1-2]: " -r FILE_CHOICE

    local FILE
    case "$FILE_CHOICE" in
        1) FILE="${SCRIPT_DIR}/group_vars/vault.yml" ;;
        2) read -p "Enter file path: " -r FILE ;;
        *) print_warning "Invalid option"; show_vault_menu; return ;;
    esac

    if [[ ! -f "$FILE" ]]; then
        print_error "File not found: $FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    print_info "Viewing encrypted file: $FILE"
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo

    if ansible-vault view "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
        echo
        echo "═══════════════════════════════════════════════════════════"
        echo
        print_success "File displayed (decrypted in-memory only)"
    else
        echo
        echo "═══════════════════════════════════════════════════════════"
        echo
        print_error "Failed to view vault file (wrong password or corrupt file)"
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Encrypt file
vault_encrypt() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_warning "Vault password file not found, creating one..."
        openssl rand -base64 32 > "$VAULT_PASSWORD_FILE"
        chmod 600 "$VAULT_PASSWORD_FILE"
        print_success "Created vault password file: $VAULT_PASSWORD_FILE"
    fi

    read -p "Enter file path to encrypt: " -r FILE

    if [[ ! -f "$FILE" ]]; then
        print_error "File not found: $FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    # Check if already encrypted
    if head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
        print_warning "File is already encrypted: $FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    # Create backup
    local BACKUP_FILE="${FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$FILE" "$BACKUP_FILE"
    print_info "Created backup: $BACKUP_FILE"

    # Encrypt
    if ansible-vault encrypt "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
        print_success "File encrypted successfully: $FILE"
        print_info "Backup saved at: $BACKUP_FILE"
    else
        print_error "Failed to encrypt file: $FILE"
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Decrypt file
vault_decrypt() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_error "Vault password file not found: $VAULT_PASSWORD_FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    echo
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "                   SECURITY WARNING                        "
    print_warning "═══════════════════════════════════════════════════════════"
    echo
    echo "Decrypting creates a PLAIN TEXT file containing sensitive data!"
    echo
    print_warning "NEVER commit the decrypted file to Git!"
    print_warning "Delete the decrypted file immediately after use!"
    echo

    read -p "Do you understand and want to proceed? (yes/NO): " -r
    echo

    if [[ ! "$REPLY" = "yes" ]]; then
        print_info "Aborted. Consider using 'View Vault' or 'Edit Vault' instead."
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    read -p "Enter file path to decrypt: " -r FILE

    if [[ ! -f "$FILE" ]]; then
        print_error "File not found: $FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    if ! head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
        print_warning "File is NOT encrypted: $FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    if ansible-vault decrypt "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
        print_success "File decrypted: $FILE"
        print_warning "REMEMBER: Re-encrypt or delete this file when done!"
    else
        print_error "Failed to decrypt file"
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Re-key vault
vault_rekey() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_error "Vault password file not found: $VAULT_PASSWORD_FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    echo
    print_warning "═══════════════════════════════════════════════════════════"
    print_warning "               VAULT PASSWORD ROTATION                     "
    print_warning "═══════════════════════════════════════════════════════════"
    echo
    echo "This will change the vault password for encrypted files."
    echo
    print_warning "IMPORTANT:"
    echo "  1. Old password will no longer work"
    echo "  2. Team members will need the new password"
    echo

    echo -e "${BOLD}Options:${NC}"
    echo "  1) Re-key single file"
    echo "  2) Re-key ALL encrypted vault files"
    echo "  3) Cancel"
    echo
    read -p "Choose [1-3]: " -r REKEY_CHOICE

    case "$REKEY_CHOICE" in
        1)
            read -p "Enter file path: " -r FILE
            if [[ ! -f "$FILE" ]]; then
                print_error "File not found: $FILE"
                read -p "Press Enter to continue..."
                show_vault_menu
                return
            fi
            read -p "Re-key $FILE? (yes/NO): " -r
            if [[ "$REPLY" = "yes" ]]; then
                if ansible-vault rekey "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"; then
                    print_success "File re-keyed: $FILE"
                else
                    print_error "Failed to re-key: $FILE"
                fi
            fi
            ;;
        2)
            print_info "Searching for encrypted vault files..."
            local encrypted_files
            encrypted_files=$(find "${SCRIPT_DIR}" -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

            if [[ -z "$encrypted_files" ]]; then
                print_warning "No encrypted vault files found."
            else
                echo "Found encrypted files:"
                echo "$encrypted_files"
                echo
                read -p "Re-key all these files? (yes/NO): " -r
                if [[ "$REPLY" = "yes" ]]; then
                    local rekey_failed=false
                    echo "$encrypted_files" | while read -r file; do
                        print_info "Re-keying: $file"
                        if ! ansible-vault rekey "$file" --vault-password-file="$VAULT_PASSWORD_FILE"; then
                            print_error "Failed to re-key: $file"
                            rekey_failed=true
                        fi
                    done
                    if [[ "$rekey_failed" == false ]]; then
                        print_success "All files re-keyed!"
                    fi
                fi
            fi
            ;;
        3)
            print_info "Cancelled."
            ;;
    esac

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Validate vault
vault_validate() {
    check_vault_deps || { show_vault_menu; return; }

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        print_error "Vault password file not found: $VAULT_PASSWORD_FILE"
        read -p "Press Enter to continue..."
        show_vault_menu
        return
    fi

    print_info "Searching for encrypted vault files..."
    local encrypted_files
    encrypted_files=$(find "${SCRIPT_DIR}" -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -z "$encrypted_files" ]]; then
        print_warning "No encrypted vault files found."
    else
        echo
        echo "$encrypted_files" | while read -r file; do
            print_info "Validating: $file"
            if ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE" > /dev/null 2>&1; then
                print_success "Valid: $file"
            else
                print_error "Invalid: $file"
            fi
        done
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# Show vault status
vault_status() {
    check_vault_deps || { show_vault_menu; return; }

    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Ansible Vault Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo

    local VAULT_PASSWORD_FILE
    VAULT_PASSWORD_FILE=$(get_vault_password_file)

    # Check vault password file
    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        print_success "Vault password file exists: $VAULT_PASSWORD_FILE"
        if [[ -r "$VAULT_PASSWORD_FILE" ]]; then
            local perms
            perms=$(stat -c %a "$VAULT_PASSWORD_FILE" 2>/dev/null || stat -f %Lp "$VAULT_PASSWORD_FILE" 2>/dev/null)
            print_info "  Permissions: $perms"
        fi
    else
        print_error "Vault password file NOT found: $VAULT_PASSWORD_FILE"
    fi

    echo

    # Find encrypted files
    print_info "Searching for encrypted vault files..."
    local encrypted_files
    encrypted_files=$(find "${SCRIPT_DIR}" -type f -name "*vault*.yml" -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -n "$encrypted_files" ]]; then
        print_success "Found encrypted vault files:"
        echo "$encrypted_files" | while read -r file; do
            echo "  - $file"
        done
    else
        print_warning "No encrypted vault files found."
    fi

    echo

    # Check .gitignore
    print_info "Checking .gitignore..."
    if grep -q ".vault_password" "${SCRIPT_DIR}/.gitignore" 2>/dev/null; then
        print_success ".vault_password is in .gitignore"
    else
        print_warning ".vault_password is NOT in .gitignore (security risk!)"
    fi

    echo

    # Check ansible.cfg
    print_info "Checking ansible.cfg..."
    if grep -q "vault_password_file" "${SCRIPT_DIR}/ansible.cfg" 2>/dev/null; then
        print_success "Vault password file configured in ansible.cfg"
    else
        print_info "No vault password file config in ansible.cfg"
    fi

    read -p "Press Enter to continue..."
    show_vault_menu
}

# =============================================================================
# ADD SERVER FUNCTION
# =============================================================================

run_add_server() {
    clear
    print_header
    echo -e "${BOLD}Add Server to Inventory${NC}"
    echo

    local server_name=""
    local ansible_host=""
    local ansible_user="ansible"
    local ansible_port="22"
    local custom_hostname=""

    # Server name
    while true; do
        read -p "Server name (e.g., webserver01): " -r server_name
        if [[ -z "$server_name" ]]; then
            print_error "Server name cannot be empty"
            continue
        fi
        if [[ ! "$server_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Invalid name. Use only letters, numbers, hyphens, underscores."
            continue
        fi
        break
    done

    # IP/hostname
    while true; do
        read -p "IP address or hostname: " -r ansible_host
        if [[ -z "$ansible_host" ]]; then
            print_error "Address cannot be empty"
            continue
        fi
        break
    done

    # SSH user
    read -p "SSH username [ansible]: " -r input
    [[ -n "$input" ]] && ansible_user="$input"

    # SSH port
    read -p "SSH port [22]: " -r input
    [[ -n "$input" ]] && ansible_port="$input"

    # Custom hostname
    read -p "Custom hostname (leave empty to use '$server_name'): " -r custom_hostname

    # Summary
    echo
    echo -e "${BOLD}Summary:${NC}"
    echo "  Server Name: $server_name"
    echo "  Host:        $ansible_host"
    echo "  User:        $ansible_user"
    echo "  Port:        $ansible_port"
    [[ -n "$custom_hostname" ]] && echo "  Hostname:    $custom_hostname"
    echo

    read -p "Add this server to inventory? (Y/n): " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "Cancelled."
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    local inventory_file="${SCRIPT_DIR}/inventory/hosts.yml"

    if [[ ! -f "$inventory_file" ]]; then
        print_warning "Inventory file not found. Creating new inventory..."
        mkdir -p "${SCRIPT_DIR}/inventory"

        # Create a basic inventory file
        cat > "$inventory_file" <<EOF
# Server Helper Inventory
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

---
all:
  hosts:
    ${server_name}:
      ansible_host: ${ansible_host}
      ansible_user: ${ansible_user}
      ansible_become: yes
      ansible_python_interpreter: /usr/bin/python3
EOF
        if [[ "$ansible_port" != "22" ]]; then
            echo "      ansible_port: ${ansible_port}" >> "$inventory_file"
        fi
        if [[ -n "$custom_hostname" ]]; then
            echo "      hostname: \"${custom_hostname}\"" >> "$inventory_file"
        fi

        cat >> "$inventory_file" <<EOF

  children:
    servers:
      hosts:
        ${server_name}:

  vars:
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

        print_success "Created inventory file: $inventory_file"
    else
        # Create backup
        local backup_file="${inventory_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$inventory_file" "$backup_file"
        print_info "Backed up inventory to: $backup_file"

        # Check if server already exists
        if grep -q "^    ${server_name}:" "$inventory_file" 2>/dev/null; then
            print_error "Server '$server_name' already exists in inventory!"
            read -p "Press Enter to continue..."
            show_extras_menu
            return
        fi

        # Build the host entry block
        local host_block=""
        host_block+="    ${server_name}:\n"
        host_block+="      ansible_host: ${ansible_host}\n"
        host_block+="      ansible_user: ${ansible_user}\n"
        host_block+="      ansible_become: yes\n"
        host_block+="      ansible_python_interpreter: /usr/bin/python3"
        if [[ "$ansible_port" != "22" ]]; then
            host_block+="\n      ansible_port: ${ansible_port}"
        fi
        if [[ -n "$custom_hostname" ]]; then
            host_block+="\n      hostname: \"${custom_hostname}\""
        fi

        # Use python3 (required by Ansible, so always available) for reliable YAML editing
        if command -v python3 &>/dev/null; then
            if python3 - "$inventory_file" "$server_name" "$ansible_host" "$ansible_user" "$ansible_port" "${custom_hostname:-}" <<'PYEOF'
import sys, os

inventory_path = sys.argv[1]
name = sys.argv[2]
host = sys.argv[3]
user = sys.argv[4]
port = sys.argv[5]
custom_hostname = sys.argv[6] if len(sys.argv) > 6 else ""

with open(inventory_path, 'r') as f:
    lines = f.readlines()

new_lines = []
in_all_hosts = False
inserted_host = False
in_servers_hosts = False
inserted_server = False

i = 0
while i < len(lines):
    line = lines[i]
    new_lines.append(line)

    stripped = line.rstrip()

    # Detect "  hosts:" under "all:" (top-level hosts section)
    if stripped == '  hosts:' and not in_all_hosts and not inserted_host:
        in_all_hosts = True
        i += 1
        continue

    # When inside hosts section, find the end to insert before
    if in_all_hosts and not inserted_host:
        # We're past hosts: header. Look for the next non-host line
        # (a line that is indented at <= 2 spaces and not blank)
        if stripped and not stripped.startswith('    ') and not stripped.startswith('#'):
            # Insert our new host BEFORE this line
            entry = f"    {name}:\n"
            entry += f"      ansible_host: {host}\n"
            entry += f"      ansible_user: {user}\n"
            entry += f"      ansible_become: yes\n"
            entry += f"      ansible_python_interpreter: /usr/bin/python3\n"
            if port != "22":
                entry += f"      ansible_port: {port}\n"
            if custom_hostname:
                entry += f'      hostname: "{custom_hostname}"\n'
            entry += "\n"
            # Insert before the current line (which was already appended)
            new_lines.insert(len(new_lines) - 1, entry)
            inserted_host = True
            in_all_hosts = False

    # Detect "      hosts:" under "    servers:" (children group)
    if stripped == '      hosts:' and not inserted_server:
        in_servers_hosts = True
        i += 1
        continue

    # Insert server reference right after "      hosts:" line
    if in_servers_hosts and not inserted_server:
        new_lines.insert(len(new_lines) - 1, f"        {name}:\n")
        inserted_server = True
        in_servers_hosts = False

    i += 1

# If host wasn't inserted (hosts section goes to end of file), append
if not inserted_host:
    entry = f"\n    {name}:\n"
    entry += f"      ansible_host: {host}\n"
    entry += f"      ansible_user: {user}\n"
    entry += f"      ansible_become: yes\n"
    entry += f"      ansible_python_interpreter: /usr/bin/python3\n"
    if port != "22":
        entry += f"      ansible_port: {port}\n"
    if custom_hostname:
        entry += f'      hostname: "{custom_hostname}"\n'
    # Try to insert before children section
    for idx, l in enumerate(new_lines):
        if l.strip() == 'children:':
            new_lines.insert(idx, entry + "\n")
            inserted_host = True
            break
    if not inserted_host:
        new_lines.append(entry)

with open(inventory_path, 'w') as f:
    f.writelines(new_lines)

print("OK")
PYEOF
            then
                print_success "Server '$server_name' added to inventory!"
            else
                print_error "Failed to update inventory file"
                print_info "Restoring from backup..."
                cp "$backup_file" "$inventory_file"
                read -p "Press Enter to continue..."
                show_extras_menu
                return
            fi
        else
            # Fallback: append as a separate block and warn
            print_warning "python3 not found. Using basic append (manual review recommended)."
            {
                echo ""
                echo -e "$host_block"
            } >> "$inventory_file"
            print_success "Server '$server_name' appended to inventory."
            print_warning "Please verify the YAML structure in: $inventory_file"
        fi
    fi

    # Test SSH connection
    echo
    read -p "Test SSH connection to ${ansible_host}? (Y/n): " -r
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        print_info "Testing SSH connection to ${ansible_user}@${ansible_host}..."
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$ansible_port" "${ansible_user}@${ansible_host}" "echo 'Connected'" &>/dev/null; then
            print_success "SSH connection successful!"
        else
            print_warning "SSH connection failed. You may need to:"
            echo "  1. Copy SSH key: ssh-copy-id -p $ansible_port ${ansible_user}@${ansible_host}"
            echo "  2. Run bootstrap: ansible-playbook playbooks/bootstrap.yml --limit $server_name -K"
        fi
    fi

    echo
    print_success "Server '$server_name' added successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Verify inventory: ansible-inventory --list"
    echo "  2. Test connection: ansible $server_name -m ping"
    echo "  3. Bootstrap: ansible-playbook playbooks/bootstrap.yml --limit $server_name -K"
    echo "  4. Setup: ansible-playbook playbooks/setup-targets.yml --limit $server_name"
    echo

    read -p "Press Enter to continue..."
    show_extras_menu
}

# =============================================================================
# OPEN UI FUNCTION
# =============================================================================

# Helper: open a URL in the system browser
_open_browser_url() {
    local url="$1"
    local label="${2:-$url}"

    print_info "Opening ${label}: ${url}"

    if command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null &
    elif command -v open &>/dev/null; then
        open "$url"
    elif command -v start &>/dev/null; then
        start "$url" 2>/dev/null || cmd.exe /c start "$url" 2>/dev/null
    else
        print_warning "Could not detect browser. Open manually: $url"
    fi
}

# Helper: read a port from group_vars/all.yml
_get_config_port() {
    local service="$1"
    local default_port="$2"
    local config_file="${SCRIPT_DIR}/group_vars/all.yml"

    if [[ ! -f "$config_file" ]]; then
        echo "$default_port"
        return
    fi

    local port=""
    case "$service" in
        dockge)
            port=$(awk '/^target_dockge:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        netdata)
            port=$(awk '/^target_netdata:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        uptime-kuma)
            port=$(awk '/^control_uptime_kuma:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
        grafana)
            port=$(awk '/^control_grafana:/{found=1} found && /port:/{print $2; exit}' "$config_file" 2>/dev/null)
            ;;
    esac

    echo "${port:-$default_port}"
}

# Helper: parse inventory and populate host arrays
_parse_inventory_hosts() {
    local inventory_file="${SCRIPT_DIR}/inventory/hosts.yml"
    _INV_NAMES=()
    _INV_IPS=()

    if [[ ! -f "$inventory_file" ]]; then
        return 1
    fi

    local in_hosts=false
    local current_name=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*hosts:[[:space:]]*$ ]]; then
            in_hosts=true
            continue
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]{4}([a-zA-Z0-9_-]+):[[:space:]]*$ ]]; then
            current_name="${BASH_REMATCH[1]}"
            _INV_NAMES+=("$current_name")
        fi

        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ansible_host:[[:space:]]*([0-9.a-zA-Z_-]+) ]]; then
            _INV_IPS+=("${BASH_REMATCH[1]}")
        fi

        # Stop if we leave the hosts section (non-indented key)
        if [[ "$in_hosts" == true ]] && [[ "$line" =~ ^[[:space:]]{2}[a-z] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]] && [[ ! "$line" =~ ^[[:space:]]*hosts: ]]; then
            in_hosts=false
        fi
    done < "$inventory_file"

    [[ ${#_INV_NAMES[@]} -gt 0 ]]
}

# Helper: let user pick a host, sets _SELECTED_IP
_select_host_ip() {
    _SELECTED_IP=""

    if ! _parse_inventory_hosts; then
        print_warning "Could not parse inventory."
        read -p "Enter server IP address manually: " -r _SELECTED_IP
        return
    fi

    if [[ ${#_INV_NAMES[@]} -eq 1 ]]; then
        _SELECTED_IP="${_INV_IPS[0]}"
        print_info "Using host: ${_INV_NAMES[0]} (${_SELECTED_IP})"
        return
    fi

    echo -e "${BOLD}Select a host:${NC}"
    for idx in "${!_INV_NAMES[@]}"; do
        echo "  $((idx+1))) ${_INV_NAMES[$idx]} (${_INV_IPS[$idx]})"
    done
    echo "  $((${#_INV_NAMES[@]}+1))) Enter IP manually"
    echo

    read -p "Choose host: " -r host_num

    if [[ "$host_num" =~ ^[0-9]+$ ]] && [[ "$host_num" -ge 1 ]] && [[ "$host_num" -le ${#_INV_NAMES[@]} ]]; then
        _SELECTED_IP="${_INV_IPS[$((host_num-1))]}"
        print_info "Using host: ${_INV_NAMES[$((host_num-1))]} (${_SELECTED_IP})"
    else
        read -p "Enter server IP address: " -r _SELECTED_IP
    fi
}

run_open_ui() {
    clear
    print_header
    echo -e "${BOLD}Open Service UIs${NC}"
    echo

    local inventory_file="${SCRIPT_DIR}/inventory/hosts.yml"

    if [[ ! -f "$inventory_file" ]]; then
        print_error "No inventory found. Run Setup first."
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    # Let user pick a host
    _select_host_ip
    local host_ip="$_SELECTED_IP"

    if [[ -z "$host_ip" ]]; then
        print_error "No host selected."
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    # Read configured ports
    local dockge_port netdata_port kuma_port grafana_port
    dockge_port=$(_get_config_port "dockge" "5001")
    netdata_port=$(_get_config_port "netdata" "19999")
    kuma_port=$(_get_config_port "uptime-kuma" "3001")
    grafana_port=$(_get_config_port "grafana" "3000")

    echo
    echo -e "${BOLD}Select service to open:${NC}"
    echo "  1) Dockge            (http://${host_ip}:${dockge_port})"
    echo "  2) Netdata           (http://${host_ip}:${netdata_port})"
    echo "  3) Uptime Kuma       (http://${host_ip}:${kuma_port})"
    echo "  4) Grafana           (http://${host_ip}:${grafana_port})"
    echo "  5) All Services"
    echo "  6) List URLs only"
    echo "  7) Back"
    echo
    read -p "Choose [1-7]: " -r UI_CHOICE

    case "$UI_CHOICE" in
        1) _open_browser_url "http://${host_ip}:${dockge_port}" "Dockge" ;;
        2) _open_browser_url "http://${host_ip}:${netdata_port}" "Netdata" ;;
        3) _open_browser_url "http://${host_ip}:${kuma_port}" "Uptime Kuma" ;;
        4) _open_browser_url "http://${host_ip}:${grafana_port}" "Grafana" ;;
        5)
            _open_browser_url "http://${host_ip}:${dockge_port}" "Dockge"
            sleep 1
            _open_browser_url "http://${host_ip}:${netdata_port}" "Netdata"
            sleep 1
            _open_browser_url "http://${host_ip}:${kuma_port}" "Uptime Kuma"
            sleep 1
            _open_browser_url "http://${host_ip}:${grafana_port}" "Grafana"
            ;;
        6)
            echo
            echo -e "${BOLD}Service URLs for ${host_ip}:${NC}"
            echo "  Dockge:      http://${host_ip}:${dockge_port}"
            echo "  Netdata:     http://${host_ip}:${netdata_port}"
            echo "  Uptime Kuma: http://${host_ip}:${kuma_port}"
            echo "  Grafana:     http://${host_ip}:${grafana_port}"
            ;;
        7) show_extras_menu; return ;;
        *) print_warning "Invalid option" ;;
    esac

    echo
    read -p "Press Enter to continue..."
    show_extras_menu
}

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

run_test_all_roles() {
    clear
    print_header
    echo -e "${BOLD}Test All Ansible Roles${NC}"
    echo

    # Check dependencies
    if ! command -v molecule &> /dev/null; then
        print_error "Molecule is not installed"
        print_info "Install with: pip install molecule molecule-docker"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not running"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    print_success "Dependencies OK"
    echo

    local ROLES_DIR="${SCRIPT_DIR}/roles"
    local PASSED=()
    local FAILED=()

    if [[ ! -d "$ROLES_DIR" ]]; then
        print_error "Roles directory not found: $ROLES_DIR"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    # Find roles with molecule tests
    local roles_with_tests=()
    for role_dir in "$ROLES_DIR"/*/; do
        local role
        role=$(basename "$role_dir")
        if [[ -d "$role_dir/molecule/default" ]]; then
            roles_with_tests+=("$role")
        fi
    done

    if [[ ${#roles_with_tests[@]} -eq 0 ]]; then
        print_warning "No roles with Molecule tests found"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    echo -e "${BOLD}Found ${#roles_with_tests[@]} roles with tests:${NC}"
    for role in "${roles_with_tests[@]}"; do
        echo "  - $role"
    done
    echo

    read -p "Run tests for all roles? (Y/n): " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        show_extras_menu
        return
    fi

    # Test each role
    for role in "${roles_with_tests[@]}"; do
        echo
        echo -e "${BLUE}======================================${NC}"
        echo -e "${BLUE}Testing role: $role${NC}"
        echo -e "${BLUE}======================================${NC}"

        cd "$ROLES_DIR/$role"

        if molecule test; then
            print_success "PASSED: $role"
            PASSED+=("$role")
        else
            print_error "FAILED: $role"
            FAILED+=("$role")
        fi
    done

    cd "$SCRIPT_DIR"

    # Summary
    echo
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo

    if [[ ${#PASSED[@]} -gt 0 ]]; then
        echo -e "${GREEN}Passed (${#PASSED[@]}):${NC}"
        for role in "${PASSED[@]}"; do
            echo "  - $role"
        done
    fi

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}Failed (${#FAILED[@]}):${NC}"
        for role in "${FAILED[@]}"; do
            echo "  - $role"
        done
    fi

    read -p "Press Enter to continue..."
    show_extras_menu
}

run_test_single_role() {
    clear
    print_header
    echo -e "${BOLD}Test Single Ansible Role${NC}"
    echo

    # Check dependencies
    if ! command -v molecule &> /dev/null; then
        print_error "Molecule is not installed"
        print_info "Install with: pip install molecule molecule-docker"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    local ROLES_DIR="${SCRIPT_DIR}/roles"

    if [[ ! -d "$ROLES_DIR" ]]; then
        print_error "Roles directory not found"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    # List available roles
    echo -e "${BOLD}Available roles with tests:${NC}"
    local i=1
    local roles=()
    for role_dir in "$ROLES_DIR"/*/; do
        local role
        role=$(basename "$role_dir")
        if [[ -d "$role_dir/molecule/default" ]]; then
            echo "  $i) $role"
            roles+=("$role")
            ((i++))
        fi
    done

    if [[ ${#roles[@]} -eq 0 ]]; then
        print_warning "No roles with Molecule tests found"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    echo
    read -p "Select role number: " -r role_num

    if [[ ! "$role_num" =~ ^[0-9]+$ ]] || [[ "$role_num" -lt 1 ]] || [[ "$role_num" -gt ${#roles[@]} ]]; then
        print_error "Invalid selection"
        read -p "Press Enter to continue..."
        show_extras_menu
        return
    fi

    local selected_role="${roles[$((role_num-1))]}"

    echo
    echo -e "${BOLD}Molecule command:${NC}"
    echo "  1) test (full test cycle)"
    echo "  2) converge (create and run)"
    echo "  3) verify (run tests only)"
    echo "  4) destroy (cleanup)"
    echo
    read -p "Select command [1]: " -r cmd_choice
    cmd_choice=${cmd_choice:-1}

    local molecule_cmd
    case "$cmd_choice" in
        1) molecule_cmd="test" ;;
        2) molecule_cmd="converge" ;;
        3) molecule_cmd="verify" ;;
        4) molecule_cmd="destroy" ;;
        *) molecule_cmd="test" ;;
    esac

    echo
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Testing role: $selected_role${NC}"
    echo -e "${BLUE}Command: molecule $molecule_cmd${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo

    cd "$ROLES_DIR/$selected_role"
    if molecule "$molecule_cmd"; then
        print_success "molecule $molecule_cmd completed successfully for: $selected_role"
    else
        print_error "molecule $molecule_cmd failed for: $selected_role"
    fi
    cd "$SCRIPT_DIR"

    read -p "Press Enter to continue..."
    show_extras_menu
}

run_test_remediation() {
    clear
    print_header
    echo -e "${BOLD}Test Remediation System${NC}"
    echo

    print_info "Remediation tests check the auto-remediation infrastructure:"
    echo "  - Webhook service status"
    echo "  - Trigger scripts (service restart, disk cleanup, cert renewal)"
    echo "  - Remediation playbook syntax"
    echo "  - Log files and rotation"
    echo "  - Uptime Kuma integration"
    echo

    echo -e "${BOLD}Where to run tests:${NC}"
    echo "  1) Locally (this machine is a target server)"
    echo "  2) Remotely via Ansible (run on target servers)"
    echo "  3) Back"
    echo
    read -p "Choose [1-3]: " -r REM_CHOICE

    case "$REM_CHOICE" in
        1)
            _run_remediation_tests_local
            ;;
        2)
            _run_remediation_tests_remote
            ;;
        3)
            show_extras_menu
            return
            ;;
        *)
            print_warning "Invalid option"
            read -p "Press Enter to continue..."
            show_extras_menu
            return
            ;;
    esac

    read -p "Press Enter to continue..."
    show_extras_menu
}

_remediation_log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

_remediation_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

_remediation_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

_run_remediation_tests_local() {
    echo
    print_warning "Local tests require root privileges."
    echo

    if [[ "$EUID" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        print_info "You will be prompted for your sudo password."
    fi

    local failed=0

    echo
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}  Automated Remediation System - Test Suite${NC}"
    echo -e "${BLUE}===========================================${NC}"
    echo

    # Test 1: Webhook service
    _remediation_log "Testing webhook service..."
    if sudo systemctl is-active --quiet remediation-webhook 2>/dev/null; then
        _remediation_log "Webhook service is running"
    else
        _remediation_error "Webhook service is not running"
        ((failed++)) || true
    fi

    if curl -s -f "http://localhost:9090?action=health_check" > /dev/null 2>&1; then
        _remediation_log "Webhook endpoint is responding"
    else
        _remediation_warn "Webhook endpoint is not responding (may not be configured)"
    fi
    echo

    # Test 2: Trigger scripts
    _remediation_log "Testing trigger scripts..."
    local scripts=(
        "/usr/local/bin/trigger-service-restart.sh"
        "/usr/local/bin/trigger-disk-cleanup.sh"
        "/usr/local/bin/trigger-cert-renewal.sh"
    )
    for script in "${scripts[@]}"; do
        if [[ -x "$script" ]]; then
            _remediation_log "$(basename "$script") is executable"
        else
            _remediation_error "$(basename "$script") is not executable or missing"
            ((failed++)) || true
        fi
    done
    echo

    # Test 3: Remediation playbook
    _remediation_log "Testing remediation playbook..."
    local playbook="/opt/ansible/playbooks/remediation.yml"
    if [[ -f "$playbook" ]]; then
        _remediation_log "Remediation playbook exists"
        if ansible-playbook --syntax-check "$playbook" > /dev/null 2>&1; then
            _remediation_log "Remediation playbook syntax is valid"
        else
            _remediation_error "Remediation playbook has syntax errors"
            ((failed++)) || true
        fi
    else
        _remediation_error "Remediation playbook not found: $playbook"
        ((failed++)) || true
    fi
    echo

    # Test 4: Log files
    _remediation_log "Testing log files..."
    local logs=(
        "/var/log/auto-remediation.log"
        "/var/log/remediation-webhook.log"
    )
    for logfile in "${logs[@]}"; do
        if [[ -f "$logfile" ]]; then
            _remediation_log "$logfile exists"
        else
            _remediation_warn "$logfile does not exist (created on first use)"
        fi
    done

    if [[ -f "/etc/logrotate.d/remediation" ]]; then
        _remediation_log "Log rotation is configured"
    else
        _remediation_warn "Log rotation not configured"
    fi
    echo

    # Test 5: Uptime Kuma integration
    _remediation_log "Testing Uptime Kuma integration..."
    if [[ -f "/root/uptime-kuma-monitors.json" ]]; then
        _remediation_log "Uptime Kuma monitor configuration exists"
    else
        _remediation_warn "Uptime Kuma monitor configuration not found"
    fi

    if curl -s -f "http://localhost:3001" > /dev/null 2>&1; then
        _remediation_log "Uptime Kuma is accessible"
    else
        _remediation_warn "Uptime Kuma is not accessible (may not be enabled)"
    fi
    echo

    # Optional: Service restart test
    read -p "Run service restart test? (creates temporary container) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _remediation_log "Testing service auto-restart..."
        if command -v docker &>/dev/null; then
            _remediation_log "Creating test container..."
            sudo docker run -d --name remediation-test-container --rm alpine sleep 3600 > /dev/null 2>&1 || true
            sleep 2
            _remediation_log "Stopping test container..."
            sudo docker stop remediation-test-container > /dev/null 2>&1 || true
            sleep 5
            _remediation_log "Triggering service restart..."
            if [[ -x "/usr/local/bin/trigger-service-restart.sh" ]]; then
                sudo /usr/local/bin/trigger-service-restart.sh "remediation-test-container" "test" > /dev/null 2>&1 &
                sleep 10
                if sudo docker ps | grep -q remediation-test-container; then
                    _remediation_log "Service auto-restart works"
                    sudo docker stop remediation-test-container > /dev/null 2>&1 || true
                else
                    _remediation_warn "Service auto-restart test inconclusive"
                    sudo docker rm -f remediation-test-container > /dev/null 2>&1 || true
                fi
            else
                _remediation_warn "trigger-service-restart.sh not found, skipping"
            fi
        else
            _remediation_warn "Docker not available, skipping"
        fi
        echo
    fi

    # Optional: Disk cleanup test
    read -p "Run disk cleanup test? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _remediation_log "Testing disk cleanup..."
        local before_df
        before_df=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
        _remediation_log "Disk usage before cleanup: ${before_df}%"
        if [[ -f "/opt/ansible/playbooks/remediation.yml" ]]; then
            sudo ansible-playbook /opt/ansible/playbooks/remediation.yml -e "action=disk_cleanup" > /dev/null 2>&1 || true
            sleep 5
            local after_df
            after_df=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
            _remediation_log "Disk usage after cleanup: ${after_df}%"
        else
            _remediation_warn "Remediation playbook not found, skipping"
        fi
        echo
    fi

    # Optional: Cert renewal test
    read -p "Run certificate renewal test? (dry run only) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        _remediation_log "Testing certificate renewal (dry run)..."
        if command -v certbot > /dev/null 2>&1; then
            if sudo certbot renew --dry-run > /dev/null 2>&1; then
                _remediation_log "Certificate renewal dry run successful"
            else
                _remediation_warn "Certbot dry run failed (may not have certs configured)"
            fi
        else
            _remediation_warn "Certbot not installed, skipping"
        fi
        echo
    fi

    # Summary
    echo -e "${BLUE}===========================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}===========================================${NC}"

    if [[ $failed -eq 0 ]]; then
        _remediation_log "All tests passed!"
    else
        _remediation_error "$failed test(s) failed"
    fi
}

_run_remediation_tests_remote() {
    echo

    if ! command -v ansible &>/dev/null; then
        print_error "Ansible is not installed."
        return
    fi

    local inventory_file="${SCRIPT_DIR}/inventory/hosts.yml"
    if [[ ! -f "$inventory_file" ]]; then
        print_error "No inventory found. Run Setup first."
        return
    fi

    # Let user pick target host(s)
    echo -e "${BOLD}Run tests on which hosts?${NC}"
    echo "  1) All hosts"
    echo "  2) Specific host"
    echo
    read -p "Choose [1-2]: " -r target_choice

    local target="all"
    if [[ "$target_choice" == "2" ]]; then
        _select_host_ip
        if [[ -n "$_SELECTED_IP" ]]; then
            # Find the host name for this IP
            target=$(grep -B1 "ansible_host: ${_SELECTED_IP}" "$inventory_file" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':' || echo "$_SELECTED_IP")
        fi
    fi

    echo
    print_info "Running remediation checks on: $target"
    echo

    # Run ad-hoc checks via ansible
    echo -e "${BLUE}--- Checking webhook service ---${NC}"
    ansible "$target" -m shell -a "systemctl is-active remediation-webhook 2>/dev/null || echo 'not running'" 2>/dev/null || true
    echo

    echo -e "${BLUE}--- Checking trigger scripts ---${NC}"
    ansible "$target" -m shell -a "ls -la /usr/local/bin/trigger-*.sh 2>/dev/null || echo 'No trigger scripts found'" 2>/dev/null || true
    echo

    echo -e "${BLUE}--- Checking remediation playbook ---${NC}"
    ansible "$target" -m shell -a "test -f /opt/ansible/playbooks/remediation.yml && echo 'Playbook exists' || echo 'Playbook not found'" 2>/dev/null || true
    echo

    echo -e "${BLUE}--- Checking log files ---${NC}"
    ansible "$target" -m shell -a "ls -la /var/log/auto-remediation.log /var/log/remediation-webhook.log 2>/dev/null || echo 'No remediation logs found'" 2>/dev/null || true
    echo

    echo -e "${BLUE}--- Checking log rotation ---${NC}"
    ansible "$target" -m shell -a "test -f /etc/logrotate.d/remediation && echo 'Log rotation configured' || echo 'No log rotation'" 2>/dev/null || true
    echo

    echo -e "${BLUE}--- Checking Uptime Kuma ---${NC}"
    ansible "$target" -m shell -a "curl -sf http://localhost:3001 > /dev/null 2>&1 && echo 'Uptime Kuma accessible' || echo 'Uptime Kuma not accessible'" 2>/dev/null || true
    echo

    print_success "Remote remediation checks complete."
}

# =============================================================================
# SETUP MENU (original setup flow)
# =============================================================================

run_setup_menu() {
    # This runs the original setup flow
    # Clear MAIN_CHOICE to prevent menu loop issues
    unset MAIN_CHOICE

    # Continue with the original setup flow
    run_original_setup
}

run_original_setup() {
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

# =============================================================================
# ORIGINAL SETUP FUNCTIONS
# =============================================================================

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
    local temp_vault="/tmp/vault_temp.yml"

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
    # Check for command line arguments for direct access
    case "${1:-}" in
        --setup|-s)
            run_setup_menu
            exit 0
            ;;
        --extras|-e)
            show_extras_menu
            exit 0
            ;;
        --vault|-v)
            show_vault_menu
            exit 0
            ;;
        --add-server)
            run_add_server
            exit 0
            ;;
        --open-ui)
            run_open_ui
            exit 0
            ;;
        --test-all)
            run_test_all_roles
            exit 0
            ;;
        --test-role)
            run_test_single_role
            exit 0
            ;;
        --help|-h)
            print_header
            echo -e "${BOLD}Usage:${NC} $0 [OPTION]"
            echo
            echo "Options:"
            echo "  --setup, -s        Run setup directly (skip menu)"
            echo "  --extras, -e       Open extras menu directly"
            echo "  --vault, -v        Open vault management menu"
            echo "  --add-server       Add a new server to inventory"
            echo "  --open-ui          Open service UIs in browser"
            echo "  --test-all         Run all Molecule role tests"
            echo "  --test-role        Run Molecule test for single role"
            echo "  --help, -h         Show this help message"
            echo
            echo "Without options, shows the interactive main menu."
            exit 0
            ;;
        "")
            # No arguments - show main menu
            show_main_menu
            ;;
        *)
            print_error "Unknown option: $1"
            print_info "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
