#!/usr/bin/env bash
#
# vault-rekey.sh - Helper script to change Ansible Vault password
# Part of Server Helper v1.0.0
#
# Use this when:
#   - Rotating vault password (security best practice)
#   - Vault password has been compromised
#   - Onboarding/offboarding team members
#
# Usage:
#   ./scripts/vault-rekey.sh [file]
#   ./scripts/vault-rekey.sh group_vars/vault.yml
#   ./scripts/vault-rekey.sh --all  # Re-key ALL encrypted files
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

# Check if ansible-vault is installed
if ! command -v ansible-vault &> /dev/null; then
    error "ansible-vault not found. Please install Ansible first."
fi

# Change to project root
cd "$PROJECT_ROOT"

# Check if vault password file exists
VAULT_PASSWORD_FILE=".vault_password"
if [[ ! -f "$VAULT_PASSWORD_FILE" ]]; then
    error "Vault password file not found: $VAULT_PASSWORD_FILE"
fi

# Function to rekey a single file
rekey_file() {
    local file="$1"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        warning "File not found: $file (skipping)"
        return 1
    fi

    # Check if file is encrypted
    if ! head -1 "$file" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
        warning "File is NOT encrypted: $file (skipping)"
        return 1
    fi

    info "Re-keying: $file"

    # Create backup before re-keying
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup_file"
    info "Created backup: $backup_file"

    # Rekey the file
    ansible-vault rekey "$file" --vault-password-file="$VAULT_PASSWORD_FILE"

    if [[ $? -eq 0 ]]; then
        success "Re-keyed: $file"
        return 0
    else
        error "Failed to re-key: $file"
        return 1
    fi
}

# Display warning
echo
warning "═══════════════════════════════════════════════════════════"
warning "               VAULT PASSWORD ROTATION                     "
warning "═══════════════════════════════════════════════════════════"
echo
echo "This script will change the vault password for encrypted files."
echo
warning "IMPORTANT:"
echo "  1. This will change the encryption password"
echo "  2. Old password will no longer work"
echo "  3. Team members will need the new password"
echo "  4. Backups will be created before re-keying"
echo
echo "═══════════════════════════════════════════════════════════"
echo

# Check if --all flag is provided
if [[ $# -eq 1 && "$1" == "--all" ]]; then
    info "Re-keying ALL encrypted vault files..."
    echo

    # Find all encrypted files
    encrypted_files=$(find . -type f \( -name "vault.yml" -o -name "*vault*.yml" \) -exec grep -l '^\$ANSIBLE_VAULT' {} \; 2>/dev/null || true)

    if [[ -z "$encrypted_files" ]]; then
        warning "No encrypted vault files found."
        exit 0
    fi

    echo "Found encrypted files:"
    echo "$encrypted_files" | while read -r file; do
        echo "  - $file"
    done
    echo

    read -p "Re-key all these files with a new password? (yes/NO): " -r
    echo

    if [[ ! "$REPLY" = "yes" ]]; then
        info "Aborted. No files were re-keyed."
        exit 0
    fi

    # Generate new vault password
    info "Generating new vault password..."
    new_password_file=".vault_password_new"
    openssl rand -base64 32 > "$new_password_file"
    chmod 600 "$new_password_file"
    success "Generated new vault password"
    echo

    # Re-key each file
    success_count=0
    fail_count=0

    echo "$encrypted_files" | while read -r file; do
        if rekey_file "$file"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo
    done

    # Replace old password file with new one
    backup_old_password="${VAULT_PASSWORD_FILE}.old.$(date +%Y%m%d_%H%M%S)"
    mv "$VAULT_PASSWORD_FILE" "$backup_old_password"
    mv "$new_password_file" "$VAULT_PASSWORD_FILE"

    success "All files re-keyed successfully!"
    echo
    info "Old vault password backed up to: $backup_old_password"
    info "New vault password: $VAULT_PASSWORD_FILE"
    echo
    warning "⚠️  REMEMBER:"
    echo "  1. Share the new password with your team (securely!)"
    echo "  2. Update password in CI/CD systems"
    echo "  3. Delete old password backup after verifying"

elif [[ $# -eq 0 ]]; then
    # No arguments - show usage
    echo "Usage: $0 <file>"
    echo "       $0 --all"
    echo
    echo "Examples:"
    echo "  $0 group_vars/vault.yml    # Re-key single file"
    echo "  $0 --all                   # Re-key all encrypted files"
    echo
    info "This will prompt for a new password and re-encrypt the file(s)."
    exit 1
else
    # Single file
    FILE="$1"

    read -p "Re-key $FILE with a new password? (yes/NO): " -r
    echo

    if [[ ! "$REPLY" = "yes" ]]; then
        info "Aborted. No files were re-keyed."
        exit 0
    fi

    rekey_file "$FILE"

    echo
    success "File re-keyed successfully!"
    echo
    warning "⚠️  REMEMBER: Share the new password with your team (securely!)"
fi
