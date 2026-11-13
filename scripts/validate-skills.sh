#!/usr/bin/env bash
# Repo consistency checks for own skills. Run locally or in CI; read-only.
#
# Own skills are every plugin/skills/<name>/ folder, so a new skill is covered
# without editing this script.
#
# Usage: ./scripts/validate-skills.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

fail=0
err() { echo "FAIL  $*"; fail=1; }

# 1. Every plugin/skills entry is a real folder with a SKILL.md. Symlinks are
#    rejected: a link pointing outside the plugin may not survive being copied
#    into a CLI's plugin cache.
for entry in plugin/skills/*; do
  name="$(basename "$entry")"
  if [ -L "$entry" ]; then err "plugin/skills/$name is a symlink; own skills must be real folders"; continue; fi
  [ -d "$entry" ] || { err "plugin/skills/$name is not a folder"; continue; }
  [ -f "$entry/SKILL.md" ] || err "plugin/skills/$name has no SKILL.md"
done

# 2. No skill folders outside plugin/skills (the old root-level layout).
for stray in */SKILL.md; do
  [ -f "$stray" ] || continue
  err "$(dirname "$stray")/ holds a SKILL.md at the repo root; move it to plugin/skills/"
done

# 3. Frontmatter: name equals folder; description is a plain one-line YAML
#    scalar (no quoting, no folded block) of at most 1024 characters.
python3 - <<'PY' || fail=1
import glob, os, re, sys

bad = 0
def fail(path, msg):
    global bad
    print(f"FAIL  {path}: {msg}"); bad = 1

for path in sorted(glob.glob("plugin/skills/*/SKILL.md")):
    folder = os.path.basename(os.path.dirname(path))
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        fail(path, "no frontmatter"); continue
    lines = m.group(1).split("\n")
    fields = {}
    for line in lines:
        km = re.match(r"^([\w-]+):\s*(.*)$", line)
        if not km:
            fail(path, f"frontmatter line is not 'key: value' on one line: {line[:40]!r}"); continue
        fields[km.group(1)] = km.group(2).strip()
    if fields.get("name") != folder:
        fail(path, f"name must equal folder '{folder}'")
    desc = fields.get("description", "")
    if not desc:
        fail(path, "empty description")
    elif desc[0] in "'\">|":
        fail(path, "description must be a plain one-line value (no quotes, no '>' or '|' block)")
    elif ": " in desc or " #" in desc:
        fail(path, "description contains ': ' or ' #', which breaks plain YAML; rephrase it")
    elif len(desc) > 1024:
        fail(path, f"description is {len(desc)} chars (max 1024)")
sys.exit(bad)
PY

# 4. The generated skill tables in README.md and docs/TRIGGERS.md are current.
./scripts/sync-docs.sh --check || fail=1

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
