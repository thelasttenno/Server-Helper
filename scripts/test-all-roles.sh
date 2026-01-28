#!/bin/bash
#
# Test all Ansible roles using Molecule
# This script runs Molecule tests for all roles that have test configurations
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
PASSED=()
FAILED=()
SKIPPED=()

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Server-Helper Molecule Test Suite${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v molecule &> /dev/null; then
    echo -e "${RED}Error: Molecule is not installed${NC}"
    echo "Install with: pip install -r requirements-test.txt"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependencies OK${NC}"
echo ""

# Find all roles with Molecule tests
ROLES_DIR="$PROJECT_ROOT/roles"
cd "$ROLES_DIR"

# Get list of roles with molecule tests
ROLES_WITH_TESTS=()
for role_dir in */; do
    role=$(basename "$role_dir")
    if [ -d "$role_dir/molecule/default" ]; then
        ROLES_WITH_TESTS+=("$role")
    fi
done

if [ ${#ROLES_WITH_TESTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No roles with Molecule tests found${NC}"
    exit 0
fi

echo -e "${BLUE}Found ${#ROLES_WITH_TESTS[@]} roles with tests:${NC}"
for role in "${ROLES_WITH_TESTS[@]}"; do
    echo "  - $role"
done
echo ""

# Test each role
for role in "${ROLES_WITH_TESTS[@]}"; do
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}Testing role: $role${NC}"
    echo -e "${BLUE}======================================${NC}"

    cd "$ROLES_DIR/$role"

    # Install Galaxy dependencies if requirements.yml exists
    if [ -f "molecule/default/requirements.yml" ]; then
        echo -e "${YELLOW}Installing Galaxy dependencies...${NC}"
        ansible-galaxy install -r molecule/default/requirements.yml || true
    fi

    # Run molecule test
    if molecule test; then
        echo -e "${GREEN}✓ PASSED: $role${NC}"
        PASSED+=("$role")
    else
        echo -e "${RED}✗ FAILED: $role${NC}"
        FAILED+=("$role")
    fi

    echo ""
done

# Print summary
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

if [ ${#PASSED[@]} -gt 0 ]; then
    echo -e "${GREEN}Passed (${#PASSED[@]}):${NC}"
    for role in "${PASSED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $role"
    done
    echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}Failed (${#FAILED[@]}):${NC}"
    for role in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${NC} $role"
    done
    echo ""
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo -e "${YELLOW}Skipped (${#SKIPPED[@]}):${NC}"
    for role in "${SKIPPED[@]}"; do
        echo -e "  ${YELLOW}○${NC} $role"
    done
    echo ""
fi

# Exit with appropriate code
if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
