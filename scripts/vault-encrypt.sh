#!/usr/bin/env bash
#
# vault-encrypt.sh - Helper script to encrypt files with Ansible Vault
# Part of Server Helper v2.0.0
#
# Usage:
#   ./scripts/vault-encrypt.sh [file]
#   ./scripts/vault-encrypt.sh group_vars/vault.yml
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
    warning "Vault password file not found: $VAULT_PASSWORD_FILE"
    echo
    info "Creating vault password file..."
    openssl rand -base64 32 > "$VAULT_PASSWORD_FILE"
    chmod 600 "$VAULT_PASSWORD_FILE"
    success "Created vault password file: $VAULT_PASSWORD_FILE"
    echo
    warning "IMPORTANT: Save this password in a secure location!"
    info "You can view it with: cat $VAULT_PASSWORD_FILE"
    echo
fi

# Check if file argument is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>"
    echo
    echo "Examples:"
    echo "  $0 group_vars/vault.yml"
    echo "  $0 inventory/hosts.yml"
    echo
    info "Common files to encrypt:"
    echo "  - group_vars/vault.yml (secrets)"
    echo "  - group_vars/all.yml (configuration)"
    echo "  - inventory/hosts.yml (inventory)"
    exit 1
fi

FILE="$1"

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    error "File not found: $FILE"
fi

# Check if file is already encrypted
if head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
    warning "File is already encrypted: $FILE"
    echo
    read -p "Do you want to re-encrypt it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted."
        exit 0
    fi

    # Decrypt first, then re-encrypt
    info "Re-encrypting file..."
    ansible-vault rekey "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
    success "File re-encrypted: $FILE"
else
    # Encrypt the file
    info "Encrypting file: $FILE"

    # Create backup
    BACKUP_FILE="${FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$FILE" "$BACKUP_FILE"
    info "Created backup: $BACKUP_FILE"

    # Encrypt
    ansible-vault encrypt "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"

    if [[ $? -eq 0 ]]; then
        success "File encrypted successfully: $FILE"
        echo
        info "The original file has been backed up to: $BACKUP_FILE"
        info "You can safely delete the backup after verifying the encrypted file."
        echo
        info "To view the encrypted file:"
        echo "  ./scripts/vault-view.sh $FILE"
        echo
        info "To edit the encrypted file:"
        echo "  ./scripts/vault-edit.sh $FILE"
    else
        error "Failed to encrypt file: $FILE"
    fi
fi
