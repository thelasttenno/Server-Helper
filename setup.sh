#!/usr/bin/env bash
# =============================================================================
# Server Helper v0.4.0 — Quick Setup Entry Point
# =============================================================================
# Wrapper: delegates to scripts/setup.sh so you can run ./setup.sh from root.
# =============================================================================

set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/setup.sh" "$@"
