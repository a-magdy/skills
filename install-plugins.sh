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
#   ./install-plugins.sh -h | --help  # show this help
#
# A target whose CLI is not on PATH is skipped safely (with a warning); the
# script still installs into whichever CLIs are present. Each plugin is also
# constrained to the targets it declares in plugins.list. The exit code is
# non-zero only if an actual install command failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="$REPO_ROOT/plugins.list"

DRY_RUN=false
ONLY_TARGETS=()

print_help() { sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/q;p;}' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --copilot) ONLY_TARGETS+=("copilot"); shift ;;
    --claude)  ONLY_TARGETS+=("claude");  shift ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$LIST_FILE" ] || { echo "no plugins.list found at $LIST_FILE" >&2; exit 1; }

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

run() {
  if $DRY_RUN; then echo "  would run: $*"; else echo "  + $*"; "$@"; fi
}

# Like run(), but never aborts the script: used for steps that report failure
# when the desired state already exists (e.g. re-adding a registered marketplace).
run_soft() {
  if $DRY_RUN; then echo "  would run: $*"; return 0; fi
  echo "  + $*"
  "$@" || echo "  (already present or non-fatal — continuing)"
}

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
  command -v "$t" &>/dev/null || echo "note: '$t' CLI not on PATH — its plugins will be skipped."
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
  echo "== $plugin ($mp_repo) =="

  IFS=',' read -ra tlist <<< "$targets"
  for t in "${tlist[@]}"; do
    target_wanted "$t" || continue
    if ! command -v "$t" &>/dev/null; then
      echo "  skip $t: CLI not on PATH"; skipped=$((skipped+1))
      continue
    fi
    case "$t" in
      copilot)
        run_soft copilot plugin marketplace add "$mp_repo"
        if run copilot plugin install "${plugin}@${mp_name}"; then
          installed=$((installed+1))
        else
          echo "  ERROR: install failed for $plugin on copilot"; failed=$((failed+1))
        fi
        ;;
      claude)
        run_soft claude plugin marketplace add "$mp_repo"
        if run claude plugin install "${plugin}@${mp_name}" -y; then
          installed=$((installed+1))
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

echo "Done. $installed installed, $skipped skipped, $failed failed."
[ "$failed" -eq 0 ] || exit 1
