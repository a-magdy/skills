#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIXTURE/scripts"
  cp "$REPO_ROOT/scripts/sync-version.sh" "$FIXTURE/scripts/sync-version.sh"
  printf '1.0.0\n' > "$FIXTURE/VERSION"
  printf '{"version":"0.9.0"}\n' > "$FIXTURE/marketplace.json"
  printf 'version: 1.0.0\n' > "$FIXTURE/apm.yml"
}

@test "check reports JSON version drift without rewriting manifests" {
  before="$(cat "$FIXTURE/marketplace.json")"
  run bash "$FIXTURE/scripts/sync-version.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"VERSION drift"* ]]
  [ "$(cat "$FIXTURE/marketplace.json")" = "$before" ]
}