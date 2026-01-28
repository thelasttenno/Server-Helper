#!/bin/bash
#
# Test a single Ansible role using Molecule
#
# Usage: ./test-single-role.sh <role-name> [molecule-command]
#   molecule-command: test (default), converge, verify, destroy, etc.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Role name required${NC}"
    echo "Usage: $0 <role-name> [molecule-command]"
    echo ""
    echo "Available roles with tests:"
    for role_dir in "$PROJECT_ROOT/roles"/*/; do
        role=$(basename "$role_dir")
        if [ -d "$role_dir/molecule/default" ]; then
            echo "  - $role"
        fi
    done
    exit 1
fi

ROLE_NAME=$1
MOLECULE_CMD=${2:-test}  # Default to 'test' if not specified

ROLE_DIR="$PROJECT_ROOT/roles/$ROLE_NAME"

# Check if role exists
if [ ! -d "$ROLE_DIR" ]; then
    echo -e "${RED}Error: Role '$ROLE_NAME' not found${NC}"
    exit 1
fi

# Check if role has molecule tests
if [ ! -d "$ROLE_DIR/molecule/default" ]; then
    echo -e "${RED}Error: Role '$ROLE_NAME' does not have Molecule tests${NC}"
    echo "Create tests in: $ROLE_DIR/molecule/default/"
    exit 1
fi

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Testing role: $ROLE_NAME${NC}"
echo -e "${BLUE}Command: molecule $MOLECULE_CMD${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

cd "$ROLE_DIR"

# Install Galaxy dependencies if requirements.yml exists
if [ -f "molecule/default/requirements.yml" ]; then
    echo -e "${YELLOW}Installing Galaxy dependencies...${NC}"
    ansible-galaxy install -r molecule/default/requirements.yml || true
    echo ""
fi

# Run molecule command
echo -e "${YELLOW}Running: molecule $MOLECULE_CMD${NC}"
if molecule "$MOLECULE_CMD"; then
    echo ""
    echo -e "${GREEN}✓ Success: molecule $MOLECULE_CMD completed for $ROLE_NAME${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Failed: molecule $MOLECULE_CMD failed for $ROLE_NAME${NC}"
    exit 1
fi
