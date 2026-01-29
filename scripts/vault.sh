#!/usr/bin/env bash
#
# Server Helper - Vault Management Script
# ========================================
# All-in-one tool for Ansible Vault operations.
#
# Usage:
#   ./scripts/vault.sh <command> [args]
#
# Security:
#   - Uses library modules for secure operations
#   - Cleanup trap clears sensitive variables on exit
#

set -euo pipefail

# =============================================================================
# INITIALIZATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# =============================================================================
# SOURCE LIBRARY MODULES
# =============================================================================

if [[ -f "${LIB_DIR}/ui_utils.sh" ]]; then
    source "${LIB_DIR}/ui_utils.sh"
else
    # Fallback if library not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'

    print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
    print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fi

# Source vault manager if available
if [[ -f "${LIB_DIR}/vault_mgr.sh" ]]; then
    source "${LIB_DIR}/vault_mgr.sh"
fi

# =============================================================================
# SECURITY: CLEANUP TRAP
# =============================================================================

_cleanup() {
    # Unset sensitive variables
    local var
    for var in $(compgen -v | grep -iE 'password|secret|token|key' 2>/dev/null || true); do
        unset "$var" 2>/dev/null || true
    done
}

trap _cleanup EXIT SIGINT SIGTERM

# =============================================================================
# CONFIGURATION
# =============================================================================

VAULT_PASSWORD_FILE="${PROJECT_ROOT}/.vault_password"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

error() {
    print_error "$1"
    exit 1
}

success() {
    print_success "$1"
}

warning() {
    print_warning "$1"
}

info() {
    print_info "$1"
}

title() {
    echo -e "${CYAN:-\033[0;36m}═══════════════════════════════════════════════════════════${NC:-\033[0m}"
    echo -e "${CYAN:-\033[0;36m}  $1${NC:-\033[0m}"
    echo -e "${CYAN:-\033[0;36m}═══════════════════════════════════════════════════════════${NC:-\033[0m}"
    echo
}

# Check dependencies
check_dependencies() {
    if ! command -v ansible-vault &> /dev/null; then
        error "ansible-vault not found. Please install Ansible first."
    fi
}

# Validate vault password file permissions
check_vault_permissions() {
    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        local perms
        perms=$(stat -c "%a" "$VAULT_PASSWORD_FILE" 2>/dev/null || stat -f "%Lp" "$VAULT_PASSWORD_FILE" 2>/dev/null || echo "unknown")

        if [[ "$perms" != "600" ]] && [[ "$perms" != "unknown" ]]; then
            warning "Vault password file has insecure permissions: $perms"
            info "Fixing permissions to 600..."
            chmod 600 "$VAULT_PASSWORD_FILE" 2>/dev/null || true
        fi
    fi
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    title "Ansible Vault Management Tool"

    echo "Usage: $0 <command> [args]"
    echo
    echo -e "${CYAN:-\033[0;36m}Commands:${NC:-\033[0m}"
    echo
    echo -e "  ${GREEN:-\033[0;32m}create${NC:-\033[0m} <file>           Create new encrypted vault file"
    echo -e "  ${GREEN:-\033[0;32m}edit${NC:-\033[0m} <file>             Edit encrypted vault file (recommended)"
    echo -e "  ${GREEN:-\033[0;32m}view${NC:-\033[0m} <file>             View encrypted vault file (read-only)"
    echo -e "  ${GREEN:-\033[0;32m}encrypt${NC:-\033[0m} <file>          Encrypt a plain text file"
    echo -e "  ${GREEN:-\033[0;32m}decrypt${NC:-\033[0m} <file>          Decrypt an encrypted file (dangerous!)"
    echo -e "  ${GREEN:-\033[0;32m}rekey${NC:-\033[0m} <file|--all>      Change vault password"
    echo -e "  ${GREEN:-\033[0;32m}validate${NC:-\033[0m} [file]         Validate vault file(s)"
    echo -e "  ${GREEN:-\033[0;32m}init${NC:-\033[0m}                    Initialize vault setup"
    echo -e "  ${GREEN:-\033[0;32m}status${NC:-\033[0m}                  Show vault status"
    echo -e "  ${GREEN:-\033[0;32m}diff${NC:-\033[0m} <file>             Show diff of encrypted file"
    echo -e "  ${GREEN:-\033[0;32m}backup${NC:-\033[0m} <file>           Create backup of vault file"
    echo -e "  ${GREEN:-\033[0;32m}restore${NC:-\033[0m} <backup>        Restore from backup"
    echo
    echo -e "${CYAN:-\033[0;36m}Examples:${NC:-\033[0m}"
    echo
    echo "  $0 init"
    echo "  $0 create group_vars/vault.yml"
    echo "  $0 edit group_vars/vault.yml"
    echo "  $0 view group_vars/vault.yml"
    echo "  $0 validate"
    echo "  $0 status"
    echo
}

