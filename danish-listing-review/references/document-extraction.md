# Document extraction

Danish property PDFs are generated from templates by a handful of vendors (TÜV SÜD Domutech,
OBH, Botjek and others for condition reports; the Dansk Ejendomsmæglerforening form for the
salgsopstilling). They are consistent enough to parse reliably, but they have one trap that
ruins naive analysis.

## The severity trap

In the Tilstandsrapport, every defect in the `SKADESOVERSIGT` section gets a severity
rating. That rating is rendered as **a coloured icon, not as text.** Extract the text and
the severity vanishes entirely — a critical roof failure and a cosmetic hairline crack in
a sokkel come out looking identical.

This is not a subtle degradation. It is the difference between "some minor wear, as expected
for the age" and "four critical defects and an end-of-life asbestos roof". Any analysis that
skips the icons will be confidently, dangerously wrong in the reassuring direction.

### The colour key

| Colour | Approx RGB | Danish | Meaning |
|---|---|---|---|
| Red | `(212, 48, 57)` | Kritiske skader | Function fails in the short term (~2 years); may already be damaging other parts |
| Yellow / amber | `(247, 183, 0)` | Alvorlige skader | Function will fail in the longer term; may damage other parts |
| Grey | `(128, 128, 125)` | Mindre alvorlige skader | No influence on function |
| Blue-ish / marked UN | varies | Mulige skader | Needs investigation; could turn out critical or serious |

Match with tolerance rather than exact equality — vendors vary the shade slightly and JPEG
compression shifts values by a few points. A nearest-match against these four anchors within
a distance threshold is robust.

### How to decode them

Icons appear in the page's content stream in the same order as the defect rows. So:

1. Parse the page content stream for image draw operators (`/I42 Do`) in order
2. For each referenced image, take the dominant non-black, non-white colour
3. Zip that ordered list against the numbered defect rows from the extracted text

Black and white dominate most icons (outline and background), so discard them before
picking the dominant colour.

`scripts/extract_property_pdfs.py` implements this. Run it rather than reimplementing —
getting the draw-order/row alignment right took several attempts.

### Sanity check the alignment

Before trusting the mapping, verify the count of decoded icons equals the count of numbered
defect rows on that page. If they differ, the page has decorative images mixed in — fall
back to rendering the page and reading it visually. The script warns when counts mismatch.

The salgsopstilling also states the report's overall grade in words, e.g. *"Der foreligger
tilstandsrapport med forhold karakteriseret rødt hus og gult hus"*. Cross-check your decoded
severities against that sentence; if the salgsopstilling says "rødt hus" and you found no red
icons, your extraction is wrong.

## The energy label is also an image

On page 1 of the Energimærkningsrapport, the big letter (A2020…G) is a graphic. Text
extraction often yields a stray unrelated character from the page furniture, which is
worse than yielding nothing because it looks like a real answer.

Render the page and read the letter visually. The script crops and saves the relevant
region. Always cross-check against what the salgsopstilling claims — a mismatch is either
an extraction error or a genuine discrepancy worth raising, and you need to know which.

Page 4 (`BAGGRUNDSINFORMATION`) has the reliable structured data: BBR area, build year,
heated area, roof-storey heated area, heating supply, and the calculated heat demand in kWh.

Note that the label is **calculated**, not measured. A B label on a 1970s house usually
means good insulation and district heating on paper; actual consumption depends on the
household. Say so rather than presenting it as a guaranteed running cost.

## Where the caveats hide

The headline figures are on page 1. The problems are never there. In the salgsopstilling,
read these sections in full:

| Section | What turns up there |
|---|---|
| `Andre forhold af væsentlig betydning` | Contamination, BBR discrepancies, tax-reform exposure, planning |
| `Gæld udenfor købesummen` | Association debt — often listed as `afventer`, i.e. unresolved |
| `Servitutter` | Restrictions on building, use, materials, shared facilities |
| `Tilstandsrapport ... elinstallationsrapport` summary line | The one-line verdict: rødt/gult hus, shock/fire risk |
| Financing footnotes | Whether the quoted standardfinansiering is actually obtainable |
| `Tilbehør` | Which appliances are included, and which are broken |
| `Ejerudgift 1. år` breakdown | Whether tax figures are provisional (`foreløbig`) |
| `Grundejerforening` | Mandatory membership, contribution, security arrangements |

A recurring pattern: the financing footnote sometimes says outright that the standard
financing **cannot** be obtained for this property (typically because the loan is reduced by
security pledged to the association). The monthly figures on the front page then describe a
loan the buyer cannot actually get. Always read to the end of that paragraph.

## Seller disclosures

`SÆLGEROPLYSNINGER` in the Tilstandsrapport is a fixed questionnaire. Sellers are frequently
more candid here than anywhere else in the sale, because the questions are specific and the
answers are on record. The ones that repeatedly matter:

- **3.3** larger renovations — what, when, and whether self-built. Cross-check against the
  marketing copy, which often implies more was renovated than actually was.
- **4.1 / 4.2** roof leaks and past repairs after moisture, rot, fungus or insects
- **10.1** punctured thermal panes, and where
- **13.3 / 13.4** pipe damage, and drain cleaning in the last 5 years
- **14.1** asbestos — which materials and where. A `Ja` here against a 1960s–80s build
  usually means the roof, and that reprices any roof work substantially.
- **14.2** rats

Note that disclosures carry no warranty and the seller may genuinely not know. Treat a `Nej`
as weaker evidence than a `Ja`.

## Danish labels worth grepping

```
Kontantpris  Ejerudgift  Boligareal  Grundareal  Værelser  Etage  Byggeår
Opført/ombygget  Energimærke  Ejendomsværdi  Grundværdi  Ejendomsværdiskat
Grundskyld  Zonestatus  Matr.nr.  BFE-nr.  Varmeinstallation  Fjernvarme
Tilstandsrapport  Elinstallationsrapport  Servitutter  Grundejerforening
altan  elevator  carport  garage  p-plads  udhus  tilbygning  krybekælder
```

## Running the script

```bash
python scripts/extract_property_pdfs.py /path/to/pdfs --outdir ./extracted
```

It accepts a single PDF or a directory, auto-detects document type from the content, and
writes per-document text plus a `defects.json` with each defect's number, section, severity,
description and risk text. Dependencies (`pypdf`, `pypdfium2`, `pillow`) install into a
throwaway venv if they are not already present — it prints the command if it cannot.

If the script fails on an unusual vendor layout, fall back to rendering the
`SKADESOVERSIGT` pages to PNG and reading them directly. That always works; it is just
slower and uses more context.
