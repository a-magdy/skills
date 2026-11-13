# personal/skills

Agent skills and the tooling to install them, for both [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) and [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli). One repo sets up a machine with:

| What | Where it lives | Installed by |
|---|---|---|
| **Own skills**, shipped as the `personal-skills` plugin with session hooks | [`plugin/`](./plugin/) | each CLI's `plugin install` |
| **Third-party skills**, pinned by commit and content hash | [`apm.yml`](./apm.yml) + [`apm.lock.yaml`](./apm.lock.yaml) | [`install.sh`](./install.sh) |
| **Whole third-party plugins** (hooks, agents, MCP servers) | [`plugins.list`](./plugins.list) | [`install-plugins.sh`](./install-plugins.sh) |
| **Global preferences** shared by both CLIs | [`config/global/AGENTS.md`](./config/global/AGENTS.md) | [`install-instructions.sh`](./install-instructions.sh) |

The own skills centre on long, multi-day sessions: keeping track of state, handing context to the next session, and recording decisions where they belong. A few standalone skills (commits, site design, Danish property due diligence) ship alongside.

## Own skills

**Invocation:** *auto* means the agent loads the skill when your prompt matches its `description`; `/name` means it never loads on its own and you type the slash command. Example prompts for each skill are in [`docs/TRIGGERS.md`](./docs/TRIGGERS.md).

<!-- BEGIN own-skills -->
| Skill | Invocation | What it does |
|---|---|---|
| [`cinematic-static-site`](./plugin/skills/cinematic-static-site/) | auto | Build cinematic, presentation-grade static websites with smooth scrolling, GSAP or CSS scroll-triggered reveals, parallax, WebGL backgrounds and chapter-based editorial layouts that feel like an interactive story. |
| [`danish-listing-review`](./plugin/skills/danish-listing-review/) | auto | Deep buy-side due diligence on a Danish property the user is considering buying. |
| [`decision-log`](./plugin/skills/decision-log/) | auto | Append a single decision entry to a project-level decision log (`DECISIONS.md` at the repo root by default). |
| [`multi-variant-site-design`](./plugin/skills/multi-variant-site-design/) | auto | Design a website by building several parallel, working design variants from one content brief, housing them in a comparison gallery, and promoting the winner to production while keeping the rest as an archive. |
| [`scratch-workspace-routing`](./plugin/skills/scratch-workspace-routing/) | auto | Find and verify the real project repository when a session starts outside it, in a scratch, temp, sandbox or home directory, or an editor- or app-generated scratch workspace with no project selected, but the user's request refers to existing project work. |
| [`session-carry-forward`](./plugin/skills/session-carry-forward/) | auto | Produce a structured handoff document at the end of a long agent session so the next session (or a teammate) can pick up without re-litigating decisions or re-running discovery. |
| [`session-resume`](./plugin/skills/session-resume/) | auto | Resume work from a session-carry-forward document. |
| [`session-status`](./plugin/skills/session-status/) | auto | Mid-session health-and-status report for a long agent session. |
| [`staged-commit`](./plugin/skills/staged-commit/) | auto | Commit working-tree changes in small, logically-grouped stages with clean, convention-following messages. |
<!-- END own-skills -->

This table is generated from each skill's frontmatter by `./scripts/sync-docs.sh`.

### The session lifecycle

```
Project start ──→ … ──→ Long session ──→ Session end ──→ Days pass ──→ Next session
                              ↑              ↑                            ↑
                       session-status   session-carry-forward      session-resume
                            ↑
                       decision-log   (anytime, accumulates project-level)
```

