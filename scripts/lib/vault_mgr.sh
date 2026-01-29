#!/usr/bin/env bash
#
# Server Helper - Vault Manager
# =============================
# Manages Ansible Vault operations with security hardening.
# Includes both core vault functions AND interactive menu system.
#
# Usage:
#   source scripts/lib/vault_mgr.sh
#   vault_menu_show  # Show interactive vault menu
#
# Security:
#   - All variables are local to prevent leakage
#   - RAM disk used for temporary decryption when available
#   - Temp files cleaned up on exit
#   - No secrets written to regular filesystem
#   - IMPORTANT: Decrypt-to-plaintext is DISABLED for security
#     Use vault_edit() or vault_view() instead
#

# Prevent multiple sourcing
[[ -n "${_VAULT_MGR_LOADED:-}" ]] && return 0
readonly _VAULT_MGR_LOADED=1

# Require ui_utils
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: vault_mgr.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

# Require security module
if [[ -z "${_SECURITY_LOADED:-}" ]]; then
    echo "ERROR: vault_mgr.sh requires security.sh to be sourced first" >&2
    return 1
fi

# =============================================================================
# Configuration
# =============================================================================
readonly VAULT_PASSWORD_FILE="${VAULT_PASSWORD_FILE:-.vault_password}"
readonly DEFAULT_VAULT_FILE="group_vars/vault.yml"

# Secure temp directory (prefer RAM disk)
_get_secure_temp_dir() {
    local temp_dir

    # Try RAM-based filesystems first (more secure)
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        temp_dir="/dev/shm/server-helper-$$"
    elif [[ -d "/run/user/$(id -u)" ]] && [[ -w "/run/user/$(id -u)" ]]; then
        temp_dir="/run/user/$(id -u)/server-helper-$$"
    else
        # Fall back to /tmp but warn
        temp_dir="/tmp/server-helper-$$"
        print_warning "Using /tmp for temporary files (RAM disk not available)"
    fi

    mkdir -p "$temp_dir" 2>/dev/null
    chmod 700 "$temp_dir" 2>/dev/null
    echo "$temp_dir"
}

# =============================================================================
# Vault Password Management
# =============================================================================

# Check if vault password file exists and has correct permissions
vault_check_password_file() {
    local password_file="${1:-$VAULT_PASSWORD_FILE}"

    if [[ ! -f "$password_file" ]]; then
        print_error "Vault password file not found: $password_file"
        return 1
    fi

    # Check permissions (should be 600)
    local perms
    perms=$(stat -c "%a" "$password_file" 2>/dev/null || stat -f "%Lp" "$password_file" 2>/dev/null)

    if [[ "$perms" != "600" ]]; then
        print_warning "Vault password file has insecure permissions: $perms (should be 600)"
        print_info "Fixing permissions..."
        chmod 600 "$password_file"
        if [[ $? -eq 0 ]]; then
            print_success "Permissions fixed"
        else
            print_error "Failed to fix permissions"
            return 1
        fi
    fi

    return 0
}

# Initialize vault password file
vault_init() {
    local password_file="${1:-$VAULT_PASSWORD_FILE}"
    local password
    local password_confirm

    if [[ -f "$password_file" ]]; then
        if ! prompt_confirm "Vault password file already exists. Overwrite?"; then
            print_info "Keeping existing password file"
            return 0
        fi
    fi

    print_info "Creating new vault password file..."

    # Get password securely
    password=$(prompt_password "Enter vault password")

    if [[ -z "$password" ]]; then
        print_error "Password cannot be empty"
        # Clear variable immediately
        unset password
        return 1
    fi

    password_confirm=$(prompt_password "Confirm vault password")

    if [[ "$password" != "$password_confirm" ]]; then
        print_error "Passwords do not match"
        # Clear variables immediately
        unset password password_confirm
        return 1
    fi

    # Write password to file securely
    (
        umask 077
        echo "$password" > "$password_file"
    )

    # Clear variables immediately
    unset password password_confirm

    if [[ -f "$password_file" ]]; then
        print_success "Vault password file created: $password_file"
        return 0
    else
        print_error "Failed to create vault password file"
        return 1
    fi
}

