# personal/skills

This repo holds Claude Code skills for managing long, multi-day sessions, plus third-party skills managed via [APM](https://github.com/microsoft/apm). Skills live under `~/.claude/skills/` and auto-activate when Claude recognises their trigger phrases.

## Repo layout

```
skills/
├─ CLAUDE.md                        ← this file
├─ README.md                        ← user-facing overview and install guide
├─ install.sh                       ← installs (symlink or copy) into ~/.claude/skills/
├─ apm.yml                          ← APM manifest (third-party skill dependencies)
├─ apm.lock.yaml                    ← APM lockfile (pinned commits + hashes)
├─ .gitignore                       ← ignores apm_modules/, .claude/skills/, .agents/skills/
├─ decision-log/SKILL.md
├─ cinematic-static-site/SKILL.md
├─ multi-variant-site-design/SKILL.md
├─ session-carry-forward/
│   ├─ SKILL.md
│   └─ references/template.md      ← the carry-forward doc template
├─ session-resume/SKILL.md
├─ session-status/SKILL.md
├─ .claude/skills/                  ← APM-managed skills (generated, gitignored)
└─ .agents/skills/                  ← APM-managed skills for Copilot (generated, gitignored)
```

## Skill format

Each skill is a folder with a `SKILL.md` at its root. The SKILL.md frontmatter has `name:` and `description:` fields — Claude uses `description` to decide when to trigger the skill. A `references/` subdir holds supporting docs (templates, checklists, examples) that the SKILL.md can reference.

## Install

```sh
./install.sh          # symlink all (native + APM-managed) into ~/.claude/skills/
./install.sh --copilot # also install into ~/.copilot/skills/ (Copilot CLI)
./install.sh --dry-run
```

The script automatically runs `apm install` if APM dependencies haven't been fetched yet.

Existing real dirs at the target are backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` before being replaced. Existing symlinks are silently re-pointed.

## APM (Agent Package Manager)

Third-party skills from `anthropics/skills` are declared in `apm.yml` and resolved by [APM](https://github.com/microsoft/apm). Running `apm install` fetches them into `.claude/skills/` and `.agents/skills/` (both gitignored). The lockfile `apm.lock.yaml` pins exact commits and content hashes.

Currently managed via APM:
- `frontend-design`
- `mcp-builder`
- `pdf`
- `pptx`
- `skill-creator`
- `xlsx`

To update these to the latest upstream: `apm update`.

## Working on a skill

Because `~/.claude/skills/` points here via symlinks, edits to any skill file take effect immediately in Claude — no re-install needed.

When adding a new skill:
1. Create `<skill-name>/SKILL.md` with `name:`, `description:`, and the skill body.
2. Add a one-line entry to the skills table in `README.md`.
3. Run `./install.sh <skill-name>` to symlink it.
4. Test by triggering it in a Claude session with one of its stated trigger phrases.

## Testing and evals

The `skill-creator` skill (managed via APM) can run evals against a skill. Point it at a SKILL.md and a set of trigger / non-trigger prompts to measure precision and recall.

## Conventions

- Trigger phrases are listed in the SKILL.md `## When to invoke` section and summarised in `README.md`.
- Skills are non-destructive by default — only `session-carry-forward` and `decision-log` write files, and neither commits.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers are produced by these skills.
