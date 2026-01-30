#!/usr/bin/env bash
#
# Server Helper - Testing Library
# =================================
# Provides Molecule testing functions for Ansible roles.
#
# Usage:
#   source scripts/lib/testing.sh
#
# Dependencies:
#   - scripts/lib/ui_utils.sh (required)
#   - molecule (not in apt, use pipx for PEP 668 compliance)
#     Install: pipx install molecule && pipx inject molecule molecule-plugins[docker]
#   - Docker daemon running
#

# Prevent multiple sourcing
[[ -n "${_TESTING_LOADED:-}" ]] && return 0
readonly _TESTING_LOADED=1

# Require ui_utils
if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
    echo "ERROR: testing.sh requires ui_utils.sh to be sourced first" >&2
    return 1
fi

# =============================================================================
# Configuration
# =============================================================================

# Get project directory (caller should set SCRIPT_DIR)
_TESTING_PROJECT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
_TESTING_ROLES_DIR="${_TESTING_PROJECT_DIR}/roles"
_TESTING_LOG_DIR="${_TESTING_PROJECT_DIR}/logs/molecule"
_TESTING_CACHE_FILE="${_TESTING_PROJECT_DIR}/.molecule-results"

# Track test results
declare -a _TESTING_PASSED=()
declare -a _TESTING_FAILED=()
declare -a _TESTING_SKIPPED=()
declare -a _TESTING_CACHED=()

# =============================================================================
# Logging Functions
# =============================================================================

# Initialize logging directory and return log file path
# Args: $1 = role name (optional, for combined log use "all")
_testing_init_log() {
    local role="${1:-all}"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")

    # Create log directory
    mkdir -p "${_TESTING_LOG_DIR}"

    # Generate log file path
    local log_file="${_TESTING_LOG_DIR}/${timestamp}_${role}.log"

    # Initialize log file with header
    {
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Server Helper - Molecule Test Log"
        echo "  Role: ${role}"
        echo "  Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "  Working Directory: ${_TESTING_PROJECT_DIR}"
        echo "═══════════════════════════════════════════════════════════════"
        echo
    } > "$log_file"

    echo "$log_file"
}

# Append to log file
# Args: $1 = log file, $2 = message
_testing_log() {
    local log_file="$1"
    local message="$2"
    echo "$message" >> "$log_file"
}