# =============================================================================
# Vault File Operations
# =============================================================================

# Check if a file is encrypted with Ansible Vault
vault_is_encrypted() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    head -1 "$file" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT;'
}

# Get vault status for a file
vault_status() {
    local file="${1:-$DEFAULT_VAULT_FILE}"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if vault_is_encrypted "$file"; then
        print_success "$file is encrypted"
        return 0
    else
        print_warning "$file is NOT encrypted"
        return 1
    fi
}

# Encrypt a file with Ansible Vault
vault_encrypt() {
    local file="$1"
    local password_file="${2:-$VAULT_PASSWORD_FILE}"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! vault_check_password_file "$password_file"; then
        return 1
    fi

    if vault_is_encrypted "$file"; then
        print_warning "File is already encrypted: $file"
        return 0
    fi

    print_info "Encrypting: $file"

    if ansible-vault encrypt "$file" --vault-password-file="$password_file"; then
        print_success "File encrypted successfully"
        return 0
    else
        print_error "Failed to encrypt file"
        return 1
    fi
}

# =============================================================================
# SECURITY NOTE: vault_decrypt() is INTENTIONALLY REMOVED
# =============================================================================
# Decrypting vault files to plaintext is a security risk:
#   - Plaintext secrets can be accidentally committed to git
#   - Plaintext files may persist in filesystem journals/backups
#   - Easy to forget to re-encrypt
#
# Use instead:
#   - vault_view() - View contents without decrypting the file
#   - vault_edit() - Edit in-place (decrypts only in memory)
# =============================================================================

# View encrypted vault file contents
vault_view() {
    local file="${1:-$DEFAULT_VAULT_FILE}"
    local password_file="${2:-$VAULT_PASSWORD_FILE}"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! vault_check_password_file "$password_file"; then
        return 1
    fi

    if ! vault_is_encrypted "$file"; then
        print_warning "File is not encrypted, showing directly..."
        cat "$file"
        return 0
    fi

    ansible-vault view "$file" --vault-password-file="$password_file"
}

# Edit encrypted vault file
vault_edit() {
    local file="${1:-$DEFAULT_VAULT_FILE}"
    local password_file="${2:-$VAULT_PASSWORD_FILE}"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! vault_check_password_file "$password_file"; then
        return 1
    fi

    # Use nano as default editor if EDITOR not set
    export EDITOR="${EDITOR:-nano}"

    print_info "Opening $file in $EDITOR..."

    ansible-vault edit "$file" --vault-password-file="$password_file"
}

# Rekey vault file (change password)
vault_rekey() {
    local file="${1:-$DEFAULT_VAULT_FILE}"
    local old_password_file="${2:-$VAULT_PASSWORD_FILE}"
    local new_password_file

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! vault_check_password_file "$old_password_file"; then
        return 1
    fi

    if ! vault_is_encrypted "$file"; then
        print_error "File is not encrypted: $file"
        return 1
    fi

    # Create secure temp directory for new password
    local secure_temp
    secure_temp=$(_get_secure_temp_dir)
    new_password_file="${secure_temp}/new_password"

    # Get new password
    local new_password
    local new_password_confirm

    new_password=$(prompt_password "Enter new vault password")
    new_password_confirm=$(prompt_password "Confirm new vault password")

    if [[ "$new_password" != "$new_password_confirm" ]]; then
        print_error "Passwords do not match"
        unset new_password new_password_confirm
        rm -rf "$secure_temp"
        return 1
    fi

    # Write new password to secure temp file
    (
        umask 077
        echo "$new_password" > "$new_password_file"
    )

    # Clear password variables immediately
    unset new_password new_password_confirm

    print_info "Rekeying vault file..."

    if ansible-vault rekey "$file" \
        --vault-password-file="$old_password_file" \
        --new-vault-password-file="$new_password_file"; then

        print_success "Vault rekeyed successfully"

        if prompt_confirm "Update main vault password file?"; then
            cp "$new_password_file" "$old_password_file"
            chmod 600 "$old_password_file"
            print_success "Password file updated"
        fi
    else
        print_error "Failed to rekey vault"
        rm -rf "$secure_temp"
        return 1
    fi

    # Clean up secure temp directory
    rm -rf "$secure_temp"
    return 0
}

