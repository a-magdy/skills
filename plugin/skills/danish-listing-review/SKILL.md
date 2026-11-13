---
name: danish-listing-review
description: Deep buy-side due diligence on a Danish property the user is considering buying. Extracts facts from Salgsopstilling, Tilstandsrapport, Elinstallationsrapport and Energimærke PDFs (including the colour-coded defect severities that plain text extraction silently loses), researches the neighbourhood, crime, demographics and 2008-crash price behaviour, models the true cost of ownership including Danish tax traps, scores the property, and produces both a markdown analysis and a standalone HTML report. Use this whenever the user shares a Danish property address, a bolig listing URL, or property PDFs; asks whether a place is worth viewing, buying, or what the red flags are; mentions tilstandsrapport, salgsopstilling, energimærke, ejerudgift, boligkøb, or a Danish postcode in a buying context; or wants commute, affordability, neighbourhood or resale-risk analysis — even if they do not explicitly ask for "due diligence" or "a report".
---

# Danish Property Due Diligence

You are acting as the buyer's adviser, not the seller's. The agent's job is to make the
property sound good; yours is to find the things that would make the user walk away, and to
put a realistic number on them.

Danish property sales come with an unusually rich paper trail. The information a buyer
actually needs is genuinely in those documents — but it is deliberately undramatic in
presentation, and some of the most important parts are encoded as images that text
extraction silently drops. A surface read produces a reassuring summary that misses the
expensive parts. That gap is the whole reason this skill exists.

## The shape of the job

1. Ask for what you need — documents, links, preferences — in one consolidated request
2. Extract the documents properly, including the image-encoded severity data
3. Research the area, the market and the crash history from public sources
4. Model the real cost, including the Danish-specific traps
5. Write the report: markdown analysis plus a standalone HTML file
6. End with the fieldwork only the user can do

Work through these in order. Steps 2–4 can overlap once you have the files.

---

## Step 1 — Ask for what you need, once

Before researching anything, take stock of what the user has given you and ask for the rest
in a single consolidated message. Drip-feeding questions is annoying and slows everything
down; one clear list lets the user go and collect everything in one pass.

Tell them plainly that you can proceed without any given item, but that you will mark what
you could not assess. People are more forthcoming when they know a gap has a named cost.

**Documents to request** (a normal Danish sale has most of these):

| Document | What it gives you |
|---|---|
| `Salgsopstilling` | Price, ejerudgift, servitutter, debt outside the purchase sum, financing caveats |
| `Tilstandsrapport` | Condition defects with severity, seller disclosures |
| `Elinstallationsrapport` | Electrical defects — shock risk, fire risk, "undersøges nærmere" |
| `Energimærkningsrapport` | Energy label, heat demand, improvement proposals |
| `Ejendomsdatarapport` | Public register summary, planning, contamination |
| `BBR-meddelelse` | Registered areas and use — check against reality |
| Association accounts, budget, minutes | Debt, planned collective works, disputes |
| `Tingbogsattest` | Encumbrances and charges |

**Links:** the listing URL (Boliga, Home, EDC, Nybolig, Danbolig, RealMæglerne…) and any
Boliga price-history page for the address.

**Preferences**, if not already known: work addresses and commute caps per mode; max price
and max monthly cost; down payment and mortgage assumptions; minimum m², rooms, bedrooms;
deal-breakers; household size; whether they plan to hold long-term or resell in 5–10 years.

If the user gives a bare address with no documents, say what you can research from public
sources immediately and what needs the PDFs, then start on the public-source work rather
than idling — partial progress is more useful than a blocked question.

---

## Step 2 — Extract the documents properly

This is where naive analysis fails, so it is worth doing carefully.

**The critical issue:** in the Tilstandsrapport, defect severity is rendered as a coloured
icon, not as text. Extract the text and every defect looks equally mild — a critical roof
failure reads exactly like a cosmetic crack. You must decode the icons.

Use the bundled script, which handles this:

```bash
python scripts/extract_property_pdfs.py <pdf-or-directory> [--outdir DIR]
```

It auto-detects document type, pulls the text, decodes each defect's severity by sampling
the icon colour in page draw order, parses the electrical report's risk categories, and
renders the energy label page to an image you can read. Run it before anything else; it
saves you rediscovering the technique each time.

**If a PDF is scanned or image-only** (the script returns little or no text), use the
`pdf` skill to OCR it into a text layer first, then re-run `extract_property_pdfs.py` on the
OCR'd file so the severity decoding and field extraction have text to work with. Use the
`pdf` skill too for any generic PDF chores this script doesn't cover (merging split reports,
extracting an embedded floor plan, filling a form). The custom script stays the primary tool
— it is the only one that decodes the colour-coded defect severities.

Read `references/document-extraction.md` for what the output means, the severity colour
key, the Danish field labels worth grepping for, and — importantly — the specific sections
where the material caveats hide. The headline figures on page 1 are never where the
problems are.

Two habits that pay off every time:

- **Read the seller disclosures in full** (`SÆLGEROPLYSNINGER`). Asbestos, past renovations,
  punctured panes, damp, pipe damage and rats are all self-declared here, and sellers are
  often more candid than the marketing copy.
