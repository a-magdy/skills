# Roadmap & known gaps

Maintainer notes for this skill. **Deliberately not referenced from `SKILL.md`**, so it never
loads into context when the skill runs — a model doing a property analysis does not benefit
from reading about the skill's own backlog, and telling it "the el-parser is unvalidated"
mid-task just makes it hedge on cases that work fine.

Keep it here rather than in a session handoff because these are properties of *the skill*,
not of a conversation. They stay true until someone fixes them, they travel with the code in
git, and the next person to open this directory finds them without knowing what to search for.

Last reviewed: 2026-09-29

---

## 1. Evals have never actually been run

**Status:** open · **Impact:** high · **Effort:** a session

`evals/evals.json` holds 9 prompts with `expected_output` prose, but no `assertions` field and
no recorded run. They are hypotheses about how the skill behaves, not evidence.

Everything in the skill so far has been verified by the same agent that wrote it — reading its
own work, checking its own arithmetic. That catches typos and contradictions. It cannot catch
the failure mode that matters most: an independent model reading these instructions and
drawing a different conclusion than intended.

To close it, follow the `skill-creator` loop:

1. Add `assertions` to each eval — objectively checkable statements, not vibes.
2. Spawn with-skill and baseline runs for each eval **in the same turn**, into
   `../danish-listing-review-workspace/iteration-1/eval-<id>/`.
3. Grade, aggregate with `scripts.aggregate_benchmark`, review in `eval-viewer/generate_review.py`.

Highest-value evals to run first, because they cover the traps where a wrong answer is
confidently wrong rather than obviously wrong: **3** (skatterabat / tax uplift), **4** (split
loan), **7** (andelsbolig), **9** (condition adjustment).

## 2. Electrical-report parser is validated only against a synthetic fixture

**Status:** open · **Impact:** medium · **Effort:** ~1 hour, needs a real PDF

`extract_elinstallationsrapport()` in `scripts/extract_property_pdfs.py` was written from the
standard category wording and tested against a `reportlab`-generated fixture. No real
elinstallationsrapport has ever been passed through it.

Risk is bounded — on no match it prints "read the report manually" rather than implying a
clean bill, so it fails loud rather than silent. But the category-matching subtlety is real:
the shock and fire headings *contain* the literal words "ulovlige forhold", so a naive count
files critical findings under the mild bucket. The fixture was built by the same reasoning
that wrote the parser, which means it validates internal consistency, not correctness.

What to do when a real report turns up: run it, check the severity counts against what a human
reads off the document, and pay particular attention to whether real reports use the heading
wording assumed here or something looser.

## 3. Rate constants go stale annually

**Status:** recurring · **Impact:** medium · **Effort:** ~15 minutes/year

`RATES_YEAR = 2024` in `scripts/property_finance.py` gates a staleness warning that fires
whenever the current year differs. It is firing right now.

The warning is the safety net, not the fix. Each year, verify against skat.dk and refresh:
ejendomsværdiskat rates and thresholds, the progressive threshold, grundskyld permille
guidance in `references/calculations.md` (currently 5–10‰ post-reform), `rentefradrag`
percentages and the threshold where the higher rate stops, and `BIDRAG_BANDS`.

`BOLIGLAAN_DEFAULT_RATE` (7.0%) is a different kind of number — a placeholder for a figure
that is genuinely borrower-specific. It should stay flagged `[rate ASSUMED]` in output no
matter how current it is, because the bank's real offer is the only correct value.

## 4. Description has not been through trigger optimisation

**Status:** open · **Impact:** low-to-medium · **Effort:** ~1 hour, mostly waiting

The `description` frontmatter is the sole mechanism deciding whether this skill fires. It was
hand-written and never tested against a trigger eval set.

Worth doing *after* the content settles, not before — optimising the description of a skill
whose behaviour is still changing means re-doing it. Use `skill-creator`'s `scripts.run_loop`
with ~20 queries, weighted toward near-misses: Danish rental enquiries, Swedish or Norwegian
property, generic mortgage maths with no property attached, and "should I buy this?" questions
about non-Danish homes. Those are the cases where a keyword match would fire wrongly.

---

## Deliberately not doing

Recording these so they do not get re-proposed and re-rejected:

- **Live API integration** (boliga, DST, OIS). Tempting, but the value here is knowing *which*
  source answers which question and how to read the answer. Scraping adds a maintenance burden
  and a breakage surface in exchange for saving a web search.
- **Automating the fieldwork list.** The point of `references/fieldwork.md` is that a human
  goes and stands on the street at 22:00. Generating a checklist automatically is fine;
  pretending the checklist substitutes for the visit is the failure mode to avoid.
- **A single headline score.** Repeatedly tempting, consistently wrong. Specification and
  condition answer different questions and collapsing them is how a report recommends a house
  with a failing roof. See `references/scoring.md`.
