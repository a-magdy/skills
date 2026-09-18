---
name: session-status
description: 'Mid-session health-and-status report for a long Claude Code session. Three flavors triggered by phrasing — running summary ("summarize so far"), safe-to-close health check ("is it safe to close"), and current-focus view ("what am I in the middle of"). Non-destructive: prints a synthesis, never writes a file. Use this when the user wants a snapshot of state without producing a handoff document.'
---

# session-status

A read-only, mid-session status report. Three flavors, one skill, because they share the same underlying survey.

## When to invoke

- "summarize this session so far", "where are we", "running summary"
- "is it safe to close (this session)?", "can I close down?", "anything in flight?"
- "what am I in the middle of", "what's the current focus", "what was I doing"

The user's phrasing tells you which flavor they want. If ambiguous, do all three in one report — they're cheap to combine.

This skill never writes a file. If the user wants a handoff doc, invoke `session-carry-forward` instead.

## Procedure

1. **Survey.** Gather state in parallel where possible:
   - `git rev-parse --show-toplevel` to find the repo root (skip if not in one)
   - `git status -sb` for branch + ahead/behind + working-tree state
   - `git log --oneline origin/<branch>..HEAD` for unpushed commits
   - `git log --oneline -10` for recent context
   - `jobs -l` for background shell jobs in the current session
   - Recent Bash invocations that ran `run_in_background: true` and may still be live (check `/private/tmp/claude-*/tasks/` if relevant)
   - The task list (TaskList) for in-progress / pending items
   - `gh run list --limit 3` if a `gh` remote is configured
2. **Pick the flavor(s)** based on the user's phrasing.
3. **Report.** Markdown reply, no file output.

## Flavor A — "summarize so far"

A running TL;DR for when context is getting long or the user wants a checkpoint without producing a handoff.

Sections:

- **TL;DR** — 2-4 sentences. What's been done, current focus, immediate next thing.
- **Decisions so far** — bulleted, one line each. Just the *what*; the *why* belongs in a carry-forward.
- **Open threads** — questions the user hasn't answered, choices not yet made, tasks not yet picked up.

Keep under ~25 lines. If the user wants more, they'll ask.

## Flavor B — "is it safe to close?"

Tight health check. Return a yes/no on the first line, then the specific items that block "yes" (if any).

Check these, in order:

- Background jobs still running? (`jobs -l`, any in-flight `run_in_background` Bash agents, any active subagents from `Agent` tool)
- Working tree dirty? (modified, untracked, staged)
- Unpushed commits on the current branch?
- In-flight CI? (`gh run list --status in_progress`)
- Stale lock files or temporary files this session created?
- Tasks in `in_progress` status that haven't been completed?
- Any plan-mode plan that wasn't approved/exited?

If everything is clear: report **"Safe to close."** with a one-line summary of why (e.g. "working tree clean, no background jobs, all commits pushed, no in-flight CI").

If anything blocks: report **"Not safe to close until:"** with the bulleted list of blockers. Each blocker should include the command to address it (e.g. "Push 6 unpushed commits: `git push`").

## Flavor C — "what am I in the middle of?"

Smaller scope than the summary. Focused on *what's happening right now*.

Sections:

- **Current task** — the in-progress TaskList item, or the last commit subject, or the open file being edited.
- **Last decision** — most recent decision made in the session, if any.
- **Open question to me** — if you asked the user something they haven't answered yet, surface it.
- **Next intended action** — one line, what the user would do next if they continued.

Useful as a "remind me where I am" after a break.

## Boundaries

- Read-only. No `git add`, no commits, no edits, no file writes.
- Synthesize, don't dump command output. The user wants the answer, not the inputs.
- If the session is brand new (no decisions made, no work done), say so plainly: "Session just started — nothing to report yet."
- If the user asks for one flavor and another flavor surfaces something critical (e.g. they ask for a summary but you discover an in-flight CI run that's failing), mention it briefly at the end.

## Style

- Top of reply is the headline (a TL;DR or a yes/no).
- One section per flavor requested; don't pad with sections that have nothing to say.
- Commit SHAs in `code` formatting.
- Absolute dates only.
