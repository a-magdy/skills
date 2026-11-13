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
  printf '%s\n' \
    '# comment' \
    'acme/tools-marketplace | tools-marketplace | tools | copilot,claude | Example' \
    'acme/extras | extras | extras | copilot | Copilot only' > "$FIXTURE/plugins.list"
  : > "$LOG"
  export LOG REGISTERED=""
  for cli in claude copilot; do
    cat > "$BIN/$cli" <<'STUB'
#!/usr/bin/env bash
echo "$(basename "$0") $*" >> "$LOG"
if [ "$1 $2 $3" = "plugin marketplace list" ]; then
  printf '%s\n' $REGISTERED
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
  ! grep -q 'plugin install' "$LOG"
}

@test "a missing CLI is skipped and a failing install is reported" {
  rm "$BIN/copilot"
  run bash "$FIXTURE/install-plugins.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip copilot: CLI not on PATH"* ]]
  printf '#!/usr/bin/env bash\n[ "$2" = install ] && exit 1\nexit 0\n' > "$BIN/claude"
  run bash "$FIXTURE/install-plugins.sh" --claude
  [ "$status" -eq 1 ]
  [[ "$output" == *"install failed for tools on claude"* ]]
}
