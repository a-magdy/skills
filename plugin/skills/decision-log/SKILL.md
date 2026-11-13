---
name: decision-log
description: Append a single decision entry to a project-level decision log (`DECISIONS.md` at the repo root by default). Each entry records what was chosen, the rejected alternative, the reason, and the consequences. Use when the user says "log this decision", "add to decision log", "record this", "ADR for X", "remember that we decided Y over Z", or any phrasing that asks to persist a decision beyond the current session. Different from the `session-carry-forward` skill, which captures decisions only inside per-session handoff docs; this skill accumulates them in a long-lived, project-level record.
---

# decision-log

Append one decision at a time to a project's `DECISIONS.md`. Each entry is short and self-contained — the file becomes a chronological project memory that survives across sessions and people.

## When to invoke

- "log this decision", "add to the decision log", "record this"
- "ADR for <thing>", "write an ADR" (though we use a lighter format than full ADRs)
- "remember that we decided X over Y"
- "this is the kind of choice we should write down"

Don't invoke automatically on every decision-shaped statement. Only when the user asks to *persist* one.

## Output location

**Default: `<repo-root>/DECISIONS.md`.** Single file, chronological (newest decisions at the top).

Decision tree:

1. If `git rev-parse --show-toplevel` succeeds, use `<repo-root>/DECISIONS.md`.
2. If `<repo-root>/docs/decisions/` exists as a directory, write to a new file there using the pattern `YYYY-MM-DD-<slug>.md` (one decision per file, ADR-style). This matches existing convention.
3. If the user provides an explicit path, honor it.
4. Otherwise, fall back to `<repo-root>/DECISIONS.md`, creating the file with a header if missing.

## Procedure

1. **Determine the file location.**
2. **Read the existing file if it exists.** Match its conventions (heading level for entry, separator style, date format). Don't force a new style on a file the user has been maintaining.
3. **If the file doesn't exist**, create it with this header:

   ```markdown
   # Decisions

   Project-level decision log. Newest entries at the top. Each entry
   captures what was chosen, the rejected alternative, the reason,
   and the consequences.

   ---
   ```

4. **Gather the entry's content.** From the user's wording and from session context, fill in:
   - **Date** (YYYY-MM-DD)
   - **Decision** — one-line headline of what was chosen
   - **Context** — why this decision was needed (1-2 sentences)
   - **Rejected alternative(s)** — what was considered and not picked, with a one-line reason
   - **Consequences** — what is now true / different because of the decision (1-2 sentences)

   If any of these can't be inferred and the user hasn't given them, ask once. Don't invent the rejected alternative — if the user only said "we chose X", ask what was rejected.

5. **Insert the new entry** immediately after the header / introduction block, above the previous most-recent entry. Newest-first ordering.

6. **Tell the user** the path and quote the new entry back to them so they can verify.

## Entry format (the default)

```markdown
## YYYY-MM-DD — <one-line decision>

**Context:** <1-2 sentences on why this was up for decision>

**Decision:** <what was chosen, named clearly>

**Rejected alternative:** <what was considered>. **Why not:** <one line>

**Consequences:** <1-2 sentences on what's now true>

---
```

If multiple alternatives were rejected, list them:

```markdown
**Rejected alternatives:**
- <option A> — <why not>
- <option B> — <why not>
```

If the project uses ADR format (separate file per decision under `docs/decisions/`), use this:

```markdown
# ADR <N>: <title>

- **Status:** accepted
- **Date:** YYYY-MM-DD

## Context
<paragraph>

## Decision
<paragraph>

## Alternatives considered
- <option> — <reason rejected>

## Consequences
<paragraph>
```

…and bump `<N>` to one past the highest existing ADR number.

## What NOT to record

- Implementation details that belong in code comments.
- Choices that have no rejected alternative ("we used `git status` to check state" — that's not a decision).
- Decisions the user hasn't actually committed to — if the discussion is ongoing, say so and offer to log it later.
- Anything that would expose secrets or sensitive context.

## Boundaries

- Don't commit the file. The user will, when they're ready.
- Don't modify or delete existing entries — the log is append-only.
- If a decision contradicts a previous logged entry, **don't silently overwrite**; add the new entry and note the supersession in its **Consequences** line ("supersedes the 2025-11-04 decision about X").
- One invocation, one entry. If the user dumps several decisions at once, ask whether they want them as one combined entry or several.