# Rekey all vault files
vault_rekey_all() {
    local password_file="${1:-$VAULT_PASSWORD_FILE}"
    local vault_files=()
    local file

    print_info "Finding all vault-encrypted files..."

    # Find all encrypted files
    while IFS= read -r -d '' file; do
        if vault_is_encrypted "$file"; then
            vault_files+=("$file")
        fi
    done < <(find . -name "*.yml" -type f -print0 2>/dev/null)

    if [[ ${#vault_files[@]} -eq 0 ]]; then
        print_warning "No encrypted vault files found"
        return 0
    fi

    print_info "Found ${#vault_files[@]} encrypted file(s):"
    for file in "${vault_files[@]}"; do
        echo "  - $file"
    done

    if ! prompt_confirm "Rekey all these files?"; then
        return 0
    fi

    # Get new password
    local secure_temp
    secure_temp=$(_get_secure_temp_dir)
    local new_password_file="${secure_temp}/new_password"

    local new_password
    local new_password_confirm

    new_password=$(prompt_password "Enter new vault password")
    new_password_confirm=$(prompt_password "Confirm new vault password")

    if [[ "$new_password" != "$new_password_confirm" ]]; then
        print_error "Passwords do not match"
        unset new_password new_password_confirm
        rm -rf "$secure_temp"
        return 1
    fi

    (
        umask 077
        echo "$new_password" > "$new_password_file"
    )
    unset new_password new_password_confirm

    # Rekey each file
    local failed=0
    for file in "${vault_files[@]}"; do
        print_info "Rekeying: $file"
        if ansible-vault rekey "$file" \
            --vault-password-file="$password_file" \
            --new-vault-password-file="$new_password_file" 2>/dev/null; then
            print_success "  Rekeyed: $file"
        else
            print_error "  Failed: $file"
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        print_success "All files rekeyed successfully"

        if prompt_confirm "Update main vault password file?"; then
            cp "$new_password_file" "$password_file"
            chmod 600 "$password_file"
            print_success "Password file updated"
        fi
    else
        print_error "$failed file(s) failed to rekey"
    fi

    # Clean up
    rm -rf "$secure_temp"
    return $failed
}

# Validate vault can be decrypted
vault_validate() {
    local file="${1:-$DEFAULT_VAULT_FILE}"
    local password_file="${2:-$VAULT_PASSWORD_FILE}"

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    if ! vault_check_password_file "$password_file"; then
        return 1
    fi

    if ! vault_is_encrypted "$file"; then
        print_warning "File is not encrypted: $file"
        return 0
    fi

    print_info "Validating vault access..."

    if ansible-vault view "$file" --vault-password-file="$password_file" >/dev/null 2>&1; then
        print_success "Vault password is valid"
        return 0
    else
        print_error "Vault password is invalid or file is corrupted"
        return 1
    fi
}

# Create a new vault file from template
vault_create() {
    local file="$1"
    local password_file="${2:-$VAULT_PASSWORD_FILE}"

    if [[ -z "$file" ]]; then
        print_error "No file specified"
        return 1
    fi

    if [[ -f "$file" ]]; then
        print_error "File already exists: $file"
        return 1
    fi

    if ! vault_check_password_file "$password_file"; then
        return 1
    fi

    # Create directory if needed
    local dir
    dir=$(dirname "$file")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi

    # Create empty vault file
    print_info "Creating new vault file: $file"

    export EDITOR="${EDITOR:-nano}"
    ansible-vault create "$file" --vault-password-file="$password_file"
}

# =============================================================================
# Vault Status Report
# =============================================================================

# Show comprehensive vault status
vault_show_status() {
    local script_dir="${SCRIPT_DIR:-.}"
    local password_file="${1:-$VAULT_PASSWORD_FILE}"

    print_section "Ansible Vault Status"

    # Check vault password file
    if [[ -f "$password_file" ]]; then
        print_success "Vault password file exists: $password_file"
        if [[ -r "$password_file" ]]; then
            local perms
            perms=$(stat -c %a "$password_file" 2>/dev/null || stat -f %Lp "$password_file" 2>/dev/null)
            if [[ "$perms" == "600" ]]; then
                print_success "  Permissions: $perms (secure)"
            else
                print_warning "  Permissions: $perms (should be 600)"
            fi
        fi
    else
        print_error "Vault password file NOT found: $password_file"
    fi

    echo

    # Find encrypted files
    print_info "Searching for encrypted vault files..."
    local encrypted_files
    encrypted_files=$(find "$script_dir" -type f -name "*vault*.yml" -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

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
    if grep -q ".vault_password" "${script_dir}/.gitignore" 2>/dev/null; then
        print_success ".vault_password is in .gitignore"
    else
        print_warning ".vault_password is NOT in .gitignore (security risk!)"
    fi

    echo

    # Check ansible.cfg
    print_info "Checking ansible.cfg..."
    if grep -q "vault_password_file" "${script_dir}/ansible.cfg" 2>/dev/null; then
        print_success "Vault password file configured in ansible.cfg"
    else
        print_info "No vault password file config in ansible.cfg"
    fi
}

# =============================================================================
# Interactive Vault Menu System
# =============================================================================

# Check if ansible-vault is available
_vault_check_deps() {
    if ! command -v ansible-vault &>/dev/null; then
        print_error "ansible-vault not found. Please install Ansible first."
        return 1
    fi
    return 0
}

# Initialize vault (menu wrapper)
_vault_menu_init() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"
    local script_dir="${SCRIPT_DIR:-.}"

    print_section "Initialize Ansible Vault"

    if [[ -f "$password_file" ]]; then
        print_warning "Vault password file already exists: $password_file"
        echo
        if ! prompt_confirm "Do you want to create a new one?"; then
            print_info "Keeping existing vault password file."
            return 0
        fi

        # Backup existing password
        local backup="${password_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$password_file" "$backup"
        print_info "Backed up existing password to: $backup"
    fi

    print_info "Generating strong vault password..."
    openssl rand -base64 32 > "$password_file"
    chmod 600 "$password_file"
    print_success "Created vault password file: $password_file"

    echo
    print_warning "IMPORTANT: Save this password in a secure location!"
    print_info "You can view it with: cat $password_file"
    echo

    # Check if vault.yml exists
    if [[ ! -f "${script_dir}/group_vars/vault.yml" ]]; then
        echo
        if prompt_confirm "Do you want to create group_vars/vault.yml now?"; then
            mkdir -p "${script_dir}/group_vars"
            if ansible-vault create "${script_dir}/group_vars/vault.yml" --vault-password-file="$password_file"; then
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
}

# Edit vault file (menu wrapper)
_vault_menu_edit() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"
    local script_dir="${SCRIPT_DIR:-.}"

    if [[ ! -f "$password_file" ]]; then
        print_error "Vault password file not found: $password_file"
        print_info "Run 'Initialize Vault' first."
        return 1
    fi

    # Enforce permissions
    security_check_vault_permissions "$password_file"

    print_section "Edit Vault File"
    echo "  1) group_vars/vault.yml (main secrets)"
    echo "  2) Enter custom path"
    echo

    local file_choice
    file_choice=$(prompt_input "Choose [1-2]")

    local file
    case "$file_choice" in
        1) file="${script_dir}/group_vars/vault.yml" ;;
        2) file=$(prompt_input "Enter file path") ;;
        *) print_warning "Invalid option"; return 1 ;;
    esac

    if [[ ! -f "$file" ]]; then
        print_warning "File not found: $file"
        if prompt_confirm "Do you want to create a new encrypted file?"; then
            mkdir -p "$(dirname "$file")"
            if ansible-vault create "$file" --vault-password-file="$password_file"; then
                print_success "Created and encrypted: $file"
            else
                print_warning "File creation cancelled or failed."
            fi
        fi
        return 0
    fi

    print_info "Opening encrypted file in editor: $file"
    print_info "The file will be decrypted in-memory only (secure)."
    echo

    if ansible-vault edit "$file" --vault-password-file="$password_file"; then
        print_success "File edited and saved (still encrypted): $file"
    else
        print_warning "Edit cancelled or failed."
    fi
}

