#!/usr/bin/env bash
# Stamp the single source-of-truth version (the VERSION file) into every manifest
# that carries a version, so they never drift.
#
# Updates: apm.yml, marketplace.json, .claude-plugin/marketplace.json,
#          plugin/plugin.json, plugin/.claude-plugin/plugin.json
#
# Usage:
#   ./scripts/sync-version.sh            # stamp VERSION into all manifests
#   ./scripts/sync-version.sh 1.2.0      # set VERSION to 1.2.0, then stamp
#   ./scripts/sync-version.sh --check    # verify all manifests match VERSION (CI)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CHECK=false
case "${1:-}" in
  --check) CHECK=true ;;
  "") ;;
  *) printf '%s\n' "$1" > VERSION ;;  # explicit new version
esac

[ -f VERSION ] || { echo "no VERSION file at repo root" >&2; exit 1; }
VERSION="$(tr -d '[:space:]' < VERSION)"

# JSON manifests: top-level "version", or each entry under a "plugins" array.
JSON_MANIFESTS=(
  marketplace.json
  .claude-plugin/marketplace.json
  plugin/plugin.json
  plugin/.claude-plugin/plugin.json
)

python3 - "$VERSION" "$CHECK" "${JSON_MANIFESTS[@]}" <<'PY'
import json, sys

version, check_flag = sys.argv[1], sys.argv[2] == "True"
files = sys.argv[3:]
drift = []

for path in files:
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        continue

    def stamp(obj):
        changed = False
        if "version" in obj and obj["version"] != version:
            if check_flag:
                drift.append(f"{path}: {obj['version']} != {version}")
            else:
                obj["version"] = version; changed = True
        for p in obj.get("plugins", []):
            if p.get("version") != version:
                if check_flag:
                    drift.append(f"{path} (plugin {p.get('name')}): {p.get('version')} != {version}")
                else:
                    p["version"] = version; changed = True
        return changed

    if stamp(data) and not check_flag:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(f"stamped {version} -> {path}")

if drift:
    print("VERSION drift:\n  " + "\n  ".join(drift), file=sys.stderr)
    sys.exit(1)
PY

# apm.yml: a top-level `version:` line.
if [ -f apm.yml ]; then
  if $CHECK; then
    grep -qE "^version:[[:space:]]*${VERSION}$" apm.yml || {
      echo "VERSION drift:\n  apm.yml version != ${VERSION}" >&2; exit 1; }
  else
    # portable in-place edit (BSD/GNU sed)
    tmp="$(mktemp)"
    sed -E "s/^version:.*/version: ${VERSION}/" apm.yml > "$tmp" && mv "$tmp" apm.yml
    echo "stamped ${VERSION} -> apm.yml"
  fi
fi

$CHECK && echo "OK: all manifests match VERSION ${VERSION}" || echo "Done. Version ${VERSION} synced."
