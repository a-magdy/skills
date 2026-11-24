#!/usr/bin/env bash
# Install whole plugins / harnesses listed in plugins.list into agent CLIs.
#
# Unlike APM skills (symlinked per-skill by install.sh), these are full plugins
# that carry hooks, session bootstraps, and companion tools. Each agent CLI has
# its own plugin system, so we install them natively per CLI.
#
# Usage:
#   ./install-plugins.sh              # install into BOTH copilot and claude (default)
#   ./install-plugins.sh --dry-run    # show the exact CLI commands, run nothing
#   ./install-plugins.sh --copilot    # only the copilot target
#   ./install-plugins.sh --claude     # only the claude target
#   ./install-plugins.sh --check      # read-only expected-plugin and source audit
#   ./install-plugins.sh --local      # own marketplace from this checkout (explicit development)
#   ./install-plugins.sh -h | --help  # show this help
#
# A target whose CLI is not on PATH is skipped safely (with a warning); the
# script still installs into whichever CLIs are present. Each plugin is also
# constrained to the targets it declares in plugins.list. This repo's own
# marketplace defaults to plugins.list; --local selects this checkout. Its plugin is
# updated on every run; third-party plugins are only installed. The exit code is
# non-zero on inventory, registration, install or update failures. --check also
# fails when a selected CLI is missing. --dry-run invokes no CLI commands.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="$REPO_ROOT/plugins.list"

DRY_RUN=false
CHECK=false
LOCAL=false
ONLY_TARGETS=()

print_help() { sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/q;p;}' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --check) CHECK=true; shift ;;
    --local) LOCAL=true; shift ;;
    --copilot) ONLY_TARGETS+=("copilot"); shift ;;
    --claude)  ONLY_TARGETS+=("claude");  shift ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$LIST_FILE" ] || { echo "no plugins.list found at $LIST_FILE" >&2; exit 1; }
if $CHECK && $DRY_RUN; then printf '%s\n' 'Use either --check or --dry-run, not both.' >&2; exit 2; fi
if ! $DRY_RUN && ! command -v python3 >/dev/null; then
  printf '%s\n' 'UNKNOWN: python3 is required to parse plugin inventories safely.' >&2
  exit 1
fi

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

run() {
  if $DRY_RUN; then echo "  would run: $*"; else echo "  + $*"; "$@"; fi
}

# Register a marketplace unless the CLI already knows one by that name. An
# existing registration is left alone, so a marketplace added from a local
# checkout (for working on the plugin) is not re-pointed at GitHub.
add_marketplace() {
  local cli="$1" repo="$2" name="$3"
  local inventory rc=0
  if $DRY_RUN; then run "$cli" plugin marketplace add "$repo"; return; fi
  if ! inventory="$("$cli" plugin marketplace list --json)"; then
    printf 'UNKNOWN %s marketplace inventory failed; check CLI authentication/version.\n' "$cli" >&2
    return 1
  fi
  printf '%s\n' "$inventory" | python3 -B "$REPO_ROOT/scripts/plugin-state.py" registered "$cli" "$name" "$repo" || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "  marketplace $name already registered in $cli — keeping it"
    return 0
  fi
  [ "$rc" -eq 1 ] || return 1
  run "$cli" plugin marketplace add "$repo"
}

check_plugin() {
  local cli="$1" repo="$2" name="$3" plugin="$4" markets plugins rc=0
  if ! markets="$("$cli" plugin marketplace list --json)" || ! plugins="$("$cli" plugin list --json)"; then
    printf 'UNKNOWN %s inventory failed; check CLI authentication/version.\n' "$cli" >&2
    return 1
  fi
  printf '%s\n' "$markets" | python3 -B "$REPO_ROOT/scripts/plugin-state.py" marketplace "$cli" "$name" "$repo" || rc=1
  printf '%s\n' "$plugins" | python3 -B "$REPO_ROOT/scripts/plugin-state.py" plugin "$cli" "$plugin@$name" "$repo" || rc=1
  return "$rc"
}

