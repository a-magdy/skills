# personal/skills

This repo holds hand-written skills for managing long, multi-day sessions, plus third-party skills and whole plugins pulled from public repos. It is **dual-target**: everything deploys to both Claude Code (`~/.claude/skills/`) and Copilot CLI (`~/.copilot/skills/`). Most skills auto-activate when a prompt matches their `description`; skills with `disable-model-invocation: true` (`i-have-adhd`, `grill-me`, `show-me`) load only when the user types `/name`. The per-skill list is in `docs/TRIGGERS.md`.

Agent context deploys at **two layers** (see `README.md` for the full explanation):

1. **Skills** — a `SKILL.md` folder, symlinked into the agent skill dirs by `install.sh`. Sources: native dirs in this repo + APM deps in `apm.yml`.
2. **Whole plugins / harnesses** — full plugins (hooks, companion tools, MCP/LSP servers) installed natively via each CLI's plugin system by `install-plugins.sh`, listed in `plugins.list`. A plain symlink cannot express these.

## Repo layout

```
skills/
├─ AGENTS.md                        ← this file
├─ README.md                        ← user-facing overview and install guide
├─ install.sh                       ← symlink third-party skills into ~/.claude & ~/.copilot (layer 1); --check audits them
├─ install-plugins.sh               ← install whole plugins via each CLI (layer 2)
├─ install-instructions.sh          ← link global preferences; --check / --dry-run are read-only
├─ config/global/AGENTS.md          ← shared cross-project preferences, NOT this repo's instructions
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
├─ scripts/sync-version.sh          ← stamps VERSION into every manifest
├─ docs/TRIGGERS.md                 ← what makes each skill fire (keep in sync with descriptions)
├─ <skill>/evals/                   ← optional: trigger_set.json + evals.json (see Testing and evals)
├─ carry-forwards/                  ← session handoff docs (output of session-carry-forward)
└─ .agents/skills/                  ← APM-managed skills (generated, gitignored; source for all installs)
```

## Skill format

Each skill is a folder with a `SKILL.md` at its root. The SKILL.md frontmatter has `name:` (must equal the folder name) and `description:` fields. The agent sees **only** `description` when deciding whether to load a skill, so it must carry the triggers: what the skill does, a "Use when …" clause with example phrases, and a "Not for … (use X)" clause for any skill it overlaps with. Keep it under 1024 characters. Add `disable-model-invocation: true` for skills that should only run on `/name`. A `references/` subdir holds supporting docs (templates, checklists, examples) that the SKILL.md can reference.

## Install

```sh
./install.sh            # symlink third-party (APM) skills into ~/.claude/skills/
./install.sh --claude --copilot  # both CLIs
./install.sh --check    # read-only audit of both skill dirs (missing / broken / copy / duplicate)
./install.sh --dry-run
./install.sh --with-plugins  # after skills, also run install-plugins.sh (opt-in convenience)
./install.sh --claude --copilot --with-instructions  # opt-in global instruction links
./install.sh --claude --copilot --with-plugins --with-instructions  # dotfiles bootstrap
bash install-instructions.sh --claude --copilot --dry-run
bash install-instructions.sh --claude --check
bash install-instructions.sh --copilot --check
bash install-instructions.sh --check  # audit global instruction links only
./install-plugins.sh    # install whole plugins/harnesses via each CLI (plugins.list)
```

`install.sh` automatically runs `apm install` if APM dependencies haven't been fetched yet. Existing real dirs at the target are backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` before being replaced; existing symlinks are silently re-pointed.

`install-plugins.sh` is separate and idempotent: it defaults to both CLIs, skips any target whose CLI is not on `PATH`, and is safe to re-run. Full machine bootstrap order:

```sh
git pull && apm install && ./install.sh --copilot && ./install-plugins.sh
```

