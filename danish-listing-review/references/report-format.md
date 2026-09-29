# Report format

Two deliverables every time: a markdown analysis in the conversation, and a standalone HTML
file on disk. The markdown is for reading now; the HTML is for sharing with a partner,
printing to PDF, or taking to a viewing.

## Section order

Use this order. It moves from "what is it" to "what's wrong" to "what does it cost" to "what
do I do" — which is the order a buyer actually thinks in.

1. **Snapshot** — key facts table: price, kr/m², public assessment, area, rooms, plot, build
   year, ejerudgift, energy label, heating, condition-report status. **State the ownership
   form in the first line** — ejer, andel or lejlighed changes what every later number means,
   and a reader who assumes the wrong one misreads the whole report.
2. **Red flags** — ranked by financial and safety severity, *not* document order
3. **Secondary concerns**
4. **Fit against preferences** — hard filters (pass/fail) kept separate from scoring; commute
   per mode per destination
5. **Area & neighbourhood** — crime, demographics, facilities, transport, planned development,
   environment. Sourced.
6. **Price history & downside risk** — including 2008 peak-to-trough and recovery time
7. **Valuation** — asking vs assessment vs comparables; suggested offer range. **For an
   andelsbolig, valuation works the other way round:** the price is capped by *maksimalprisen*
   derived from the andelskrone, so the question is not "is this worth the asking price?" but
   "is the asking price legal, and how was the forening's valuation basis set?" Check which
   basis is used — anskaffelsespris, offentlig vurdering or valuarvurdering — because a
   valuar-based andelskrone can fall at the next revaluation and take the resale value with
   it. Overpricing above maksimalpris is unlawful and recoverable from the seller.
8. **Cost** — itemised table. Show the realkredit and boliglån legs on separate rows, and
   add only the property-tax *uplift* rather than the full recomputed figure, since
   ejerudgift already contains the seller's tax. Mark any assumed bank rate as assumed.
   **For an andelsbolig this section is shaped differently:** the recurring charge is
   *boligafgift*, not ejerudgift; there is no realkredit leg, because the buyer finances with
   a bank andelsboliglån; and ejendomsværdiskat and grundskyld do not appear at all, since
   the forening is the taxpayer and its bill is already inside the boligafgift. Print the tax
   line as "n/a — paid by the forening" rather than omitting it, so the reader can see it was
   considered rather than forgotten. Add a row for the buyer's share of the forening's debt,
   which is a real liability that sits outside the purchase price.
9. **Score** — specification score, sub-scores, condition adjustment, adjusted total
10. **Pros / Cons** — side by side, concrete
11. **Pre-offer checklist** — numbered actions, including which documents are still missing
12. **Unknowns & open items**
13. **What only you can check** — the fieldwork list

Omit a section only if it is genuinely inapplicable, and say why rather than silently dropping
it — a missing section reads as an oversight.

## Red flag entries

Each one needs:

- **Severity badge** — Critical / Serious / Minor, taken from the decoded icon colours
- **The evidence**, quoted from the source. Keep the Danish where the phrasing carries the
  meaning (*"nærliggende risiko for skader på andre bygningsdele"*), with a translation. The
  original wording matters because the user may quote it back to the agent.
- **Why it matters** in plain terms
- **An indicative DKK range** to remedy
- **Insurance status** — flag explicitly when the ejerskifteforsikring will *not* cover it
  because it is already documented in the reports. Buyers routinely assume insurance catches
  these; it is precisely the documented ones it excludes.

Rank by financial and safety consequence. A grey cosmetic crack listed first because it was
defect #3 in the PDF buries the critical roof finding at #1.

## The bottom line

Open the report with a short verdict box — three or four sentences that answer: what is good,
what is wrong, what it really costs, and whether to proceed. Someone reading only that box
should come away with the correct impression. Everything after it is evidence.

## Tone

Buy-side adviser, not brochure. Direct about problems, specific about numbers, honest about
gaps. If the property is genuinely fine and the report is thin, say that — false alarm costs
as much credibility as false comfort.

Avoid hedging that removes information. "There may potentially be some considerations
regarding the roof" tells the user nothing. "The roof is asbestos eternit from 1976 with a
critical defect; budget 250,000–400,000 kr" tells them what to do.

## The HTML file

Copy `assets/report-template.html` and fill it in rather than writing CSS from scratch — it
keeps reports consistent between properties, which matters when the user is comparing several.

Requirements:

- **Single self-contained file.** No external assets, no CDN links, no web fonts. All CSS
  inlined in a `<style>` block. It must work offline, from a USB stick, and as an email
  attachment.
- System font stack; max content width ~900px
- Colour used semantically: red critical, amber serious, grey minor, green positive
- Severity badges on red flags
- Snapshot as a key-facts grid
- Tables with right-aligned tabular numerals (`font-variant-numeric: tabular-nums`)
- Prominent verdict box at the top
- **Must print cleanly to PDF** — no fixed heights, no viewport units, no dark backgrounds
  that waste ink

Save it next to the source documents where possible, or in the working directory, and tell
the user the full path.

### Template placeholders

`assets/report-template.html` marks fill points with `<!-- FILL: name -->` comments. Replace
the whole comment with your content. Delete any block you are not using rather than leaving
an empty shell.

## Verifying before you hand it over

Two checks worth doing, because a broken report is worse than no report:

1. Confirm the HTML tags are balanced — an unclosed `div` silently swallows the rest of the
   document in some browsers.
2. Open or serve it and confirm it renders. If a browser canvas is available, show the user
   directly rather than just naming a file path.
