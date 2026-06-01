# personal/skills

This repo holds four Claude Code skills for managing long, multi-day sessions. Skills live under `~/.claude/skills/` and auto-activate when Claude recognises their trigger phrases.

## Repo layout

```
skills/
├─ CLAUDE.md                        ← this file
├─ README.md                        ← user-facing overview and install guide
├─ install.sh                       ← installs (symlink or copy) into ~/.claude/skills/
├─ decision-log/SKILL.md
├─ session-carry-forward/
│   ├─ SKILL.md
│   └─ references/template.md      ← the carry-forward doc template
├─ session-resume/SKILL.md
└─ session-status/SKILL.md
```

## Skill format

Each skill is a folder with a `SKILL.md` at its root. The SKILL.md frontmatter has `name:` and `description:` fields — Claude uses `description` to decide when to trigger the skill. A `references/` subdir holds supporting docs (templates, checklists, examples) that the SKILL.md can reference.

## Install

```sh
./install.sh          # symlink all into ~/.claude/skills/
./install.sh --dry-run
```

Existing real dirs at the target are backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` before being replaced. Existing symlinks are silently re-pointed.

## Working on a skill

Because `~/.claude/skills/` points here via symlinks, edits to any skill file take effect immediately in Claude — no re-install needed.

When adding a new skill:
1. Create `<skill-name>/SKILL.md` with `name:`, `description:`, and the skill body.
2. Add a one-line entry to the skills table in `README.md`.
3. Run `./install.sh <skill-name>` to symlink it.
4. Test by triggering it in a Claude session with one of its stated trigger phrases.

## Testing and evals

The `skill-creator` skill (at `~/.claude/skills/skill-creator/`) can run evals against a skill. Point it at a SKILL.md and a set of trigger / non-trigger prompts to measure precision and recall.

## Conventions

- Trigger phrases are listed in the SKILL.md `## When to invoke` section and summarised in `README.md`.
- Skills are non-destructive by default — only `session-carry-forward` and `decision-log` write files, and neither commits.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers are produced by these skills.
