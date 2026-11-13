#!/usr/bin/env bats

# Each test runs the validator against a throwaway copy of the tracked files.
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIXTURE"
  (cd "$REPO_ROOT" && git ls-files -z --cached --others --exclude-standard | tar -cf - --null -T - 2>/dev/null) \
    | tar -xf - -C "$FIXTURE"
  cd "$FIXTURE"
  git init -q .
  git add -A
  SKILL="plugin/skills/example-skill"
}

add_skill() {
  mkdir -p "$SKILL"
  printf -- '---\nname: example-skill\ndescription: %s\n---\n\n# Example\n' "$1" > "$SKILL/SKILL.md"
  git add -A
}

@test "the repository as committed passes" {
  run ./scripts/validate-skills.sh
  [ "$status" -eq 0 ]
}

@test "a new skill fails until the docs are regenerated, then passes" {
  add_skill 'Does an example thing. Use when the user says "run the example", "do the demo" or "show a sample".'
  run ./scripts/validate-skills.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"out of date"* ]]
  ./scripts/sync-docs.sh
  run ./scripts/validate-skills.sh
  [ "$status" -eq 0 ]
  grep -q '`example-skill`' README.md
  grep -q '"run the example"' docs/TRIGGERS.md
}

@test "rejects a name that differs from the folder" {
  add_skill 'Does an example thing.'
  sed -i.bak 's/^name: example-skill/name: other/' "$SKILL/SKILL.md" && rm "$SKILL/SKILL.md.bak"
  ./scripts/sync-docs.sh
  run ./scripts/validate-skills.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"name must equal folder"* ]]
}

@test "rejects quoted, folded or colon-bearing descriptions" {
  add_skill "'Quoted description.'"
  run ./scripts/validate-skills.sh
  [[ "$output" == *"plain one-line value"* ]]
  add_skill 'Has a colon: which breaks plain YAML.'
  run ./scripts/validate-skills.sh
  [[ "$output" == *"breaks plain YAML"* ]]
}

@test "rejects a skill folder at the repo root and a symlinked skill" {
  mkdir stray && printf -- '---\nname: stray\ndescription: Stray.\n---\n' > stray/SKILL.md
  run ./scripts/validate-skills.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"move it to plugin/skills/"* ]]
  rm -r stray
  ln -s ../../docs plugin/skills/linked
  run ./scripts/validate-skills.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"is a symlink"* ]]
}

@test "rejects hook configs that differ and home paths in tracked files" {
  printf '{}\n' > plugin/com.github.copilot/hooks/hooks.json
  run ./scripts/validate-skills.sh
  [[ "$output" == *"hooks.json differ"* ]]
  git checkout -q -- plugin 2>/dev/null || true
  # Built from parts so this test file does not itself contain a home path.
  printf 'see /%s/someone/project\n' Users > leak.md
  git add leak.md
  run ./scripts/validate-skills.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute home path"* ]]
}
