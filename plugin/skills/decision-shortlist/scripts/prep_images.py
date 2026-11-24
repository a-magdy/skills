#!/usr/bin/env python3
"""Resize product photos for a comparison page and build a contact sheet.

Usage: python3 prep_images.py <src_dir> <dst_dir> [contact_sheet.jpg]

Every .jpg/.jpeg/.png/.webp in src_dir is converted to RGB, shrunk to fit
720x720, and written to dst_dir as a progressive JPEG (quality 78) with the
same base name. The contact sheet (default: <dst_dir>/../contact-sheet.jpg)
puts every result in one labelled grid. Open it to check each photo shows the
right product and colour before using it on the page.
"""
import os
import sys

from PIL import Image, ImageDraw

EXTS = (".jpg", ".jpeg", ".png", ".webp")
MAX_SIDE = 720
QUALITY = 78


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    sheet = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(dst)), "contact-sheet.jpg")
    os.makedirs(dst, exist_ok=True)

    files = sorted(f for f in os.listdir(src) if f.lower().endswith(EXTS))
    if not files:
        print(f"no images in {src}")
        return 1

    thumbs = []
    for f in files:
        im = Image.open(os.path.join(src, f)).convert("RGB")
        im.thumbnail((MAX_SIDE, MAX_SIDE))
        out = os.path.splitext(f)[0] + ".jpg"
        im.save(os.path.join(dst, out), "JPEG", quality=QUALITY, optimize=True, progressive=True)
        t = im.copy()
        t.thumbnail((220, 220))
        thumbs.append((out, t))
        print(f"{out}\t{os.path.getsize(os.path.join(dst, out))} bytes")

    cols = 6
    rows = (len(thumbs) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * 230, rows * 250), "white")
    draw = ImageDraw.Draw(canvas)
    for i, (name, t) in enumerate(thumbs):
        x, y = (i % cols) * 230 + 5, (i // cols) * 250 + 5
        canvas.paste(t, (x, y))
        draw.text((x, y + 225), name, fill="black")
    canvas.save(sheet)
    print(f"contact sheet: {sheet}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
