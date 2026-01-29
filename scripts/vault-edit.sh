#!/usr/bin/env bash
#
# vault-edit.sh - Helper script to edit encrypted Ansible Vault files
# Part of Server Helper v1.0.0
#
# This is the RECOMMENDED way to edit vault files (no plain text file created).
#
# Usage:
#   ./scripts/vault-edit.sh [file]
#   ./scripts/vault-edit.sh group_vars/vault.yml
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Use nano as the default editor
export EDITOR=nano

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

# Check if file argument is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>"
    echo
    echo "Examples:"
    echo "  $0 group_vars/vault.yml"
    echo
    info "Common vault files:"
    echo "  - group_vars/vault.yml"
    echo "  - group_vars/dev/vault.yml"
    echo "  - group_vars/prod/vault.yml"
    echo
    info "This will open the file in your default editor."
    info "The file is decrypted in-memory only (secure)."
    exit 1
fi

FILE="$1"

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    # File doesn't exist - offer to create it
    warning "File not found: $FILE"
    echo
    read -p "Do you want to create a new encrypted file? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Aborted."
        exit 0
    fi

    # Create new encrypted file
    info "Creating new encrypted vault file: $FILE"

    # Ensure directory exists
    mkdir -p "$(dirname "$FILE")"

    ansible-vault create "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"

    if [[ $? -eq 0 ]]; then
        success "Created and encrypted: $FILE"
    else
        error "Failed to create file: $FILE"
    fi
    exit 0
fi

# Check if file is encrypted
if ! head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
    warning "File is NOT encrypted: $FILE"
    echo
    info "This file is currently in plain text."
    read -p "Do you want to encrypt it first? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        ansible-vault encrypt "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"
        success "File encrypted: $FILE"
    fi
fi

# Edit the file
info "Opening encrypted file in editor: $FILE"
echo
info "The file will be decrypted in-memory only (no plain text file created)."
info "Your changes will be automatically encrypted when you save and exit."
echo

ansible-vault edit "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"

if [[ $? -eq 0 ]]; then
    success "File edited and saved (still encrypted): $FILE"
    echo
    info "To view the file:"
    echo "  ./scripts/vault-view.sh $FILE"
else
    warning "Edit cancelled or failed."
fi