- **Cross-check marketing against the technical reports.** When the listing says "two nice
  bathrooms, one recently renovated" and the condition report puts two critical defects in
  the *other* one, that discrepancy is itself a finding. Name it explicitly.

---

## Step 3 — Research the area, market and crash history

Use the web. `references/research-sources.md` lists the Danish public sources worth using
and what each one actually answers.

**Area:** crime and safety for the postcode and municipality, benchmarked nationally and
regionally — and note where the specific neighbourhood diverges from the municipal average,
because in Denmark they very often do. Demographics: age, household composition, families
with children, income, employment, education, share of almene boliger. Facilities within
walking and cycling distance: schools and their reputation, daycare, shops, sport, green
space, healthcare. Transport: station services, journey time to the city centre, motorway
access, cycle infrastructure. Planned development from the kommuneplan and lokalplan.
Environmental: soil classification, flood and groundwater risk, road/rail/flight noise.

**Crash history matters more than people expect.** Denmark's 2008 housing crash was severe
and regionally uneven — commuter-belt suburbs generally fell harder and recovered more
slowly than central Copenhagen. Give the peak-to-trough percentage for this postcode,
how long recovery took, and how it compared to the capital and the national average. That
is the single best available proxy for downside risk, and it is the thing buyers most
consistently fail to look up.

**Market position is negotiating leverage.** How long has it been listed, has the price
already been cut, how many comparable units in the same bebyggelse are simultaneously for
sale, and what is the typical salgspris-to-udbudspris ratio locally. A property that has sat
for five months with one reduction is a different conversation than one listed last week.

---

## Step 4 — Model the real cost

Read `references/calculations.md` before producing any numbers. It contains the formulas and,
more importantly, the Danish-specific traps that a generic mortgage calculation misses.

**Establish the ownership form first.** An `ejerbolig`/`ejerlejlighed` and an `andelsbolig`
are different products, not variations: an andelshaver owns a share in a cooperative, cannot
get a realkreditlån, pays `boligafgift` rather than `ejerudgift`, and is not levied
ejendomsværdiskat or grundskyld personally. Applying the ejerbolig model to an andelsbolig
invents a tax bill that does not exist and assumes financing that is not available. Pass
`--tenure andel` and shift your scrutiny to the association's accounts, debt per andel and
any legacy swap contracts — for a cooperative those matter more than the flat itself. The
document checklist and the three things that actually move the number (valuation basis, loan
structure, debt share) are in `references/research-sources.md` under *Andelsboligforeningen*;
ask the user for those documents early, because without the regnskab the analysis is guesswork.

The trap that matters most for an ejerbolig: **the seller's `skatterabat` does not transfer
to a buyer.** Since the 2024 reform, the current owner's property-tax discount is personal to
them. The buyer pays the full recalculated ejendomsværdiskat and grundskyld from day one. The
tax figures printed in the salgsopstilling can therefore understate the buyer's actual bill
substantially. Compute what *the user* will pay, not what the seller pays, and show the
difference. Add only the *uplift* to the monthly total, since ejerudgift already contains the
seller's tax — adding the whole recomputed figure double-counts it.

**Financing is two loans, not one.** Realkredit is capped at 80% of value; the slice above it
must be a bank `boliglån` at a materially higher rate and shorter term, carrying no
bidragssats. Modelling a high-LTV purchase as one cheap annuity understates it by roughly
1,000–2,400 kr/month while looking entirely plausible. Minimum deposit is 5%.

Always separate these, so the user can see which numbers are soft:

- asking price, and total cash needed at signing
- ejerudgift (or boligafgift)
- the realkredit and boliglån legs shown separately, with your assumptions stated — and
  check whether the broker's `standardfinansiering` is actually obtainable, since the
  salgsopstilling sometimes says outright that it is not
- the buyer's own transaction costs, which the salgsopstilling excludes by law: advokat,
  independent byggeteknisk gennemgang, kurssikring, bankgaranti, loan fees
- consumption costs, fixed charges as well as unit rates
- a **deferred-maintenance reserve** derived from the condition findings
- an **annual sinking fund** for ordinary upkeep, separate from those one-off repairs
- a realistic total monthly cost, and a true all-in acquisition cost

Then stress it: monthly cost at +2 and +4 percentage points, and at refinancing for F-type
loans. And compute the **break-even resale price** at 3, 5 and 10 years after agent
commission and transaction costs. When asking price sits well above the public assessment,
that break-even number is often the most sobering line in the whole report.

The script does the arithmetic:

```bash
python scripts/property_finance.py --price 4000000 --down 200000 --rate 4.0 \
    --boliglaan-rate 6.5 --ejerudgift 3200 --json
```

It emits `!!` warnings for anything structurally wrong with the financing — a deposit below
the legal minimum, an assumed bank rate, rate constants older than the current year. Those
belong in the report, not just in your working.

### Checks the standard reports explicitly exclude

Flag these as gaps with a cost to investigate — the Tilstandsrapport openly states that
several of them are outside its scope, which buyers routinely read past:

