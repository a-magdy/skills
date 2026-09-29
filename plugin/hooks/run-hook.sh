#!/usr/bin/env bash
# Dispatcher for personal-skills plugin hooks.
# Never blocks a session: any failure is swallowed and we always exit 0.
#
# Usage: run-hook.sh <session-start|session-end>

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
  session-start) bash "$HOOK_DIR/session-start" || true ;;
  session-end)   bash "$HOOK_DIR/session-end"   || true ;;
  *) : ;;  # unknown hook name — do nothing
esac

exit 0
