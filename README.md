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

Use the bundled installer:

```sh
git clone <this-repo-url> ~/dev/personal/skills
cd ~/dev/personal/skills
./install.sh
```

By default it **symlinks** each skill into `~/.claude/skills/`, so edits you make in this repo flow through immediately. Useful flags:

| Flag | Effect |
|---|---|
| `--copy` | copy instead of symlink (no auto-update from this repo) |
| `--target PATH` | install to a non-default location |
| `--dry-run` | preview the plan without making changes |
| `-h`, `--help` | full help text |
| _positional args_ | install only those skills (e.g. `./install.sh session-status decision-log`) |

Existing folders at the target are handled safely:

- a previous symlink → removed and replaced;
- a real directory → backed up to `<name>.bak-<YYYYMMDD-HHMMSS>` and replaced.

After install, the skills auto-activate when Claude recognizes the trigger phrases in the table above. No manual invocation needed — though you can also force one with the Skill tool if Claude doesn't trigger automatically.

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
