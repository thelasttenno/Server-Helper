#!/usr/bin/env bash
#
# vault.sh - Master Ansible Vault management script
# Part of Server Helper v2.0.0
#
# All-in-one tool for vault operations
#
# Usage:
#   ./scripts/vault.sh <command> [args]
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

title() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo
}

# Check dependencies
check_dependencies() {
    if ! command -v ansible-vault &> /dev/null; then
        error "ansible-vault not found. Please install Ansible first."
    fi
}

# Show usage
usage() {
    title "Ansible Vault Management Tool"

    echo "Usage: $0 <command> [args]"
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo
    echo -e "  ${GREEN}create${NC} <file>           Create new encrypted vault file"
    echo -e "  ${GREEN}edit${NC} <file>             Edit encrypted vault file (recommended)"
    echo -e "  ${GREEN}view${NC} <file>             View encrypted vault file (read-only)"
    echo -e "  ${GREEN}encrypt${NC} <file>          Encrypt a plain text file"
    echo -e "  ${GREEN}decrypt${NC} <file>          Decrypt an encrypted file (dangerous!)"
    echo -e "  ${GREEN}rekey${NC} <file|--all>      Change vault password"
    echo -e "  ${GREEN}validate${NC} [file]         Validate vault file(s)"
    echo -e "  ${GREEN}init${NC}                    Initialize vault setup"
    echo -e "  ${GREEN}status${NC}                  Show vault status"
    echo -e "  ${GREEN}diff${NC} <file>             Show diff of encrypted file"
    echo -e "  ${GREEN}backup${NC} <file>           Create backup of vault file"
    echo -e "  ${GREEN}restore${NC} <backup>        Restore from backup"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo
    echo "  $0 init"
    echo "  $0 create group_vars/vault.yml"
    echo "  $0 edit group_vars/vault.yml"
    echo "  $0 view group_vars/vault.yml"
    echo "  $0 validate"
    echo "  $0 status"
    echo
    echo -e "${CYAN}Documentation:${NC}"
    echo
    echo "  docs/guides/vault.md               - Complete guide"
    echo "  docs/reference/vault-commands.md   - Quick reference"
    echo "  docs/workflows/vault-in-ci-cd.md   - CI/CD integration"
    echo
}

# Initialize vault setup
init_vault() {
    title "Initialize Ansible Vault"

    VAULT_PASSWORD_FILE="$PROJECT_ROOT/.vault_password"

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
        BACKUP="${VAULT_PASSWORD_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
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
            "$SCRIPT_DIR/vault-edit.sh" "$PROJECT_ROOT/group_vars/vault.yml"
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

# Show vault status
show_status() {
    title "Ansible Vault Status"

    cd "$PROJECT_ROOT"

    # Check vault password file
    VAULT_PASSWORD_FILE=".vault_password"
    if [[ -f "$VAULT_PASSWORD_FILE" ]]; then
        success "Vault password file exists: $VAULT_PASSWORD_FILE"
        info "  Permissions: $(stat -c %a "$VAULT_PASSWORD_FILE" 2>/dev/null || stat -f %Lp "$VAULT_PASSWORD_FILE")"
    else
        error "Vault password file NOT found: $VAULT_PASSWORD_FILE"
    fi

    echo

    # Find encrypted files
    info "Searching for encrypted vault files..."
    encrypted_files=$(find . -type f -name "*vault*.yml" -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -n "$encrypted_files" ]]; then
        success "Found encrypted vault files:"
        echo "$encrypted_files" | while read -r file; do
            size=$(du -h "$file" | cut -f1)
            echo "  ✓ $file ($size)"
        done
    else
        warning "No encrypted vault files found."
    fi

    echo

    # Find plain text vault files (potential security issue)
    info "Checking for plain text vault files..."
    plaintext_files=$(find . -type f -name "*vault*.yml" ! -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -n "$plaintext_files" ]]; then
        warning "Found PLAIN TEXT vault files (security risk!):"
        echo "$plaintext_files" | while read -r file; do
            echo "  ⚠ $file"
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

