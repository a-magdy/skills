# Session carry-forward — {{ session_topic }}

**Date:** {{ YYYY-MM-DD }}
**Repo / working dir:** {{ path }}
**Session length:** ~{{ approx-hours }}h
**Audience:** {{ same-user | teammate }}

## TL;DR

> 3-5 sentences. What happened, what state things are in, what's next. The next session reads only this if pressed for time.

## Current state snapshot

- **Branch:** `<name>` — {{ ahead/behind origin }}
- **Last commits of note:**
  - `<sha>` — <one-line subject>
  - …
- **Pushed:** yes / no — last push at <time>
- **Untracked / WIP:** {{ list, or "clean working tree" }}
- **CI status:** <run id> green / red on <branch>
- **Live external artifacts (if any):** <image / package / deployed URL>

## Decisions made

Each as: **what** + **why** + **what was rejected**.

- **<decision>** — chose <X> over <Y>. Reason: <one line>.
- …

## Rejected & abandoned paths

Considered but not implemented, OR tried and reverted. With a one-line reason so the next session doesn't suggest them again.

- **<path>** — <why not>.
- …

## Deferred / open items

Intentionally not done yet. The next session's TODO list, in priority order.

- [ ] <item> — <one-line context>
- [ ] …

## Findings & gotchas

### Technical

- <bug, version pitfall, undocumented behavior>
- …

### Procedural

- <a workflow that worked or didn't, a tool quirk, a recurring time sink>
- …

## Files & paths touched

Short orientation, not a diff dump. Group by purpose.

- **<purpose>:** `path/to/file.ext`, `another/path.ext`
- …

## External-systems status

Anything live that could shift between sessions. Include enough to verify next time.

- **GitHub:** <repo>, branch <name>, CI <green/red>, last run <id>
- **GHCR / registries:** <images and tags that exist>
- **Open PRs / issues:** <links>
- **Secrets requiring action:** <e.g. "rotate PAT discovered at …">

## Verification commands

The first thing the next session runs to confirm the state above. Each line is paste-ready.

```sh
git -C <repo> log --oneline -5
git -C <repo> status -s
gh run list --repo <owner/repo> --limit 3
# add anything else that matters
```

## People / accounts / context

Only non-obvious things the next session needs.

- **GitHub user:** <handle>
- **Org / customer:** <if relevant>
- **User's role:** <one line>

## References

- <plan files, audit logs, design docs produced in this session>

---

## Seed prompt for the next session

Paste this verbatim at the start of the next session.

```
This is a resumption of an earlier session.

Read the carry-forward at:
  {{ absolute-path-to-this-file }}

…for the full context: decisions, rejected paths, deferred items,
gotchas, and the verification commands to confirm state.

Immediate next action:
  {{ one specific thing }}

Don't restart from scratch — pick up from where the prior session paused.
```
