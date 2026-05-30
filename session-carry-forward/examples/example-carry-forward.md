# Session carry-forward — demos consolidation & de-corporatize sweep

**Span:** 2026-05-21 → 2026-05-30 (intermittent, ~9 calendar days)
**Repo / working dir:** `/Users/zak/dev/hub/training/github-actions-training`
**Audience:** same-user

## TL;DR

Migrated `~/dev/hub/demos` (28 scattered folders) into one consolidated training repo at `~/dev/hub/training/github-actions-training`, then ran a 5-step "de-corporatize" sweep so the repo runs end-to-end with only assets the maintainer owns. Current branch `main` is **6 commits ahead of `origin/main` and not yet pushed**; the working tree is clean. The published CI (`Lint`) is green on the last pushed commit. The deferred next action is **push and trigger the publish workflows** to populate `ghcr.io/a-magdy/github-actions-training/base-image`, then run a smoke test of one workflow per topic.

## Current state snapshot

- **Branch:** `main` — 6 commits ahead of `origin/main`, not pushed.
- **Working tree:** clean. No untracked files.
- **Last six unpushed commits** (newest first):
  - `238fac0` — published-reusable lesson now also has a runnable local-syntax caller via `.github/workflows/teaching-reusable.yml`
  - `69c7f7b` — dropped trump-quotes narrative, consolidated private-image refs on `ghcr.io/a-magdy/ubuntu` (Path B)
  - `b90086e` — converted 22 cross-repo composite `uses:` refs to local `./` paths
  - `dd42eef` — added `.github/copilot-instructions.md`
  - `2d8a042` — user's prior WIP: modernized trump-quotes & test-gh-docker workflows (timeout-minutes, docker/login-action@v3, github.repository for image paths, build-push-action@v6)
  - `99485d8` — sweep pass 2: BEST-PRACTICES.md, all-contexts.yml, TIPS.md, paired TASK.md files, audit-log updates
- **CI on origin/main:** last `Lint` run green (`gh run 26422468392`).
- **Local actionlint:** 77 workflow files pass with `-ignore 'could not read reusable workflow file'`.
- **Live external artifacts:** none yet for this repo's namespace. `ghcr.io/a-magdy/ubuntu` (the maintainer's personal package) is the canonical private image the lessons reference.

## Decisions made

- **Two repos, not three or more.** Kept `pr-codename-action` as a separate repo since it has its own release lifecycle (CodeQL, check-dist, dist/); folding it in would muddle releases.
- **Start fresh, no git-history preservation.** Reason: training repos don't benefit from the multi-root mess `git filter-repo` would produce.
- **Topic-first layout, course modules secondary.** Top-level `01-fundamentals/` … `08-models-agentic/`. `COURSE.md` sequences topics into Day 1/2/3 paths via links rather than duplicating content.
- **`demos/` stays untouched** as the historical source of truth. All migration is copy-out, never move.
- **2-day course content (`ActionsFundamentals/hol/`) lives under `courses/fundamentals-hol/`**, not split across topic folders; the integrated 11-lesson `actions-demos/fundamentals-pack/` similarly stays whole in `courses/fundamentals-pack/`.
- **Repo-level lint workflow at root `.github/workflows/lint.yml`** is the only auto-running workflow. All teaching workflows live in plain `workflows/` subdirs (never `.github/workflows/`) so they don't auto-run when the lesson repo is published.
- **`actionlint -ignore 'could not read reusable workflow file'`** in CI: teaching workflows reference `./.github/workflows/X.yml` paths that only resolve when copied to a student's fork. Suppressed in CI; teaching examples preserved.
- **`markdown-link-check` invoked directly with an explicit file list** instead of `gaurav-nelson/github-action-markdown-link-check@v1` (which silently ignores its `file-path` input and globs every `*.md`, which tripped on template-style relative links in the migrated HOL course material).
- **Path B over Path A on trump-quotes** (chosen 2026-05-29): drop the trump-quotes narrative entirely; point all private-image refs at the existing `ghcr.io/a-magdy/ubuntu`. Rejected Path A (build & publish `ghcr.io/a-magdy/github-actions-training/trump-quotes-action`) — simpler to consume an existing image than to maintain a custom one for a fictional narrative.
- **Three deliberate external `uses:` refs preserved**: `03-reusable/reusable-workflows-published/workflows/{caller,reusable}.yml` and `06-environments/hosted-actions/workflows/use-a-hosted-action.yml` — each lesson is *about* the cross-repo pattern; converting them would defeat the lesson.
- **Carry-forward skill at user-level**, not project-level. Output path **inside the calling repo's `carry-forwards/`** so the doc lives with the work it describes.

## Rejected & abandoned paths

