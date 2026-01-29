#!/usr/bin/env bash
#
# vault-decrypt.sh - Helper script to decrypt Ansible Vault files
# Part of Server Helper v2.0.0
#
# ⚠️ WARNING: Use this script with caution!
# Decrypted files contain sensitive information and should NOT be committed to Git.
#
# Usage:
#   ./scripts/vault-decrypt.sh [file]
#   ./scripts/vault-decrypt.sh group_vars/vault.yml
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

# Check if file argument is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <file>"
    echo
    echo "Examples:"
    echo "  $0 group_vars/vault.yml"
    echo
    warning "⚠️  SECURITY WARNING ⚠️"
    echo
    echo "Decrypting a file will expose sensitive information!"
    echo "The decrypted file should:"
    echo "  - NEVER be committed to Git"
    echo "  - Be deleted immediately after use"
    echo "  - Be handled with extreme care"
    echo
    info "Consider using these safer alternatives:"
    echo "  - ./scripts/vault-view.sh (read-only viewing)"
    echo "  - ./scripts/vault-edit.sh (edit without creating plain text file)"
    exit 1
fi

FILE="$1"

# Check if file exists
if [[ ! -f "$FILE" ]]; then
    error "File not found: $FILE"
fi

# Check if file is encrypted
if ! head -1 "$FILE" 2>/dev/null | grep -q '^\$ANSIBLE_VAULT'; then
    warning "File is NOT encrypted: $FILE"
    info "Nothing to decrypt."
    exit 0
fi

# Display security warning
echo
warning "═══════════════════════════════════════════════════════════"
warning "                   ⚠️  SECURITY WARNING ⚠️                  "
warning "═══════════════════════════════════════════════════════════"
echo
echo "You are about to decrypt: $FILE"
echo
echo "This will create a PLAIN TEXT file containing sensitive data!"
echo
warning "NEVER commit the decrypted file to Git!"
warning "Delete the decrypted file immediately after use!"
echo
echo "═══════════════════════════════════════════════════════════"
echo

read -p "Do you understand and want to proceed? (yes/NO): " -r
echo

if [[ ! "$REPLY" = "yes" ]]; then
    info "Aborted. No files were decrypted."
    echo
    info "Consider using safer alternatives:"
    echo "  - ./scripts/vault-view.sh $FILE (view without decrypting)"
    echo "  - ./scripts/vault-edit.sh $FILE (edit without plain text file)"
    exit 0
fi

# Decrypt the file
info "Decrypting file: $FILE"

ansible-vault decrypt "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"

if [[ $? -eq 0 ]]; then
    success "File decrypted successfully: $FILE"
    echo
    warning "⚠️  REMEMBER: This file is now in PLAIN TEXT!"
    echo
    info "Next steps:"
    echo "  1. Use the decrypted file as needed"
    echo "  2. Re-encrypt immediately: ./scripts/vault-encrypt.sh $FILE"
    echo "  3. Or delete the file if no longer needed"
    echo
    warning "DO NOT commit this file to Git!"
else
    error "Failed to decrypt file: $FILE"
fi
