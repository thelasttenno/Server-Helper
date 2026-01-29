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
# Session Preferences (reduces form fatigue by remembering values)
# =============================================================================
readonly PREFS_FILE="${SCRIPT_DIR:-.}/.server-helper-prefs"

# Load preferences file into associative array
declare -gA _PREFS
prefs_load() {
    _PREFS=()
    if [[ -f "$PREFS_FILE" ]]; then
        while IFS='=' read -r key value; do
            [[ -z "$key" || "$key" == \#* ]] && continue
            _PREFS["$key"]="$value"
        done < "$PREFS_FILE"
    fi
}

# Save preferences to file
prefs_save() {
    {
        echo "# Server Helper Preferences (auto-generated)"
        echo "# These values are remembered to reduce repeated input"
        for key in "${!_PREFS[@]}"; do
            echo "${key}=${_PREFS[$key]}"
        done
    } > "$PREFS_FILE"
    chmod 600 "$PREFS_FILE" 2>/dev/null
}

# Get a preference value
prefs_get() {
    local key="$1"
    echo "${_PREFS[$key]:-}"
}

# Set a preference value and save
prefs_set() {
    local key="$1"
    local value="$2"
    _PREFS["$key"]="$value"
    prefs_save
}

# Initialize preferences on load
prefs_load

# =============================================================================
# User Input Functions
# =============================================================================

# Standard prompt with static default (dim brackets)
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt} ${DIM}[${default}]${NC}: ")" result
        echo "${result:-$default}"
    else
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt}: ")" result
        echo "$result"
    fi
}

# Smart prompt with auto-fill distinction
# Usage: prompt_input_auto "Prompt" "auto_value" "pref_key" [fallback_default]
#   - auto_value: detected/remembered value (cyan brackets)
#   - pref_key: preference key to check for remembered value
#   - fallback_default: static default if no auto value (dim brackets)
prompt_input_auto() {
    local prompt="$1"
    local auto_value="${2:-}"
    local pref_key="${3:-}"
    local fallback="${4:-}"
    local result

    # Check preferences for remembered value
    local remembered=""
    if [[ -n "$pref_key" ]]; then
        remembered=$(prefs_get "$pref_key")
    fi

    # Determine which value to show and how
    local display_value=""
    local is_auto=false

    if [[ -n "$auto_value" ]]; then
        display_value="$auto_value"
        is_auto=true
    elif [[ -n "$remembered" ]]; then
        display_value="$remembered"
        is_auto=true
    elif [[ -n "$fallback" ]]; then
        display_value="$fallback"
        is_auto=false
    fi

    # Display with appropriate styling
    if [[ -n "$display_value" ]]; then
        if [[ "$is_auto" == true ]]; then
            # Auto-fill: cyan brackets with "auto:" prefix
            read -rp "$(echo -e "${BLUE}?${NC} ${prompt} ${CYAN}[auto: ${display_value}]${NC}: ")" result
        else
            # Static default: dim brackets
            read -rp "$(echo -e "${BLUE}?${NC} ${prompt} ${DIM}[${display_value}]${NC}: ")" result
        fi
        result="${result:-$display_value}"
    else
        read -rp "$(echo -e "${BLUE}?${NC} ${prompt}: ")" result
    fi

    # Save to preferences if key provided and value entered
    if [[ -n "$pref_key" ]] && [[ -n "$result" ]]; then
        prefs_set "$pref_key" "$result"
    fi

    echo "$result"
}

# Prompt that only uses remembered value (no auto-detection)
# Usage: prompt_input_remember "Prompt" "pref_key" [static_default]
prompt_input_remember() {
    local prompt="$1"
    local pref_key="$2"
    local default="${3:-}"

    prompt_input_auto "$prompt" "" "$pref_key" "$default"
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
