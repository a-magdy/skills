#!/usr/bin/env bash
# Install the skills in this repo into ~/.claude/skills/ (or a custom target).
#
# Usage:
#   ./install.sh                          # symlink all skills into ~/.claude/skills/
#   ./install.sh --copy                   # copy instead of symlink
#   ./install.sh --target /custom/path    # install to a custom location
#   ./install.sh session-status           # install only specific skill(s)
#   ./install.sh --dry-run                # show what would happen, don't do it
#   ./install.sh -h | --help              # show this help
#
# Defaults:
#   - mode:   symlink (so edits in this repo flow through to Claude)
#   - target: ~/.claude/skills
#
# Existing skill folders at the target:
#   - if a symlink: removed and replaced.
#   - if a real directory: backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` and replaced.

set -euo pipefail

# ---- Defaults -----------------------------------------------------------------

DEFAULT_TARGET="$HOME/.claude/skills"
MODE="symlink"
TARGET="$DEFAULT_TARGET"
DRY_RUN=false
SKILLS_TO_INSTALL=()

# ---- Parse args ---------------------------------------------------------------

print_help() {
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/q;p;}' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)    MODE="copy"; shift ;;
    --symlink) MODE="symlink"; shift ;;
    --target)  TARGET="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) print_help; exit 0 ;;
    --) shift; SKILLS_TO_INSTALL+=("$@"); break ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *)  SKILLS_TO_INSTALL+=("$1"); shift ;;
  esac
done

# ---- Discover skills ----------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Anything that has a SKILL.md one level down is a skill.
mapfile -t REPO_SKILLS < <(
  find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -type f \
    | xargs -n1 dirname \
    | xargs -n1 basename \
    | sort
)

if [ ${#REPO_SKILLS[@]} -eq 0 ]; then
  echo "no skills found under $REPO_ROOT (looking for */SKILL.md)" >&2
  exit 1
fi

# If no specific skills requested, install them all.
if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
  SKILLS_TO_INSTALL=("${REPO_SKILLS[@]}")
fi

# ---- Print plan ---------------------------------------------------------------

echo "Source: $REPO_ROOT"
echo "Target: $TARGET"
echo "Mode:   $MODE"
$DRY_RUN && echo "(dry run — no changes will be made)"
echo "Skills to install:"
for s in "${SKILLS_TO_INSTALL[@]}"; do echo "  - $s"; done
echo

# ---- Install ------------------------------------------------------------------

$DRY_RUN || mkdir -p "$TARGET"

installed=0
skipped=0
backed_up=0

for skill in "${SKILLS_TO_INSTALL[@]}"; do
  src="$REPO_ROOT/$skill"
  dst="$TARGET/$skill"

  if [ ! -d "$src" ] || [ ! -f "$src/SKILL.md" ]; then
    echo "skip: $skill (no $src/SKILL.md)" >&2
    skipped=$((skipped+1))
    continue
  fi

  # Handle existing destination.
  if [ -L "$dst" ]; then
    if $DRY_RUN; then
      echo "would unlink existing symlink: $dst"
    else
      rm "$dst"
    fi
  elif [ -e "$dst" ]; then
    backup="$dst.bak-$(date +%Y%m%d-%H%M%S)"
    if $DRY_RUN; then
      echo "would back up existing: $dst -> $backup"
    else
      mv "$dst" "$backup"
      echo "backed up existing: $skill -> $(basename "$backup")"
    fi
    backed_up=$((backed_up+1))
  fi

  # Install.
  if $DRY_RUN; then
    echo "would $MODE: $skill"
  elif [ "$MODE" = "symlink" ]; then
    ln -s "$src" "$dst"
    echo "linked: $skill"
  else
    cp -R "$src" "$dst"
    echo "copied: $skill"
  fi
  installed=$((installed+1))
done

echo
echo "Done. $installed installed, $skipped skipped, $backed_up backed up."
$DRY_RUN || {
  echo
  echo "Installed at $TARGET:"
  ls -la "$TARGET" | awk 'NR>1 {print "  " $0}'
}
