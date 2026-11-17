# personal/skills

This repo holds hand-written skills for managing long, multi-day sessions, plus third-party skills and whole plugins pulled from public repos. It is **dual-target**: everything deploys to both Claude Code and Copilot CLI. Most skills auto-activate when a prompt matches their `description`; skills with `disable-model-invocation: true` (`i-have-adhd`, `grill-me`, `show-me`) load only when the user types `/name`. The per-skill list is in `docs/TRIGGERS.md`.

Agent context deploys at **three layers** (see `README.md` for the user-facing explanation):

1. **Own skills** — every folder under `plugin/skills/`, shipped as the `personal-skills` plugin together with its hooks. Each CLI installs it through its plugin system.
2. **Third-party skills** — declared in `apm.yml`, fetched by APM into `.agents/skills/`, symlinked into `~/.claude/skills` and `~/.copilot/skills` by `install.sh`.
3. **Whole third-party plugins** — full plugins (hooks, agents, MCP servers) listed in `plugins.list` and installed natively by `install-plugins.sh`. A plain symlink cannot express these.

Global preferences (`config/global/AGENTS.md`) are a separate, opt-in install via `install-instructions.sh`.

## Repo layout

```
skills/
├─ AGENTS.md                  ← this file (CLAUDE.md is a symlink to it)
├─ README.md                  ← user-facing overview and install guide
├─ plugin/                    ← the `personal-skills` plugin
│   ├─ skills/<name>/         ← own skills: SKILL.md plus optional references/, scripts/, assets/, evals/
│   ├─ hooks/                 ← run-hook.sh, session-start, session-end, hooks.json (Claude)
│   ├─ com.github.copilot/hooks/hooks.json   ← Copilot hook config (must equal the Claude one)
│   ├─ plugin.json            ← Copilot manifest (Agent Plugins 1.0)
│   └─ .claude-plugin/plugin.json            ← Claude manifest
├─ marketplace.json, .claude-plugin/marketplace.json   ← this repo as a plugin marketplace
├─ install.sh                 ← symlink third-party skills (layer 2); --check audits them
├─ install-plugins.sh         ← install whole plugins via each CLI (layer 3)
├─ install-instructions.sh    ← link global preferences; --check / --dry-run are read-only
├─ config/global/AGENTS.md    ← shared cross-project preferences, NOT this repo's instructions
├─ plugins.list               ← whole-plugin manifest (pipe-delimited)
├─ apm.yml, apm.lock.yaml     ← APM manifest and lockfile (pinned commits + hashes)
├─ VERSION                    ← single source of truth for the version
├─ scripts/
│   ├─ sync-version.sh        ← stamps VERSION into every manifest
│   ├─ sync-docs.sh           ← regenerates the skill tables in README.md and docs/TRIGGERS.md
│   └─ validate-skills.sh     ← consistency checks; CI runs it
├─ tests/*.bats               ← shell tests for installers, hooks and scripts
├─ docs/                      ← TRIGGERS.md (example prompts; own-skills table is generated), per-skill roadmaps
├─ carry-forwards/            ← local session handoff docs (gitignored)
└─ .agents/skills/            ← APM-managed skills (generated, gitignored)
```

The layout deliberately lists no individual skill: `plugin/skills/` is the list.

## Skill format

Each skill is a folder with a `SKILL.md` at its root. The frontmatter has `name:` (must equal the folder name) and `description:`. The agent sees **only** `description` when deciding whether to load a skill, so it must carry the triggers: what the skill does, a "Use when …" clause with quoted example phrases, and a "Not for … (use X)" clause for any skill it overlaps with.

Frontmatter rules, enforced by `validate-skills.sh`:

- one `key: value` per line; `description` is a plain one-line value, with no quotes and no `>` / `|` block;
- no `: ` (colon then space) and no ` #` inside the description, because both break plain YAML — rephrase instead;
- at most 1024 characters.

`sync-docs.sh` builds the README summary from the description's first sentence and the TRIGGERS row from its quoted phrases, so write the first sentence as a standalone summary and put real example prompts in double quotes.

Add `disable-model-invocation: true` for skills that should only run on `/name`. A `references/` subdir holds supporting docs that the SKILL.md can link to.

## Adding or changing an own skill

1. Create or edit `plugin/skills/<name>/SKILL.md`. Keep it free of personal info (see **Privacy**). There is nothing to register: both CLIs discover every folder under `plugin/skills/`. Do **not** add own skills to `apm.yml`.
2. Run `./scripts/sync-docs.sh`. It regenerates the own-skill tables in `README.md` and `docs/TRIGGERS.md`. Never edit between the `<!-- BEGIN own-skills -->` / `<!-- END own-skills -->` markers by hand.
3. If the change is user-visible, bump the version: `./scripts/sync-version.sh <version>`.
4. Run `./scripts/validate-skills.sh` and `bats tests/*.bats`.
5. If the skill overlaps another, add the pair to "Known overlaps" in `docs/TRIGGERS.md` (hand-written).
6. Test it by using one of its trigger phrases in both CLIs.

