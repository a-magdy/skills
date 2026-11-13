#!/usr/bin/env bash
# Install third-party skills into ~/.claude/skills/ and ~/.copilot/skills/ (or a custom target).
#
# Usage:
#   ./install.sh                          # symlink APM (third-party) skills into both CLIs
#   ./install.sh --claude                 # only ~/.claude/skills/
#   ./install.sh --copilot                # only ~/.copilot/skills/
#   ./install.sh --copy                   # copy instead of symlink
#   ./install.sh --target /custom/path    # install to a custom location
#   ./install.sh session-status           # install only specific skill(s), own or APM
#   ./install.sh --dry-run                # show what would happen, don't do it
#   ./install.sh --with-plugins           # after skills, also run install-plugins.sh (whole plugins)
#   ./install.sh --with-instructions      # also link global preferences for selected CLI targets
#   ./install.sh --check                  # report missing / broken / duplicate skills, change nothing
#   ./install.sh -h | --help              # show this help
#
# NOTE: by default this installs only APM-managed (third-party) skills. The
# repo's own skills live in plugin/skills/ and ship via the `personal-skills`
# plugin (marketplace.json), so they are not symlinked here (avoids
# double-loading with the plugin). Name one explicitly to link it for live edits.
#
# Targets (repeatable; default is both --claude and --copilot):
#   --claude            ~/.claude/skills   (APM skills sourced from .agents/skills/)
#   --copilot           ~/.copilot/skills  (APM skills sourced from .agents/skills/)
#   --target PATH       custom dir         (APM skills sourced from .agents/skills/)
#
# Defaults:
#   - mode:   symlink (so edits in this repo flow through to the agent)
#   - target: ~/.claude/skills and ~/.copilot/skills (same default as the other installers)
#
# --check (read-only): checks ~/.claude/skills and ~/.copilot/skills (or the
# targets you pass) and reports, per skill: ok, MISSING, BROKEN symlink,
# COPY (real dir instead of a symlink), DUPLICATE (an own skill that also
# ships in the plugin), and leftover .backup.* backups. Exits 1 if anything
# needs fixing or APM skill sources are unavailable.
#
# Existing skill folders at the target:
#   - if a symlink: removed and replaced.
#   - if a real directory: backed up to `<name>.backup.<YYYYMMDD-HHMMSS>` and replaced.

set -euo pipefail

# ---- Defaults -----------------------------------------------------------------

CLAUDE_TARGET="$HOME/.claude/skills"
COPILOT_TARGET="$HOME/.copilot/skills"
MODE="symlink"
DRY_RUN=false
CHECK=false
WITH_PLUGINS=false
WITH_INSTRUCTIONS=false
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
    --target)  [ $# -ge 2 ] || { echo "--target needs a path" >&2; exit 2; }
               TARGET_DIRS+=("$2");              TARGET_APM_SRCS+=(".agents/skills"); shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --check)   CHECK=true; shift ;;
    --with-plugins) WITH_PLUGINS=true; shift ;;
    --with-instructions) WITH_INSTRUCTIONS=true; shift ;;
    -h|--help) print_help; exit 0 ;;
    --) shift; SKILLS_TO_INSTALL+=("$@"); break ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *)  SKILLS_TO_INSTALL+=("$1"); shift ;;
  esac
done