- **Preserving git history via `git filter-repo`** — considered, rejected because training content is value-per-file, not value-per-commit.
- **Day-based layout (`day1/`, `day2/`)** — rejected because the same concept (matrix, conditions) gets re-taught across days; topic-first removes duplication.
- **Folding `pr-codename-action` into `04-custom-actions/`** — rejected to preserve its independent release lifecycle.
- **Converting *all* external `uses:` refs to local** — rejected for the 3 lessons whose subject *is* cross-repo refs.
- **Keeping the original `gaurav-nelson/github-action-markdown-link-check@v1` action** for link-checking — abandoned after first push: it ignores `file-path` and globs everything, tripping on intentional HOL template links.
- **`actions/checkout@v6` / `actions/setup-node@v6`** that appeared in some migrated files — downgraded to `@v5` / `@v4` because v6 of those actions isn't released as of the session window.

## Deferred / open items

In priority order:

- [ ] **Push the 6 unpushed commits to `origin/main`.** Triggers the Lint CI on the cumulative changes.
- [ ] **Trigger `publish-base-image.yml`** via `gh workflow run` so `ghcr.io/${{ github.repository }}/base-image` exists. Currently nothing publishes to this repo's GHCR namespace.
- [ ] **Smoke-test one workflow per topic** by dispatching them on GitHub. The audit log's "Smoke" column is `⏳` across the board.
- [ ] **Optionally replace the `https://github.com/` placeholder URLs** in `README.md` (line 33) and `04-custom-actions/{README.md, js-action/README.md}` — they're currently ignored by the link checker but a real URL (`https://github.com/a-magdy/pr-codename-action`?) would be cleaner.
- [ ] **Fill the three thin course placeholders** at `courses/{day-demos, migration-labs, slides-fundamentals}/` — they have `TODO.md` scaffolds, no content.
- [ ] **Address Node.js 20 deprecation** before 2026-09-16 (GitHub forces Node 24 on `actions/checkout@v4` and other v4 actions on 2026-06-02; full removal on 2026-09-16).
- [ ] **Decide whether the `05-docker/ghcr-private-image/` folder is duplicative** of `04-custom-actions/docker-action/` + `05-docker/registry-auth/` now that the trump-quotes narrative is gone. The lesson (wrapper-vs-native timing) is unique; the *content* may overlap.

## Findings & gotchas

### Technical

- **`demos/debug-code-actions/.env` contains a literal GitHub PAT** (`ghp_…`). Not copied to the new repo. **Should be rotated** at <https://github.com/settings/tokens>; consider scrubbing the file from `demos/` history.
- **`uses: ./path` resolves relative to the repo root, not the workflow file.** Several migrated workflows had `./trump-quotes-action-wrapper` thinking it would resolve relative to the workflow — silently broken. Fixed during step 2.
- **Reusable workflows can only live under `.github/workflows/`.** Putting one in a topic folder makes it non-callable. That's why `teaching-reusable.yml` is at the repo root even though the lesson it serves lives in `03-reusable/reusable-workflows-published/`.
- **`image: docker://` and Dockerfile `FROM` lines cannot use `${{ }}` expressions.** Forks have to edit the literal path. Mitigation: leave a `# Forks: change 'a-magdy' to your user/org.` comment in every such file.
- **Workflow-level `permissions:` block drops *all* defaults** the moment you set anything. A job that only sets `packages: read` will lose `contents: read` and `actions/checkout` will fail. Documented in `.github/copilot-instructions.md`.
- **DinD with Docker 28 reports `linux/amd64/v3`** which doesn't match multi-arch manifests. Always add `--platform linux/amd64` to `docker run` inside container jobs. Documented in `.github/copilot-instructions.md`.
- **`image: docker://...` actions pull the image during workflow setup, *before* any login step runs.** This is the central lesson of `05-docker/registry-auth/` and `05-docker/ghcr-private-image/`. Composite wrappers work around it because their steps execute at job runtime.
- **`runner.name` context isn't available at job-level `env:`** — only at step-level. Caught by actionlint in `courses/fundamentals-pack/workflows/05-context-vars.yml`.

### Procedural

- **Inventory before edit.** A `grep -rln` pass before each sweep step (cross-repo refs, solidifydemo refs, github-actions-training/ubuntu refs) caught sites that the per-file diff would have missed.
- **Step-by-step confirmation flow worked well** for the 5-step de-corporatize sweep. The user wanted to approve each step's *goal* before any edits; in practice this caught two design pivots (Path A vs B, what to do with hosted-actions lesson) that would have been wasted work.
- **Local lint before push.** `actionlint -ignore 'could not read reusable workflow file'` over the explicit file list catches everything CI catches, with a faster feedback loop. Same for `markdown-link-check`.
- **Sweep pass 2** found significant content missed in pass 1 (a 397-line best-practices skill, a richer all-contexts demo, a tips file, three exercise-prompt-to-solution pairings). Lesson: always do a final pass-2 sweep for any large migration.

## Files & paths touched

Grouped by purpose, not exhaustive.

