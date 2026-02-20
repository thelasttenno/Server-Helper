#!/usr/bin/env bash
# =============================================================================
# ui_utils.sh — Colors, headers, logging, and user interaction
# =============================================================================
# MUST be sourced after security.sh (uses is_sensitive for log redaction)
# =============================================================================

# =============================================================================
# COLORS
# =============================================================================
export RED=$'\033[0;31m'
export GREEN=$'\033[0;32m'
export YELLOW=$'\033[1;33m'
export BLUE=$'\033[0;34m'
export CYAN=$'\033[0;36m'
export MAGENTA=$'\033[0;35m'
export BOLD=$'\033[1m'
export NC=$'\033[0m'  # No Color

# =============================================================================
# OUTPUT HELPERS
# =============================================================================
print_header() {
    local title="$1"
    local width=60
    local border
    border=$(printf '═%.0s' $(seq 1 "$width"))
    echo -e ""
    echo -e "  ${CYAN}╔${border}╗${NC}"
    printf "  ${CYAN}║${NC} ${BOLD}%-$(( width - 2 ))s${NC} ${CYAN}║${NC}\n" "$title"
    echo -e "  ${CYAN}╚${border}╝${NC}"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1" >&2
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

print_step() {
    echo -e "  ${MAGENTA}→${NC} $1"
}

# =============================================================================
# LOG_EXEC — Execute command with redaction of sensitive keywords
# =============================================================================
log_exec() {
    local cmd="$1"
    local display_cmd="$cmd"

    # Redact sensitive parts of the command for display
    if is_sensitive "$cmd"; then
        display_cmd=$(echo "$cmd" | sed -E "s/(password|token|vault|secret|key|credential)[= ]+[^ '\"]*/\1=***REDACTED***/gi")
    fi

    print_step "Running: $display_cmd"
    echo ""

    # Execute the command
    eval "$cmd"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        print_success "Command completed successfully"
    else
        print_error "Command failed with exit code $exit_code"
    fi

    return $exit_code
}

# =============================================================================
# USER PROMPTS
# =============================================================================
confirm() {
    local prompt="${1:-Are you sure?}"
    echo -n "  $prompt [y/N]: "
    local reply
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        echo -n "  $prompt [$default]: " >&2
    else
        echo -n "  $prompt: " >&2
    fi

    read -r result
    echo "${result:-$default}"
}

prompt_secret() {
    local prompt="$1"
    local result
    echo -n "  $prompt: " >&2
    read -rs result
    echo "" >&2
    echo "$result"
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================
check_requirements() {
    local missing=()

    command -v ansible-playbook >/dev/null 2>&1 || missing+=("ansible")
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v python3 >/dev/null 2>&1 || missing+=("python3")

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Missing requirements: ${missing[*]}"
        print_info "Some features may not work without these tools installed."
        echo ""
    fi
}
