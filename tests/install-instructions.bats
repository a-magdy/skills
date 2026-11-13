#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export CLAUDE_CONFIG_DIR="$HOME/custom-claude"
  export COPILOT_HOME="$HOME/custom-copilot"
  SOURCE_FILE="$REPO_ROOT/config/global/AGENTS.md"
  INSTALLER="$REPO_ROOT/install-instructions.sh"
}

@test "installs both clients with overrides and preserves identical links on rerun" {
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  [ "$(readlink "$CLAUDE_CONFIG_DIR/CLAUDE.md")" = "$SOURCE_FILE" ]
  [ "$(readlink "$COPILOT_HOME/copilot-instructions.md")" = "$SOURCE_FILE" ]
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  [ "$(find "$HOME" -name '*.backup.*' | wc -l | tr -d ' ')" = 0 ]
  run bash "$INSTALLER" --check
  [ "$status" -eq 0 ]
}

@test "uses default config roots when overrides are unset" {
  unset CLAUDE_CONFIG_DIR COPILOT_HOME
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$SOURCE_FILE" ]
  [ "$(readlink "$HOME/.copilot/copilot-instructions.md")" = "$SOURCE_FILE" ]
}

@test "backs up files and broken symlinks without changing their contents" {
  mkdir -p "$CLAUDE_CONFIG_DIR" "$COPILOT_HOME"
  printf 'original\n' > "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  ln -s "$HOME/missing.md" "$COPILOT_HOME/copilot-instructions.md"
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  backups=("$CLAUDE_CONFIG_DIR"/CLAUDE.md.backup.*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(cat "${backups[0]}")" = original ]
  backups=("$COPILOT_HOME"/copilot-instructions.md.backup.*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(readlink "${backups[0]}")" = "$HOME/missing.md" ]
}

@test "refuses directories before modifying the other client" {
  mkdir -p "$COPILOT_HOME/copilot-instructions.md"
  run bash "$INSTALLER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing to replace"* ]]
  [ ! -e "$CLAUDE_CONFIG_DIR" ]
  [ -d "$COPILOT_HOME/copilot-instructions.md" ]
}

@test "dry-run and failing check do not write anything" {
  run bash "$INSTALLER" --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$HOME" ]
  run bash "$INSTALLER" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing or incorrect"* ]]
  [ ! -e "$HOME" ]
}

@test "client selection leaves the other client untouched" {
  run bash "$INSTALLER" --copilot
  [ "$status" -eq 0 ]
  [ ! -e "$CLAUDE_CONFIG_DIR" ]
  [ -L "$COPILOT_HOME/copilot-instructions.md" ]
}

@test "invalid options and conflicting modes fail explicitly" {
  run bash "$INSTALLER" --invalid
  [ "$status" -eq 2 ]
  run bash "$INSTALLER" --check --dry-run
  [ "$status" -eq 2 ]
  [ ! -e "$HOME" ]
}

@test "missing preference source fails without writing destinations" {
  cp "$INSTALLER" "$BATS_TEST_TMPDIR/install-instructions.sh"
  run bash "$BATS_TEST_TMPDIR/install-instructions.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Global instructions missing"* ]]
  [ ! -e "$HOME" ]
}

@test "skill-only installs remain opt-in and main installer defaults select both clients" {
  run bash "$REPO_ROOT/install.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Would back up any existing file and link"* ]]
  run bash "$REPO_ROOT/install.sh" --dry-run --with-instructions
  [ "$status" -eq 0 ]
  [[ "$output" == *"$CLAUDE_CONFIG_DIR/CLAUDE.md"* ]]
  [[ "$output" == *"$COPILOT_HOME/copilot-instructions.md"* ]]
  [ ! -e "$HOME" ]
}

@test "main installer dry-run and check forward client selection without writing" {
  run bash "$REPO_ROOT/install.sh" --copilot --dry-run --with-instructions
  [ "$status" -eq 0 ]
  [[ "$output" == *"$COPILOT_HOME/copilot-instructions.md"* ]]
  [[ "$output" != *"$CLAUDE_CONFIG_DIR/CLAUDE.md"* ]]
  [ ! -e "$HOME" ]
  run bash "$REPO_ROOT/install.sh" --copilot --check --with-instructions
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing or incorrect instruction link"* ]]
  [ ! -e "$HOME" ]
}