Whenever you add, rename, remove or re-describe a skill in this repo, do steps 2 and 4 before reporting the work as done.

Whether edits are live depends on the CLI and on where the marketplace was added from. With the marketplace added from the **local checkout path**: Copilot CLI loads the plugin in place ("Live Plugins" in `copilot plugin list`), so edits apply on the next session; Claude Code copies it into a per-version cache under `~/.claude/plugins/cache/`, so run `claude plugin update personal-skills@personal-skills-marketplace` after editing (bump `VERSION` first if it reports nothing to update) and restart. Added from **GitHub**, both need push + `plugin update`. `install-plugins.sh` follows `plugins.list` by default; `--local` explicitly selects this checkout for the own marketplace. It runs `plugin update` for the own plugin each time and preserves existing registrations until explicitly removed. A plugin can also be installed but **disabled**; `--check` audits enabled state and marketplace source without installing.

To try one own skill without the plugin, `./install.sh <skill-name> --claude` symlinks just that skill. Remove the link afterwards: alongside the plugin it loads twice (`--check` reports DUPLICATE).

## Install

```sh
./install.sh                    # symlink third-party (APM) skills into both CLIs
./install.sh --claude           # only one CLI (or --copilot)
./install.sh --check            # read-only audit of both skill dirs
./install.sh --dry-run
./install.sh --with-plugins --with-instructions   # everything in one go
./install-plugins.sh            # whole plugins from plugins.list
./install-instructions.sh       # global preferences (opt-in)
```

Shared conventions across the three installers: default to both CLIs, `--claude` / `--copilot` narrow that, `--dry-run` never writes, and anything replaced is moved to a `.backup.*` sibling. Keep new installer code consistent with these.

