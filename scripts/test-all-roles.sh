#!/usr/bin/env bash
#
# Server Helper - Test All Roles
# ===============================
# Runs Molecule tests for all roles with automatic dependency installation.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Server Helper - Molecule Test Runner${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo

# -----------------------------------------------------------------------------
# Auto-install dependencies if missing
# -----------------------------------------------------------------------------
install_dependencies() {
    local needs_install=0

    # Check for pipx
    if ! command -v pipx &>/dev/null; then
        echo -e "${YELLOW}Installing pipx...${NC}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq pipx
        pipx ensurepath
        export PATH="$HOME/.local/bin:$PATH"
        needs_install=1
    fi

    # Check for molecule
    if ! command -v molecule &>/dev/null; then
        echo -e "${YELLOW}Installing molecule via pipx (PEP 668 compliant)...${NC}"
        pipx install molecule || pipx upgrade molecule
        pipx inject molecule molecule-plugins[docker] pytest-testinfra ansible
        needs_install=1
    fi

    # Install collections in molecule's pipx venv (required for isolated environment)
    local molecule_venv="$HOME/.local/share/pipx/venvs/molecule"
    if [[ -d "$molecule_venv" ]]; then
        local galaxy_bin="$molecule_venv/bin/ansible-galaxy"
        if [[ -x "$galaxy_bin" ]]; then
            if ! "$galaxy_bin" collection list 2>/dev/null | grep -q "ansible.posix"; then
                echo -e "${YELLOW}Installing Ansible collections in molecule venv...${NC}"
                "$galaxy_bin" collection install ansible.posix community.general community.docker --force
                needs_install=1
            fi
        fi
    fi

    # Also install system-wide for ansible-lint etc
    if command -v ansible-galaxy &>/dev/null; then
        if ! ansible-galaxy collection list 2>/dev/null | grep -q "ansible.posix"; then
            echo -e "${YELLOW}Installing Ansible collections system-wide...${NC}"
            ansible-galaxy collection install ansible.posix community.general community.docker --force 2>/dev/null || true
        fi
    fi

    if [[ $needs_install -eq 1 ]]; then
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
        echo
    fi
}

# Check Docker is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}ERROR: Docker is not installed${NC}"
        exit 1
    fi

    if ! docker info &>/dev/null 2>&1; then
        if groups | grep -q docker; then
            echo -e "${RED}ERROR: Docker daemon is not running${NC}"
        else
            echo -e "${RED}ERROR: User not in docker group${NC}"
            echo "Run: sudo usermod -aG docker \$USER && newgrp docker"
        fi
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
install_dependencies
check_docker

# Find all testable roles
ROLES_DIR="$PROJECT_DIR/roles"
declare -a PASSED=()
declare -a FAILED=()

echo -e "${BLUE}Finding roles with Molecule tests...${NC}"
for role_dir in "$ROLES_DIR"/*/molecule/default; do
    if [[ -d "$role_dir" ]]; then
        role=$(basename "$(dirname "$(dirname "$role_dir")")")
        echo "  - $role"
    fi
done
echo

# Run tests
for role_dir in "$ROLES_DIR"/*/molecule/default; do
    if [[ -d "$role_dir" ]]; then
        role=$(basename "$(dirname "$(dirname "$role_dir")")")
        role_path="$ROLES_DIR/$role"

        echo
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Testing role: ${role}${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo

        cd "$role_path"
        if molecule test; then
            echo -e "${GREEN}PASSED: ${role}${NC}"
            PASSED+=("$role")
        else
            echo -e "${RED}FAILED: ${role}${NC}"
            FAILED+=("$role")
        fi
    fi
done

# Summary
echo
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo
echo "  Total:  $((${#PASSED[@]} + ${#FAILED[@]}))"
echo -e "  ${GREEN}Passed: ${#PASSED[@]}${NC}"
echo -e "  ${RED}Failed: ${#FAILED[@]}${NC}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo
    echo -e "${RED}Failed roles:${NC}"
    for role in "${FAILED[@]}"; do
        echo "  - $role"
    done
    exit 1
else
    echo
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
