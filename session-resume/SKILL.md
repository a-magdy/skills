---
name: session-resume
description: Resume work from a session-carry-forward document. Reads the latest carry-forward in `./carry-forwards/`, runs its verification commands to confirm reality still matches what the doc described, surfaces any drift (new commits, CI changes, untracked files), recreates the task list from the doc's deferred items, and reports a single "ready to continue from <next action>" line. Use when a user pastes a carry-forward seed prompt, says "resume from carry-forward", says "pick up from last session", or otherwise starts a session by pointing at a prior carry-forward file.
---

# session-resume

Reads a carry-forward written by `session-carry-forward`, verifies the world hasn't drifted, and reorients without re-asking everything.

## When to invoke

- A new session opens with a paste-block that says "This is a resumption of an earlier session" + a path.
- "Resume from carry-forward", "pick up from last session", "continue from <path>".
- The user mentions a `carry-forwards/` doc by name.

Do not invoke automatically just because there's a `carry-forwards/` directory in the repo. The user has to ask.

## Inputs

- **Carry-forward path** — explicit path the user provided, or:
  - The most recent file under `<repo-root>/carry-forwards/*.md` (sort by filename, which encodes YYYY-MM-DD).
  - Failing that, `~/.claude/carry-forwards/*` matching the current repo basename.
- If multiple recent files exist and the choice is ambiguous, ask the user which one. Don't guess.

## Procedure

1. **Locate and read the carry-forward file.** Quote the full path back to the user.
2. **Parse the structured sections.** You're looking for: Current state snapshot, Deferred / open items, Verification commands, Seed prompt (in particular the "immediate next action" line).
3. **Run the verification commands** from the doc's "Verification commands" section. Capture output; don't paste raw output back to the user — synthesize.
4. **Compare reality vs. the doc.** For each:
   - **Branch / ahead-behind:** has it changed since the doc was written? New commits? Now pushed/merged?
   - **Unpushed commits listed in the doc:** still local, or pushed?
   - **CI status:** still the same run reported, or has a newer run appeared?
   - **Working tree:** clean? Same untracked files? New ones?
   - **External artifacts:** still present? Tags/images mentioned still resolvable?
   - **Listed secrets/follow-ups:** has the user said anywhere they've rotated/done them? (Memory check.)
5. **Repopulate the task list.** Use the doc's "Deferred / open items" as `TaskCreate` calls, preserving the order. Mark anything already-done (per drift check) as `completed`.
6. **Report.**

## Output format

A single tight reply structured as:

```
Resumed from: <absolute path to carry-forward>

State check:
- <one line per item: ✓ matches doc, ⚠ drifted (describe), or ❓ couldn't verify>

[If drift detected:]
Drift detected:
- <one line per drift item, with what changed>

Open items recreated as tasks: <count>

Ready to continue. Next action per the carry-forward:
  <one-line copy of the next-action from the seed prompt>
```

If the user wants to deviate from the carry-forward's stated next action, they'll say so. Don't assume.

## Drift handling

Drift is normal across days. Be precise about it, not alarmed.

- **Benign drift** — new commits on `main` from elsewhere, CI re-ran since, untracked files appeared. Report and move on.
- **Notable drift** — the "immediate next action" has already been done, listed unpushed commits have been pushed, an external artifact mentioned in the doc no longer exists.
- **Breaking drift** — the branch has been rebased/squashed and SHAs in the doc no longer exist; the file the doc points at has moved or been deleted; secret rotation status unclear.

For breaking drift, **stop and report** — don't try to proceed. The user needs to decide whether to honor the carry-forward or write a new one.

## Boundaries

- Read-only verification. Don't push, commit, edit, or run anything destructive while resuming.
- Don't dump verification output into the reply; synthesize.
- If the carry-forward is more than ~14 days old, flag it: state has likely drifted enough that the doc is more of an archeological hint than a resume point.
- If no carry-forward is found, say so and offer to start fresh. Don't invent one.
- Don't run any command from the carry-forward's "Verification commands" that mutates state. If a listed command looks destructive (`gh pr create`, `git push`, `rm`, etc.), skip it and note that you skipped it.
