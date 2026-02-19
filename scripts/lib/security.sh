#!/usr/bin/env bash
# =============================================================================
# security.sh — MUST BE SOURCED FIRST
# =============================================================================
# Registers EXIT/SIGINT/SIGTERM cleanup trap that unsets sensitive environment
# variables. Provides secure temp directory selection (RAM disk preferred) and
# vault password file permission enforcement.
# =============================================================================

# =============================================================================
# CLEANUP TRAP — unset sensitive variables on exit
# =============================================================================
_security_cleanup() {
    # Unset all sensitive environment variables
    local sensitive_vars=(
        ANSIBLE_VAULT_PASSWORD
        RESTIC_PASSWORD
        RESTIC_REPOSITORY
        AWS_ACCESS_KEY_ID
        AWS_SECRET_ACCESS_KEY
        SMTP_PASSWORD
        DISCORD_WEBHOOK
        SLACK_WEBHOOK
    )
    for var in "${sensitive_vars[@]}"; do
        unset "$var" 2>/dev/null || true
    done

    # Remove secure temp files if they exist
    if [[ -n "${SECURE_TMPDIR:-}" && -d "${SECURE_TMPDIR}" ]]; then
        rm -rf "${SECURE_TMPDIR}"
    fi
}

trap _security_cleanup EXIT SIGINT SIGTERM

# =============================================================================
# SECURE TEMP DIRECTORY — prefer RAM disk
# =============================================================================
get_secure_tmpdir() {
    local tmpdir

    if [[ -d /dev/shm && -w /dev/shm ]]; then
        # RAM disk available (most Linux systems)
        tmpdir=$(mktemp -d /dev/shm/server-helper.XXXXXX)
    elif [[ -d /run/user/$(id -u) ]]; then
        # Per-user runtime dir (systemd)
        tmpdir=$(mktemp -d "/run/user/$(id -u)/server-helper.XXXXXX")
    else
        # Fallback to /tmp
        tmpdir=$(mktemp -d /tmp/server-helper.XXXXXX)
    fi

    chmod 700 "$tmpdir"
    SECURE_TMPDIR="$tmpdir"
    echo "$tmpdir"
}

# =============================================================================
# VAULT PASSWORD FILE — enforce permissions
# =============================================================================
enforce_vault_permissions() {
    local vault_password_file="$PROJECT_ROOT/.vault_password"

    if [[ -f "$vault_password_file" ]]; then
        local perms
        perms=$(stat -c '%a' "$vault_password_file" 2>/dev/null || stat -f '%Lp' "$vault_password_file" 2>/dev/null)
        if [[ "$perms" != "600" ]]; then
            echo "WARNING: Fixing vault password file permissions (was $perms, should be 600)"
            chmod 600 "$vault_password_file"
        fi
    fi
}

# =============================================================================
# SENSITIVE PATTERN DETECTION
# =============================================================================
SENSITIVE_PATTERNS="password|token|vault|secret|key|credential|api_key"

is_sensitive() {
    local text="$1"
    echo "$text" | grep -qiE "$SENSITIVE_PATTERNS"
}

# Run permission enforcement on source
enforce_vault_permissions
