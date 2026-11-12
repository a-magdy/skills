---
name: scratch-workspace-routing
description: Find and verify the real project repository when a session starts outside it, in a scratch, temp, sandbox or home directory, or an editor- or app-generated scratch workspace with no project selected, but the user's request refers to existing project work. Use when the working directory is not a git repo (or is a scratch/scratchpad/tmp dir) and the user names a repo, path, branch, issue, session ID, or says "continue where we left off", "keep working on X", "in my <project> repo", "resume session <id>". Resolves session IDs to their recorded working directory, verifies the candidate repo, loads its instructions, and asks when the evidence is ambiguous. Not for resuming from a carry-forward doc once the repo is known (use session-resume), and not for tasks that need no repository.
---

# Scratch Workspace Routing

The session started somewhere that is not the project: an editor/app scratch workspace, a sandbox, `/tmp`, or `$HOME`. The user's task belongs to a real repository elsewhere. Find it, prove it is the right one, and work there, without guessing and without turning the scratch directory into a fake project.

## 0. Fast exit: does this task need a repository?

Treat any scratch-workspace notice as environment context, not as the task and not as evidence about the project. Read the user's request on its own.

If the request is repository-independent (a general question, a one-off script, a calculation, writing that is not tied to a codebase), stop here and work in the scratch directory. Do not run project discovery.

## 1. Extract clues, strongest first

| Strength | Clue | Treat as |
|---|---|---|
| Strong | Absolute or `~`-relative path, `owner/repo`, remote URL | Near-direct pointer; still verify |
| Strong | Session ID (UUID-like) | Resolve via session history (step 2) |
| Medium | Repo or project name, branch name, issue/PR number | Search key |
| Weak | File names, distinctive identifiers, technical terms | Tie-breaker only |

Never treat a weak clue as proof of identity.

## 2. Resolve session IDs and prior-work references

Session transcripts usually record the working directory they ran in, which turns a session ID straight into a repo path. Look only in the history of the CLI you are running in unless the user says otherwise.

- **Claude Code**: transcripts live at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. The folder name is the cwd with `/` replaced by `-`; each JSON line carries a `"cwd"` field, which is authoritative (the folder encoding is lossy for paths containing `-`).
  `ls ~/.claude/projects/*/<id>.jsonl` then `grep -m1 -o '"cwd":"[^"]*"' <file>`
- **Copilot CLI**: `~/.copilot/session-state/<session-id>/workspace.yaml` has `cwd:` and a `summary:` of the first prompt; `events.jsonl` has `gitRoot` and `branch` in the `session.start` event.
- **Other tools**: check that tool's documented history location; if none is available, say so and continue with the remaining clues.

For "continue where we left off" without an ID, list the most recent sessions (by mtime) and match their cwd/summary against the user's clues. Read only enough to identify the repo and the intended next action. Do not invent prior context.

If the matched repo contains a `carry-forwards/` directory with a recent doc that matches, hand off to the `session-resume` skill once the repo is verified.

## 3. Locate candidates, with a bounded search

Search in this order and stop as soon as one strong candidate verifies:

1. Paths given by the user or resolved from session history.
2. Recent editor workspaces, if readable (e.g. VS Code's recently-opened list).
3. Common project roots: `~/dev`, `~/code`, `~/src`, `~/projects`, `~/repos`, `~/work`, `~/git`, `~/Developer`, and their immediate subfolders.

Keep it cheap: `find <root> -maxdepth 4 -type d -name .git -prune` filtered by the name clue, pruning `node_modules`, `.venv`, `vendor`, build output and caches. Never scan `/` or the whole home directory recursively. If reading outside the working directory needs permission, ask once with the specific directories you want to read.

## 4. Verify each candidate

For every candidate:

- `git -C <path> rev-parse --show-toplevel` succeeds and is the root you expect.
- The evidence matches: the named files exist, the branch exists (`git -C <path> branch -a --list '*<name>*'`), the remote matches `owner/repo`, or recent commits mention the issue/topic.
- Distinguish worktrees and clones of the same remote: prefer the one that session history pointed at, or the one with the matching branch checked out.

A candidate is **verified** only when at least one strong clue, or two independent medium clues, match.

## 5. Decide

- **Exactly one verified candidate**: use it.
- **Several plausible candidates**, or the task depends on prior context you could not find: ask one focused question listing each candidate path with the evidence that distinguishes it. Do not guess.
- **None**: say what you searched and ask for the path. Do not create a repository, clone, or scaffold one in the scratch directory as a substitute.

## 6. Switch context properly

The target repo's instructions did not load, because the session started elsewhere. Before doing any work:

1. Read the repo's agent instructions: `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, and any nested ones relevant to the files you will touch. Follow them as if they had loaded at startup.
2. Check state with `git -C <root> status --short` and the current branch. Preserve all existing uncommitted changes; never stash, reset, or check out over them without asking.
3. Work with the repo root as the context. If the shell cannot change directory persistently, use verified absolute paths (or `git -C <root>`) for every command and keep all edits inside that repo. If the work will be long, suggest the user reopen the session from the repo root so instructions, memory and permissions load natively.
4. Do not move files out of or into the scratch workspace to "bridge" the two.

## 7. Report

Open with one line naming the repo and the evidence, e.g.:

> Working in `~/dev/acme/widget-service`: session `3f2a…` ran there, and branch `fix/retry-backoff` exists.

Or, when asking: the candidate paths and the one question that decides between them.

## Privacy

Session history can contain secrets, unrelated projects and personal details. Read the minimum, quote nothing beyond what the task needs, and never copy transcript content into files, commits or external requests.