# =============================================================================
# VAULT OPERATIONS
# =============================================================================

init_vault() {
    title "Initialize Ansible Vault"

    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        warning "Vault password file already exists: $VAULT_PASSWORD_FILE"
        echo
        read -p "Do you want to create a new one? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Keeping existing vault password file."
            return 0
        fi

        # Backup existing password
        local BACKUP="${VAULT_PASSWORD_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$VAULT_PASSWORD_FILE" "$BACKUP"
        info "Backed up existing password to: $BACKUP"
    fi

    info "Generating strong vault password..."
    openssl rand -base64 32 > "$VAULT_PASSWORD_FILE"
    chmod 600 "$VAULT_PASSWORD_FILE"
    success "Created vault password file: $VAULT_PASSWORD_FILE"

    echo
    warning "IMPORTANT: Save this password in a secure location!"
    info "You can view it with: cat $VAULT_PASSWORD_FILE"
    echo

    # Check if vault.yml exists
    if [[ ! -f "$PROJECT_ROOT/group_vars/vault.yml" ]]; then
        echo
        read -p "Do you want to create group_vars/vault.yml now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            mkdir -p "$PROJECT_ROOT/group_vars"
            export EDITOR="${EDITOR:-nano}"
            ansible-vault create "$PROJECT_ROOT/group_vars/vault.yml" --vault-password-file="$VAULT_PASSWORD_FILE"
        fi
    fi

    echo
    success "Vault initialization complete!"
    echo
    info "Next steps:"
    echo "  1. Save vault password in your password manager"
    echo "  2. Share vault password securely with team (if applicable)"
    echo "  3. Edit vault file: $0 edit group_vars/vault.yml"
    echo "  4. Reference vault variables in group_vars/all.yml"
}

show_status() {
    title "Ansible Vault Status"

    cd "$PROJECT_ROOT"

    # Check vault password file
    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        success "Vault password file exists: $VAULT_PASSWORD_FILE"
        local perms
        perms=$(stat -c %a "$VAULT_PASSWORD_FILE" 2>/dev/null || stat -f %Lp "$VAULT_PASSWORD_FILE" 2>/dev/null)
        if [[ "$perms" == "600" ]]; then
            success "  Permissions: $perms (secure)"
        else
            warning "  Permissions: $perms (should be 600)"
        fi
    else
        print_error "Vault password file NOT found: $VAULT_PASSWORD_FILE"
    fi

    echo

    # Find encrypted files
    info "Searching for encrypted vault files..."
    local encrypted_files
    encrypted_files=$(find . -type f -name "*vault*.yml" -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -n "$encrypted_files" ]]; then
        success "Found encrypted vault files:"
        echo "$encrypted_files" | while read -r file; do
            local size
            size=$(du -h "$file" | cut -f1)
            echo "  - $file ($size)"
        done
    else
        warning "No encrypted vault files found."
    fi

    echo

    # Find plain text vault files
    info "Checking for plain text vault files..."
    local plaintext_files
    plaintext_files=$(find . -type f -name "*vault*.yml" ! -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -n "$plaintext_files" ]]; then
        warning "Found PLAIN TEXT vault files (security risk!):"
        echo "$plaintext_files" | while read -r file; do
            echo "  - $file"
        done
        echo
        warning "Encrypt these files with: $0 encrypt <file>"
    else
        success "No plain text vault files found."
    fi

    echo

    # Check .gitignore
    info "Checking .gitignore..."
    if grep -q ".vault_password" .gitignore 2>/dev/null; then
        success ".vault_password is in .gitignore"
    else
        warning ".vault_password is NOT in .gitignore (security risk!)"
        echo "  Add it with: echo '.vault_password' >> .gitignore"
    fi

    echo

    # Check ansible.cfg
    info "Checking ansible.cfg..."
    if grep -q "vault_password_file" ansible.cfg 2>/dev/null; then
        local vault_config
        vault_config=$(grep "vault_password_file" ansible.cfg | grep -v "^#" || true)
        if [[ -n "$vault_config" ]]; then
            success "Vault password file configured in ansible.cfg"
            echo "  $vault_config"
        else
            info "Vault password file config commented out in ansible.cfg"
        fi
    else
        info "No vault password file config in ansible.cfg"
    fi

    echo
}

