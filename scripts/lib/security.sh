#!/usr/bin/env bash
#
# Server Helper - Security Library Module
# ========================================
# Core security functions for all scripts including cleanup traps,
# permission enforcement, and memory sanitization.
#
# This module should be sourced FIRST by all scripts that handle
# sensitive data (passwords, tokens, vault operations).
#
# Usage:
#   source scripts/lib/security.sh
#   security_register_cleanup  # Call once after sourcing
#
# Security Features:
#   - Automatic cleanup of sensitive variables on exit
#   - Trap handlers for EXIT, SIGINT, SIGTERM
#   - Permission enforcement for vault password files
#   - Secure temp directory creation (prefers RAM disk)
#
# Dependencies:
#   - None (this is a foundational module)
#

# Prevent multiple inclusion
[[ -n "${_SECURITY_LOADED:-}" ]] && return 0
readonly _SECURITY_LOADED=1

# =============================================================================
# CONFIGURATION
# =============================================================================

# Keywords that identify sensitive variables
readonly _SENSITIVE_VAR_PATTERNS='PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL|AUTH|VAULT'

# Default vault password file location
readonly SECURITY_VAULT_PASSWORD_FILE="${SECURITY_VAULT_PASSWORD_FILE:-.vault_password}"

# Required permissions for sensitive files
readonly SECURITY_SENSITIVE_FILE_PERMS="600"

# =============================================================================
# MEMORY SANITIZATION
# =============================================================================

# Clear all sensitive variables from memory
# This function iterates through all environment variables and unsets
# any that match sensitive patterns (PASSWORD, SECRET, TOKEN, KEY, etc.)
#
# Usage: _cleanup_sensitive
# Called automatically by trap on script exit
_cleanup_sensitive() {
    local var
    local vars_cleared=0

    # Find and unset variables matching sensitive patterns
    for var in $(compgen -v 2>/dev/null | grep -iE "$_SENSITIVE_VAR_PATTERNS" || true); do
        # Skip readonly variables (they can't be unset)
        if ! declare -p "$var" 2>/dev/null | grep -q "^declare -r"; then
            unset "$var" 2>/dev/null || true
            ((vars_cleared++)) || true
        fi
    done

    # Also clear common sensitive variable names explicitly
    # (in case they don't match patterns but contain secrets)
    local explicit_vars=(
        "password" "passwd" "pwd"
        "secret" "api_key" "apikey"
        "token" "access_token" "refresh_token"
        "credential" "cred"
        "private_key" "pub_key"
        "vault_pass" "ansible_vault_password"
    )

    for var in "${explicit_vars[@]}"; do
        unset "$var" 2>/dev/null || true
        unset "${var^^}" 2>/dev/null || true  # Also uppercase version
    done

    return 0
}

# =============================================================================
# TRAP MANAGEMENT
# =============================================================================

# Track if cleanup trap is registered
_SECURITY_TRAP_REGISTERED=""

# Register the cleanup trap for sensitive variable sanitization
# Call this once after sourcing the security library
#
# Usage: security_register_cleanup
security_register_cleanup() {
    if [[ -n "$_SECURITY_TRAP_REGISTERED" ]]; then
        return 0  # Already registered
    fi

    trap '_cleanup_sensitive' EXIT SIGINT SIGTERM
    _SECURITY_TRAP_REGISTERED=1
}

# Unregister the cleanup trap (rarely needed)
#
# Usage: security_unregister_cleanup
security_unregister_cleanup() {
    trap - EXIT SIGINT SIGTERM
    _SECURITY_TRAP_REGISTERED=""
}

# =============================================================================
# PERMISSION ENFORCEMENT
# =============================================================================

# Check and enforce correct permissions on vault password file
# Automatically fixes permissions if they are incorrect
#
# Args: $1 = password file path (optional, defaults to .vault_password)
# Returns: 0 on success, 1 on failure
#
# Usage: security_check_vault_permissions [file_path]
security_check_vault_permissions() {
    local password_file="${1:-$SECURITY_VAULT_PASSWORD_FILE}"

    # Check if file exists
    if [[ ! -f "$password_file" ]]; then
        # File doesn't exist - not an error, caller handles this
        return 0
    fi

    # Get current permissions (cross-platform)
    local perms
    if perms=$(stat -c "%a" "$password_file" 2>/dev/null); then
        : # Linux stat worked
    elif perms=$(stat -f "%Lp" "$password_file" 2>/dev/null); then
        : # macOS stat worked
    else
        # Cannot determine permissions
        echo "WARNING: Cannot check permissions on $password_file" >&2
        return 1
    fi

    # Check if permissions are correct
    if [[ "$perms" != "$SECURITY_SENSITIVE_FILE_PERMS" ]]; then
        # Attempt to fix permissions
        if chmod "$SECURITY_SENSITIVE_FILE_PERMS" "$password_file" 2>/dev/null; then
            # Silently fixed - this is expected behavior
            return 0
        else
            echo "ERROR: Cannot fix permissions on $password_file (current: $perms, required: $SECURITY_SENSITIVE_FILE_PERMS)" >&2
            return 1
        fi
    fi

    return 0
}

