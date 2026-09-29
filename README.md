# personal/skills

A small set of [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) skills for managing long, multi-day sessions: keeping track of state, preserving context across sessions, and capturing decisions where they belong.

All four skills work together along the session lifecycle — **start, middle, end, across sessions, across projects**. Each one fills a single gap; together they let you treat a Claude session more like a working memory and less like a chat that gets forgotten.

## Skills

| Skill | Trigger phrases | Output |
|---|---|---|
| [`session-status`](./session-status/) | "summarize so far" / "safe to close?" / "what am I in the middle of" | text reply, non-destructive |
| [`session-carry-forward`](./session-carry-forward/) | "wrap up" / "/carry-forward" / "create a handoff" | `<repo>/carry-forwards/<YYYY-MM-DD>-<slug>.md` |
| [`session-resume`](./session-resume/) | "resume from carry-forward" / seed-prompt detection at session start | task list + verification report |
| [`decision-log`](./decision-log/) | "log this decision" / "ADR for X" / "record this" | append to `<repo>/DECISIONS.md` |

### When each one fires

```
Project start ──→ … ──→ Long session ──→ Session end ──→ Days pass ──→ Next session
                              ↑              ↑                            ↑
                       session-status   session-carry-forward      session-resume
                            ↑
                       decision-log   (anytime, accumulates project-level)
```

## Per-skill detail

### `session-status` — mid-session check

A read-only snapshot. Three flavors triggered by phrasing:

- **"summarize this session so far"** — running TL;DR + decision log + open threads. Useful when context is getting long or you're stepping away briefly.
- **"is it safe to close (this session)?"** — yes/no health check. Returns the specific blockers if "no": background jobs, dirty tree, unpushed commits, in-flight CI, stale agents, in-progress tasks.
- **"what am I in the middle of?"** — focused view: current task, last decision, open question to the user, next intended action.

Never writes a file. If you want a handoff doc, ask for a carry-forward instead.

### `session-carry-forward` — end-of-session handoff doc

Produces a single structured Markdown file that captures everything a future session needs to resume cleanly: outcome state, decisions paired with the rejected alternative + reason, abandoned paths, deferred TODOs, gotchas, files touched, external-systems status, verification commands, and a paste-ready seed prompt.

Writes to `<repo>/carry-forwards/<YYYY-MM-DD>-<slug>.md` so the doc lives with the work it describes. Don't commit it automatically — the user does that when ready.

### `session-resume` — pick up from a carry-forward

The companion to `session-carry-forward`. Reads the latest carry-forward doc, runs the verification commands inside it, surfaces drift (new commits, CI changes, untracked files, etc.), recreates the task list from the doc's "Deferred / open items" section, and reports a single "ready to continue from <next action>" line.

Without this skill, the carry-forward is just a doc you re-read manually. With it, picking up next week takes one prompt.

### `decision-log` — accumulating project-level decision record