- **Repo-root docs (new in this session):** `README.md`, `COURSE.md`, `CHEATSHEET.md`, `BEST-PRACTICES.md`, `TIPS.md`, `MIGRATION-AUDIT.md`.
- **CI / repo-level workflows:** `.github/workflows/lint.yml`, `.github/workflows/teaching-reusable.yml`, `.github/markdown-link-check.json`, `.github/copilot-instructions.md`, `.github/skills/github-actions-best-practices/{SKILL.md, references/checklists.md, evals/evals.json}`.
- **Topic READMEs (per-topic):** `0{1-8}-*/README.md` and per-lesson README inside each subfolder.
- **Topic workflows:** `0{1-8}-*/**/workflows/*.yml` — ~70 teaching workflow files.
- **Custom-action manifests:** `0{3-5}-*/**/action.yml` — composite, JS, Docker variants.
- **Sample app:** `sample-apps/react-vite/` (source-only; no `dist/`, no `node_modules/`).
- **Courses:** `courses/{fundamentals-hol, fundamentals-pack, day-demos, migration-labs, slides-fundamentals}/`.
- **Exercise prompts paired with solutions:** `02-workflow-features/{chaining, matrix}/TASK.md`, `03-reusable/reusable-workflows-local/TASK.md`.
- **Carry-forward (this file):** `carry-forwards/2026-05-30-demos-consolidation.md`.
- **External plan file:** `~/.claude/plans/this-folder-is-a-ticklish-comet.md`.

## External-systems status

- **GitHub repo:** `a-magdy/github-actions-training`, branch `main`. **6 commits ahead of `origin/main`, not pushed.**
- **Last pushed CI run:** `gh run 26422468392` — green.
- **GHCR packages owned by this repo's namespace (`ghcr.io/a-magdy/github-actions-training/*`):** none yet. `publish-base-image.yml` hasn't been run.
- **GHCR package consumed by lessons:** `ghcr.io/a-magdy/ubuntu` (user's personal package). Workflows assume the `GITHUB_TOKEN` of this repo has `packages: read` access to it; if forks fail with 401, package settings on the user's account need to grant access to the consumer repo.
- **Secrets requiring action:** **rotate the GitHub PAT in `~/dev/hub/demos/debug-code-actions/.env`** (`ghp_…`). Not migrated, but exists in the source folder.
- **Separate repo also in scope:** `a-magdy/pr-codename-action` (published TypeScript action, referenced from `04-custom-actions/`). No changes made this session.

## Verification commands

Paste-ready. First three confirm the state described above; the rest are spot checks.

```sh
cd /Users/zak/dev/hub/training/github-actions-training

# State of local vs remote
git log --oneline origin/main..HEAD
git status -sb

# Demos folder unchanged (baseline was 7942 files; check it still is)
find /Users/zak/dev/hub/demos -type f | wc -l

# Local lint (should print exit=0)
bash -c '
  set -euo pipefail
  mapfile -t FILES < <(find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
      -not -path "./.git/*" -not -path "./sample-apps/*" \
      -not -name "action.yml" -not -name "action.yaml" -not -name "docker-compose.yml")
  actionlint -shellcheck "" -ignore "could not read reusable workflow file" "${FILES[@]}"
  echo "exit=$?"
'

# No external orgs left in the repo
grep -rni "solidifydemo" --include="*.md" --include="*.yml" --include="*.yaml" --include="*.sh" --include="Dockerfile" | grep -v MIGRATION-AUDIT.md

# Last 3 CI runs on origin
gh run list --repo a-magdy/github-actions-training --limit 3
```

## People / accounts / context

- **GitHub user:** `a-magdy` (Ahmed Magdy, Eficode).
- **Personal GHCR package referenced by lessons:** `ghcr.io/a-magdy/ubuntu`.
- **Role:** delivers GitHub Actions trainings; this repo is the canonical source-of-truth for those trainings.
- **Companion repo (separate, untouched this session):** `a-magdy/pr-codename-action`.

## References

- Plan file: `/Users/zak/.claude/plans/this-folder-is-a-ticklish-comet.md`.
- Audit log: `MIGRATION-AUDIT.md` (repo root) — includes "Sweep pass 2" and "Sweep pass 3" sections.
- Memory: `/Users/zak/.claude/projects/-Users-zak-dev-hub-demos/memory/{MEMORY.md, user-role.md, project-demos-consolidation.md}`.
- Skill that produced this file: `/Users/zak/.claude/skills/session-carry-forward/`.

---

## Seed prompt for the next session

Paste this verbatim at the start of the next session.

```
This is a resumption of an earlier session.

Read the carry-forward at:
  /Users/zak/dev/hub/training/github-actions-training/carry-forwards/2026-05-30-demos-consolidation.md

…for the full context: decisions, rejected paths, deferred items,
gotchas, and the verification commands to confirm state.

Immediate next action:
  Push the 6 unpushed commits on main, watch the Lint workflow run
  green via `gh run watch`, then run `publish-base-image.yml` via
  `gh workflow run` so the repo's GHCR namespace has a base-image
  to consume. After that, smoke-test one workflow per topic.

Don't restart from scratch — pick up from where the prior session paused.
```