# Default to both CLIs when no target flag was given, like install-plugins.sh
# and install-instructions.sh.
if [ ${#TARGET_DIRS[@]} -eq 0 ]; then
  TARGET_DIRS=("$CLAUDE_TARGET" "$COPILOT_TARGET")
  TARGET_APM_SRCS=(".agents/skills" ".agents/skills")
fi

INSTRUCTIONS_RC=0
# Global instructions use CLI config roots, not a custom skill --target directory.
if $WITH_INSTRUCTIONS; then
  if [ ${#PLUGIN_ARGS[@]} -eq 0 ]; then
    INSTRUCTION_ARGS=(--claude --copilot)
  else
    INSTRUCTION_ARGS=("${PLUGIN_ARGS[@]}")
  fi
  if $CHECK; then
    INSTRUCTION_ARGS+=("--check")
  elif $DRY_RUN; then
    INSTRUCTION_ARGS+=("--dry-run")
  fi
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-instructions.sh" "${INSTRUCTION_ARGS[@]}" || INSTRUCTIONS_RC=$?
  # In --check mode, carry on to the skill audit and fail at the end.
  if [ "$INSTRUCTIONS_RC" -ne 0 ] && ! $CHECK; then exit "$INSTRUCTIONS_RC"; fi
  echo
fi

# ---- Discover skills ----------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Ensure APM dependencies are fetched -------------------------------------

# Skill names declared in apm.yml: the last path segment of each dependency.
DECLARED_APM=()
if [ -f "$REPO_ROOT/apm.yml" ]; then
  while IFS= read -r s; do DECLARED_APM+=("$s"); done < <(
    sed -n 's|^[[:space:]]*-[[:space:]]*\([^[:space:]#]*/[^[:space:]#]*\).*|\1|p' "$REPO_ROOT/apm.yml" \
      | awk -F/ '{print $NF}'
  )
fi

# Declared skills that have not been fetched into .agents/skills/ yet.
unfetched_apm() {
  local s
  for s in ${DECLARED_APM[@]+"${DECLARED_APM[@]}"}; do
    [ -f "$REPO_ROOT/.agents/skills/$s/SKILL.md" ] || printf '%s\n' "$s"
  done
}

UNFETCHED="$(unfetched_apm | tr '\n' ' ')"
if ! $CHECK && [ -n "$UNFETCHED" ]; then
  if ! command -v apm &>/dev/null; then
    # Naming skills explicitly (e.g. an own skill) does not need APM.
    if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
      printf '%s\n' "APM is not on PATH, so the third-party skills in apm.yml cannot be fetched." \
        "Install it (brew install microsoft/apm/apm), then rerun." >&2
      exit 1
    fi
  elif $DRY_RUN; then
    echo "would run apm install to fetch: $UNFETCHED(skipped in dry run)"
    echo
  else
    echo "Running apm install to fetch: $UNFETCHED"
    (cd "$REPO_ROOT" && apm install)
    echo
  fi
fi

# Own skills: every plugin/skills/<name>/ holding a SKILL.md.
# (while-read loops instead of mapfile so this runs on macOS's bash 3.2.)
OWN_SKILLS_REL="plugin/skills"
REPO_SKILLS=()
while IFS= read -r s; do REPO_SKILLS+=("$s"); done < <(
  for skill_md in "$REPO_ROOT/$OWN_SKILLS_REL"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    basename "$(dirname "$skill_md")"
  done | sort
)

# APM-managed skills live under .agents/skills/ after `apm install`.
APM_SKILLS=()
while IFS= read -r s; do APM_SKILLS+=("$s"); done < <(
  if [ -d "$REPO_ROOT/.agents/skills" ]; then
    find "$REPO_ROOT/.agents/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f \
      | while IFS= read -r skill_path; do
          basename "$(dirname "$skill_path")"
        done \
      | sort
  fi
)

if $CHECK && [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ] && [ -f "$REPO_ROOT/apm.yml" ]; then
  if [ ${#APM_SKILLS[@]} -eq 0 ]; then
    printf '%s\n' 'Check incomplete: no APM skill sources found in .agents/skills. Run "apm install" in this repo, then rerun --check.' >&2
    exit 1
  elif [ -n "$UNFETCHED" ]; then
    printf '%s\n' "Check incomplete: declared in apm.yml but not fetched: $UNFETCHED" 'Run "apm install" in this repo, then rerun --check.' >&2
    exit 1
  fi
fi

# Combined list (own + APM-managed) — used only for explicit-name resolution.
ALL_SKILLS=(${REPO_SKILLS[@]+"${REPO_SKILLS[@]}"} ${APM_SKILLS[@]+"${APM_SKILLS[@]}"})

if [ ${#ALL_SKILLS[@]} -eq 0 ]; then
  echo "no skills found under $REPO_ROOT (looking for */SKILL.md)" >&2
  exit 1
fi

# By default, install only APM-managed (third-party) skills. The repo's own
# skills are distributed via the `personal-skills` plugin (see marketplace.json),
# not by symlinking — this avoids double-loading them alongside the plugin.
# Pass skill names explicitly to install specific skills (own or APM).
if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
  SKILLS_TO_INSTALL=(${APM_SKILLS[@]+"${APM_SKILLS[@]}"})
fi
if [ ${#SKILLS_TO_INSTALL[@]} -eq 0 ]; then
  echo "no third-party skills to install (apm.yml declares none)" >&2
  exit 1
fi

# ---- Check (read-only) --------------------------------------------------------

# Resolve sources identically for installation and auditing.
skill_source() {
  if [ -f "$REPO_ROOT/$OWN_SKILLS_REL/$1/SKILL.md" ]; then
    printf '%s\n' "$REPO_ROOT/$OWN_SKILLS_REL/$1"
  elif [ -f "$REPO_ROOT/.agents/skills/$1/SKILL.md" ]; then
    printf '%s\n' "$REPO_ROOT/.agents/skills/$1"
  else
    printf 'No SKILL.md source found for %s\n' "$1" >&2
    return 1
  fi
}

if $CHECK; then
  problems=0
  for TARGET in "${TARGET_DIRS[@]}"; do
    echo "==> $TARGET"
    if [ ! -d "$TARGET" ]; then
      echo "  MISSING    target dir does not exist (nothing installed here)"
      problems=$((problems+1)); echo; continue
    fi
    for skill in "${SKILLS_TO_INSTALL[@]}"; do
      dst="$TARGET/$skill"
      if [ -L "$dst" ] && [ ! -e "$dst" ]; then
        echo "  BROKEN     $skill -> $(readlink "$dst")"; problems=$((problems+1))
      elif [ -L "$dst" ]; then
        if [ ! -f "$dst/SKILL.md" ]; then
          echo "  INVALID    $skill (link target has no SKILL.md)"; problems=$((problems+1))
        elif ! src="$(skill_source "$skill")"; then
          problems=$((problems+1))
        elif [ "$(cd "$dst" && pwd -P)" != "$(cd "$src" && pwd -P)" ]; then
          echo "  WRONG      $skill -> $(readlink "$dst") (expected $src)"; problems=$((problems+1))
        else
          echo "  ok         $skill"
        fi
      elif [ -d "$dst" ]; then
        echo "  COPY       $skill (real dir, not a symlink: won't pick up repo changes)"; problems=$((problems+1))
      else
        echo "  MISSING    $skill"; problems=$((problems+1))
      fi
    done
    # Own skills ship in the personal-skills plugin; a copy here loads them twice.
    for skill in ${REPO_SKILLS[@]+"${REPO_SKILLS[@]}"}; do
      case " ${SKILLS_TO_INSTALL[*]} " in *" $skill "*) continue ;; esac
      if [ -e "$TARGET/$skill" ] || [ -L "$TARGET/$skill" ]; then
        echo "  DUPLICATE  $skill (also ships in the personal-skills plugin)"; problems=$((problems+1))
      fi
    done
    for entry in "$TARGET"/*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      name="$(basename "$entry")"
      case "$name" in
        *.backup.*|*.bak-*) echo "  BACKUP     $name (left by an earlier install; delete when happy)" ;;
      esac
      case " ${SKILLS_TO_INSTALL[*]} ${REPO_SKILLS[*]-} " in *" $name "*) continue ;; esac
      if [ -L "$entry" ] && [ ! -e "$entry" ]; then
        echo "  BROKEN     $name -> $(readlink "$entry") (not from this repo)"; problems=$((problems+1))
      fi
    done
    echo
  done
  if [ "$INSTRUCTIONS_RC" -ne 0 ]; then
    echo "Global instruction links need fixing: ./install-instructions.sh"
  fi
  if [ "$problems" -eq 0 ]; then
    echo "Skills: all good."
  else
    echo "$problems problem(s). Fix: ./install.sh --claude --copilot (and remove any COPY/DUPLICATE dirs)."
  fi
  echo 'Plugins are not checked here: run "claude plugin list" and "copilot plugin list".'
  [ "$problems" -eq 0 ] && [ "$INSTRUCTIONS_RC" -eq 0 ]
  exit $?
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
    if ! src="$(skill_source "$skill")"; then
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
      backup="$dst.backup.$(date +%Y%m%d-%H%M%S)"
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
