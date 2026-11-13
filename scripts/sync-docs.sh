#!/usr/bin/env bash
# Regenerate the own-skill tables in README.md and docs/TRIGGERS.md from the
# frontmatter of every plugin/skills/<name>/SKILL.md, so adding or editing a
# skill never needs a hand-edited table.
#
# Each target file holds one generated block between these markers:
#   <!-- BEGIN own-skills -->  ...  <!-- END own-skills -->
# Everything outside the markers is hand-written and left alone.
#
# Usage:
#   ./scripts/sync-docs.sh           # rewrite the generated blocks
#   ./scripts/sync-docs.sh --check   # exit 1 if a block is out of date (CI)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

case "${1:-}" in
  ""|--check) ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

python3 - "${1:-}" <<'PY'
import glob, os, re, sys

check = sys.argv[1] == "--check"
BEGIN, END = "<!-- BEGIN own-skills -->", "<!-- END own-skills -->"


def load(path):
    text = open(path, encoding="utf-8").read()
    fm = re.match(r"---\n(.*?)\n---\n", text, re.S).group(1)
    fields = dict(re.findall(r"^([\w-]+):\s*(.*)$", fm, re.M))
    return {
        "name": os.path.basename(os.path.dirname(path)),
        "description": fields.get("description", "").strip(),
        "manual": fields.get("disable-model-invocation", "").strip() == "true",
    }


def cell(text):
    return text.replace("|", "\\|").replace("<", "&lt;").replace(">", "&gt;")


def summary(desc):
    """First sentence of the description."""
    return re.split(r"(?<=[.!?])\s", desc, maxsplit=1)[0]


def triggers(desc):
    """Quoted example phrases from the description, else its 'Use when' clause."""
    scope = re.split(r"\bNot for\b", desc)[0]
    phrases = re.findall(r'"([^"]{3,80})"', scope)
    if len(phrases) >= 3:
        return " · ".join(f'"{p}"' for p in phrases)
    use = re.search(r"\bUse (?:this )?when(?:ever)?\b[^.;]*", scope)
    return use.group(0).strip() if use else summary(desc)


skills = [load(p) for p in sorted(glob.glob("plugin/skills/*/SKILL.md"))]


def readme_block():
    rows = ["| Skill | Invocation | What it does |", "|---|---|---|"]
    for s in skills:
        how = f"`/{s['name']}`" if s["manual"] else "auto"
        link = f"[`{s['name']}`](./plugin/skills/{s['name']}/)"
        rows.append(f"| {link} | {how} | {cell(summary(s['description']))} |")
    return "\n".join(rows)


def triggers_block():
    rows = ["| Skill | Example prompts |", "|---|---|"]
    for s in skills:
        rows.append(f"| `{s['name']}` | {cell(triggers(s['description']))} |")
    return "\n".join(rows)


stale = []
for path, block in (("README.md", readme_block()), ("docs/TRIGGERS.md", triggers_block())):
    text = open(path, encoding="utf-8").read()
    if text.count(BEGIN) != 1 or text.count(END) != 1:
        sys.exit(f"{path}: expected exactly one '{BEGIN}' ... '{END}' block")
    head, rest = text.split(BEGIN)
    _, tail = rest.split(END)
    new = f"{head}{BEGIN}\n{block}\n{END}{tail}"
    if new == text:
        continue
    if check:
        stale.append(path)
    else:
        open(path, "w", encoding="utf-8").write(new)
        print(f"updated {path}")

if stale:
    sys.exit("out of date: " + ", ".join(stale) + " (run ./scripts/sync-docs.sh)")
print("OK: skill tables match plugin/skills/" if check else "Done.")
PY