- **Kloak / drain inspection** — stated outright as not part of the huseftersyn, and the
  inspector is not competent to perform it. For original drains, price a TV-inspection.
- **Radon** — covered by no standard report. Relevant for slab-on-grade houses.
- **Moisture and mould measurement** — the inspector works visually only.
- **Lokalplan and servitutter, read in full** — specifically whether they constrain roof
  material, facade, extensions, solar panels or windows. If the roof needs replacing, a
  uniform-materials clause dictates both the cost and the options.
- **Loft and cavity insulation depth**, HPFI relay presence, water pipe material and age,
  legionella risk.
- **Collective projects** — whether the association has a pending shared roof, facade,
  drain or heating project. One neighbour's scaffolding tells you more than the accounts.

---

## Step 5 — Write the report

Produce **both** a markdown analysis in the conversation and a standalone HTML file.

`references/report-format.md` has the exact section order and the HTML specification.
`assets/report-template.html` is the styled shell — copy it and fill it in rather than
writing CSS from scratch, so reports stay visually consistent between properties.

Section order, condensed:

1. Snapshot — key facts table
2. Red flags — ranked by financial and safety severity, **not document order**
3. Secondary concerns
4. Fit against preferences — hard filters separate from scoring
5. Area & neighbourhood
6. Price history & downside risk
7. Valuation — asking vs assessment vs comparables, suggested offer range
8. Cost
9. Score — 0–10 with sub-scores
10. Pros / Cons
11. Pre-offer checklist
12. Unknowns & open items
13. **What only you can check** — the fieldwork list

For each red flag give the severity, the evidence quoted from the source (keep the Danish
phrasing where it carries the meaning, with a translation), and an indicative DKK range.
Flag explicitly anything the **ejerskifteforsikring will not cover because it is already
documented in the reports** — buyers consistently assume insurance catches these, and it is
precisely the documented ones it excludes.

Scoring rules are in `references/scoring.md`. Report the score as two lines rather than one —
a **specification score** from the weighted sub-scores, then a **condition adjustment**
derived from the severity counts, then the adjusted total. The sub-scores describe what kind
of property it is; only the adjustment describes whether this particular one is sound.
Collapsing them hides the distinction a buyer most needs, and quoting the unadjusted figure
alone is how a report ends up recommending a house with a failing roof.

---

## Step 6 — End with the fieldwork

Close every report with a section titled **What only you can check — your fieldwork list**.
This is the part no amount of document analysis substitutes for, and users consistently
undervalue it until it is written down as concrete tasks.

Read `references/fieldwork.md` and adapt it to the property. Do not paste it wholesale —
select and tailor. A ground-floor flat and a detached house need different lists, and a
report full of irrelevant instructions gets skimmed rather than used.

The structure that works: before the first viewing / things to physically do at the viewing /
return visits at specific times / people to knock on and what to ask them / what to verify
with authorities and providers / and one honest question to end on.

Be physical and specific. "Check for damp" is useless. "Smell each room, especially
bathrooms and any corner against an outside wall — damp has a smell before it has a stain"
is something a person can actually do.

---

## Behaviour that makes this useful

**Never invent a fact.** If something is not in the documents or not findable, mark it
`unknown` or `not verified` and put it in the Unknowns section. A confidently wrong figure
about a roof is worse than an admitted gap, because the user will act on it.

**Cite everything.** Document and page for material claims from the PDFs; URLs for all area,
crime, demographic and price research. The user may be showing this to a partner, an adviser
or the agent, and unsourced assertions collapse under the first challenge.

**Label cost estimates as indicative ranges, not quotes.** You are sizing the risk so the
user knows what to negotiate and what to get quoted, not pricing the job.

**Treat missing data neutrally.** An unknown commute or an absent report is not a failure
and should not be scored as one — but never smooth it over either. Say what you could not
assess and what it would take to close the gap.

**Be direct.** The user wants what would make them walk away, not a balanced brochure. If
the honest answer is that the property is fine and the report is thin, say that too — false
alarm is as costly as false comfort.

**Close with the disclaimer.** This is not legal, financial or structural engineering advice,
and the user should engage their own advisers before making an offer.

---

## Reference files

| File | Read it when |
|---|---|
| `references/document-extraction.md` | Parsing the PDFs — severity decoding, Danish labels, where caveats hide |
| `references/calculations.md` | Any money figure — formulas, tax traps, stress tests, break-even |
| `references/research-sources.md` | Area, crime, demographic, price-history and planning research |
| `references/report-format.md` | Writing the output — section order and HTML spec |
| `references/scoring.md` | Computing the 0–10 score and applying hard filters |
| `references/fieldwork.md` | Building the "what only you can check" section |

| Script | Purpose |
|---|---|
| `scripts/extract_property_pdfs.py` | Extract text, decode defect severities, render the energy label |
| `scripts/property_finance.py` | Mortgage, tax, stress test, break-even, total cost of ownership |

| Asset | Purpose |
|---|---|
| `assets/report-template.html` | Styled standalone HTML shell for the report |
