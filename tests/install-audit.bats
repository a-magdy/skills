#!/usr/bin/env bats

setup() {
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  TARGET="$BATS_TEST_TMPDIR/installed"
  SKILLS="$FIXTURE/plugin/skills"
  mkdir -p "$SKILLS/example" "$TARGET"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$FIXTURE/install.sh"
  printf '# Example\n' > "$SKILLS/example/SKILL.md"
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
