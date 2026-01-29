#!/usr/bin/env bash
#
# vault-view.sh - Helper script to view encrypted Ansible Vault files
# Part of Server Helper v2.0.0
#
# This is the SAFE way to view vault files (no plain text file created).
#
# Usage:
#   ./scripts/vault-view.sh [file]
#   ./scripts/vault-view.sh group_vars/vault.yml
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
    echo "  $0 group_vars/dev/vault.yml"
    echo
    info "Common vault files:"
    echo "  - group_vars/vault.yml"
    echo "  - group_vars/dev/vault.yml"
    echo "  - group_vars/prod/vault.yml"
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
    echo
    info "Displaying plain text file (no decryption needed):"
    echo
    cat "$FILE"
    exit 0
fi

# View the encrypted file
info "Viewing encrypted file: $FILE"
echo
echo "═══════════════════════════════════════════════════════════"
echo

ansible-vault view "$FILE" --vault-password-file="$VAULT_PASSWORD_FILE"

echo
echo "═══════════════════════════════════════════════════════════"
echo
success "File displayed (decrypted in-memory only, no plain text file created)"
echo
info "To edit this file:"
echo "  ./scripts/vault-edit.sh $FILE"