# View vault file (menu wrapper)
_vault_menu_view() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"
    local script_dir="${SCRIPT_DIR:-.}"

    if [[ ! -f "$password_file" ]]; then
        print_error "Vault password file not found: $password_file"
        return 1
    fi

    # Enforce permissions
    security_check_vault_permissions "$password_file"

    print_section "View Vault File"
    echo "  1) group_vars/vault.yml"
    echo "  2) Enter custom path"
    echo

    local file_choice
    file_choice=$(prompt_input "Choose [1-2]")

    local file
    case "$file_choice" in
        1) file="${script_dir}/group_vars/vault.yml" ;;
        2) file=$(prompt_input "Enter file path") ;;
        *) print_warning "Invalid option"; return 1 ;;
    esac

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    print_info "Viewing encrypted file: $file"
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo

    if ansible-vault view "$file" --vault-password-file="$password_file"; then
        echo
        echo "═══════════════════════════════════════════════════════════"
        echo
        print_success "File displayed (decrypted in-memory only)"
    else
        echo
        echo "═══════════════════════════════════════════════════════════"
        echo
        print_error "Failed to view vault file (wrong password or corrupt file)"
        return 1
    fi
}

# Encrypt file (menu wrapper)
_vault_menu_encrypt() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"

    if [[ ! -f "$password_file" ]]; then
        print_warning "Vault password file not found, creating one..."
        openssl rand -base64 32 > "$password_file"
        chmod 600 "$password_file"
        print_success "Created vault password file: $password_file"
    fi

    # Enforce permissions
    security_check_vault_permissions "$password_file"

    local file
    file=$(prompt_input "Enter file path to encrypt")

    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi

    # Check if already encrypted
    if head -1 "$file" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
        print_warning "File is already encrypted: $file"
        return 0
    fi

    # Create backup
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    print_info "Created backup: $backup_file"

    # Encrypt
    if ansible-vault encrypt "$file" --vault-password-file="$password_file"; then
        print_success "File encrypted successfully: $file"
        print_info "Backup saved at: $backup_file"
    else
        print_error "Failed to encrypt file: $file"
        return 1
    fi
}

