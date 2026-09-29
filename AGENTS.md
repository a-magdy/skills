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
├─ staged-commit/SKILL.md
├─ session-carry-forward/
│   ├─ SKILL.md
│   └─ references/template.md      ← the carry-forward doc template
├─ session-resume/SKILL.md
├─ session-status/SKILL.md
├─ plugin/                          ← the `personal-skills` plugin (skills symlinks + hooks + manifests)
├─ VERSION                          ← single source of truth for the version (see sync-version.sh)
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
./install.sh --with-plugins  # after skills, also run install-plugins.sh (opt-in convenience)
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

When adding a new **own** skill (ships via the `personal-skills` plugin, so it reaches both Claude and Copilot):
1. Create `<skill-name>/SKILL.md` with `name:`, `description:`, and the skill body. Keep it free of personal info (see **Privacy** below).
2. Symlink it into the plugin so both CLIs pick it up:
   `ln -s ../../<skill-name> plugin/skills/<skill-name>`. Do **not** add own skills to `apm.yml` — that's for third-party skills only.
3. Add a one-line entry to the appropriate skills table in `README.md` (keep the README in sync — it's the user-facing index).
4. Commit. CI (`.github/workflows/validate.yml`) checks every skill dir has a `SKILL.md`, lints the manifests, and runs `sync-version.sh --check`.
5. Test by triggering it with one of its stated trigger phrases.

For live editing, `install.sh` symlinks only third-party (APM) skills by default; own skills are consumed through the installed plugin. To edit an own skill and see it live in Claude/Copilot, edit the file in place — the plugin's `plugin/skills/<name>` symlink points back here.

When adding a whole plugin (not just a skill):
1. Add a pipe-delimited line to `plugins.list` (`marketplace_repo | marketplace_name | plugin | targets | description`).
2. Run `./install-plugins.sh` (or `--dry-run` to preview the CLI commands first).
3. Do **not** also add the plugin's individual skills to `apm.yml` — the whole plugin already ships them, and duplicating causes conflicting copies.

## Testing and evals

The `skill-creator` skill (managed via APM) can run evals against a skill. Point it at a SKILL.md and a set of trigger / non-trigger prompts to measure precision and recall.

## Keeping Claude and Copilot in sync

One repo serves both CLIs; several files must move together or the two targets drift:

- **Own skills** ship through `plugin/skills/` symlinks — add/rename/remove the symlink whenever you add/rename/remove an own skill. Both CLIs read the same `plugin/skills/`, so a symlink change updates both at once.
- **Version** lives only in `VERSION`. After bumping it (or adding a manifest), run `./scripts/sync-version.sh <version>` to stamp it into `apm.yml`, `marketplace.json`, `.claude-plugin/marketplace.json`, `plugin/plugin.json`, and `plugin/.claude-plugin/plugin.json`. CI runs `--check` and fails on drift.
- **Plugin manifests** come in pairs — the Copilot manifest (`plugin/plugin.json`, Agent Plugins 1.0) and the Claude manifest (`plugin/.claude-plugin/plugin.json`). Edit both. Same for the two `marketplace.json` files.
- **Hooks** come in pairs — `plugin/hooks/hooks.json` (Claude) and `plugin/com.github.copilot/hooks/hooks.json` (Copilot), both invoking the shared scripts under `plugin/hooks/`. Change them together.
- **README** is the user-facing index — update its skills tables and install docs whenever skills, flags, or the two-layer model change.

## Privacy — no personal info in committed files

This repo is public. Never commit personal or environment-specific data:

- No absolute home paths (`/Users/<name>`, `/home/<name>`), usernames, emails, hostnames, or IPs. Use repo-relative paths and generic placeholders.
- No employer/client/org names or internal project names in skills, examples, or docs. Examples must be fictional (e.g. `acme/widget-service`).
- No secrets, tokens, API keys, or `.env` values — ever.
- `carry-forwards/` stays **local and untracked** (it captures real session state); do not commit it.
- Before committing, scan the diff for the above. The `staged-commit` skill does this automatically.

## Conventions

- Trigger phrases are listed in the SKILL.md `## When to invoke` section and summarised in `README.md`.
- Skills are non-destructive by default — only `session-carry-forward` and `decision-log` write files, and neither commits.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers and no AI/tool references in commit messages.