# Append summary to log file
# Args: $1 = log file
_testing_log_summary() {
    local log_file="$1"
    {
        echo
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Test Summary"
        echo "  Completed: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "═══════════════════════════════════════════════════════════════"
        echo "  Total:   $(( ${#_TESTING_PASSED[@]} + ${#_TESTING_FAILED[@]} + ${#_TESTING_SKIPPED[@]} + ${#_TESTING_CACHED[@]} ))"
        echo "  Passed:  ${#_TESTING_PASSED[@]}"
        echo "  Failed:  ${#_TESTING_FAILED[@]}"
        echo "  Skipped: ${#_TESTING_SKIPPED[@]}"
        echo "  Cached:  ${#_TESTING_CACHED[@]}"
        echo
        if [[ ${#_TESTING_PASSED[@]} -gt 0 ]]; then
            echo "Passed roles:"
            for role in "${_TESTING_PASSED[@]}"; do
                echo "  - $role"
            done
        fi
        if [[ ${#_TESTING_FAILED[@]} -gt 0 ]]; then
            echo "Failed roles:"
            for role in "${_TESTING_FAILED[@]}"; do
                echo "  - $role"
            done
        fi
    } >> "$log_file"
}

# =============================================================================
# Test Result Cache
# =============================================================================

# Cache file format: one line per role, "role_name=PASSED|FAILED timestamp"

# Check if a role has a cached PASSED result
# Args: $1 = role name
# Returns: 0 if cached pass exists, 1 otherwise
_testing_cache_is_passed() {
    local role="$1"
    [[ -f "$_TESTING_CACHE_FILE" ]] || return 1
    grep -q "^${role}=PASSED " "$_TESTING_CACHE_FILE" 2>/dev/null
}

# Save a test result to the cache
# Args: $1 = role name, $2 = PASSED|FAILED
_testing_cache_save() {
    local role="$1"
    local result="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Remove old entry for this role if it exists
    if [[ -f "$_TESTING_CACHE_FILE" ]]; then
        local tmp="${_TESTING_CACHE_FILE}.tmp"
        grep -v "^${role}=" "$_TESTING_CACHE_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$_TESTING_CACHE_FILE"
    fi

    # Append new result
    echo "${role}=${result} ${timestamp}" >> "$_TESTING_CACHE_FILE"
}

# Clear the entire test result cache
_testing_cache_clear() {
    rm -f "$_TESTING_CACHE_FILE"
    print_success "Test result cache cleared"
}

# Show cached results
_testing_cache_show() {
    if [[ ! -f "$_TESTING_CACHE_FILE" ]] || [[ ! -s "$_TESTING_CACHE_FILE" ]]; then
        print_info "No cached test results"
        return 0
    fi

    print_section "Cached Test Results"
    while IFS='=' read -r role rest; do
        [[ -z "$role" ]] && continue
        local result="${rest%% *}"
        local timestamp="${rest#* }"
        if [[ "$result" == "PASSED" ]]; then
            echo -e "  ${GREEN}PASSED${NC}  $role  ${DIM}($timestamp)${NC}"
        else
            echo -e "  ${RED}FAILED${NC}  $role  ${DIM}($timestamp)${NC}"
        fi
    done < "$_TESTING_CACHE_FILE"
    echo
}

# =============================================================================
# Dependency Checks & Auto-Install
# =============================================================================

# Auto-install testing dependencies if missing
testing_install_dependencies() {
    local needs_install=0

    # Check for pipx
    if ! command -v pipx &>/dev/null; then
        print_info "Installing pipx..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq pipx
        pipx ensurepath
        export PATH="$HOME/.local/bin:$PATH"
        needs_install=1
    fi

    # Check for molecule
    if ! command -v molecule &>/dev/null; then
        print_info "Installing molecule via pipx (PEP 668 compliant)..."
        pipx install molecule || pipx upgrade molecule
        pipx inject molecule molecule-plugins[docker] pytest-testinfra ansible
        needs_install=1
    fi

    # Install collections to ~/.ansible/collections (molecule's first search path)
    # This MUST be done before running molecule as it checks collections before installing
    local collections_dir="$HOME/.ansible/collections"
    mkdir -p "$collections_dir"

    # Use molecule's ansible-galaxy to ensure compatibility
    local molecule_venv="$HOME/.local/share/pipx/venvs/molecule"
    local galaxy_bin="ansible-galaxy"
    if [[ -x "$molecule_venv/bin/ansible-galaxy" ]]; then
        galaxy_bin="$molecule_venv/bin/ansible-galaxy"
    fi

    if ! "$galaxy_bin" collection list 2>/dev/null | grep -q "ansible.posix"; then
        print_info "Installing Ansible collections to ~/.ansible/collections..."
        "$galaxy_bin" collection install ansible.posix community.general community.docker \
            -p "$collections_dir" --force
        needs_install=1
    fi

    if [[ $needs_install -eq 1 ]]; then
        print_success "Dependencies installed successfully!"
    fi

    return 0
}

# Check if all testing dependencies are available (with auto-install)
testing_check_dependencies() {
    local missing=0

    # Auto-install if molecule is missing
    if ! command -v molecule &>/dev/null; then
        print_info "Molecule not found, installing dependencies..."
        testing_install_dependencies
    fi

    # Final check for molecule
    if ! command -v molecule &>/dev/null; then
        print_error "Molecule installation failed"
        echo "Try manually: pipx install molecule && pipx inject molecule molecule-plugins[docker]"
        ((missing++))
    fi

    # Check for Docker
    if ! command -v docker &>/dev/null; then
        print_error "Docker is not installed"
        ((missing++))
    elif ! docker info &>/dev/null 2>&1; then
        if groups | grep -q docker; then
            print_error "Docker daemon is not running"
        else
            print_error "User not in docker group. Run: sudo usermod -aG docker \$USER && newgrp docker"
        fi
        ((missing++))
    fi

    # Always check for Ansible collections (even if molecule was already installed)
    # Molecule checks collections BEFORE its dependency install phase runs
    local molecule_venv="$HOME/.local/share/pipx/venvs/molecule"
    local galaxy_bin="ansible-galaxy"
    if [[ -x "$molecule_venv/bin/ansible-galaxy" ]]; then
        galaxy_bin="$molecule_venv/bin/ansible-galaxy"
    fi

    if ! "$galaxy_bin" collection list 2>/dev/null | grep -q "ansible.posix"; then
        print_info "Ansible collections not found, installing..."
        local collections_dir="$HOME/.ansible/collections"
        mkdir -p "$collections_dir"
        if "$galaxy_bin" collection install ansible.posix community.general community.docker \
            -p "$collections_dir" --force; then
            print_success "Ansible collections installed"
        else
            print_error "Failed to install Ansible collections"
            ((missing++))
        fi
    fi

    if [[ $missing -gt 0 ]]; then
        return 1
    fi

    print_success "All testing dependencies satisfied"
    return 0
}

# =============================================================================
# Role Discovery
# =============================================================================

# Find all roles with Molecule tests
# Returns array of role names
testing_find_testable_roles() {
    local roles_dir="${1:-$_TESTING_ROLES_DIR}"
    local -a roles=()

    for role_dir in "$roles_dir"/*/; do
        local role
        role=$(basename "$role_dir")
        if [[ -d "${role_dir}molecule/default" ]]; then
            roles+=("$role")
        fi
    done

    echo "${roles[@]}"
}

# List all roles with their test status
testing_list_roles() {
    local roles_dir="${1:-$_TESTING_ROLES_DIR}"

    print_section "Available Roles"

    local has_tests=0
    local no_tests=0

    for role_dir in "$roles_dir"/*/; do
        local role
        role=$(basename "$role_dir")

        if [[ -d "${role_dir}molecule/default" ]]; then
            echo -e "  ${GREEN}*${NC} $role (has tests)"
            ((has_tests++))
        else
            echo -e "  ${DIM}-${NC} $role"
            ((no_tests++))
        fi
    done

    echo
    echo "  Testable: $has_tests"
    echo "  Without tests: $no_tests"
}

# =============================================================================
# Single Role Testing
# =============================================================================

# Run molecule test for a single role
# Args: $1 = role name, $2 = molecule command (default: test), $3 = log file (optional)
testing_run_role() {
    local role="$1"
    local molecule_cmd="${2:-test}"
    local external_log="${3:-}"
    local roles_dir="${_TESTING_ROLES_DIR}"
    local role_dir="${roles_dir}/${role}"

    if [[ -z "$role" ]]; then
        print_error "No role specified"
        return 1
    fi

    if [[ ! -d "$role_dir" ]]; then
        print_error "Role not found: $role"
        return 1
    fi

    if [[ ! -d "${role_dir}/molecule/default" ]]; then
        print_error "Role '$role' does not have Molecule tests"
        echo "To add tests, create: roles/${role}/molecule/default/molecule.yml"
        return 1
    fi

    # Validate molecule command
    case "$molecule_cmd" in
        test|converge|verify|destroy|lint|create|prepare|cleanup|side-effect|idempotence)
            ;;
        *)
            print_error "Invalid molecule command: $molecule_cmd"
            echo "Valid commands: test, converge, verify, destroy, lint, create, prepare, cleanup"
            return 1
            ;;
    esac

    # Initialize log file (use external log if provided, otherwise create one)
    local log_file
    if [[ -n "$external_log" ]]; then
        log_file="$external_log"
    else
        log_file=$(_testing_init_log "$role")
    fi

    print_section "Testing role: $role"
    print_info "Command: molecule $molecule_cmd"
    print_info "Log file: $log_file"
    echo

    local original_dir
    original_dir=$(pwd)
    cd "$role_dir" || return 1

    # Log the start of this role's test
    {
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Testing role: $role"
        echo "Command: molecule $molecule_cmd"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    } >> "$log_file"

    local exit_code=0
    # Run molecule and tee output to both console and log file
    if molecule "$molecule_cmd" 2>&1 | tee -a "$log_file"; then
        print_success "PASSED: $role"
        echo "RESULT: PASSED" >> "$log_file"
        _TESTING_PASSED+=("$role")
        # Cache result for full test runs
        if [[ "$molecule_cmd" == "test" ]]; then
            _testing_cache_save "$role" "PASSED"
        fi
    else
        print_error "FAILED: $role"
        echo "RESULT: FAILED" >> "$log_file"
        _TESTING_FAILED+=("$role")
        exit_code=1
        # Cache failure so it re-runs next time
        if [[ "$molecule_cmd" == "test" ]]; then
            _testing_cache_save "$role" "FAILED"
        fi
    fi

    cd "$original_dir" || return 1

    # If this was a standalone test (not part of test-all), add summary
    if [[ -z "$external_log" ]]; then
        _testing_log_summary "$log_file"
        echo
        print_info "Full log saved to: $log_file"
    fi

    return $exit_code
}

# Interactive single role test
testing_test_single_interactive() {
    local roles_dir="${_TESTING_ROLES_DIR}"

    print_section "Test Single Role"

    if ! testing_check_dependencies; then
        return 1
    fi

    # Get testable roles
    local -a roles
    read -ra roles <<< "$(testing_find_testable_roles)"

    if [[ ${#roles[@]} -eq 0 ]]; then
        print_warning "No roles with Molecule tests found"
        echo "To add tests, create: roles/<role>/molecule/default/molecule.yml"
        return 1
    fi

    echo "Available roles with tests:"
    for i in "${!roles[@]}"; do
        echo "  $((i+1))) ${roles[$i]}"
    done
    echo

    local role_num
    role_num=$(prompt_input "Select role number")

    if [[ ! "$role_num" =~ ^[0-9]+$ ]] || [[ "$role_num" -lt 1 ]] || [[ "$role_num" -gt ${#roles[@]} ]]; then
        print_error "Invalid selection"
        return 1
    fi

    local role="${roles[$((role_num-1))]}"

    echo
    echo "Molecule commands:"
    echo "  1) test       - Full test cycle (create, converge, verify, destroy)"
    echo "  2) converge   - Create and converge only"
    echo "  3) verify     - Run verifiers only"
    echo "  4) destroy    - Destroy instances"
    echo "  5) lint       - Run linters"
    echo

    local cmd_num
    cmd_num=$(prompt_input "Select command" "1")

    local molecule_cmd
    case "$cmd_num" in
        1) molecule_cmd="test" ;;
        2) molecule_cmd="converge" ;;
        3) molecule_cmd="verify" ;;
        4) molecule_cmd="destroy" ;;
        5) molecule_cmd="lint" ;;
        *) molecule_cmd="test" ;;
    esac

    testing_run_role "$role" "$molecule_cmd"
}

# =============================================================================
# All Roles Testing
# =============================================================================

# Reset test tracking
testing_reset_results() {
    _TESTING_PASSED=()
    _TESTING_FAILED=()
    _TESTING_SKIPPED=()
    _TESTING_CACHED=()
}

# Run molecule tests for all roles
# Args: $1 = "force" to ignore cache and re-run all tests
testing_run_all() {
    local force="${1:-}"
    local roles_dir="${_TESTING_ROLES_DIR}"
    local use_cache=0

    print_header "Test All Roles"

    if ! testing_check_dependencies; then
        return 1
    fi

    testing_reset_results

    # Find testable roles
    print_info "Finding roles with Molecule tests..."
    print_info "Roles directory: ${_TESTING_ROLES_DIR}"
    local -a roles
    local roles_output
    roles_output="$(testing_find_testable_roles)"
    if [[ -z "$roles_output" ]]; then
        print_warning "No roles with Molecule tests found"
        echo "To add tests, create: roles/<role>/molecule/default/molecule.yml"
        return 0
    fi
    read -ra roles <<< "$roles_output"

    # Check if we have cached results and offer to skip passed tests
    if [[ "$force" != "force" ]] && [[ -f "$_TESTING_CACHE_FILE" ]]; then
        local cached_pass=0
        for role in "${roles[@]}"; do
            if _testing_cache_is_passed "$role"; then
                ((cached_pass++)) || true
            fi
        done

        if [[ $cached_pass -gt 0 ]]; then
            echo
            print_info "${cached_pass} of ${#roles[@]} role(s) previously passed:"
            for role in "${roles[@]}"; do
                if _testing_cache_is_passed "$role"; then
                    echo -e "  ${GREEN}PASSED${NC}  $role"
                else
                    echo -e "  ${YELLOW}PENDING${NC} $role"
                fi
            done
            echo
            echo "  1) Skip passed tests (run only failed/untested)"
            echo "  2) Re-run all tests (ignore cache)"
            echo "  3) Clear cache and re-run all"
            echo
            local cache_choice
            cache_choice=$(prompt_input "Choose an option" "1")
            case "$cache_choice" in
                1) use_cache=1 ;;
                2) use_cache=0 ;;
                3) _testing_cache_clear; use_cache=0 ;;
                *) use_cache=1 ;;
            esac
        fi
    fi

    # Initialize combined log file
    local log_file
    log_file=$(_testing_init_log "all")
    print_info "Log file: $log_file"
    echo

    print_success "Found ${#roles[@]} testable role(s):"
    for role in "${roles[@]}"; do
        if [[ $use_cache -eq 1 ]] && _testing_cache_is_passed "$role"; then
            echo -e "  ${DIM}- $role (cached pass, skipping)${NC}"
        else
            echo "  - $role"
        fi
    done
    echo

    # Log the roles to test
    {
        echo "Roles to test:"
        for role in "${roles[@]}"; do
            echo "  - $role"
        done
        echo
    } >> "$log_file"

    # Run tests
    local exit_code=0
    local original_dir
    original_dir=$(pwd)

    for role in "${roles[@]}"; do
        # Skip cached passes if user chose to
        if [[ $use_cache -eq 1 ]] && _testing_cache_is_passed "$role"; then
            echo
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${DIM}Skipping role: ${role} (previously passed)${NC}"
            echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            _TESTING_CACHED+=("$role")
            echo "CACHED SKIP: $role (previously passed)" >> "$log_file"
            continue
        fi

        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Testing role: ${role}${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo

        # Use testing_run_role with the shared log file
        if ! testing_run_role "$role" "test" "$log_file"; then
            exit_code=1
        fi
    done

    cd "$original_dir" || true

    # Write summary to log
    _testing_log_summary "$log_file"

    # Print summary to console
    testing_print_summary

    echo
    print_info "Full log saved to: $log_file"

    return $exit_code
}

# Print test summary
testing_print_summary() {
    local total=$(( ${#_TESTING_PASSED[@]} + ${#_TESTING_FAILED[@]} + ${#_TESTING_SKIPPED[@]} + ${#_TESTING_CACHED[@]} ))

    echo
    print_section "Test Summary"
    echo "  Total Roles:  $total"
    echo -e "  ${GREEN}Passed:${NC}       ${#_TESTING_PASSED[@]}"
    echo -e "  ${RED}Failed:${NC}       ${#_TESTING_FAILED[@]}"
    echo -e "  ${YELLOW}Skipped:${NC}      ${#_TESTING_SKIPPED[@]}"
    if [[ ${#_TESTING_CACHED[@]} -gt 0 ]]; then
        echo -e "  ${CYAN}Cached:${NC}       ${#_TESTING_CACHED[@]} (previously passed, not re-run)"
    fi
    echo

    if [[ ${#_TESTING_PASSED[@]} -gt 0 ]]; then
        echo -e "${GREEN}Passed roles:${NC}"
        for role in "${_TESTING_PASSED[@]}"; do
            echo "  - $role"
        done
        echo
    fi

    if [[ ${#_TESTING_CACHED[@]} -gt 0 ]]; then
        echo -e "${CYAN}Cached roles (skipped):${NC}"
        for role in "${_TESTING_CACHED[@]}"; do
            echo -e "  ${DIM}- $role${NC}"
        done
        echo
    fi

    if [[ ${#_TESTING_FAILED[@]} -gt 0 ]]; then
        echo -e "${RED}Failed roles:${NC}"
        for role in "${_TESTING_FAILED[@]}"; do
            echo "  - $role"
        done
        echo
    fi

    if [[ ${#_TESTING_FAILED[@]} -eq 0 ]]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed."
        return 1
    fi
}

# =============================================================================
# Menu Integration
# =============================================================================

# Show testing menu
testing_show_menu() {
    while true; do
        clear
        print_header "Ansible Role Testing"
        echo

        echo "  1) Test All Roles       - Run Molecule tests for all roles"
        echo "  2) Test All (force)     - Re-run all tests, ignore cache"
        echo "  3) Test Single Role     - Run Molecule test for one role"
        echo "  4) List Testable Roles  - Show roles with Molecule tests"
        echo "  5) View Cached Results  - Show previously passed/failed tests"
        echo "  6) Clear Test Cache     - Reset cached results"
        echo "  7) Check Dependencies   - Verify testing tools installed"
        echo "  8) Back"
        echo

        local choice
        choice=$(prompt_input "Choose an option [1-8]")

        case "$choice" in
            1)
                testing_run_all
                read -rp "Press Enter to continue..."
                ;;
            2)
                testing_run_all "force"
                read -rp "Press Enter to continue..."
                ;;
            3)
                testing_test_single_interactive
                read -rp "Press Enter to continue..."
                ;;
            4)
                testing_list_roles
                read -rp "Press Enter to continue..."
                ;;
            5)
                _testing_cache_show
                read -rp "Press Enter to continue..."
                ;;
            6)
                _testing_cache_clear
                read -rp "Press Enter to continue..."
                ;;
            7)
                testing_check_dependencies
                read -rp "Press Enter to continue..."
                ;;
            8)
                return 0
                ;;
            *)
                print_warning "Invalid option"
                read -rp "Press Enter to continue..."
                ;;
        esac
    done
}

# =============================================================================
# CLI Interface (when run directly)
# =============================================================================

_testing_cli_usage() {
    echo "Usage: $0 <command> [args]"
    echo
    echo "Commands:"
    echo "  test-all              Run Molecule tests for all roles (skips cached passes)"
    echo "  test-all --force      Re-run all tests, ignore cache"
    echo "  test-role <role>      Run Molecule test for specific role"
    echo "  list                  List all testable roles"
    echo "  cache-show            Show cached test results"
    echo "  cache-clear           Clear cached test results"
    echo "  install-deps          Install test dependencies"
    echo "  help                  Show this help"
    echo
    echo "Examples:"
    echo "  $0 test-all"
    echo "  $0 test-all --force"
    echo "  $0 test-role common"
    echo "  $0 test-role common converge"
    echo
}

_testing_cli_main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        test-all|all)
            local force_flag="${1:-}"
            if [[ "$force_flag" == "--force" || "$force_flag" == "-f" ]]; then
                testing_run_all "force"
            else
                testing_run_all
            fi
            ;;
        cache-show|cache)
            _testing_cache_show
            ;;
        cache-clear)
            _testing_cache_clear
            ;;
        test-role|role|test)
            local role="${1:-}"
            local molecule_cmd="${2:-test}"
            if [[ -z "$role" ]]; then
                echo "Error: No role specified"
                echo "Usage: $0 test-role <role-name> [molecule-command]"
                echo
                echo "Available roles:"
                testing_list_roles
                exit 1
            fi
            testing_check_dependencies || exit 1
            testing_run_role "$role" "$molecule_cmd"
            ;;
        list)
            testing_list_roles
            ;;
        install-deps|deps)
            testing_install_dependencies
            ;;
        help|--help|-h)
            _testing_cli_usage
            ;;
        "")
            _testing_cli_usage
            exit 1
            ;;
        *)
            echo "Error: Unknown command: $cmd"
            _testing_cli_usage
            exit 1
            ;;
    esac
}

# Run CLI if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Minimal fallbacks if ui_utils not available
    if [[ -z "${_UI_UTILS_LOADED:-}" ]]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        BOLD='\033[1m'
        NC='\033[0m'
        print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
        print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
        print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
        print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
        print_header() { echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"; }
        print_section() { echo -e "${BOLD}$1${NC}"; }
    fi
    _testing_cli_main "$@"
fi