# Rekey vault (menu wrapper)
_vault_menu_rekey() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"
    local script_dir="${SCRIPT_DIR:-.}"

    if [[ ! -f "$password_file" ]]; then
        print_error "Vault password file not found: $password_file"
        return 1
    fi

    # Enforce permissions
    security_check_vault_permissions "$password_file"

    print_section "Vault Password Rotation"

    print_warning "This will change the vault password for encrypted files."
    echo
    print_warning "IMPORTANT:"
    echo "  1. Old password will no longer work"
    echo "  2. Team members will need the new password"
    echo

    echo "Options:"
    echo "  1) Re-key single file"
    echo "  2) Re-key ALL encrypted vault files"
    echo "  3) Cancel"
    echo

    local rekey_choice
    rekey_choice=$(prompt_input "Choose [1-3]")

    case "$rekey_choice" in
        1)
            local file
            file=$(prompt_input "Enter file path")
            if [[ ! -f "$file" ]]; then
                print_error "File not found: $file"
                return 1
            fi
            if prompt_confirm "Re-key $file?"; then
                if ansible-vault rekey "$file" --vault-password-file="$password_file"; then
                    print_success "File re-keyed: $file"
                else
                    print_error "Failed to re-key: $file"
                    return 1
                fi
            fi
            ;;
        2)
            print_info "Searching for encrypted vault files..."
            local encrypted_files
            encrypted_files=$(find "$script_dir" -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

            if [[ -z "$encrypted_files" ]]; then
                print_warning "No encrypted vault files found."
            else
                echo "Found encrypted files:"
                echo "$encrypted_files"
                echo
                if prompt_confirm "Re-key all these files?"; then
                    local rekey_failed=false
                    echo "$encrypted_files" | while read -r file; do
                        print_info "Re-keying: $file"
                        if ! ansible-vault rekey "$file" --vault-password-file="$password_file"; then
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
}

