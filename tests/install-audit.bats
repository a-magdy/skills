#!/usr/bin/env bats

setup() {
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  TARGET="$BATS_TEST_TMPDIR/installed"
  SKILLS="$FIXTURE/plugin/skills"
  mkdir -p "$SKILLS/example" "$TARGET"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$FIXTURE/install.sh"
  printf '# Example\n' > "$SKILLS/example/SKILL.md"
  export HOME="$BATS_TEST_TMPDIR/home"
}

apm_fixture() {
  mkdir -p "$FIXTURE/.agents/skills/fetched" "$FIXTURE/apm_modules" "$BATS_TEST_TMPDIR/bin"
  printf 'dependencies:\n  apm:\n  - acme/skills/skills/fetched\n' > "$FIXTURE/apm.yml"
  printf 'lock: original\n' > "$FIXTURE/apm.lock.yaml"
  printf '# Stale\n' > "$FIXTURE/.agents/skills/fetched/SKILL.md"
  cat > "$BATS_TEST_TMPDIR/bin/apm" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [ "$*" = "install --help" ]; then printf '%s\n' '--frozen'; exit 0; fi
[ "$*" = "install --frozen" ] || exit 2
printf '# Reconciled\n' > .agents/skills/fetched/SKILL.md
STUB
  chmod +x "$BATS_TEST_TMPDIR/bin/apm"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
}

@test "reconciles an updated lock even when generated directories already exist" {
  apm_fixture
  mkdir -p "$FIXTURE/.agents/skills/removed"
  printf '# Removed dependency\n' > "$FIXTURE/.agents/skills/removed/SKILL.md"
  printf 'lock: updated\n' > "$FIXTURE/apm.lock.yaml"
  run bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 0 ]
  [ "$(cat "$TARGET/fetched/SKILL.md")" = '# Reconciled' ]
  [ "$(cat "$FIXTURE/apm.lock.yaml")" = 'lock: updated' ]
  [ ! -e "$TARGET/removed" ]
}

@test "requires APM for existing dependencies but not explicitly named own skills" {
  apm_fixture
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"APM is not on PATH"* ]]
  [ ! -e "$TARGET/fetched" ]
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --target "$TARGET" example
  [ "$status" -eq 0 ]
}

@test "check and dry-run neither invoke APM nor change source or destination state" {
  apm_fixture
  printf '#!/bin/bash\nprintf called > "%s"\nexit 1\n' "$BATS_TEST_TMPDIR/apm-called" > "$BATS_TEST_TMPDIR/bin/apm"
  run bash "$FIXTURE/install.sh" --dry-run --target "$TARGET"
  [ "$status" -eq 0 ]
  run bash "$FIXTURE/install.sh" --check --target "$TARGET"
  [ "$status" -eq 1 ]
  [ ! -e "$BATS_TEST_TMPDIR/apm-called" ]
  [ ! -e "$TARGET/fetched" ]
  [ ! -e "$HOME" ]
  [ "$(cat "$FIXTURE/.agents/skills/fetched/SKILL.md")" = '# Stale' ]
  [ "$(cat "$FIXTURE/apm.lock.yaml")" = 'lock: original' ]
}

@test "a dry run before the first fetch lists the skills it would fetch" {
  apm_fixture
  rm -rf "$FIXTURE/.agents"
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --dry-run --target "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"would fetch and symlink: fetched"* ]]
  [[ "$output" != *"Unavailable"* ]]
  [ ! -e "$TARGET/fetched" ]
}

@test "an APM failure cannot become a native-skill-only success" {
  apm_fixture
  printf '#!/bin/bash\nif [ "$2" = "--help" ]; then printf -- "--frozen"; else exit 1; fi\n' > "$BATS_TEST_TMPDIR/bin/apm"
  run bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [ ! -e "$TARGET/fetched" ]
}

@test "missing lock and unsupported frozen mode fail before installing skills" {
  apm_fixture
  rm "$FIXTURE/apm.lock.yaml"
  run bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Restore the committed lockfile"* ]]
  printf 'lock: original\n' > "$FIXTURE/apm.lock.yaml"
  printf '#!/bin/bash\nprintf "legacy help\\n"\n' > "$BATS_TEST_TMPDIR/bin/apm"
  run bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Upgrade APM"* ]]
  [ ! -e "$TARGET/fetched" ]
}