# Check permissions on any sensitive file
#
# Args: $1 = file path, $2 = required permissions (default: 600)
# Returns: 0 if correct/fixed, 1 on failure
#
# Usage: security_enforce_permissions /path/to/file [perms]
security_enforce_permissions() {
    local file_path="$1"
    local required_perms="${2:-$SECURITY_SENSITIVE_FILE_PERMS}"

    if [[ ! -f "$file_path" ]]; then
        return 0  # File doesn't exist, not an error
    fi

    local perms
    if perms=$(stat -c "%a" "$file_path" 2>/dev/null); then
        : # Linux
    elif perms=$(stat -f "%Lp" "$file_path" 2>/dev/null); then
        : # macOS
    else
        return 1
    fi

    if [[ "$perms" != "$required_perms" ]]; then
        chmod "$required_perms" "$file_path" 2>/dev/null || return 1
    fi

    return 0
}

# =============================================================================
# SECURE TEMP DIRECTORY
# =============================================================================

# Get a secure temporary directory (prefers RAM-based filesystems)
# The directory is created with mode 700 (owner-only access)
#
# Returns: Path to secure temp directory (printed to stdout)
#
# Usage: secure_temp=$(security_get_temp_dir)
security_get_temp_dir() {
    local temp_dir
    local pid_suffix="$$"

    # Try RAM-based filesystems first (more secure - not written to disk)
    if [[ -d "/dev/shm" ]] && [[ -w "/dev/shm" ]]; then
        temp_dir="/dev/shm/server-helper-${pid_suffix}"
    elif [[ -d "/run/user/$(id -u)" ]] && [[ -w "/run/user/$(id -u)" ]]; then
        temp_dir="/run/user/$(id -u)/server-helper-${pid_suffix}"
    else
        # Fall back to /tmp (still better than current directory)
        temp_dir="/tmp/server-helper-${pid_suffix}"
    fi

    # Create directory with secure permissions
    mkdir -p "$temp_dir" 2>/dev/null
    chmod 700 "$temp_dir" 2>/dev/null

    echo "$temp_dir"
}

# Clean up a secure temp directory
#
# Args: $1 = temp directory path
#
# Usage: security_cleanup_temp_dir "$secure_temp"
security_cleanup_temp_dir() {
    local temp_dir="$1"

    if [[ -n "$temp_dir" ]] && [[ -d "$temp_dir" ]]; then
        # Securely remove contents first
        rm -rf "${temp_dir:?}"/* 2>/dev/null || true
        rmdir "$temp_dir" 2>/dev/null || rm -rf "$temp_dir" 2>/dev/null || true
    fi
}

# =============================================================================
# DEPENDENCY CHECKING
# =============================================================================

# Check if required commands are available
#
# Args: command names to check
# Returns: 0 if all present, 1 if any missing
#
# Usage: security_check_commands ansible-vault ssh || exit 1
security_check_commands() {
    local cmd
    local missing=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Required commands not found: ${missing[*]}" >&2
        return 1
    fi

    return 0
}

# =============================================================================
# LIBRARY SOURCING HELPERS
# =============================================================================

# Source a library module with strict error handling
# Exits with error if library cannot be loaded
#
# Args: $1 = library path
#
# Usage: security_source_library "$LIB_DIR/ui_utils.sh"
security_source_library() {
    local lib_path="$1"
    local lib_name
    lib_name=$(basename "$lib_path")

    if [[ ! -f "$lib_path" ]]; then
        echo "FATAL: Required library not found: $lib_path" >&2
        exit 1
    fi

    # shellcheck source=/dev/null
    if ! source "$lib_path"; then
        echo "FATAL: Failed to source library: $lib_path" >&2
        exit 1
    fi
}

# =============================================================================
# GITIGNORE VERIFICATION
# =============================================================================

# Check if sensitive files are properly listed in .gitignore
#
# Args: $1 = project root directory
# Returns: 0 if all sensitive patterns present, 1 if any missing
#
# Usage: security_check_gitignore "/path/to/project"
security_check_gitignore() {
    local project_root="${1:-.}"
    local gitignore_file="${project_root}/.gitignore"
    local missing=()

    # Patterns that should be in .gitignore
    local required_patterns=(
        ".vault_password"
        "*.log"
        "setup.log"
    )

    if [[ ! -f "$gitignore_file" ]]; then
        echo "WARNING: No .gitignore found at $gitignore_file" >&2
        return 1
    fi

    for pattern in "${required_patterns[@]}"; do
        if ! grep -qF "$pattern" "$gitignore_file" 2>/dev/null; then
            missing+=("$pattern")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "WARNING: Missing from .gitignore: ${missing[*]}" >&2
        return 1
    fi

    return 0
}
