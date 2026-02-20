#!/usr/bin/env bash
# =============================================================================
# bootstrap-target.sh — Quick bootstrap for new servers
# =============================================================================
# Wrapper around playbooks/bootstrap.yml for convenience.
# Usage: ./scripts/bootstrap-target.sh <hostname>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <hostname>"
    echo "  hostname: Must be defined in inventory/hosts.yml"
    exit 1
fi

HOST="$1"

echo "Bootstrapping target: $HOST"
ansible-playbook \
    -i "$PROJECT_ROOT/inventory/hosts.yml" \
    "$PROJECT_ROOT/playbooks/bootstrap.yml" \
    --limit "$HOST"

echo "Bootstrap complete for $HOST"
