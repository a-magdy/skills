#!/usr/bin/env bash
# Link shared global preferences into Claude Code and Copilot CLI.
#
# Usage: ./install-instructions.sh [--claude] [--copilot] [--dry-run | --check]
# Defaults to both clients. Honors CLAUDE_CONFIG_DIR and COPILOT_HOME.
# Existing files/links are preserved in unique sibling .backup.* paths.
# Directories are never replaced. --check and --dry-run never write files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$REPO_ROOT/config/global/AGENTS.md"
DESTINATIONS=()
MODE="install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --claude) DESTINATIONS+=("${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md") ;;
    --copilot) DESTINATIONS+=("${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md") ;;
    --dry-run|--check)
      if [[ "$MODE" != "install" && "$MODE" != "${1#--}" ]]; then
        printf '%s\n' 'Use either --dry-run or --check, not both.' >&2
        exit 2
      fi
      MODE="${1#--}"
      ;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

if [[ ${#DESTINATIONS[@]} -eq 0 ]]; then
  DESTINATIONS=(
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
    "${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md"
  )
fi

if [[ ! -f "$SOURCE_FILE" ]]; then
  printf 'Global instructions missing: %s\n' "$SOURCE_FILE" >&2
  exit 1
fi

# Validate all destinations before changing either client.
for destination in "${DESTINATIONS[@]}"; do
  if [[ -d "$destination" ]]; then
    printf 'Refusing to replace an instruction directory: %s\n' "$destination" >&2
    exit 1
  fi
done

problems=0
for destination in "${DESTINATIONS[@]}"; do
  if [[ -L "$destination" && "$(readlink "$destination")" == "$SOURCE_FILE" ]]; then
    printf 'Already linked: %s\n' "$destination"
    continue
  fi
  case "$MODE" in
    check)
      printf 'Missing or incorrect instruction link: %s -> %s\n' "$destination" "$SOURCE_FILE" >&2
      problems=$((problems + 1))
      continue
      ;;
    dry-run)
      printf 'Would back up any existing file and link: %s -> %s\n' "$destination" "$SOURCE_FILE"
      continue
      ;;
  esac
  mkdir -p "$(dirname "$destination")"
  # Moving preserves regular files and symlinks, including broken links.
  if [[ -e "$destination" || -L "$destination" ]]; then
    backup="$(mktemp "${destination}.backup.XXXXXX")"
    mv -f "$destination" "$backup"
    printf 'Previous instructions backed up to %s\n' "$backup"
  fi
  ln -s "$SOURCE_FILE" "$destination"
  printf 'Linked: %s -> %s\n' "$destination" "$SOURCE_FILE"
done

[[ "$problems" -eq 0 ]]