# Validate vault files
validate_vault() {
    title "Validate Vault Files"

    cd "$PROJECT_ROOT"

    VAULT_PASSWORD_FILE=".vault_password"
    if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
        error "Vault password file not found: $VAULT_PASSWORD_FILE"
    fi

    if [[ $# -gt 0 ]]; then
        # Validate specific file
        FILE="$1"
        if [[ ! -f "$FILE" ]]; then
            error "File not found: $FILE"
        fi

        info "Validating: $FILE"

        # Check if encrypted
        if ! head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
            error "File is NOT encrypted: $FILE"
        fi

        # Try to decrypt
        if ansible-vault view "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE" > /dev/null 2>&1; then
            success "File is valid and can be decrypted: $FILE"

            # Validate YAML syntax
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
        encrypted_files=$(find . -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

        if [[ -z "$encrypted_files" ]]; then
            warning "No encrypted vault files found."
            exit 0
        fi

        success_count=0
        fail_count=0

        echo "$encrypted_files" | while read -r file; do
            echo
            info "Validating: $file"

            if ansible-vault view "$file" --vault-password-file="$VAULT_PASSWORD_FILE" > /dev/null 2>&1; then
                success "✓ Valid: $file"
                ((success_count++)) || true
            else
                error "✗ Invalid: $file"
                ((fail_count++)) || true
            fi
        done

        echo
        if [[ $fail_count -eq 0 ]]; then
            success "All vault files are valid!"
        else
            warning "$fail_count file(s) failed validation"
        fi
    fi
}

# Backup vault file
backup_vault() {
    if [[ $# -eq 0 ]]; then
        error "Usage: $0 backup <file>"
    fi

    FILE="$1"
    cd "$PROJECT_ROOT"

    if [[ ! -f "$FILE" ]]; then
        error "File not found: $FILE"
    fi

    BACKUP_DIR="$PROJECT_ROOT/backups/vault"
    mkdir -p "$BACKUP_DIR"

    BACKUP_FILE="$BACKUP_DIR/$(basename "$FILE").backup.$(date +%Y%m%d_%H%M%S)"
    cp "$FILE" "$BACKUP_FILE"

    success "Backup created: $BACKUP_FILE"

    # Keep only last 10 backups
    backup_count=$(ls -1 "$BACKUP_DIR" | wc -l)
    if [[ $backup_count -gt 10 ]]; then
        info "Cleaning old backups (keeping last 10)..."
        ls -1t "$BACKUP_DIR" | tail -n +11 | xargs -I {} rm "$BACKUP_DIR/{}"
    fi
}

# Restore from backup
restore_vault() {
    if [[ $# -eq 0 ]]; then
        echo "Available backups:"
        ls -lh "$PROJECT_ROOT/backups/vault/" 2>/dev/null || echo "No backups found"
        echo
        error "Usage: $0 restore <backup-file>"
    fi

    BACKUP_FILE="$1"

    if [[ ! -f "$BACKUP_FILE" ]]; then
        error "Backup file not found: $BACKUP_FILE"
    fi

    # Determine original file path
    ORIGINAL_FILE="group_vars/$(basename "$BACKUP_FILE" | sed 's/.backup.*//')"

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

# Show diff
show_diff() {
    if [[ $# -eq 0 ]]; then
        error "Usage: $0 diff <file>"
    fi

    FILE="$1"
    cd "$PROJECT_ROOT"

    VAULT_PASSWORD_FILE=".vault_password"
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

# Main
main() {
    check_dependencies

    cd "$PROJECT_ROOT"

    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    COMMAND="$1"
    shift

    case "$COMMAND" in
        create)
            exec "$SCRIPT_DIR/vault-edit.sh" "$@"
            ;;
        edit)
            exec "$SCRIPT_DIR/vault-edit.sh" "$@"
            ;;
        view)
            exec "$SCRIPT_DIR/vault-view.sh" "$@"
            ;;
        encrypt)
            exec "$SCRIPT_DIR/vault-encrypt.sh" "$@"
            ;;
        decrypt)
            exec "$SCRIPT_DIR/vault-decrypt.sh" "$@"
            ;;
        rekey)
            exec "$SCRIPT_DIR/vault-rekey.sh" "$@"
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
            echo
            usage
            exit 1
            ;;
    esac
}

main "$@"