- **`session-status`** is a read-only snapshot with three flavors: "summarize this session so far", "is it safe to close?" (a yes/no with the specific blockers), and "what am I in the middle of?". It never writes a file.
- **`session-carry-forward`** writes one structured handoff file to `<repo>/carry-forwards/<YYYY-MM-DD>-<slug>.md`: state, decisions paired with the rejected alternative, abandoned paths, open items, verification commands and a paste-ready seed prompt. It keeps the file out of git and never commits.
- **`session-resume`** reads the latest carry-forward, runs its verification commands, reports drift, recreates the task list and names the next action.
- **`decision-log`** appends one entry to `<repo>/DECISIONS.md` (or `docs/decisions/` if the repo uses that). Unlike a carry-forward, it is a long-lived project record.
- **`scratch-workspace-routing`** finds and verifies the real repository when a session starts in a scratch, temp or home directory but the prompt refers to existing project work.

### Hooks

The plugin also ships two hooks ([`plugin/hooks/`](./plugin/hooks/)), both read-only:

- **SessionStart** (startup and resume): outside a git repo it points the agent at `scratch-workspace-routing`; inside a repo it notes the newest carry-forward if one exists and is under 14 days old. The agent is told not to act on it unprompted.
- **SessionEnd**: if the working tree is dirty, it suggests a carry-forward.

## Quick start

```sh
git clone <this-repo-url> && cd skills
apm install              # fetch third-party skills (apm.yml); requires APM
./install.sh             # symlink them into ~/.claude/skills and ~/.copilot/skills
./install-plugins.sh     # install whole plugins, including this repo's own skills
./install.sh --check     # audit the result
```

