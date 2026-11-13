# What triggers each skill

Quick reference for which prompts load which skill. The source of truth is each skill's `description` in its `SKILL.md`, since that is all the agent sees when choosing. Update this file whenever a description changes.

- **auto**: loads when your prompt matches the description. The phrases below are examples, not an exact-match list.
- **`/name`**: `disable-model-invocation: true`. Never loads on its own; type the slash command at the start of your prompt.

## Manual-only (slash command)

| Skill | Turn on | Turn off / notes |
|---|---|---|
| `i-have-adhd` | `/i-have-adhd` | Stays on for the whole session. Off: "stop adhd mode" or "normal mode". |
| `grill-me` | `/grill-me` | Relentless interview to sharpen a plan or design. |
| `show-me` | `/show-me` | Explains the current topic with diagrams, code-shape sketches, small HTML artifacts. |

In Copilot CLI, type the slash command yourself; asking the model to "use the i-have-adhd skill" fails for these skills (github/copilot-cli#4438).

## Session lifecycle (own, via plugin)

| Skill | Example prompts |
|---|---|
| `session-status` | "summarize this session so far" · "is it safe to close?" · "what am I in the middle of?" |
| `session-carry-forward` | "wrap this session" · "create a handoff" · "carry-forward" · "session summary for next time" · "leave me a doc to pick this up later" |
| `session-resume` | paste a carry-forward seed prompt · "resume from carry-forward" · "pick up from last session" |
| `decision-log` | "log this decision" · "add to decision log" · "ADR for X" · "remember that we decided Y over Z" |
| `scratch-workspace-routing` | session started in a scratch/temp/sandbox/home dir **and** the prompt points at a repo: "keep working on widget-service" · "resume session 3f2a…" · "continue where we left off" · "in my acme repo, fix the failing test" |

The plugin's SessionStart hook ([`plugin/hooks/session-start`](../plugin/hooks/session-start)) backs `scratch-workspace-routing` up: when a session starts outside any git repo it injects a one-paragraph note pointing at the skill, so routing does not depend on the agent noticing its working directory on its own. Inside a repo, the same hook notes the newest carry-forward (by filename, if it is under 14 days old) so the agent can mention it; `session-resume` still runs only when you ask. The hook fires on startup and resume, not after `/clear` or compaction.

## Other own skills (via plugin)

| Skill | Example prompts |
|---|---|
| `staged-commit` | "commit this" · "commit my changes" · "commit in stages" · "stage and commit" · "break this into commits" |
| `danish-listing-review` | a Danish property address, bolig listing URL or property PDFs · "is this worth buying?" · "red flags?" · tilstandsrapport, salgsopstilling, energimærke, ejerudgift, boligkøb |
| `cinematic-static-site` | "cinematic" · "scroll-driven animations" · "parallax" · "WebGL background" · "smooth scrolling" · "awwwards-style" · "make my static site look amazing" |
| `multi-variant-site-design` | "design variants" · "show me a few directions for the site" · "gallery of designs" · "compare layouts" · "A/B site concepts" |

## Third-party (via APM, `install.sh`)

| Skill | Example prompts |
|---|---|
| `frontend-design` | "design / restyle this UI" · "make it look distinctive, not templated" · typography and aesthetic direction |
| `mcp-builder` | "build an MCP server for the X API" (Python FastMCP or TypeScript SDK) |
| `pdf` | any task that reads, creates, merges, splits, fills or OCRs a `.pdf` |
| `pptx` | "deck", "slides", "presentation", or any `.pptx` / `.potx` file |
| `xlsx` | any task where a spreadsheet (`.xlsx`, `.csv`, `.tsv`) is the input or output |
| `skill-creator` | "create a skill" · "improve this skill" · "run evals on this skill" · "optimize the description's triggering" |
| `improve-claude-md` | "improve my CLAUDE.md" · add `<important if>` blocks |

## Known overlaps

Prompts where two skills compete. Be explicit if the wrong one fires.

- "wrap up": `session-carry-forward` (handoff doc) vs `staged-commit` ("wrap up my working tree into commits").
- "make the site look premium": `frontend-design` (visual style) vs `cinematic-static-site` (motion). Add "variants" / "options" and `multi-variant-site-design` joins in.
- "record this": `decision-log`, but generic enough to miss. Say "log this decision".
- "continue where we left off": `scratch-workspace-routing` finds the repo when the session started outside it; `session-resume` takes over once a carry-forward doc is found there.
