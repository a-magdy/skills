#!/usr/bin/env bats

# install-plugins.sh is run against stub `claude` and `copilot` commands that
# record every invocation, so no real CLI or network is touched.
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FIXTURE="$BATS_TEST_TMPDIR/repo"
  BIN="$BATS_TEST_TMPDIR/bin"
  LOG="$BATS_TEST_TMPDIR/calls.log"
  mkdir -p "$FIXTURE" "$BIN"
  cp "$REPO_ROOT/install-plugins.sh" "$FIXTURE/"
  mkdir -p "$FIXTURE/scripts"
  # The JSON parser is exercised through the real shell entry point.
  if [ -f "$REPO_ROOT/scripts/plugin-state.py" ]; then
    cp "$REPO_ROOT/scripts/plugin-state.py" "$FIXTURE/scripts/"
  fi
  export HOME="$BATS_TEST_TMPDIR/home"
  printf '%s\n' \
    '# comment' \
    'acme/tools-marketplace | tools-marketplace | tools | copilot,claude | Example' \
    'acme/extras | extras | extras | copilot | Copilot only' > "$FIXTURE/plugins.list"
  : > "$LOG"
  export LOG REGISTERED="" PLUGINS_JSON='[]' MARKETS_JSON='[]' FAIL_ADD="" FAIL_LIST=""
  for cli in claude copilot; do
    cat > "$BIN/$cli" <<'STUB'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$LOG"
if [ "$1 $2 $3" = "plugin marketplace list" ]; then
  [ -z "$FAIL_LIST" ] || { printf 'authentication failed\n' >&2; exit 1; }
  if [ -n "$REGISTERED" ]; then
    printf '[{"name":"%s","source":"github","repo":"acme/tools-marketplace"}]\n' "$REGISTERED"
  else
    printf '%s\n' "$MARKETS_JSON"
  fi
elif [ "$1 $2" = "plugin list" ]; then
  printf '%s\n' "$PLUGINS_JSON"
elif [ "$1 $2 $3" = "plugin marketplace add" ] && [ -n "$FAIL_ADD" ]; then
  printf 'authentication failed\n' >&2
  exit 1
fi
exit 0
STUB
    chmod +x "$BIN/$cli"
  done
  PATH="$BIN:/usr/bin:/bin"
}

@test "adds each marketplace and installs each plugin for its declared targets" {
  run bash "$FIXTURE/install-plugins.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 installed, 0 skipped, 0 failed"* ]]
  grep -qx 'copilot plugin marketplace add acme/tools-marketplace' "$LOG"
  grep -qx 'claude plugin marketplace add acme/tools-marketplace' "$LOG"
  grep -qx 'copilot plugin install tools@tools-marketplace' "$LOG"
  grep -qx 'claude plugin install tools@tools-marketplace' "$LOG"
  grep -qx 'copilot plugin install extras@extras' "$LOG"
  ! grep -q 'claude plugin install extras' "$LOG"
}

@test "passes no unsupported flags to plugin install" {
  run bash "$FIXTURE/install-plugins.sh"
  ! grep -E 'plugin install .* -' "$LOG"
}

@test "keeps a marketplace that is already registered" {
  export REGISTERED="tools-marketplace"
  run bash "$FIXTURE/install-plugins.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already registered"* ]]
  ! grep -q 'marketplace add acme/tools-marketplace' "$LOG"
  grep -qx 'claude plugin install tools@tools-marketplace' "$LOG"
  grep -qx 'copilot plugin marketplace add acme/extras' "$LOG"
}

@test "target flags limit the run and dry-run executes nothing" {
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 0 ]
  ! grep -q '^copilot ' "$LOG"
  : > "$LOG"
  run bash "$FIXTURE/install-plugins.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would run: claude plugin install tools@tools-marketplace"* ]]
  [ ! -s "$LOG" ]
}

@test "a missing CLI is skipped and a failing install is reported" {
  rm "$BIN/copilot"
  run bash "$FIXTURE/install-plugins.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip copilot: CLI not on PATH"* ]]
  printf '#!/usr/bin/env bash\n[ "$2" = install ] && exit 1\nprintf "[]\\n"\n' > "$BIN/claude"
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"install failed for tools on claude"* ]]
}

