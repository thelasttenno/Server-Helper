#!/usr/bin/env bash
#
# Server Helper - UI Utilities
# ============================
# Provides terminal colors, headers, and secure logging functions.
#
# Usage:
#   source scripts/lib/ui_utils.sh
#
# Security:
#   - log_exec redacts commands containing sensitive keywords
#   - No secrets are written to log files
#

# Prevent multiple sourcing
[[ -n "${_UI_UTILS_LOADED:-}" ]] && return 0
readonly _UI_UTILS_LOADED=1

# =============================================================================
# Terminal Colors
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# =============================================================================
# Log File Configuration
# =============================================================================
LOG_FILE="${LOG_FILE:-setup.log}"

# =============================================================================
# Print Functions
# =============================================================================

print_header() {
    local title="${1:-Server Helper}"
    echo ""
    echo -e "${BLUE}${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    printf "${BLUE}${BOLD}║${NC}  %-58s${BLUE}${BOLD}║${NC}\n" "$title"
    echo -e "${BLUE}${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    local title="$1"
    echo ""
    echo -e "${CYAN}${BOLD}━━━ ${title} ━━━${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${DIM}[DEBUG]${NC} $1"
    fi
}

print_step() {
    local step="$1"
    local total="$2"
    local message="$3"
    echo -e "${BLUE}[${step}/${total}]${NC} ${message}"
}

# =============================================================================
# Secure Logging Functions
# =============================================================================

# Keywords that trigger command redaction
readonly _SENSITIVE_KEYWORDS="password|token|vault|secret|key|credential|auth"

# Check if a string contains sensitive keywords
_contains_sensitive() {
    local text="$1"
    echo "$text" | grep -qiE "$_SENSITIVE_KEYWORDS"
}

# Log a message to the log file with timestamp
log_message() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Execute a command and log it securely
# SECURITY: Commands containing sensitive keywords are redacted in logs
log_exec() {
    local cmd="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if command contains sensitive keywords
    if _contains_sensitive "$cmd"; then
        # Log redacted version
        echo "[${timestamp}] EXEC: [REDACTED COMMAND]" >> "$LOG_FILE"
        print_debug "Executing: [REDACTED COMMAND]"
    else
        # Log full command
        echo "[${timestamp}] EXEC: ${cmd}" >> "$LOG_FILE"
        print_debug "Executing: ${cmd}"
    fi

    # Execute the command and capture output
    local output
    local exit_code

    if output=$("$@" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    # Log output (also check for sensitive content)
    if [[ -n "$output" ]]; then
        if _contains_sensitive "$output"; then
            echo "[${timestamp}] OUTPUT: [REDACTED OUTPUT]" >> "$LOG_FILE"
        else
            echo "[${timestamp}] OUTPUT: ${output}" >> "$LOG_FILE"
        fi
    fi

    # Log exit code
    echo "[${timestamp}] EXIT_CODE: ${exit_code}" >> "$LOG_FILE"

    # Return the original exit code
    return $exit_code
}

# Execute command silently (no output to terminal, only log)
log_exec_silent() {
    local cmd="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if _contains_sensitive "$cmd"; then
        echo "[${timestamp}] EXEC: [REDACTED COMMAND]" >> "$LOG_FILE"
    else
        echo "[${timestamp}] EXEC: ${cmd}" >> "$LOG_FILE"
    fi

    if "$@" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        return $?
    fi
}

# =============================================================================
# User Input Functions
# =============================================================================

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt} [${default}]: ")" result
        echo "${result:-$default}"
    else
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt}: ")" result
        echo "$result"
    fi
}

prompt_password() {
    local prompt="$1"
    local result

    read -srp "$(echo -e "${BLUE}?${NC} ${prompt}: ")" result
    echo ""  # New line after password input
    echo "$result"
}

prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt} [Y/n]: ")" response
        response="${response:-y}"
    else
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt} [y/N]: ")" response
        response="${response:-n}"
    fi

    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# Progress Indicators
# =============================================================================

spinner() {
    local pid=$1
    local message="${2:-Working...}"
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}[%s]${NC} %s" "${spin_chars:i++%${#spin_chars}:1}" "$message"
        sleep 0.1
    done
    printf "\r"
}

# =============================================================================
# Menu Helpers
# =============================================================================

print_menu_item() {
    local number="$1"
    local label="$2"
    local description="${3:-}"

    if [[ -n "$description" ]]; then
        printf "  ${CYAN}%2s${NC}) %-25s ${DIM}%s${NC}\n" "$number" "$label" "$description"
    else
        printf "  ${CYAN}%2s${NC}) %s\n" "$number" "$label"
    fi
}

print_menu_separator() {
    echo -e "  ${DIM}────────────────────────────────────────${NC}"
}