# Only --local overrides the own marketplace source from plugins.list.
OWN_MARKETPLACE=""
if [ -f "$REPO_ROOT/marketplace.json" ]; then
  OWN_MARKETPLACE="$(sed -n 's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO_ROOT/marketplace.json" | head -n 1)"
fi

# Effective targets: explicit flags if given, otherwise both.
if [ ${#ONLY_TARGETS[@]} -eq 0 ]; then
  WANTED_TARGETS=(copilot claude)
else
  WANTED_TARGETS=("${ONLY_TARGETS[@]}")
fi

target_wanted() {
  local x; for x in "${WANTED_TARGETS[@]}"; do [ "$x" = "$1" ] && return 0; done
  return 1
}

# Warn once up front about any wanted CLI that isn't installed.
for t in "${WANTED_TARGETS[@]}"; do
  if ! $CHECK; then
    command -v "$t" &>/dev/null || echo "note: '$t' CLI not on PATH — its plugins will be skipped."
  fi
done

installed=0
skipped=0
failed=0

while IFS= read -r line || [ -n "$line" ]; do
  line="$(trim "$line")"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac

  IFS='|' read -r mp_repo mp_name plugin targets _desc <<< "$line"
  mp_repo="$(trim "$mp_repo")"
  mp_name="$(trim "$mp_name")"
  plugin="$(trim "$plugin")"
  targets="$(trim "$targets")"; targets="${targets// /}"

  [ -z "$mp_repo" ] && continue
  own=false
  if [ -n "$OWN_MARKETPLACE" ] && [ "$mp_name" = "$OWN_MARKETPLACE" ]; then
    own=true
    if $LOCAL; then mp_repo="$REPO_ROOT"; fi
  fi
  echo "== $plugin ($mp_repo) =="

  IFS=',' read -ra tlist <<< "$targets"
  for t in "${tlist[@]}"; do
    target_wanted "$t" || continue
    if ! command -v "$t" &>/dev/null; then
      if $CHECK; then
        printf 'UNKNOWN %s: CLI not on PATH\n' "$t"
        failed=$((failed+1))
        continue
      fi
      echo "  skip $t: CLI not on PATH"; skipped=$((skipped+1))
      continue
    fi
    if $CHECK; then
      if check_plugin "$t" "$mp_repo" "$mp_name" "$plugin"; then
        installed=$((installed+1))
      else
        failed=$((failed+1))
      fi
      continue
    fi
    case "$t" in
      copilot)
        if ! add_marketplace copilot "$mp_repo" "$mp_name"; then failed=$((failed+1)); continue; fi
        if run copilot plugin install "${plugin}@${mp_name}"; then
          installed=$((installed+1))
          # Pick up changes pulled into this checkout since the last install.
          if $own && ! run copilot plugin update "${plugin}@${mp_name}"; then failed=$((failed+1)); fi
        else
          echo "  ERROR: install failed for $plugin on copilot"; failed=$((failed+1))
        fi
        ;;
      claude)
        if ! add_marketplace claude "$mp_repo" "$mp_name"; then failed=$((failed+1)); continue; fi
        if run claude plugin install "${plugin}@${mp_name}"; then
          installed=$((installed+1))
          # Pick up changes pulled into this checkout since the last install.
          if $own && ! run claude plugin update "${plugin}@${mp_name}"; then failed=$((failed+1)); fi
        else
          echo "  ERROR: install failed for $plugin on claude"; failed=$((failed+1))
        fi
        ;;
      *)
        echo "  skip $t: unknown target"; skipped=$((skipped+1))
        ;;
    esac
  done
  echo
done < "$LIST_FILE"

if $CHECK; then
  printf 'Audit: %s healthy, %s failed.\n' "$installed" "$failed"
else
  printf 'Done. %s installed, %s skipped, %s failed.\n' "$installed" "$skipped" "$failed"
fi
[ "$failed" -eq 0 ] || exit 1
