#!/usr/bin/env bash
# Install the skills in this repo into ~/.claude/skills/ (or a custom target).
#
# Usage:
#   ./install.sh                          # symlink APM (third-party) skills into ~/.claude/skills/
#   ./install.sh --copilot                # also/instead install into ~/.copilot/skills/
#   ./install.sh --claude --copilot       # install into both Claude and Copilot
#   ./install.sh --copy                   # copy instead of symlink
#   ./install.sh --target /custom/path    # install to a custom location
#   ./install.sh session-status           # install only specific skill(s), own or APM
#   ./install.sh --dry-run                # show what would happen, don't do it
#   ./install.sh --with-plugins           # after skills, also run install-plugins.sh (whole plugins)
#   ./install.sh -h | --help              # show this help
#
# NOTE: by default this installs only APM-managed (third-party) skills. The
# repo's own skills ship via the `personal-skills` plugin (marketplace.json),
# so they are no longer symlinked here (avoids double-loading with the plugin).
#
# Targets (repeatable; default is --claude only):
#   --claude            ~/.claude/skills   (APM skills sourced from .agents/skills/)
#   --copilot           ~/.copilot/skills  (APM skills sourced from .agents/skills/)
#   --target PATH       custom dir         (APM skills sourced from .agents/skills/)
#
# Defaults:
#   - mode:   symlink (so edits in this repo flow through to the agent)
#   - target: ~/.claude/skills
#
# Existing skill folders at the target:
#   - if a symlink: removed and replaced.
#   - if a real directory: backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` and replaced.

set -euo pipefail

# ---- Defaults -----------------------------------------------------------------

CLAUDE_TARGET="$HOME/.claude/skills"
COPILOT_TARGET="$HOME/.copilot/skills"
MODE="symlink"
DRY_RUN=false
WITH_PLUGINS=false
PLUGIN_ARGS=()
SKILLS_TO_INSTALL=()

# Parallel arrays: each install target is a (destination dir, APM source subdir) pair.
TARGET_DIRS=()
TARGET_APM_SRCS=()

# ---- Parse args ---------------------------------------------------------------

print_help() {
  sed -n '2,/^set -euo pipefail/{/^set -euo pipefail/q;p;}' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)    MODE="copy"; shift ;;
    --symlink) MODE="symlink"; shift ;;
    --claude)  TARGET_DIRS+=("$CLAUDE_TARGET");  TARGET_APM_SRCS+=(".agents/skills"); PLUGIN_ARGS+=("--claude");  shift ;;
    --copilot) TARGET_DIRS+=("$COPILOT_TARGET"); TARGET_APM_SRCS+=(".agents/skills"); PLUGIN_ARGS+=("--copilot"); shift ;;
    --target)  TARGET_DIRS+=("$2");              TARGET_APM_SRCS+=(".agents/skills"); shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --with-plugins) WITH_PLUGINS=true; shift ;;
    -h|--help) print_help; exit 0 ;;
    --) shift; SKILLS_TO_INSTALL+=("$@"); break ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *)  SKILLS_TO_INSTALL+=("$1"); shift ;;
  esac
done

# Default to Claude only when no target flag was given (backward compatible).
if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  TARGET_DIRS=("$CLAUDE_TARGET")
  TARGET_APM_SRCS=(".agents/skills")
fi

# ---- Discover skills ----------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Ensure APM dependencies are fetched -------------------------------------

if [ -f "$REPO_ROOT/apm.yml" ] && command -v apm &>/dev/null; then
  if [ ! -d "$REPO_ROOT/.agents/skills" ] || [ ! -d "$REPO_ROOT/apm_modules" ]; then
    if $DRY_RUN; then
      echo "would run apm install to fetch dependencies (skipped in dry run)"
      echo
    else
      echo "Running apm install to fetch dependencies..."
      (cd "$REPO_ROOT" && apm install)
      echo
    fi
  fi
fi

# Anything that has a SKILL.md one level down is a skill (native skills).
mapfile -t REPO_SKILLS < <(
  find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -type f \
    -not -path "$REPO_ROOT/.claude/*" \
    -not -path "$REPO_ROOT/.agents/*" \
    | xargs -n1 dirname \
    | xargs -n1 basename \
    | sort
)

# APM-managed skills live under .agents/skills/ after `apm install`.
mapfile -t APM_SKILLS < <(
  if [ -d "$REPO_ROOT/.agents/skills" ]; then
    find "$REPO_ROOT/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f \
      | xargs -n1 dirname \
      | xargs -n1 basename \
      | sort
  fi
)

# Combined list (native + APM-managed) — used only for explicit-name resolution.
ALL_SKILLS=("${REPO_SKILLS[@]}" "${APM_SKILLS[@]}")

if [ ${#ALL_SKILLS[@]} -eq 0 ]; then
  echo "no skills found under $REPO_ROOT (looking for */SKILL.md)" >&2
  exit 1
fi

# By default, install only APM-managed (third-party) skills. The repo's own
# skills are distributed via the `personal-skills` plugin (see marketplace.json),
# not by symlinking — this avoids double-loading them alongside the plugin.
# Pass skill names explicitly to install specific skills (own or APM).
if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
  SKILLS_TO_INSTALL=("${APM_SKILLS[@]}")
fi

# ---- Print plan ---------------------------------------------------------------

echo "Source: $REPO_ROOT"
echo "Mode:   $MODE"
$DRY_RUN && echo "(dry run — no changes will be made)"
echo "Targets:"
for t in "${TARGET_DIRS[@]}"; do echo "  - $t"; done
echo "Skills to install:"
for s in "${SKILLS_TO_INSTALL[@]}"; do echo "  - $s"; done
echo

# ---- Install ------------------------------------------------------------------

installed=0
skipped=0
backed_up=0

for ti in "${!TARGET_DIRS[@]}"; do
  TARGET="${TARGET_DIRS[$ti]}"
  APM_SRC_REL="${TARGET_APM_SRCS[$ti]}"

  echo "==> $TARGET (APM source: $APM_SRC_REL)"
  $DRY_RUN || mkdir -p "$TARGET"

  for skill in "${SKILLS_TO_INSTALL[@]}"; do
    # Resolve source: prefer native repo skill, fall back to APM-managed for this target.
    if [ -d "$REPO_ROOT/$skill" ] && [ -f "$REPO_ROOT/$skill/SKILL.md" ]; then
      src="$REPO_ROOT/$skill"
    elif [ -d "$REPO_ROOT/$APM_SRC_REL/$skill" ] && [ -f "$REPO_ROOT/$APM_SRC_REL/$skill/SKILL.md" ]; then
      src="$REPO_ROOT/$APM_SRC_REL/$skill"
    else
      echo "skip: $skill (no SKILL.md found under $APM_SRC_REL)" >&2
      skipped=$((skipped+1))
      continue
    fi
    dst="$TARGET/$skill"

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
done

echo "Done. $installed installed, $skipped skipped, $backed_up backed up."
$DRY_RUN || {
  for t in "${TARGET_DIRS[@]}"; do
    echo
    echo "Installed at $t:"
    ls -la "$t" | awk 'NR>1 {print "  " $0}'
  done
}

# Opt-in: also install whole plugins (layer 2) via install-plugins.sh.
if $WITH_PLUGINS; then
  echo
  echo "==> Whole plugins (install-plugins.sh)"
  $DRY_RUN && PLUGIN_ARGS+=("--dry-run")
  "$REPO_ROOT/install-plugins.sh" ${PLUGIN_ARGS[@]+"${PLUGIN_ARGS[@]}"}
fi
