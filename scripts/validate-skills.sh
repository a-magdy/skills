#!/usr/bin/env bash
# Repo consistency checks for own skills. Run locally or in CI; read-only.
#
# The list of own skills is derived from plugin/skills/ (what the plugin ships)
# and from top-level dirs holding a SKILL.md, so a new skill is covered without
# editing this script.
#
# Usage: ./scripts/validate-skills.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
err() { echo "FAIL  $*"; fail=1; }

# 1. Every plugin/skills entry is a symlink that resolves to a dir with a SKILL.md.
for link in plugin/skills/*; do
  name="$(basename "$link")"
  [ -L "$link" ] || { err "plugin/skills/$name is not a symlink"; continue; }
  [ -f "$link/SKILL.md" ] || err "plugin/skills/$name does not resolve to a dir with SKILL.md"
done

# 2. Every top-level skill dir is shipped by the plugin.
for f in */SKILL.md; do
  name="$(dirname "$f")"
  [ -L "plugin/skills/$name" ] || err "$name has a SKILL.md but no plugin/skills/$name symlink"
done

# 3. Frontmatter: name equals folder, description present and <= 1024 chars.
python3 - <<'PY' || fail=1
import glob, os, re, sys

bad = 0
for path in sorted(glob.glob("*/SKILL.md")):
    folder = os.path.dirname(path)
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        print(f"FAIL  {path}: no frontmatter"); bad = 1; continue
    fm = m.group(1)
    name = re.search(r"^name:\s*(.+)$", fm, re.M)
    if not name or name.group(1).strip().strip("'\"") != folder:
        print(f"FAIL  {path}: name must equal folder '{folder}'"); bad = 1
    desc = re.search(r"^description:\s*(.*?)(?=^\S[\w-]*:|\Z)", fm, re.S | re.M)
    body = " ".join(desc.group(1).split()) if desc else ""
    body = re.sub(r"^[>|][+-]?\s*", "", body)
    if not body:
        print(f"FAIL  {path}: empty description"); bad = 1
    elif len(body) > 1024:
        print(f"FAIL  {path}: description is {len(body)} chars (max 1024)"); bad = 1
sys.exit(bad)
PY

# 4. Each own skill is listed in the README and the triggers doc.
for f in */SKILL.md; do
  name="$(dirname "$f")"
  grep -q "\`$name\`" README.md        || err "$name is not listed in README.md"
  grep -q "\`$name\`" docs/TRIGGERS.md || err "$name is not listed in docs/TRIGGERS.md"
done

# 5. The Claude and Copilot hook configs must stay identical.
cmp -s plugin/hooks/hooks.json plugin/com.github.copilot/hooks/hooks.json \
  || err "plugin/hooks/hooks.json and plugin/com.github.copilot/hooks/hooks.json differ"

# 6. Privacy: no real home paths, and session handoffs stay untracked.
#    Placeholders such as /Users/<name> and the fictional /Users/jane are allowed.
if git ls-files -z | xargs -0 grep -nIE '/(Users|home)/[a-z][a-z0-9_-]+' 2>/dev/null \
     | grep -vE '/(Users|home)/(jane|runner)\b' | grep -v '^scripts/validate-skills.sh:'; then
  err "absolute home path in a tracked file (see lines above)"
fi
if [ -n "$(git ls-files carry-forwards)" ]; then
  err "carry-forwards/ is tracked; it must stay local"
fi

[ "$fail" -eq 0 ] && echo "OK: skills, manifests and docs are consistent"
exit "$fail"
