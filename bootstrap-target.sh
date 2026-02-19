#!/usr/bin/env bash
# =============================================================================
# Quick Bootstrap for New Servers
# =============================================================================
# Wrapper: delegates to scripts/bootstrap-target.sh for root-level convenience.
# Usage: ./bootstrap-target.sh <hostname>
# =============================================================================

set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/bootstrap-target.sh" "$@"