Requires [APM](https://github.com/microsoft/apm) for the third-party skills. Global preferences are opt-in; see [Global instructions](#global-instructions).

All three installers follow the same conventions: they default to both CLIs, accept `--claude` / `--copilot` to narrow that, support `--dry-run`, and back up anything they replace to a `.backup.*` sibling.

## Install

### Own skills: the plugin

This repo is itself a plugin marketplace (see [`marketplace.json`](./marketplace.json)). `install-plugins.sh` installs the `personal-skills` plugin from GitHub; to do it by hand:

```sh
# Copilot CLI
copilot plugin marketplace add a-magdy/skills
copilot plugin install personal-skills@personal-skills-marketplace

# Claude Code
claude plugin marketplace add a-magdy/skills
claude plugin install personal-skills@personal-skills-marketplace -y
```

To work on the skills, add the marketplace from your local checkout instead (`plugin marketplace add /path/to/skills`). Both CLIs copy the plugin into their own cache, so after editing run `plugin update personal-skills@personal-skills-marketplace` and restart the session.

> **Own skills come from the plugin only.** Symlinking one into `~/.claude/skills` as well loads it twice; `./install.sh --check` reports that as `DUPLICATE`.

### Third-party skills (APM)

Declared in [`apm.yml`](./apm.yml) and managed by [APM](https://github.com/microsoft/apm). `apm install` fetches them into `.agents/skills/` (gitignored); `install.sh` symlinks them from there, and runs `apm install` first if they have not been fetched.

| Skill | Source | Invocation |
|---|---|---|
| `frontend-design` | anthropics/skills | auto |
| `mcp-builder` | anthropics/skills | auto |
| `pdf` | anthropics/skills | auto |
| `pptx` | anthropics/skills | auto |
| `skill-creator` | anthropics/skills | auto |
| `xlsx` | anthropics/skills | auto |
| `improve-claude-md` | humanlayer/skills | auto |
| `i-have-adhd` | ayghri/i-have-adhd | `/i-have-adhd` (stays on until "stop adhd mode") |
| `grill-me` | mattpocock/skills | `/grill-me` |
| `show-me` | humanlayer/skills | `/show-me` |

To move to the latest upstream versions, run `apm update` and read the diff of `.agents/skills/` before committing the new lockfile: these files are prompt content that loads into your sessions.

| `install.sh` flag | Effect |
|---|---|
| `--claude`, `--copilot` | install into only that CLI (default: both) |
| `--target PATH` | install to a custom directory instead |
| `--copy` | copy instead of symlink (no auto-update from this repo) |
| `--dry-run` | preview the plan without making changes (no `apm install` is run) |
| `--check` | read-only audit of both skill directories; exits 1 on problems |
| `--with-plugins` | afterwards, also run `install-plugins.sh` |
| `--with-instructions` | also link the global preferences for the selected CLIs |
| _positional args_ | install only those skills (e.g. `./install.sh i-have-adhd grill-me`) |
| `-h`, `--help` | full help text |

An existing symlink at the target is replaced; a real directory is moved to `<name>.backup.<YYYYMMDD-HHMMSS>` first.

### Whole plugins

A symlinked skill is just a `SKILL.md` plus supporting files. A whole plugin carries things a symlink cannot express: session hooks, agents, bundled MCP servers and a manifest the CLI reads. Those are listed in [`plugins.list`](./plugins.list), one per line:

```
# marketplace_repo | marketplace_name | plugin | targets | description
obra/superpowers-marketplace | superpowers-marketplace | superpowers | copilot,claude | ...
```

| Plugin | Targets | Notes |
|---|---|---|
| `superpowers` | Copilot, Claude | Agentic development methodology with a session-start bootstrap. |
| `personal-skills` | Copilot, Claude | This repo's own skills and hooks. |
| `awesome-copilot` | Copilot | Suggests community agents, instructions and skills for the current repo. Bundles its own MCP server, which needs Docker running. |

```sh
./install-plugins.sh            # both CLIs
./install-plugins.sh --dry-run  # preview the exact CLI commands
./install-plugins.sh --copilot  # only one CLI
```

The script is safe to re-run, skips any CLI that is not on `PATH`, and exits non-zero only if an install command fails. Third-party plugins install at their marketplace's current version; neither CLI offers a way to pin one from this file, so review a plugin's hooks before adding it here.

### Global instructions

Shared cross-project preferences live in [`config/global/AGENTS.md`](./config/global/AGENTS.md). They are separate from this repository's root `AGENTS.md`, which describes maintaining this repo and must not be installed globally.

```sh
./install-instructions.sh             # link for both CLIs
./install-instructions.sh --check     # audit only
./install-instructions.sh --dry-run   # preview

./install.sh --with-instructions      # or together with the skills
```

| Destination | Source |
|---|---|
| `${CLAUDE_CONFIG_DIR:-~/.claude}/CLAUDE.md` | `config/global/AGENTS.md` |
| `${COPILOT_HOME:-~/.copilot}/copilot-instructions.md` | `config/global/AGENTS.md` |

Existing files and symlinks (including broken ones) are moved to unique sibling `.backup.*` paths. Directories are refused; correct links are left untouched. Dry-run and check modes never write files. Through `install.sh`, the installer follows the `--claude` / `--copilot` selection; a custom skill `--target` does not change instruction paths. Keep the clone where it was installed, or rerun after moving it. This does not configure VS Code's separate user instructions.

### Where each tool looks for skills

| Tool | Personal (all projects) | Project (inside a repo) | Plugins |
|---|---|---|---|
| Claude Code | `~/.claude/skills` | `.claude/skills` | yes |
| Copilot CLI | `~/.copilot/skills`, `~/.agents/skills` | `.github/skills`, `.claude/skills`, `.agents/skills` | yes |
| VS Code Copilot | `~/.copilot/skills`, `~/.claude/skills`, `~/.agents/skills` | `.github/skills`, `.claude/skills`, `.agents/skills` | yes |
| Claude desktop / claude.ai | none (upload skills in Settings) | none | Cowork plugins only |

Two consequences: APM's `.agents/skills` in this repo makes the third-party skills show up in Copilot while you work inside this repo even before installing, and VS Code reads both `~/.claude/skills` and `~/.copilot/skills`, so a skill linked into both can be listed twice there.

## Troubleshooting

Run `./install.sh --check` first. Per CLI and per skill it reports:

| Status | Meaning |
|---|---|
| `ok` | linked to the expected source in this checkout |
| `MISSING` | not installed |
| `BROKEN` | a symlink whose target no longer exists |
| `WRONG` | linked to a different checkout |
| `INVALID` | the link target has no `SKILL.md` |
| `COPY` | a real directory, which will not pick up repo changes |
| `DUPLICATE` | an own skill linked here that the plugin also ships |
| `BACKUP` | a leftover `.backup.*` directory from an earlier install |

If APM skill sources are absent, the check exits 1 with "Check incomplete" rather than reporting a healthy install: run `apm install`, then check again. Plugins are not covered; use `claude plugin list` and `copilot plugin list`.

Known quirks:

- **Only `description` decides auto-triggering.** Trigger phrases that live only in the `SKILL.md` body are never seen when the agent picks a skill.
- **Copilot CLI and `/name` skills:** typing `/i-have-adhd` at the start of the prompt works; asking the model to "use the i-have-adhd skill" does not ([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)).
- **New skill not showing mid-session:** `/skills reload` in Copilot CLI; restart Claude Code.
- **Links owned by other repositories:** `--check` reports broken links it did not create, but reinstalling from this repo does not repair them. Restore or remove those by hand.

## Working on this repo

```
plugin/                    the personal-skills plugin
├─ skills/<name>/SKILL.md  own skills: one folder each, discovered automatically
├─ hooks/                  SessionStart / SessionEnd scripts and Claude's hooks.json
└─ …                       the Claude and Copilot manifests
config/global/AGENTS.md    global preferences
scripts/                   sync-version.sh, sync-docs.sh, validate-skills.sh
tests/                     bats tests for the installers, hooks and scripts
docs/TRIGGERS.md           example prompts per skill
```

**Adding or changing a skill** takes two steps:

1. Create or edit `plugin/skills/<name>/SKILL.md`. Both CLIs discover every folder under `plugin/skills/`, so there is nothing to register.
2. Run `./scripts/sync-docs.sh` to regenerate the tables in this README and in `docs/TRIGGERS.md`.

`./scripts/validate-skills.sh` checks the result (frontmatter, generated tables, hook parity, no personal paths) and `bats tests/*.bats` runs the shell tests; CI runs both. Maintainer detail is in [`AGENTS.md`](./AGENTS.md).

**Versioning:** the [`VERSION`](./VERSION) file is the single source of truth. `./scripts/sync-version.sh 1.2.0` sets it and stamps every manifest; `--check` verifies they match.

## Design notes

- **One skill per lifecycle moment, not one per question.** `session-status` handles three related questions because they share the same survey work.
- **Decisions are always recorded with their rejected alternative.** A decision without context loses half its value next month.
- **Verification commands ship with the doc.** Drift between sessions is normal, so a carry-forward includes the commands the next session runs first. `session-resume` runs only plainly read-only ones unprompted and asks before anything else, because a carry-forward is a file that may not be yours.
- **Carry-forwards stay out of git.** `session-carry-forward` adds `carry-forwards/` to the repo's local `.git/info/exclude` unless it is already ignored.
- **Writes are explicit and local.** The session skills only read, except `session-carry-forward` and `decision-log`, which write one file each. `staged-commit` commits but never pushes; the site and property skills write their own output files. Nothing commits or pushes on its own.
- **No `Co-Authored-By` trailers.** The user's commits are the user's.

## Conventions

- Output paths default to inside the calling repo, so artifacts live with the work they describe.
- Absolute dates (`YYYY-MM-DD`) only; relative phrasing breaks across sessions.
- Commit SHAs in `code` formatting, never commit messages.
- Secrets are never written to skill output. If one is encountered, its existence and location are noted; the value never is.

## Contributing

A new skill should fill a gap that synthesizes across several sources (git, GitHub, the task list, memory), follow a non-obvious template, or persist information that would otherwise be lost across sessions. A skill that dresses up a single shell command is not worth the surface area.

See [Anthropic's skill documentation](https://docs.claude.com/en/docs/claude-code/skills) for the skill format. Licensed under [MIT](./LICENSE).