- `install.sh` always runs `apm install --frozen` before installing requested APM skills, even when generated directories exist. Missing APM, missing/inconsistent locks or missing output fail explicitly; explicitly named own skills need no APM. `--check` and `--dry-run` never invoke APM. An existing symlink at the target is re-pointed; a real directory is moved to `<name>.backup.<YYYYMMDD-HHMMSS>`.
- `install-plugins.sh` skips any CLI not on `PATH` and is safe to re-run.
- `install-instructions.sh` links `config/global/AGENTS.md` into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md` and `${COPILOT_HOME:-$HOME/.copilot}/copilot-instructions.md`. It refuses directories and leaves correct links untouched. `install.sh --with-instructions` forwards the CLI selection and `--check` / `--dry-run`; a custom skill `--target` does not redirect it. Never link the root `AGENTS.md` globally.

Full machine bootstrap:

```sh
git pull && bash ./install.sh --claude --copilot --with-plugins --with-instructions
```

## APM (third-party skills)

Third-party skills are declared in `apm.yml` and resolved by [APM](https://github.com/microsoft/apm). `apm install` fetches them into `.agents/skills/` (gitignored); `apm.lock.yaml` pins exact commits and content hashes.

Currently managed via APM:
- `frontend-design`, `mcp-builder`, `pdf`, `pptx`, `skill-creator`, `xlsx` (anthropics/skills)
- `i-have-adhd` (ayghri/i-have-adhd)
- `grill-me` (mattpocock/skills)
- `show-me`, `improve-claude-md` (humanlayer/skills)

To update: `apm update`, then read the diff of `.agents/skills/` before committing the new lockfile. These files are prompt content that loads into sessions.

## Whole plugins

1. Add a pipe-delimited line to `plugins.list` (`marketplace_repo | marketplace_name | plugin | targets | description`).
2. Run `./install-plugins.sh` (or `--dry-run` to preview the CLI commands).
3. Do **not** also declare the plugin, its skills or its MCP server in `apm.yml`. The plugin already ships them, and declaring both gives conflicting copies.

Third-party plugins install at their marketplace's current version; there is no ref to pin in `plugins.list`. Read a plugin's hooks and MCP config before adding it.

## Testing and evals

- `bats tests/*.bats` — all three installers, hooks, `sync-version.sh`, `validate-skills.sh`. Tests run against temp dirs, a fake `HOME` and stub CLIs; they never touch live config or the network.
- Maintainer notes about a skill (roadmaps, known gaps) go in `docs/`, not in the skill folder: everything under `plugin/skills/<name>/` ships to users.
- `./scripts/validate-skills.sh` — layout, frontmatter, generated docs, hook parity, privacy.
- `shellcheck -S warning` on every script; CI fails on warnings.

The `skill-creator` skill (managed via APM) can run evals against a skill. Convention per skill, under `plugin/skills/<name>/evals/`:

- `trigger_set.json` — `[{ "query": "...", "should_trigger": true|false }]`, roughly half near-misses. Measures whether `description` fires correctly.
- `evals.json` — `{ skill_name, evals: [{ id, prompt, expected_output, expectations[] }] }`. Measures whether the skill does the right thing.

Manual-only skills should never trigger from natural language, so their trigger sets are all `false` plus a slash-invocation check.

## Keeping Claude and Copilot in sync

One repo serves both CLIs; these must move together or the two targets drift:

- **Version** lives only in `VERSION`. `./scripts/sync-version.sh <version>` stamps it into `apm.yml`, both `marketplace.json` files and both plugin manifests. CI runs `--check`.
- **Plugin manifests** come in pairs — `plugin/plugin.json` (Copilot) and `plugin/.claude-plugin/plugin.json` (Claude). Edit both. Same for the two `marketplace.json` files.
- **Hooks** come in pairs — `plugin/hooks/hooks.json` (Claude) and `plugin/com.github.copilot/hooks/hooks.json` (Copilot), both invoking the shared scripts under `plugin/hooks/`. They must be byte-identical; CI checks.
- **Skill bodies** must not name tools that exist in only one CLI. Describe the capability ("the task list tool, if this CLI has one").
- **Docs** — the skill tables are generated; the rest of `README.md` (install docs, flags, the layer model) is hand-written and must be updated with the code.

## Privacy — no personal info in committed files

This repo is public. Never commit personal or environment-specific data:

- No absolute home paths (`/Users/<name>`, `/home/<name>`), usernames, emails, hostnames, or IPs. Use repo-relative paths and generic placeholders.
- No employer/client/org names or internal project names in skills, examples, or docs. Examples must be fictional (e.g. `acme/widget-service`).
- No secrets, tokens, API keys, or `.env` values — ever.
- `carry-forwards/` stays **local and untracked** (it captures real session state). It is in `.gitignore` here, and `session-carry-forward` adds it to `.git/info/exclude` in other repos.
- Before committing, scan the diff for the above. `validate-skills.sh` catches home paths; the `staged-commit` skill scans for the rest.

## Conventions

- Trigger phrases belong in the `description` (that is all the agent sees when choosing). A body `## When to invoke` section is optional extra detail, never the only place triggers live.
- Skills that write files: `session-carry-forward`, `decision-log`, `danish-listing-review` (report files), `multi-variant-site-design` and `cinematic-static-site` (site files), and `staged-commit` (commits, never pushes). Everything else is read-only.
- Output paths default to inside the calling repo so artifacts live with the work they describe.
- Absolute dates (YYYY-MM-DD) only — relative phrasing breaks across sessions.
- No `Co-Authored-By` trailers and no AI/tool references in commit messages.

## Gotchas & tooling notes

- **`plugin marketplace add <repo>` behaves differently per CLI when the name is already registered.** Copilot returns non-zero; Claude Code silently replaces the source (a local path becomes GitHub). `install-plugins.sh` checks `plugin marketplace list --json` first and skips known registrations; unknown inventory or real add failures are fatal. `plugin install` itself is idempotent.
- **`claude plugin install` takes no `-y` flag**; it is non-interactive already. `awesome-copilot` is a default marketplace in Copilot CLI and never needs adding.
- **`install.sh` source vs destination are different dirs.** The repo-relative *source* is `.agents/skills` (APM-generated); the *destination* is `$HOME/.claude/skills` / `$HOME/.copilot/skills`.
- **One `.agents/skills` source is enough.** `apm install`'s `.claude/skills` and `.agents/skills` outputs are byte-identical for plain `SKILL.md` skills, so `apm.yml` targets only `copilot`. Caveat: a skill shipping agent-specific files could differ per target — none here do.
- **The lockfile is tied to the APM version that wrote it.** An older `apm` can report a "content hash mismatch" on a package whose pinned commit and per-file hashes are unchanged, because the bundle hash is computed differently. Check `apm --version` against `apm_version` in `apm.lock.yaml` before treating it as tampering, and do not run `apm install --update` just to get past it.
- **`--check` statuses:** `WRONG` is a link into a different checkout, `INVALID` a link whose target has no `SKILL.md`, `COPY` a real directory that never picks up repo changes, `DUPLICATE` an own skill linked alongside the plugin.
- **Copilot CLI ignores manual-only skills when the model looks them up.** Skills with `disable-model-invocation: true` work when the user types `/name` at the start of a prompt, but not via "use the X skill" (github/copilot-cli#4438, open as of 2026-09-29).
- **VS Code reads `~/.claude/skills` as well as `~/.copilot/skills`.** A skill linked into both may be listed twice in VS Code; the CLIs are unaffected.
- **Plugin CLI verbs** (both `copilot` and `claude`): `plugin list|install|uninstall|update|enable|disable`, `plugin marketplace add|remove`. `uninstall` takes one name at a time (`plugin` or `plugin@marketplace`).