# Validate vault (menu wrapper)
_vault_menu_validate() {
    _vault_check_deps || return 1

    local password_file="${VAULT_PASSWORD_FILE:-.vault_password}"
    local script_dir="${SCRIPT_DIR:-.}"

    if [[ ! -f "$password_file" ]]; then
        print_error "Vault password file not found: $password_file"
        return 1
    fi

    # Enforce permissions
    security_check_vault_permissions "$password_file"

    print_info "Searching for encrypted vault files..."
    local encrypted_files
    encrypted_files=$(find "$script_dir" -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -z "$encrypted_files" ]]; then
        print_warning "No encrypted vault files found."
    else
        echo
        echo "$encrypted_files" | while read -r file; do
            print_info "Validating: $file"
            if ansible-vault view "$file" --vault-password-file="$password_file" >/dev/null 2>&1; then
                print_success "Valid: $file"
            else
                print_error "Invalid: $file"
            fi
        done
    fi
}

# Show the vault menu
vault_menu_show() {
    local return_callback="${1:-}"

    while true; do
        clear
        print_header "Vault Management"
        echo

        echo "  1) Initialize Vault     - Create vault password and setup"
        echo "  2) Edit Vault           - Edit encrypted vault file (recommended)"
        echo "  3) View Vault           - View encrypted vault file (read-only)"
        echo "  4) Encrypt File         - Encrypt a plain text file"
        echo "  5) Re-key Vault         - Change vault password"
        echo "  6) Validate Vault       - Validate vault file(s)"
        echo "  7) Vault Status         - Show vault status"
        echo "  8) Back"
        echo

        local choice
        choice=$(prompt_input "Choose an option [1-8]")

        case "$choice" in
            1)
                _vault_menu_init
                read -p "Press Enter to continue..."
                ;;
            2)
                _vault_menu_edit
                read -p "Press Enter to continue..."
                ;;
            3)
                _vault_menu_view
                read -p "Press Enter to continue..."
                ;;
            4)
                _vault_menu_encrypt
                read -p "Press Enter to continue..."
                ;;
            5)
                _vault_menu_rekey
                read -p "Press Enter to continue..."
                ;;
            6)
                _vault_menu_validate
                read -p "Press Enter to continue..."
                ;;
            7)
                vault_show_status
                read -p "Press Enter to continue..."
                ;;
            8)
                if [[ -n "$return_callback" ]] && declare -F "$return_callback" &>/dev/null; then
                    "$return_callback"
                fi
                return 0
                ;;
            *)
                print_warning "Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Alias for backwards compatibility
show_vault_menu() {
    vault_menu_show "$@"
}