Global preferences are a separate, opt-in install, not plugin content. `install-instructions.sh`
links `config/global/AGENTS.md` into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md`
and `${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md` (both by default). It backs up
existing files/links to unique `.backup.*` siblings, refuses directories, and leaves correct
links untouched. `install.sh --with-instructions` follows its CLI selections and forwards
`--check` / `--dry-run`; custom skill `--target` does not redirect global instructions.
Never link the root `AGENTS.md` globally. Tests: `bats tests/install-instructions.bats`.

## APM (Agent Package Manager)

Third-party skills from `anthropics/skills` are declared in `apm.yml` and resolved by [APM](https://github.com/microsoft/apm). Running `apm install` fetches them into `.agents/skills/` (gitignored), which `install.sh` symlinks from for both Claude and Copilot targets. The lockfile `apm.lock.yaml` pins exact commits and content hashes.

Currently managed via APM:
- `frontend-design`, `mcp-builder`, `pdf`, `pptx`, `skill-creator`, `xlsx` (anthropics/skills)
- `i-have-adhd` (ayghri/i-have-adhd)
- `grill-me` (mattpocock/skills)
- `show-me`, `improve-claude-md` (humanlayer/skills)

To update these to the latest upstream: `apm update`.

## Working on a skill

Third-party skills in `~/.claude/skills/` and `~/.copilot/skills/` are symlinks into `.agents/skills/`, so `apm update` takes effect without re-installing. Own skills reach both CLIs through the installed `personal-skills` plugin. Whether edits are live depends on where the marketplace was added from: added from the **local checkout path**, the plugin is loaded in place ("Live Plugin" in `copilot plugin list`) and edits apply on the next session; added from **GitHub**, the CLI copies it into its plugin cache and edits need push + `plugin update`. A live plugin can still be **disabled**; check the status in `plugin list`.

When adding a new **own** skill (ships via the `personal-skills` plugin, so it reaches both Claude and Copilot):
1. Create `<skill-name>/SKILL.md` with `name:`, `description:`, and the skill body. Keep it free of personal info (see **Privacy** below).
2. Symlink it into the plugin so both CLIs pick it up:
   `ln -s ../../<skill-name> plugin/skills/<skill-name>`. Do **not** add own skills to `apm.yml` — that's for third-party skills only.
3. Add a one-line entry (with its Invocation column) to the appropriate skills table in `README.md`, and its triggers to `docs/TRIGGERS.md`.
4. Commit. CI (`.github/workflows/validate.yml`) checks every skill dir has a `SKILL.md`, lints the manifests, and runs `sync-version.sh --check`.
5. Test by triggering it with one of its stated trigger phrases in both CLIs, and run `./install.sh --check`.

To test an own skill live while editing it, symlink just that one skill (`./install.sh <skill-name> --claude`), and remove the link afterwards: leaving it alongside the plugin loads the skill twice (`--check` reports it as DUPLICATE).

When adding a whole plugin (not just a skill):
1. Add a pipe-delimited line to `plugins.list` (`marketplace_repo | marketplace_name | plugin | targets | description`).
2. Run `./install-plugins.sh` (or `--dry-run` to preview the CLI commands first).
3. Do **not** also add the plugin's individual skills to `apm.yml` — the whole plugin already ships them, and duplicating causes conflicting copies.

## Testing and evals

The `skill-creator` skill (managed via APM) can run evals against a skill. Convention per skill:

- `<skill>/evals/trigger_set.json` — `[{ "query": "...", "should_trigger": true|false }]`, roughly half near-misses. Measures whether `description` fires correctly.
- `<skill>/evals/evals.json` — `{ skill_name, evals: [{ id, prompt, expected_output, expectations[] }] }`. Measures whether the skill does the right thing.

`staged-commit` has both; `danish-listing-review` has `evals.json`. Manual-only skills should never trigger from natural language, so their trigger sets are all `false` plus a slash-invocation check.

## Keeping Claude and Copilot in sync

One repo serves both CLIs; several files must move together or the two targets drift:

- **Own skills** ship through `plugin/skills/` symlinks — add/rename/remove the symlink whenever you add/rename/remove an own skill. Both CLIs read the same `plugin/skills/`, so a symlink change updates both at once.
- **Version** lives only in `VERSION`. After bumping it (or adding a manifest), run `./scripts/sync-version.sh <version>` to stamp it into `apm.yml`, `marketplace.json`, `.claude-plugin/marketplace.json`, `plugin/plugin.json`, and `plugin/.claude-plugin/plugin.json`. CI runs `--check` and fails on drift.
- **Plugin manifests** come in pairs — the Copilot manifest (`plugin/plugin.json`, Agent Plugins 1.0) and the Claude manifest (`plugin/.claude-plugin/plugin.json`). Edit both. Same for the two `marketplace.json` files.
- **Hooks** come in pairs — `plugin/hooks/hooks.json` (Claude) and `plugin/com.github.copilot/hooks/hooks.json` (Copilot), both invoking the shared scripts under `plugin/hooks/`. Change them together.
- **README** is the user-facing index — update its skills tables and install docs whenever skills, flags, or the two-layer model change. `docs/TRIGGERS.md` moves with every `description` change.

## Privacy — no personal info in committed files

This repo is public. Never commit personal or environment-specific data:

- No absolute home paths (`/Users/<name>`, `/home/<name>`), usernames, emails, hostnames, or IPs. Use repo-relative paths and generic placeholders.
- No employer/client/org names or internal project names in skills, examples, or docs. Examples must be fictional (e.g. `acme/widget-service`).
- No secrets, tokens, API keys, or `.env` values — ever.
- `carry-forwards/` stays **local and untracked** (it captures real session state); do not commit it.
- Before committing, scan the diff for the above. The `staged-commit` skill does this automatically.

## Conventions

- Trigger phrases belong in the `description` (that is all the agent sees when choosing). A body `## When to invoke` section is optional extra detail, never the only place triggers live. Summaries go in `README.md` and `docs/TRIGGERS.md`.
- Skills that write files: `session-carry-forward`, `decision-log`, `danish-listing-review` (report files), `multi-variant-site-design` and `cinematic-static-site` (site files), and `staged-commit` (commits, never pushes). Everything else is read-only.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers and no AI/tool references in commit messages.

## Gotchas & tooling notes

- **`plugin marketplace add <repo>` returns non-zero if the marketplace is already registered.** Under `set -euo pipefail` this aborts `install-plugins.sh` on any re-run — which is why it wraps that step as non-fatal (`run_soft`). `plugin install` itself is idempotent (a re-install just refreshes).
- **`install.sh` source vs destination are different dirs.** The repo-relative *source* is `.agents/skills` (APM-generated); the *destination* is `$HOME/.claude/skills` / `$HOME/.copilot/skills`. Only the source is `.agents/skills`; the destinations are unchanged, so Claude Code and Copilot still receive symlinks.
- **One `.agents/skills` source is enough.** `apm install`'s `.claude/skills` and `.agents/skills` outputs are byte-identical for plain `SKILL.md` skills (verified with `diff -rq`), so `apm.yml` targets only `copilot`. Caveat: a skill shipping agent-specific files could differ per target — none here do.
- **Copilot CLI ignores manual-only skills when the model looks them up.** Skills with `disable-model-invocation: true` work when the user types `/name` at the start of a prompt, but not via "use the X skill" (github/copilot-cli#4438, open as of 2026-09-29).
- **VS Code reads `~/.claude/skills` as well as `~/.copilot/skills`.** A skill linked into both may be listed twice in VS Code; the CLIs are unaffected.
- **A copied skill dir goes stale silently.** A real directory in `~/.claude/skills` or `~/.copilot/skills` (instead of a symlink) never picks up repo changes and nothing warns you; `./install.sh --check` flags it as COPY, or DUPLICATE if the plugin also ships it.
- `install.sh --check` also requires a linked `SKILL.md` and the expected resolved source directory; wrong-source links report WRONG, invalid targets report INVALID. Audit tests: `bats tests/install-audit.bats`.
- **Plugin CLI verbs** (both `copilot` and `claude`): `plugin list|install|uninstall|update|enable|disable`, `plugin marketplace add|remove`. `uninstall` takes one name at a time (`plugin` or `plugin@marketplace`).
