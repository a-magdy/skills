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

Items 5–18 come from a 2026-09-29 review of the skill against the maintainer's review
workflow: decode severity icons from the rendered pages; read the energy label from the image,
not the extracted text; check the salgsopstilling's claims against the technical reports; use
actual heating consumption rather than the calculated figure; flag anything the
ejerskifteforsikring won't cover. Items 5–9 are that workflow; 10–18 are other gaps.

## 5. Severity icons: make the rendered page authoritative

**Status:** open · **Impact:** high · **Effort:** a session

The workflow reads severity from the rendered `SKADESOVERSIGT` pages. Today
`severities_on_page()` reads embedded image XObjects in content-stream order and only falls
back to rendering when the counts disagree.

- The draw-operator regex `/(I\d+)\s+Do` matches one generator's naming. Other vendors use
  `/Im0`, `/X5`, or draw icons inside Form XObjects or as vector paths, and all of these
  come back as zero icons.
- On a count mismatch the script warns but still zips severities onto rows by position, so
  a defect can silently get the wrong severity. It should mark the page's rows `unknown`.
- `COLOUR_MATCH_TOLERANCE = 90` is wide enough that most mid-tones classify as grey, and the
  `Mulige skader` anchor `(0, 150, 200)` is a guess (the reference itself says "varies").

To do: always render the defect-summary pages to PNG in `--outdir`; read the icons from those
images as the source of truth; keep the draw-order decode as a cross-check only; tighten the
tolerance and sample a real "mulige skader" icon.

## 6. Energy label: locate the label instead of a fixed crop

**Status:** open · **Impact:** medium · **Effort:** ~1 hour

- `extract_energy_label()` crops the right 55% × top 30% of page 1. Another template, or a
  merged bundle where the energy report is not page 1, crops the wrong region.
- `HEADLINE_PATTERNS["energimaerke"]` reads the label from the salgsopstilling *text* and
  stores it next to the real fields in `salgsopstilling.json`. Rename it to something like
  `energimaerke_listing_claim` so it reads as the claim to check, not the answer.
- The image-first rule lives only in `references/document-extraction.md`. State it in
  SKILL.md step 2 too.

## 7. Structured cross-check: salgsopstilling claims vs technical reports

**Status:** open · **Impact:** high · **Effort:** ~1 hour

Currently a "habit" in SKILL.md step 2 with no defined output. Make it a step that produces a
table: claim (quoted, page) → what the reports say (document, page) → verdict (consistent /
contradicted / unverifiable). Typical rows: renovation claims vs seller disclosure 3.3 and the
defect list; areas vs BBR; energy label vs the rendered label; included appliances vs
`Tilbehør`; heating vs energy report page 4. Add a report section, a template block and an eval.

## 8. Heating: actual consumption first, calculated demand as fallback

**Status:** open · **Impact:** high · **Effort:** ~1 hour

`references/calculations.md` §5 and `references/document-extraction.md` tell the model to
present the energy report's calculated kWh as the baseline, and nothing asks for real usage.

- SKILL.md step 1 table: add `Forbrugsoplysninger` — the last 2–3 years of heating (and
  electricity/water) consumption from the supplier's annual statements, via the seller or agent.
- calculations.md §5: actual consumption × current tariffs + fixed charges is the primary
  figure, adjusted for household size vs the seller's. Calculated demand is the fallback and a
  cross-check. A large gap between the two is itself a finding (rooms left unheated, a very
  different household, or an optimistic label).
- `property_finance.py`: add `--consumption-source actual|calculated` and print it beside the
  consumption line, flagging `calculated` as soft.
- Eval: a listing with only an energy label → asks for real bills and labels the calculated
  figure as modelled.

## 9. Ejerskifteforsikring: a dedicated coverage section

**Status:** open · **Impact:** high · **Effort:** ~1 hour

Today it is a per-red-flag note ("not covered because already documented"). Add a report
section with one row per material finding: covered by the standard policy / excluded because
documented / only with an add-on cover / outside the reports' scope and so unassessed. Call out
that pipes and drains commonly need an add-on, and that kloak, radon and moisture measurement
are outside the inspection scope. Tell the user to get the offered policy's actual terms rather
than assuming standard cover. Add a template block and an eval.

## 10. Script invocation is cwd-relative

**Status:** open · **Impact:** medium · **Effort:** 15 minutes

SKILL.md runs `python scripts/extract_property_pdfs.py` and `python scripts/property_finance.py`.
The agent's working directory is the user's folder, not the skill's, and stock macOS has no
`python`. Refer to the scripts relative to this skill's directory and use `python3`.

## 11. Merged PDF bundles

**Status:** open · **Impact:** medium · **Effort:** ~1 hour

`detect_type()` classifies a whole file as one type, so a single "salgsmateriale" PDF containing
every report runs only one handler. Detect type per page range and split before dispatch (or
split with the `pdf` skill first).

## 12. Electrical parser: legend text and icon noise

**Status:** open · **Impact:** medium · **Effort:** with #2

Adds to #2. The category counter counts every mention of a heading. If a report prints the
category legend (likely on standard templates), a clean report shows hits in every category.
Count findings under each heading instead, or subtract a legend baseline. The icon scan also
runs `severities_on_page()` over every page with the loose tolerance, so logos and photos can
register as severities — limit it to the findings pages.

## 13. scoring.md contradicts itself on the condition penalties

**Status:** open · **Impact:** low · **Effort:** 5 minutes

"they measure the same thing by different routes, so adding them would double-count" is
followed by "The two measure different things." Pick one framing; the take-the-larger rule
works under either.

## 14. Evals: fixtures, numbering, coverage

**Status:** open · **Impact:** high · **Effort:** feeds #1

- Eval 2 names three PDFs but `files` is empty; eval 9 references `tilstandsrapport.pdf`, which
  is not in `evals/`. Add fictionalised fixtures (no real addresses — this repo is public).
- #1 lists "7 (andelsbolig)" among the first evals to run; andelsbolig is eval 5 (eval 7 is the
  HTML export).
- Add evals for #7, #8 and #9.

## 15. Description: coexistence with the pdf skill, negative cases

**Status:** open · **Impact:** medium · **Effort:** with #4

Adds to #4. The generic `pdf` skill also fires on any PDF, including a Tilstandsrapport — say in
the description that this skill takes priority for Danish property documents. Step 2 also relies
on the `pdf` skill for OCR, but that skill arrives via APM/`install.sh`, not with the plugin; on
a plugin-only install say what to do instead (render the pages and read them visually).

## 16. Rate refresh is overdue

**Status:** due now · **Impact:** medium · **Effort:** 15 minutes — see #3

`RATES_YEAR = 2024`, so the staleness warning fires on every run. Values were not re-verified in
the review. Also date-stamp the hand-written figures in `references/` (grundskyld 5–10‰,
bidragssats bands, rentefradrag, remediation cost ranges) so they are refreshed with the
constants.

## 17. Scoring uses preference keys nothing collects

**Status:** open · **Impact:** low-to-medium · **Effort:** ~30 minutes

`references/scoring.md` and calculations.md §10 use `max_purchase_price`, `max_monthly_expense`,
`allowed_floors`, POI categories, `max_transfers` and `current_home`. Step 1 asks for
preferences in prose and never names these. Either define a preferences block in step 1 that
maps onto them, or rewrite scoring in terms step 1 actually collects.

## 18. Step order: "run it before anything else" vs step 1

**Status:** open · **Impact:** low · **Effort:** 5 minutes

Step 2 says to run the extraction script "before anything else"; step 1 says to ask for
documents first. Say "as soon as you have the files".

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
