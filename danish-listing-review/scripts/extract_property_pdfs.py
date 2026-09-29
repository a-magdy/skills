#!/usr/bin/env python3
"""Extract structured data from Danish property PDFs.

The important job here is decoding defect severity in the Tilstandsrapport. Severity is
rendered as a coloured icon rather than text, so plain extraction loses it entirely and a
critical roof failure reads exactly like a cosmetic crack. This script samples the icon
colours in page draw order and zips them against the numbered defect rows.

Usage:
    python extract_property_pdfs.py <pdf-or-directory> [--outdir DIR] [--quiet]

Outputs into --outdir (default ./extracted):
    <name>.txt          page-delimited text
    defects.json        decoded defects with severity, for the Tilstandsrapport
    energy-label.png    rendered crop of the energy label, for the Energimærke
    summary.json        detected document types and headline fields
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import sys
import warnings
from collections import Counter
from pathlib import Path

# pypdf logs colour-space complaints on these templates and Pillow warns about getdata;
# neither affects the result and both drown the actual findings.
warnings.filterwarnings("ignore", category=DeprecationWarning)
logging.getLogger("pypdf").setLevel(logging.ERROR)

MISSING = []
try:
    import pypdf
except ImportError:
    MISSING.append("pypdf")
try:
    import pypdfium2 as pdfium
except ImportError:
    MISSING.append("pypdfium2")
try:
    from PIL import Image  # noqa: F401
except ImportError:
    MISSING.append("pillow")

if MISSING:
    sys.stderr.write(
        "Missing dependencies: {}\n\n"
        "Install into a throwaway venv so nothing global is touched:\n"
        "    python3 -m venv /tmp/propvenv && /tmp/propvenv/bin/pip install {}\n"
        "    /tmp/propvenv/bin/python {} <args>\n".format(
            ", ".join(MISSING), " ".join(MISSING), Path(__file__).name
        )
    )
    sys.exit(3)


# Severity anchors sampled from real TÜV SÜD / Domutech reports. Vendors vary the shade
# slightly and JPEG compression shifts values a few points, so match by nearest distance
# rather than equality.
SEVERITY_ANCHORS = {
    (212, 48, 57): ("critical", "Kritiske skader"),
    (247, 183, 0): ("serious", "Alvorlige skader"),
    (128, 128, 125): ("minor", "Mindre alvorlige skader"),
    (0, 150, 200): ("possible", "Mulige skader"),
}
COLOUR_MATCH_TOLERANCE = 90

DOC_SIGNATURES = [
    ("tilstandsrapport", ("TILSTANDSRAPPORT", "SKADESOVERSIGT", "huseftersyn")),
    ("energimaerke", ("ENERGIMÆRKNINGSRAPPORT", "energimærkningsskalaen")),
    ("elinstallationsrapport", ("ELINSTALLATIONSRAPPORT", "elinstallationer")),
    ("salgsopstilling", ("Salgsopstilling", "Kontantpris", "Ejerudgift")),
]


def detect_type(text: str) -> str:
    scores = {}
    for name, markers in DOC_SIGNATURES:
        scores[name] = sum(1 for m in markers if m.lower() in text.lower())
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "unknown"


def page_texts(path: Path) -> list[str]:
    reader = pypdf.PdfReader(str(path))
    return [(p.extract_text() or "") for p in reader.pages]


def _dominant_colour(pil_img):
    """Dominant colour ignoring black outline and white background."""
    img = pil_img.convert("RGB")
    if img.width * img.height > 40000:
        img = img.resize((64, 64))
    counts = Counter(img.getdata())
    for (r, g, b), _ in counts.most_common(12):
        if r + g + b < 90:          # near-black outline
            continue
        if r > 235 and g > 235 and b > 235:  # near-white background
            continue
        return (r, g, b)
    return None


def _classify(rgb):
    if rgb is None:
        return None, None, None
    best, best_dist = None, 1e9
    for anchor, label in SEVERITY_ANCHORS.items():
        dist = sum((a - b) ** 2 for a, b in zip(anchor, rgb)) ** 0.5
        if dist < best_dist:
            best, best_dist = label, dist
    if best_dist > COLOUR_MATCH_TOLERANCE:
        return None, None, rgb
    return best[0], best[1], rgb


def severities_on_page(page) -> list[dict]:
    """Severity icons in content-stream draw order."""
    try:
        raw = page.get_contents().get_data().decode("latin-1", errors="ignore")
    except Exception:
        return []
    draw_order = re.findall(r"/(I\d+)\s+Do", raw)
    if not draw_order:
        return []

    by_name = {}
    try:
        for im in page.images:
            key = im.name.split(".")[0]
            by_name.setdefault(key, im)
    except Exception:
        return []

    out = []
    for token in draw_order:
        entry = by_name.get(token)
        if entry is None:
            continue
        try:
            rgb = _dominant_colour(entry.image)
        except Exception:
            continue
        sev, label, raw_rgb = _classify(rgb)
        if sev:
            out.append({"severity": sev, "severity_da": label, "rgb": list(raw_rgb)})
    return out


DEFECT_ROW = re.compile(r"^\s*(\d{1,2})\s*$")
SECTION_HEAD = re.compile(
    r"^(BEBOELSE|UDHUS|GARAGE|CARPORT|SKADER)\b.*$", re.IGNORECASE
)


def parse_defect_rows(text: str) -> list[dict]:
    """Numbered defect rows with their section heading and following prose."""
    lines = text.split("\n")
    rows, section = [], None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if SECTION_HEAD.match(stripped) and "Nr." not in stripped:
            section = stripped
            continue
        m = DEFECT_ROW.match(line)
        if not m:
            continue
        body = []
        for nxt in lines[i + 1 : i + 12]:
            s = nxt.strip()
            if DEFECT_ROW.match(nxt) or SECTION_HEAD.match(s) or s.startswith("Nr."):
                break
            if re.match(r"^\d+/\d+", s) or s.startswith("Version:"):
                break
            if s:
                body.append(s)
        if body:
            rows.append(
                {
                    "number": int(m.group(1)),
                    "section": section,
                    "text": " ".join(body).strip(),
                }
            )
    return rows


def extract_tilstandsrapport(path: Path, outdir: Path, quiet: bool) -> dict:
    reader = pypdf.PdfReader(str(path))
    defects, warnings = [], []

    for idx, page in enumerate(reader.pages):
        text = page.extract_text() or ""
        if "Nr." not in text or "Vurdering" not in text:
            continue
        rows = parse_defect_rows(text)
        if not rows:
            continue
        sevs = severities_on_page(page)
        if len(sevs) != len(rows):
            warnings.append(
                f"page {idx + 1}: {len(rows)} defect rows but {len(sevs)} severity "
                f"icons — alignment uncertain, verify by rendering this page"
            )
        for j, row in enumerate(rows):
            sev = sevs[j] if j < len(sevs) else {}
            defects.append(
                {
                    "number": row["number"],
                    "page": idx + 1,
                    "section": row["section"],
                    "severity": sev.get("severity", "unknown"),
                    "severity_da": sev.get("severity_da", "ukendt"),
                    "text": row["text"],
                }
            )

    payload = {
        "source": path.name,
        "defect_count": len(defects),
        "by_severity": dict(Counter(d["severity"] for d in defects)),
        "warnings": warnings,
        "defects": defects,
    }
    (outdir / "defects.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    if not quiet:
        counts = payload["by_severity"]
        print(f"  defects: {len(defects)}  " + "  ".join(
            f"{k}={v}" for k, v in sorted(counts.items())
        ))
        for d in defects:
            if d["severity"] in ("critical", "serious"):
                print(f"    [{d['severity'].upper():8}] #{d['number']} "
                      f"{d['text'][:88]}")
        for w in warnings:
            print(f"  WARNING: {w}")
    return payload


def extract_energy_label(path: Path, outdir: Path, quiet: bool) -> dict:
    """Render the label region — the letter is a graphic, not text."""
    out = {"source": path.name, "label_image": None, "note": None}
    try:
        pdf = pdfium.PdfDocument(str(path))
        page = pdf[0]
        img = page.render(scale=2).to_pil()
        w, h = img.size
        crop = img.crop((int(w * 0.45), 0, w, int(h * 0.30)))
        dest = outdir / "energy-label.png"
        crop.save(dest)
        out["label_image"] = str(dest)
        out["note"] = "Read the letter from this image; text extraction is unreliable here."
        if not quiet:
            print(f"  energy label rendered -> {dest} (view it to read the letter)")
    except Exception as exc:  # pragma: no cover
        out["note"] = f"render failed: {exc}"
        if not quiet:
            print(f"  WARNING: could not render energy label ({exc})")
    return out


HEADLINE_PATTERNS = {
    "kontantpris": r"Kontantpris:?\s*(?:kr\.?)?\s*([\d.]+)",
    "ejerudgift_md": r"Ejerudgift/md\.?:?\s*(?:kr\.?)?\s*([\d.]+)",
    "boligareal_m2": r"Boligareal(?:\s+i\s+alt)?:?\s*([\d.]+)\s*m",
    "grundareal_m2": r"Grundareal:?\s*([\d.]+)\s*m",
    "byggeaar": r"Opført/ombygget år:?\s*(\d{4})",
    "ejendomsvaerdi": r"Ejendomsværdi:?\s*([\d.]+)",
    "grundvaerdi": r"Grundværdi:?\s*([\d.]+)",
    "grundlag_ejdvaerdiskat": r"Grundlag for ejd\.? værdiskat:?\s*([\d.]+)",
    "grundlag_grundskyld": r"Grundlag for grundskyld:?\s*([\d.]+)",
    "energimaerke": r"Energimærke:?\s*([A-G]\d{0,4})",
}

CAVEAT_SECTIONS = [
    "Andre forhold af væsentlig betydning",
    "Gæld udenfor købesummen",
    "Servitutter",
    "Grundejerforening",
]


def normalise(text: str) -> str:
    """Flatten the PDF's line wrapping so phrase matching works.

    Danish salgsopstillinger wrap mid-phrase and hyphenate across lines, so a literal
    search for "rødt hus" or "risiko for brand" silently misses. Both appeared in real
    reports as 'rødt \\nhus' and 'forure-\\nret'.
    """
    joined = re.sub(r"(\w)-\s*\n\s*(\w)", r"\1\2", text)   # de-hyphenate
    return re.sub(r"\s+", " ", joined).lower()


def extract_salgsopstilling(text: str, outdir: Path, quiet: bool) -> dict:
    fields = {}
    for key, pat in HEADLINE_PATTERNS.items():
        m = re.search(pat, text)
        fields[key] = m.group(1) if m else None

    flags = []
    lowered = normalise(text)
    if "rødt hus" in lowered:
        flags.append("Condition report graded 'rødt hus' (critical findings present)")
    if "gult hus" in lowered:
        flags.append("Condition report graded 'gult hus' (serious findings present)")
    if "risiko for brand" in lowered:
        flags.append("Electrical report: risiko for brand (fire risk)")
    if "risiko for stød" in lowered:
        flags.append("Electrical report: risiko for stød (shock risk)")
    if "undersøges nærmere" in lowered:
        flags.append("Electrical report: 'undersøges nærmere' items present")
    if "kan ikke opnås" in lowered:
        flags.append("Standard financing stated as NOT obtainable — monthly figures optimistic")
    if "foreløbig" in lowered and "beskatning" in lowered:
        flags.append("Property tax basis is provisional (foreløbig) — will be back-adjusted")
    if "afventer" in lowered:
        flags.append("Something listed as 'afventer' (pending) — check association debt")
    if "uoverensstemmelser" in lowered and "bbr" in lowered:
        flags.append("BBR discrepancy disclosed — buyer inherits the condition")
    if "lettere forurenet" in lowered:
        flags.append("Områdeklassificeret / lettere forurenet (routine for byzone)")

    present = [s for s in CAVEAT_SECTIONS if normalise(s) in lowered]

    payload = {
        "fields": fields,
        "auto_flags": flags,
        "caveat_sections_present": present,
        "reminder": "Read the caveat sections in full — headline figures never contain the problems.",
    }
    (outdir / "salgsopstilling.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if not quiet:
        for k, v in fields.items():
            if v:
                print(f"    {k}: {v}")
        for f in flags:
            print(f"    FLAG: {f}")
    return payload


def process(path: Path, outdir: Path, quiet: bool) -> dict:
    texts = page_texts(path)
    joined = "\n".join(texts)
    kind = detect_type(joined)
    if not quiet:
        print(f"\n{path.name}  [{kind}, {len(texts)} pages]")

    stem = re.sub(r"[^\w.-]+", "_", path.stem)[:60]
    (outdir / f"{stem}.txt").write_text(
        "\n".join(f"--- page {i+1}\n{t}" for i, t in enumerate(texts)),
        encoding="utf-8",
    )

    result = {"file": path.name, "type": kind, "pages": len(texts)}
    if kind == "tilstandsrapport":
        result["defects"] = extract_tilstandsrapport(path, outdir, quiet)
    elif kind == "energimaerke":
        result["energy"] = extract_energy_label(path, outdir, quiet)
    elif kind == "salgsopstilling":
        result["salgsopstilling"] = extract_salgsopstilling(joined, outdir, quiet)
    elif not quiet:
        print("  no specialised handler; text extracted only")
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("target", help="PDF file or directory of PDFs")
    ap.add_argument("--outdir", default="./extracted")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    target = Path(args.target).expanduser()
    if not target.exists():
        sys.stderr.write(f"not found: {target}\n")
        return 1

    pdfs = sorted(target.glob("*.pdf")) if target.is_dir() else [target]
    if not pdfs:
        sys.stderr.write(f"no PDFs in {target}\n")
        return 1

    outdir = Path(args.outdir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)

    results = [process(p, outdir, args.quiet) for p in pdfs]
    (outdir / "summary.json").write_text(
        json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    if not args.quiet:
        print(f"\nwrote {outdir}/")
        missing = {"tilstandsrapport", "salgsopstilling", "energimaerke",
                   "elinstallationsrapport"} - {r["type"] for r in results}
        if missing:
            print("missing document types: " + ", ".join(sorted(missing)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
