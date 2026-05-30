---
name: session-carry-forward
description: Produce a structured handoff document at the end of a long Claude Code session so the next session (or a teammate) can pick up without re-litigating decisions or re-running discovery. Use when the user says things like "wrap this session", "create a handoff", "carry-forward", "session summary for next time", "/carry-forward", or asks for a doc that will seed a future session with everything that happened, was decided, was explored, was rejected, plus what's left to do.
---

# session-carry-forward

Generate a single Markdown file that captures everything a future session needs to resume this work cleanly: outcome state, decisions with rationale, rejected paths, deferred items, findings, gotchas, and a paste-ready seed prompt.

The goal is **not** a transcript. A future reader who has never seen this session should be able to:

1. Understand the state of the world in under 60 seconds of reading.
2. Verify that state still holds (with concrete commands).
3. Pick up exactly where the prior session paused without re-asking the human anything that has already been decided.

## When to invoke

User-facing triggers:

- "/carry-forward" (slash-command-style)
- "wrap this session", "wrap up", "create a handoff"
- "session carry-forward" / "carry forward this session"
- "write a session summary for next time"
- "we're parking this — leave me a doc to pick it up later"

Don't invoke automatically — only when the user explicitly asks for a handoff.

## Output location

**Default: inside the calling repo** at `./carry-forwards/<YYYY-MM-DD>-<short-slug>.md`, where the slug is a 2-4 word kebab-case description of the session's topic (e.g. `demos-consolidation-step-4`).

Decision tree for picking the path:

1. If the current working directory is inside a git repo (run `git rev-parse --show-toplevel`), put the file under `<repo-root>/carry-forwards/<YYYY-MM-DD>-<slug>.md`. Create the directory if missing.
2. Else, fall back to `~/.claude/carry-forwards/<basename-of-cwd>-<YYYY-MM-DD>-<slug>.md`.
3. The user can override either with `path:` or a literal absolute path. Honor it.

Do not check in or commit the file yourself unless the user explicitly asks. Mention the path you wrote to.

## Procedure

1. **Confirm scope and audience.** Ask if the next reader is the same user (default) or a teammate, since the level of context-setting differs. If user doesn't volunteer, assume same-user and skip the question.
2. **Survey the current state.** Use `git log`, `git status`, `git branch`, `gh run list` (if applicable), and TaskList to inventory what landed, what's open, and what's in flight. Do not include raw command output in the doc — synthesize.
3. **Walk the session backward.** Pick out: decisions made, paths considered-but-rejected, paths attempted-and-abandoned, findings (technical and procedural), open follow-ups.
4. **Fill the template at [`references/template.md`](references/template.md) in order.** Keep each section tight; if a section would be empty for this session, drop the heading rather than write "N/A".
5. **Write the seed prompt last.** It is a literal paste-ready block, not a summary-of-the-doc. A future session pastes that block and gets re-oriented.
6. **Show the user the path** you wrote to and a quick view of the doc's top section.

## What goes in the file

The template (see `references/template.md`) enforces this set of sections. The most important ones, in priority order:

1. **TL;DR** — 3-5 sentences max. The next session reads this first.
2. **Current state snapshot** — branch name, last commit SHA(s) of interest, whether pushed, untracked files, CI status, deployed/published artifacts. This is the *invariant* the next session checks first.
3. **Decisions made** — each one paired with the *rejected alternative* and a one-line reason. Decisions without context lose half their value.
4. **Rejected & abandoned paths** — separate from decisions: things considered but not implemented, plus things attempted then reverted. Save the next session from re-suggesting them.
5. **Deferred / open items** — what's intentionally not done yet. The next session's TODO list.
6. **Findings & gotchas** — surprising things worth remembering. Split into technical (bugs, version pitfalls, undocumented behavior) vs. procedural (a workflow that worked or didn't).
7. **Files & paths touched** — short orientation list, not an exhaustive diff. Group by purpose.
8. **External-systems status** — anything live that could shift between sessions: CI runs, deployed images, open PRs, scheduled jobs, secrets that need rotation.
9. **Verification commands** — concrete shell snippets the next session runs to confirm the state described above still holds.
10. **People / accounts / context** — only what's not obvious from the repo (GitHub usernames, customer/org, role of the user).
11. **Seed prompt** — paste-ready block for the next session.

## What NOT to include

- **Don't paraphrase the whole conversation.** A transcript is worse than nothing because the reader skips it.
- **Don't include literal secrets or tokens.** If a secret was discovered during the session, note its existence and where it lives, never its value. Redact `ghp_...`, PATs, API keys, passwords.
- **Don't restate everything from the project's README.** Link to it instead.
- **Don't include speculative future plans the user hasn't agreed to.** Stick to what was decided.
- **Don't include time estimates unless the user gave them.**

## Boundaries

- Stay terse. Each bullet should be one line. Each section should be readable in <30 seconds.
- Absolute dates only (YYYY-MM-DD). "Yesterday" breaks across sessions.
- Quote commit SHAs, not commit messages.
- Mention the model/tool that wrote the doc only if asked.
- If the session was very short (under ~15 minutes of substantive work) and the doc would be padding, say so and ask if the user really wants one.

## Style of the seed prompt

The seed prompt is a literal block at the bottom of the file, fenced as a code block so it's easy to copy. It should:

- Start with one sentence telling the next session what it is.
- Point at the carry-forward file by absolute path.
- State the next intended action in one line.
- End. No fluff.

Example shape:

```
This is a resumption of an earlier session. Read the carry-forward at
<absolute-path-to-doc> for full context. The immediate next action is:
<one specific thing>.
```

## Output to the user

After writing the file, surface in your reply:

- The full path you wrote to.
- The TL;DR section verbatim (so the user can sanity-check it without opening the file).
- A reminder that the seed prompt at the bottom is the literal text to paste at the start of the next session.