@test "local development explicitly registers this checkout and updates its plugin" {
  printf '{\n  "name": "tools-marketplace"\n}\n' > "$FIXTURE/marketplace.json"
  run bash "$FIXTURE/install-plugins.sh" --local
  [ "$status" -eq 0 ]
  grep -qx "claude plugin marketplace add $FIXTURE" "$LOG"
  grep -qx "copilot plugin marketplace add $FIXTURE" "$LOG"
  ! grep -q 'marketplace add acme/tools-marketplace' "$LOG"
  grep -qx 'claude plugin update tools@tools-marketplace' "$LOG"
  ! grep -q 'plugin update extras' "$LOG"
  grep -qx 'copilot plugin marketplace add acme/extras' "$LOG"
}

@test "default own marketplace follows the published manifest" {
  printf '{\n  "name":"tools-marketplace"\n}\n' > "$FIXTURE/marketplace.json"
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 0 ]
  grep -qx 'claude plugin marketplace add acme/tools-marketplace' "$LOG"
}

@test "marketplace authentication failures stop installation instead of being swallowed" {
  export FAIL_ADD=1
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"authentication failed"* ]]
  ! grep -q 'plugin install' "$LOG"
}

@test "marketplace list failure is not mistaken for an absent marketplace" {
  export FAIL_LIST=1
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 1 ]
  ! grep -q 'marketplace add' "$LOG"
}

@test "checks installed enabled Claude and Copilot plugins without mutations" {
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/tools-marketplace"},{"name":"extras","source":"GitHub: acme/extras"}]'
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":true}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 0 ]
  export PLUGINS_JSON='[{"name":"tools","marketplace":"tools-marketplace","enabled":true},{"name":"extras","marketplace":"extras","enabled":true}]'
  run bash "$FIXTURE/install-plugins.sh" --check --copilot
  [ "$status" -eq 0 ]
  ! grep -E 'plugin (install|update)|marketplace (add|remove)' "$LOG"
  [ ! -e "$HOME" ]
}

@test "empty disabled malformed and wrong-source plugin states fail closed" {
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/tools-marketplace"}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* ]]
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":false}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"DISABLED"* ]]
  export PLUGINS_JSON='unrecognized text'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN"* ]]
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":true}]'
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/different"}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"WRONG"* ]]
}

@test "missing CLI and unsupported JSON output are explicit audit failures" {
  rm "$BIN/claude"
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN"* ]]
  export MARKETS_JSON='{}'
  run bash "$FIXTURE/install-plugins.sh" --check --copilot
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN"* ]]
}

@test "project-disabled Claude plugins are not reported as enabled" {
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/tools-marketplace"}]'
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":true,"projectEnabled":false}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"DISABLED"* ]]
}

@test "unverifiable enabled state is unknown and native load errors fail the audit" {
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/tools-marketplace"}]'
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace"}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNKNOWN"* ]]
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":true,"errors":["private diagnostic omitted"]}]'
  run bash "$FIXTURE/install-plugins.sh" --check --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"load errors"* ]]
  [[ "$output" != *"private diagnostic omitted"* ]]
}

@test "local checks verify the checkout and never replace an existing remote source" {
  printf '{\n  "name":"tools-marketplace"\n}\n' > "$FIXTURE/marketplace.json"
  export MARKETS_JSON='[{"name":"tools-marketplace","source":"github","repo":"acme/tools-marketplace"}]'
  export PLUGINS_JSON='[{"id":"tools@tools-marketplace","enabled":true}]'
  run bash "$FIXTURE/install-plugins.sh" --check --local --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"WRONG"* ]]
  ! grep -E 'marketplace (add|remove)' "$LOG"
  export MARKETS_JSON="[{\"name\":\"tools-marketplace\",\"source\":\"directory\",\"path\":\"$FIXTURE\"}]"
  run bash "$FIXTURE/install-plugins.sh" --check --local --claude
  [ "$status" -eq 0 ]
}