validate_vault() {
    title "Validate Vault Files"

    cd "$PROJECT_ROOT"

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        error "Vault password file not found: $VAULT_PASSWORD_FILE"
    fi

    if [[ $# -gt 0 ]]; then
        # Validate specific file
        local FILE="$1"
        if [[ ! -f "$FILE" ]]; then
            error "File not found: $FILE"
        fi

        info "Validating: $FILE"

        if ! head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
            error "File is NOT encrypted: $FILE"
        fi

        if ansible-vault view "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE" > /dev/null 2>&1; then
            success "File is valid and can be decrypted: $FILE"

            if ansible-vault view "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE" | python3 -c "import sys, yaml; yaml.safe_load(sys.stdin)" 2>/dev/null; then
                success "YAML syntax is valid"
            else
                warning "YAML syntax may be invalid"
            fi
        else
            error "Cannot decrypt file (wrong password?): $FILE"
        fi
    else
        # Validate all vault files
        info "Searching for encrypted vault files..."
        local encrypted_files
        encrypted_files=$(find . -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

        if [[ -z "$encrypted_files" ]]; then
            warning "No encrypted vault files found."
            exit 0
        fi

        local success_count=0
        local fail_count=0

        while read -r file; do
            echo
            info "Validating: $file"

            if ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE" > /dev/null 2>&1; then
                success "Valid: $file"
                ((success_count++)) || true
            else
                print_error "Invalid: $file"
                ((fail_count++)) || true
            fi
        done <<< "$encrypted_files"

        echo
        if [[ $fail_count -eq 0 ]]; then
            success "All vault files are valid!"
        else
            warning "$fail_count file(s) failed validation"
        fi
    fi
}

backup_vault() {
    if [[ $# -eq 0 ]]; then
        error "Usage: $0 backup <file>"
    fi

    local FILE="$1"
    cd "$PROJECT_ROOT"

    if [[ ! -f "$FILE" ]]; then
        error "File not found: $FILE"
    fi

    local BACKUP_DIR="$PROJECT_ROOT/backups/vault"
    mkdir -p "$BACKUP_DIR"

    local BACKUP_FILE="$BACKUP_DIR/$(basename "$FILE").backup.$(date +%Y%m%d_%H%M%S)"
    cp "$FILE" "$BACKUP_FILE"

    success "Backup created: $BACKUP_FILE"

    # Keep only last 10 backups
    local backup_count
    backup_count=$(ls -1 "$BACKUP_DIR" | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        info "Cleaning old backups (keeping last 10)..."
        ls -1t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm "$BACKUP_DIR/{}"
    fi
}

restore_vault() {
    if [[ $# -eq 0 ]]; then
        echo "Available backups:"
        ls -lh "$PROJECT_ROOT/backups/vault/" 2>/dev/null || echo "No backups found"
        echo
        error "Usage: $0 restore <backup-file>"
    fi

    local BACKUP_FILE="$1"

    if [[ ! -f "$BACKUP_FILE" ]]; then
        error "Backup file not found: $BACKUP_FILE"
    fi

    # Determine original file path
    local ORIGINAL_FILE="group_vars/$(basename "$BACKUP_FILE" | sed 's/.backup.*//')"

    warning "This will restore: $ORIGINAL_FILE"
    warning "From backup: $BACKUP_FILE"
    echo
    read -p "Continue? (yes/NO): " -r
    echo

    if [[ ! "$REPLY" = "yes" ]]; then
        info "Aborted."
        exit 0
    fi

    # Create backup of current file first
    if [[ -f "$ORIGINAL_FILE" ]]; then
        backup_vault "$ORIGINAL_FILE"
    fi

    cp "$BACKUP_FILE" "$ORIGINAL_FILE"
    success "Restored: $ORIGINAL_FILE"
}

show_diff() {
    if [[ $# -eq 0 ]]; then
        error "Usage: $0 diff <file>"
    fi

    local FILE="$1"
    cd "$PROJECT_ROOT"

    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        error "Vault password file not found: $VAULT_PASSWORD_FILE"
    fi

    if [[ ! -f "$FILE" ]]; then
        error "File not found: $FILE"
    fi

    info "Showing diff for: $FILE"
    echo

    git diff --textconv="ansible-vault view --vault-password-file=$VAULT_PASSWORD_FILE" "$FILE" || \
        error "Git diff failed. Is this a git repository?"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    check_dependencies
    check_vault_permissions

    cd "$PROJECT_ROOT"

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local COMMAND="$1"
    shift

    case "$COMMAND" in
        create|edit)
            # Use library function if available, otherwise inline implementation
            local file="${1:-group_vars/vault.yml}"
            export EDITOR="${EDITOR:-nano}"
            if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
                error "Vault password file not found: $VAULT_PASSWORD_FILE"
            fi
            if [[ ! -f "$file" ]]; then
                info "Creating new encrypted vault file: $file"
                mkdir -p "$(dirname "$file")"
                ansible-vault create "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
            else
                info "Editing encrypted file: $file"
                ansible-vault edit "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
            fi
            ;;
        view)
            local file="${1:-group_vars/vault.yml}"
            if [[ ! -f "$file" ]]; then
                error "File not found: $file"
            fi
            if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
                error "Vault password file not found: $VAULT_PASSWORD_FILE"
            fi
            info "Viewing encrypted file: $file"
            ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
            ;;
        encrypt)
            local file="$1"
            if [[ -z "$file" ]]; then
                error "Usage: $0 encrypt <file>"
            fi
            if [[ ! -f "$file" ]]; then
                error "File not found: $file"
            fi
            if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
                info "Creating vault password file..."
                openssl rand -base64 32 > "$VAULT_PASSWORD_FILE"
                chmod 600 "$VAULT_PASSWORD_FILE"
                success "Created vault password file: $VAULT_PASSWORD_FILE"
            fi
            if head -1 "$file" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
                warning "File is already encrypted: $file"
            else
                local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
                cp "$file" "$backup"
                info "Created backup: $backup"
                ansible-vault encrypt "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
                success "File encrypted: $file"
            fi
            ;;
        decrypt)
            local file="$1"
            if [[ -z "$file" ]]; then
                error "Usage: $0 decrypt <file>"
            fi
            if [[ ! -f "$file" ]]; then
                error "File not found: $file"
            fi
            if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
                error "Vault password file not found: $VAULT_PASSWORD_FILE"
            fi
            warning "SECURITY WARNING: This will create a plain text file!"
            warning "NEVER commit decrypted files to Git!"
            read -p "Do you understand and want to proceed? (yes/NO): " -r
            if [[ "$REPLY" != "yes" ]]; then
                info "Aborted."
                exit 0
            fi
            ansible-vault decrypt "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
            success "File decrypted: $file"
            warning "Remember to re-encrypt this file when done!"
            ;;
        rekey)
            local file="$1"
            if [[ -z "$file" ]]; then
                error "Usage: $0 rekey <file|--all>"
            fi
            if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
                error "Vault password file not found: $VAULT_PASSWORD_FILE"
            fi
            if [[ "$file" == "--all" ]]; then
                # Rekey all vault files
                local encrypted_files
                encrypted_files=$(find . -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)
                if [[ -z "$encrypted_files" ]]; then
                    warning "No encrypted vault files found."
                    exit 0
                fi
                echo "Found encrypted files:"
                echo "$encrypted_files"
                read -p "Re-key all these files? (yes/NO): " -r
                if [[ "$REPLY" != "yes" ]]; then
                    info "Aborted."
                    exit 0
                fi
                while read -r f; do
                    info "Re-keying: $f"
                    ansible-vault rekey "$f" --vault-password-file="$VAULT_PASSWORD_FILE" || warning "Failed: $f"
                done <<< "$encrypted_files"
            else
                if [[ ! -f "$file" ]]; then
                    error "File not found: $file"
                fi
                ansible-vault rekey "$file" --vault-password-file="$VAULT_PASSWORD_FILE"
                success "File re-keyed: $file"
            fi
            ;;
        init)
            init_vault
            ;;
        status)
            show_status
            ;;
        validate)
            validate_vault "$@"
            ;;
        backup)
            backup_vault "$@"
            ;;
        restore)
            restore_vault "$@"
            ;;
        diff)
            show_diff "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $COMMAND"
            ;;
    esac
}

main "$@"
