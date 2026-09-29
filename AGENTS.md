# personal/skills

This repo holds hand-written skills for managing long, multi-day sessions, plus third-party skills and whole plugins pulled from public repos. It is **dual-target**: everything deploys to both Claude Code (`~/.claude/skills/`) and Copilot CLI (`~/.copilot/skills/`). Skills auto-activate when the agent recognises their trigger phrases.

Agent context deploys at **two layers** (see `README.md` for the full explanation):

1. **Skills** — a `SKILL.md` folder, symlinked into the agent skill dirs by `install.sh`. Sources: native dirs in this repo + APM deps in `apm.yml`.
2. **Whole plugins / harnesses** — full plugins (hooks, companion tools, MCP/LSP servers) installed natively via each CLI's plugin system by `install-plugins.sh`, listed in `plugins.list`. A plain symlink cannot express these.

## Repo layout

```
skills/
├─ AGENTS.md                        ← this file
├─ README.md                        ← user-facing overview and install guide
├─ install.sh                       ← symlink skills into ~/.claude & ~/.copilot (layer 1)
├─ install-plugins.sh               ← install whole plugins via each CLI (layer 2)
├─ plugins.list                     ← whole-plugin manifest (pipe-delimited)
├─ apm.yml                          ← APM manifest (third-party skill dependencies)
├─ apm.lock.yaml                    ← APM lockfile (pinned commits + hashes)
├─ .gitignore                       ← ignores apm_modules/, .agents/skills/
├─ decision-log/SKILL.md
├─ cinematic-static-site/SKILL.md
├─ multi-variant-site-design/SKILL.md
├─ session-carry-forward/
│   ├─ SKILL.md
│   └─ references/template.md      ← the carry-forward doc template
├─ session-resume/SKILL.md
├─ session-status/SKILL.md
├─ carry-forwards/                  ← session handoff docs (output of session-carry-forward)
└─ .agents/skills/                  ← APM-managed skills (generated, gitignored; source for all installs)
```

## Skill format

Each skill is a folder with a `SKILL.md` at its root. The SKILL.md frontmatter has `name:` and `description:` fields — Claude uses `description` to decide when to trigger the skill. A `references/` subdir holds supporting docs (templates, checklists, examples) that the SKILL.md can reference.

## Install

```sh
./install.sh            # symlink all (native + APM) into ~/.claude/skills/
./install.sh --copilot  # also install into ~/.copilot/skills/ (Copilot CLI)
./install.sh --dry-run
./install-plugins.sh    # install whole plugins/harnesses via each CLI (plugins.list)
```

`install.sh` automatically runs `apm install` if APM dependencies haven't been fetched yet. Existing real dirs at the target are backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` before being replaced; existing symlinks are silently re-pointed.

`install-plugins.sh` is separate and idempotent: it defaults to both CLIs, skips any target whose CLI is not on `PATH`, and is safe to re-run. Full machine bootstrap order:

```sh
git pull && apm install && ./install.sh --copilot && ./install-plugins.sh
```

## APM (Agent Package Manager)

Third-party skills from `anthropics/skills` are declared in `apm.yml` and resolved by [APM](https://github.com/microsoft/apm). Running `apm install` fetches them into `.agents/skills/` (gitignored), which `install.sh` symlinks from for both Claude and Copilot targets. The lockfile `apm.lock.yaml` pins exact commits and content hashes.

Currently managed via APM:
- `frontend-design`, `mcp-builder`, `pdf`, `pptx`, `skill-creator`, `xlsx` (anthropics/skills)
- `i-have-adhd` (ayghri/i-have-adhd)
- `grill-me` (mattpocock/skills)
- `show-me`, `improve-claude-md` (humanlayer/skills)

To update these to the latest upstream: `apm update`.

## Working on a skill

Because `~/.claude/skills/` points here via symlinks, edits to any skill file take effect immediately in Claude — no re-install needed.

When adding a new skill:
1. Create `<skill-name>/SKILL.md` with `name:`, `description:`, and the skill body.
2. Add a one-line entry to the skills table in `README.md`.
3. Run `./install.sh <skill-name>` to symlink it.
4. Test by triggering it in a session with one of its stated trigger phrases.

When adding a whole plugin (not just a skill):
1. Add a pipe-delimited line to `plugins.list` (`marketplace_repo | marketplace_name | plugin | targets | description`).
2. Run `./install-plugins.sh` (or `--dry-run` to preview the CLI commands first).
3. Do **not** also add the plugin's individual skills to `apm.yml` — the whole plugin already ships them, and duplicating causes conflicting copies.

## Testing and evals

The `skill-creator` skill (managed via APM) can run evals against a skill. Point it at a SKILL.md and a set of trigger / non-trigger prompts to measure precision and recall.

## Conventions

- Trigger phrases are listed in the SKILL.md `## When to invoke` section and summarised in `README.md`.
- Skills are non-destructive by default — only `session-carry-forward` and `decision-log` write files, and neither commits.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers are produced by these skills.