Appends a single decision entry to `<repo>/DECISIONS.md` (or a new file under `docs/decisions/` if that's the convention in the repo). Each entry records the chosen option, the rejected alternative(s), the reason, and the consequences.

Different from `session-carry-forward`: that skill captures decisions only inside per-session docs. `decision-log` builds a long-lived, append-only record across sessions and people — useful when future-you (or a teammate) asks "why did we choose X?" months later and doesn't want to grep 12 carry-forwards.

## Install

Skills live in `~/.claude/skills/`. To install these:

```sh
git clone <this-repo-url> ~/dev/personal/skills
cd ~/dev/personal/skills
./install.sh
```

The installer automatically runs `apm install` to fetch third-party dependencies (from `anthropics/skills`) before symlinking everything into `~/.claude/skills/`. Requires [APM](https://github.com/microsoft/apm) (`curl -sSL https://aka.ms/apm-unix | sh`).

By default it **symlinks** each skill into `~/.claude/skills/`, so edits you make in this repo flow through immediately. Useful flags:

| Flag | Effect |
|---|---|
| `--copilot` | also/instead install into `~/.copilot/skills/` (Copilot CLI) |
| `--claude` | install into `~/.claude/skills/` (default when no target flag given) |
| `--copy` | copy instead of symlink (no auto-update from this repo) |
| `--target PATH` | install to a non-default location |
| `--dry-run` | preview the plan without making changes (no `apm install` is run) |
| `-h`, `--help` | full help text |
| _positional args_ | install only those skills (e.g. `./install.sh session-status decision-log`) |

Existing folders at the target are handled safely:

- a previous symlink → removed and replaced;
- a real directory → backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` and replaced.

After install, the skills auto-activate when Claude recognizes the trigger phrases in the table above. No manual invocation needed — though you can also force one with the Skill tool if Claude doesn't trigger automatically.

### Third-party skills (via APM)

The following skills are sourced from [`anthropics/skills`](https://github.com/anthropics/skills) and managed by [APM](https://github.com/microsoft/apm) (declared in `apm.yml`):

| Skill | Source |
|---|---|
| `frontend-design` | anthropics/skills |
| `mcp-builder` | anthropics/skills |
| `pdf` | anthropics/skills |
| `pptx` | anthropics/skills |
| `skill-creator` | anthropics/skills |
| `xlsx` | anthropics/skills |
| `i-have-adhd` | ayghri/i-have-adhd |
| `grill-me` | mattpocock/skills |
| `show-me` | humanlayer/skills |
| `improve-claude-md` | humanlayer/skills |

To update to latest upstream versions: `apm update`. The lockfile (`apm.lock.yaml`) pins exact commits and content hashes for reproducibility.

## Two deployment layers

This repo deploys agent context at **two layers**:

| Layer | Source of truth | Deployed by | What it is |
|---|---|---|---|
| **Skills** | `apm.yml` + native skill dirs | [`install.sh`](./install.sh) | Individual skills (a `SKILL.md` folder), symlinked into `~/.claude/skills` and `~/.copilot/skills`. |
| **Whole plugins / harnesses** | [`plugins.list`](./plugins.list) | [`install-plugins.sh`](./install-plugins.sh) | Full plugins installed natively through each agent CLI's own plugin system. |

A symlinked skill is just a `SKILL.md` plus supporting files. A **whole plugin** carries things a symlink can't express — session hooks (auto-bootstrap that re-injects after context compaction), companion tools (a `Skill` tool, subagent/task-list helpers), bundled MCP/LSP servers or agents, and a `plugin.json` / `marketplace.json` manifest the CLI reads. `obra/superpowers` is the canonical example: pulling its skills via APM makes them *available*, but only the whole plugin gives you the always-on methodology, because the auto-bootstrap lives in the plugin's hooks — not in any single `SKILL.md`.

### Whole plugins / harnesses

[`plugins.list`](./plugins.list) is pipe-delimited, one plugin per line (comments start with `#`):

```
# marketplace_repo | marketplace_name | plugin | targets | description
obra/superpowers-marketplace | superpowers-marketplace | superpowers | copilot,claude | ...
```

- **marketplace_repo** — GitHub `owner/repo` of the marketplace to register.
- **marketplace_name** — the `name` in that marketplace's `marketplace.json` (used as `plugin@marketplace_name`).
- **plugin** — the plugin's name within the marketplace.
- **targets** — comma-separated CLIs (`copilot`, `claude`).
- **description** — free text (informational only).

```sh
./install-plugins.sh            # install into both copilot and claude (default)
./install-plugins.sh --dry-run  # preview the exact CLI commands
./install-plugins.sh --copilot  # only the copilot target
./install-plugins.sh --claude   # only the claude target
```

The script is idempotent (re-adding a marketplace or re-installing a plugin is a no-op refresh) and skips any target whose CLI is not on `PATH`, so it's safe to re-run and safe on machines missing one CLI. It exits non-zero only if an actual install command fails.

### Full machine bootstrap

```sh
git pull
apm install             # fetch APM skill dependencies (apm.yml)
./install.sh --copilot  # symlink native + APM skills into ~/.claude and ~/.copilot
./install-plugins.sh    # install whole plugins/harnesses via each CLI (plugins.list)
```

## Install this repo as a plugin

This repo is itself a **plugin marketplace** (see [`marketplace.json`](./marketplace.json)). Its own skills — session lifecycle, site design, Danish due diligence — plus SessionStart/SessionEnd hooks ship as the `personal-skills` plugin, installable in one command:

```sh
# Copilot CLI
copilot plugin marketplace add a-magdy/skills
copilot plugin install personal-skills@personal-skills-marketplace

# Claude Code
claude plugin marketplace add a-magdy/skills
claude plugin install personal-skills@personal-skills-marketplace -y
```

> **Pick one path for the repo's own skills.** Installing the plugin **and** symlinking the same skills via `install.sh` loads every one **twice**. The default `install.sh` only symlinks third-party (APM) skills for this reason; the plugin is the source for the repo's own skills. Use `install.sh` symlinks when you're actively editing the skills (live edits), the plugin when you just want to consume them.

## Versioning

The single source of truth is the [`VERSION`](./VERSION) file. Run [`scripts/sync-version.sh`](./scripts/sync-version.sh) to stamp it into `apm.yml` and every plugin/marketplace manifest so they never drift:

```sh
./scripts/sync-version.sh 1.2.0   # set + stamp
./scripts/sync-version.sh --check # verify all match (used by CI)
```

## Design notes

A few principles that shaped this set:

- **One skill per lifecycle moment, not one per question.** `session-status` handles three related questions because they share the same survey work; splitting would duplicate effort.
- **Decisions are always recorded with their rejected alternative.** A decision without context loses half its value next month.
- **Verification commands ship with the doc.** Drift between sessions is normal — the carry-forward includes the shell snippets the next session runs first.
- **Read-only by default.** Only `session-carry-forward` and `decision-log` write to disk, and neither commits.
- **No `co-authored-by` trailers** are produced by these skills. The user's commits are the user's.

## Conventions

- Output paths default to inside the calling repo so the artifacts live with the code they describe.
- Absolute dates (`YYYY-MM-DD`) only — relative phrasing breaks across sessions.
- Commit SHAs in `code` formatting, never commit messages.
- Secrets are never written to skill output. If a secret is encountered, its existence and location are noted; the value never is.

## Contributing / extending

If you want to add a skill, the bar is: it should fill a gap that synthesizes across multiple sources (git + GitHub + task list + memory), follow a non-obvious template, or persist information that would otherwise be lost across sessions. A skill that just dresses up a single shell command isn't worth the surface area.

See [Anthropic's skill documentation](https://docs.claude.com/en/docs/claude-code/skills) for the full skill format.