@test "a claimed successful APM run with missing output fails explicitly" {
  apm_fixture
  rm "$FIXTURE/.agents/skills/fetched/SKILL.md"
  printf '#!/bin/bash\nprintf -- "--frozen\\n"\n' > "$BATS_TEST_TMPDIR/bin/apm"
  run bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"APM did not deploy declared skills"* ]]
  [ ! -e "$TARGET/fetched" ]
}

@test "an unavailable explicitly requested skill cannot report a successful install" {
  apm_fixture
  run bash "$FIXTURE/install.sh" --target "$TARGET" unknown-skill
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unavailable: unknown-skill"* ]]
  [ ! -e "$TARGET/unknown-skill" ]
}

@test "full check reaches plugins even when APM sources are unavailable" {
  cp "$BATS_TEST_DIRNAME/../install-plugins.sh" "$FIXTURE/"
  mkdir -p "$FIXTURE/scripts"
  if [ -f "$BATS_TEST_DIRNAME/../scripts/plugin-state.py" ]; then
    cp "$BATS_TEST_DIRNAME/../scripts/plugin-state.py" "$FIXTURE/scripts/"
  fi
  printf 'dependencies:\n  apm:\n  - acme/skills/skills/absent\n' > "$FIXTURE/apm.yml"
  printf 'acme/tools | tools | tools | claude | Example\n' > "$FIXTURE/plugins.list"
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --check --claude --with-plugins
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN"* ]]
  [[ "$output" == *"claude"* ]]
}

@test "accepts a relative link resolving to the expected source" {
  ln -s ../repo/plugin/skills/example "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok         example"* ]]
}

@test "rejects an existing skill in an old checkout without changing the link" {
  mkdir -p "$BATS_TEST_TMPDIR/old/example"
  cp "$SKILLS/example/SKILL.md" "$BATS_TEST_TMPDIR/old/example/SKILL.md"
  ln -s "$BATS_TEST_TMPDIR/old/example" "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 1 ]
  [[ "$output" == *"WRONG"* ]]
  [ "$(readlink "$TARGET/example")" = "$BATS_TEST_TMPDIR/old/example" ]
}

@test "rejects a linked empty directory or regular file" {
  mkdir "$BATS_TEST_TMPDIR/empty"
  ln -s "$BATS_TEST_TMPDIR/empty" "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 1 ]
  [[ "$output" == *"INVALID"* ]]
  rm "$TARGET/example"
  ln -s "$SKILLS/example/SKILL.md" "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 1 ]
  [[ "$output" == *"INVALID"* ]]
}

@test "still reports broken links" {
  ln -s "$BATS_TEST_TMPDIR/missing" "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 1 ]
  [[ "$output" == *"BROKEN"* ]]
}

@test "uses the APM source when no native skill exists" {
  mkdir -p "$FIXTURE/.agents/skills/example"
  mv "$SKILLS/example/SKILL.md" "$FIXTURE/.agents/skills/example/SKILL.md"
  ln -s "$FIXTURE/.agents/skills/example" "$TARGET/example"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET" example
  [ "$status" -eq 0 ]
}

@test "reports declared APM skills that were never fetched" {
  printf 'dependencies:\n  apm:\n  - acme/skills/skills/fetched\n  - acme/skills/skills/absent\n' > "$FIXTURE/apm.yml"
  mkdir -p "$FIXTURE/.agents/skills/fetched"
  printf '# Fetched\n' > "$FIXTURE/.agents/skills/fetched/SKILL.md"
  run bash "$FIXTURE/install.sh" --check --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not fetched: absent"* ]]
}

@test "fails clearly when APM is missing and skills are unfetched" {
  printf 'dependencies:\n  apm:\n  - acme/skills/skills/absent\n' > "$FIXTURE/apm.yml"
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --target "$TARGET"
  [ "$status" -eq 1 ]
  [[ "$output" == *"APM is not on PATH"* ]]
  PATH="/usr/bin:/bin" run /bin/bash "$FIXTURE/install.sh" --dry-run --target "$TARGET" example
  [ "$status" -eq 0 ]
}
