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

# Track test results
declare -a _TESTING_PASSED=()
declare -a _TESTING_FAILED=()
declare -a _TESTING_SKIPPED=()

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
# Args: $1 = role name, $2 = molecule command (default: test)
testing_run_role() {
    local role="$1"
    local molecule_cmd="${2:-test}"
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

    print_section "Testing role: $role"
    print_info "Command: molecule $molecule_cmd"
    echo

    local original_dir
    original_dir=$(pwd)
    cd "$role_dir" || return 1

    local exit_code=0
    if molecule "$molecule_cmd"; then
        print_success "PASSED: $role"
        _TESTING_PASSED+=("$role")
    else
        print_error "FAILED: $role"
        _TESTING_FAILED+=("$role")
        exit_code=1
    fi

    cd "$original_dir" || return 1
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
}

# Run molecule tests for all roles
testing_run_all() {
    local roles_dir="${_TESTING_ROLES_DIR}"

    print_header "Test All Roles"

    if ! testing_check_dependencies; then
        return 1
    fi

    testing_reset_results

    # Find testable roles
    print_info "Finding roles with Molecule tests..."
    local -a roles
    read -ra roles <<< "$(testing_find_testable_roles)"

    if [[ ${#roles[@]} -eq 0 ]]; then
        print_warning "No roles with Molecule tests found"
        echo "To add tests, create: roles/<role>/molecule/default/molecule.yml"
        return 0
    fi

    print_success "Found ${#roles[@]} testable role(s):"
    for role in "${roles[@]}"; do
        echo "  - $role"
    done
    echo

    # Run tests
    local exit_code=0
    local original_dir
    original_dir=$(pwd)

    for role in "${roles[@]}"; do
        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Testing role: ${role}${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo

        cd "${roles_dir}/${role}" || continue

        if molecule test; then
            print_success "PASSED: ${role}"
            _TESTING_PASSED+=("$role")
        else
            print_error "FAILED: ${role}"
            _TESTING_FAILED+=("$role")
            exit_code=1
        fi
    done

    cd "$original_dir" || true

    # Print summary
    testing_print_summary

    return $exit_code
}

# Print test summary
testing_print_summary() {
    local total=$(( ${#_TESTING_PASSED[@]} + ${#_TESTING_FAILED[@]} + ${#_TESTING_SKIPPED[@]} ))

    echo
    print_section "Test Summary"
    echo "  Total Roles:  $total"
    echo -e "  ${GREEN}Passed:${NC}       ${#_TESTING_PASSED[@]}"
    echo -e "  ${RED}Failed:${NC}       ${#_TESTING_FAILED[@]}"
    echo -e "  ${YELLOW}Skipped:${NC}      ${#_TESTING_SKIPPED[@]}"
    echo

    if [[ ${#_TESTING_PASSED[@]} -gt 0 ]]; then
        echo -e "${GREEN}Passed roles:${NC}"
        for role in "${_TESTING_PASSED[@]}"; do
            echo "  - $role"
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
        echo "  2) Test Single Role     - Run Molecule test for one role"
        echo "  3) List Testable Roles  - Show roles with Molecule tests"
        echo "  4) Check Dependencies   - Verify testing tools installed"
        echo "  5) Back"
        echo

        local choice
        choice=$(prompt_input "Choose an option [1-5]")

        case "$choice" in
            1)
                testing_run_all
                read -p "Press Enter to continue..."
                ;;
            2)
                testing_test_single_interactive
                read -p "Press Enter to continue..."
                ;;
            3)
                testing_list_roles
                read -p "Press Enter to continue..."
                ;;
            4)
                testing_check_dependencies
                read -p "Press Enter to continue..."
                ;;
            5)
                return 0
                ;;
            *)
                print_warning "Invalid option"
                read -p "Press Enter to continue..."
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
    echo "  test-all              Run Molecule tests for all roles"
    echo "  test-role <role>      Run Molecule test for specific role"
    echo "  list                  List all testable roles"
    echo "  install-deps          Install test dependencies"
    echo "  help                  Show this help"
    echo
    echo "Examples:"
    echo "  $0 test-all"
    echo "  $0 test-role common"
    echo "  $0 test-role common converge"
    echo
}

_testing_cli_main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        test-all|all)
            testing_run_all
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
