# Report format

Two deliverables every time: a markdown analysis in the conversation, and a standalone HTML
file on disk. The markdown is for reading now; the HTML is for sharing with a partner,
printing to PDF, or taking to a viewing.

## Section order

Use this order. It moves from "what is it" to "what's wrong" to "what does it cost" to "what
do I do" — which is the order a buyer actually thinks in.

1. **Snapshot** — key facts table: price, kr/m², public assessment, area, rooms, plot, build
   year, ejerudgift, energy label, heating, condition-report status
2. **Red flags** — ranked by financial and safety severity, *not* document order
3. **Secondary concerns**
4. **Fit against preferences** — hard filters (pass/fail) kept separate from scoring; commute
   per mode per destination
5. **Area & neighbourhood** — crime, demographics, facilities, transport, planned development,
   environment. Sourced.
6. **Price history & downside risk** — including 2008 peak-to-trough and recovery time
7. **Valuation** — asking vs assessment vs comparables; suggested offer range
8. **Cost** — itemised table
9. **Score** — total, sub-scores, and the condition caveat
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
