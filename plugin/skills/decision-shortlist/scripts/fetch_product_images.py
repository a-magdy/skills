#!/usr/bin/env python3
"""Fetch product photos from product pages. Stdlib only; resizes with macOS `sips` or Pillow.

  python3 fetch_product_images.py products.json
  python3 fetch_product_images.py --url wp660=https://shop/p/1 --url wp660=https://shop/p/2 --url sonic=https://...

products.json:
  {"out": "photos", "max": 4, "size": 720,
   "products": {"<id>": {"pages": ["https://..."], "direct": ["https://.../img.jpg"], "keywords": ["model-no"]}}}

Per page it collects, in order: Shopify /products/<handle>.js images, JSON-LD Product images,
og:image / twitter:image, then <img> tags mentioning a keyword (skipped if no keywords).
Writes <out>/<id>-<n>.jpg, <out>/manifest.json, <out>/contact.html (open it to check) and <out>.zip.
"""
import argparse, hashlib, html, json, re, shutil, subprocess, sys, time
import urllib.parse, urllib.request
from pathlib import Path

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36"
IMG = re.compile(r"\.(jpe?g|png|webp|avif)(\?|$)", re.I)
SKIP = re.compile(r"(logo|icon|sprite|favicon|placeholder|badge|rating|flag|avatar|payment|share|social|/product/grid/|/\d{2}x\d{2}/)", re.I)


def get(url, binary=False, referer=None):
    h = {"User-Agent": UA, "Accept-Language": "en;q=0.9,da;q=0.8",
         "Accept": "image/avif,image/webp,image/*,*/*;q=0.8" if binary else "text/html,application/json,*/*"}
    if referer:
        h["Referer"] = referer
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=20) as r:
        b = r.read()
        return b if binary else b.decode(r.headers.get_content_charset() or "utf-8", "replace")


def upsize(u, size):
    """Ask common image CDNs for a larger rendition."""
    u = re.sub(r"/product/\d+x\d+/", f"/product/{size}x{size}/", u)          # Klarna / PriceRunner
    u = re.sub(r"rs:fit:\d+:\d+", f"rs:fit:{size}:{size}", u)                  # imgproxy
    u = re.sub(r"_(\d{2,4})x(\d{2,4})?(\.\w+)(\?|$)", r"\3\4", u)              # Shopify _400x.jpg
    u = re.sub(r"([?&](?:w|wid|width))=\d+", rf"\1={size}", u)
    return u


def shopify(url):
    p = urllib.parse.urlparse(url)
    if "/products/" not in p.path:
        return []
    try:
        data = json.loads(get(f"{p.scheme}://{p.netloc}{p.path.rstrip('/')}.js"))
        return ["https:" + i if i.startswith("//") else i for i in data.get("images", [])]
    except Exception:
        return []


def jsonld(page):
    out = []
    for block in re.findall(r'<script[^>]+ld\+json[^>]*>(.*?)</script>', page, re.S | re.I):
        try:
            stack = [json.loads(html.unescape(block.strip()))]
        except ValueError:
            continue
        while stack:
            n = stack.pop()
            if isinstance(n, list):
                stack += n
            elif isinstance(n, dict):
                img = n.get("image")
                for i in (img if isinstance(img, list) else [img]):
                    if isinstance(i, str):
                        out.append(i)
                    elif isinstance(i, dict) and i.get("url"):
                        out.append(i["url"])
                stack += [v for v in n.values() if isinstance(v, (dict, list))]
    return out


def meta(page):
    tags = re.findall(r'<meta[^>]+(?:property|name)=["\'](?:og:image(?::secure_url)?|twitter:image)["\'][^>]*>', page, re.I)
    return [m.group(1) for t in tags if (m := re.search(r'content=["\']([^"\']+)', t))]


def img_tags(page, keywords):
    out = []
    for t in re.findall(r"<img\b[^>]*>", page, re.I):
        if not keywords or not any(k.lower() in t.lower() for k in keywords):
            continue
        if (s := re.search(r'srcset=["\']([^"\']+)', t)):
            out.append(s.group(1).split(",")[-1].strip().split(" ")[0])
        if (s := re.search(r'\s(?:data-src|src)=["\']([^"\']+)', t)):
            out.append(s.group(1))
    return out


def candidates(url, keywords, size):
    found = shopify(url)
    try:
        page = get(url)
        found += jsonld(page) + meta(page) + img_tags(page, keywords)
    except Exception as e:
        print(f"  page failed ({e}): {url[:90]}")
    seen, out = set(), []
    for u in found:
        u = urllib.parse.urljoin(url, html.unescape(u.strip()))
        if not u.startswith("http") or SKIP.search(u) or not (IMG.search(u) or "image" in u or "klarna" in u):
            continue
        u = upsize(u, size)
        key = re.sub(r"[?#].*$", "", u)
        if key not in seen:
            seen.add(key)
            out.append(u)
    return out


def resize(src, dst, size):
    if shutil.which("sips") and subprocess.run(
            ["sips", "-s", "format", "jpeg", "-s", "formatOptions", "78", "-Z", str(size), str(src), "--out", str(dst)],
            capture_output=True).returncode == 0:
        return True
    try:
        from PIL import Image
        im = Image.open(src).convert("RGB")
        im.thumbnail((size, size))
        im.save(dst, "JPEG", quality=78, optimize=True)
        return True
    except Exception as e:
        print(f"    resize failed ({e}); install Pillow or run on macOS")
        return False


def dims(path):
    """(width, height) of a saved JPEG, via sips or Pillow; (0, 0) if unknown."""
    if shutil.which("sips"):
        r = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)], capture_output=True, text=True)
        nums = re.findall(r"pixel(?:Width|Height):\s*(\d+)", r.stdout)
        if len(nums) == 2:
            return int(nums[0]), int(nums[1])
    try:
        from PIL import Image
        return Image.open(path).size
    except Exception:
        return 0, 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("config", nargs="?", help="products.json")
    ap.add_argument("--url", action="append", default=[], metavar="ID=URL", help="add a page for a product (repeatable)")
    ap.add_argument("--out"); ap.add_argument("--max", type=int); ap.add_argument("--size", type=int)
    a = ap.parse_args()

    cfg = json.loads(Path(a.config).read_text()) if a.config else {}
    products = cfg.get("products", {})
    for pair in a.url:
        pid, _, url = pair.partition("=")
        products.setdefault(pid, {}).setdefault("pages", []).append(url)
    if not products:
        ap.error("give a products.json or at least one --url id=URL")
    out = Path(a.out or cfg.get("out", "photos"))
    cap, size = a.max or cfg.get("max", 4), a.size or cfg.get("size", 720)
    raw = out / "_raw"
    raw.mkdir(parents=True, exist_ok=True)

    manifest, hashes = {}, set()
    for pid, p in products.items():
        print(f"\n{pid}")
        urls, ref = [], {}
        for page in p.get("pages", []):
            for u in candidates(page, p.get("keywords", []), size):
                if u not in ref:
                    urls.append(u); ref[u] = page
            time.sleep(1.5)
        for u in p.get("direct", []):
            if u not in ref:
                urls.append(u); ref[u] = None
        saved = []
        for u in urls:
            if len(saved) >= cap:
                break
            n = len(saved) + 1
            try:
                data = get(u, binary=True, referer=ref[u])
                digest = hashlib.sha1(data).hexdigest()
                if len(data) < 4000 or digest in hashes:  # placeholder, pixel or duplicate
                    continue
                hashes.add(digest)
                tmp, dst = raw / f"{pid}-{n}", out / f"{pid}-{n}.jpg"
                tmp.write_bytes(data)
                if resize(tmp, dst, size):
                    w, h = dims(dst)
                    if h and (w / h > 1.7 or min(w, h) < 120):  # social-share banner or sliver
                        dst.unlink()
                        print(f"  skipped banner/sliver {w}x{h}: {u[:70]}")
                        continue
                    saved.append({"file": dst.name, "source": u, "page": ref[u]})
                    print(f"  saved {dst.name}")
            except Exception as e:
                print(f"  image failed ({e}): {u[:90]}")
            time.sleep(1)
        manifest[pid] = saved

    shutil.rmtree(raw, ignore_errors=True)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2))
    cells = "".join(f'<figure><img src="{html.escape(s["file"])}"><figcaption>{html.escape(s["file"])}</figcaption></figure>'
                    for v in manifest.values() for s in v)
    (out / "contact.html").write_text(
        "<!doctype html><meta charset=utf-8><title>Contact sheet</title><style>body{font:14px system-ui;display:grid;"
        "grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px;padding:16px}img{width:100%;aspect-ratio:1;"
        f"object-fit:contain;background:#f3f3f3}}figure{{margin:0}}</style>{cells}")
    zip_path = shutil.make_archive(str(out), "zip", root_dir=out)
    print(f"\nDone: {sum(map(len, manifest.values()))} photo(s) in {out}/ (open contact.html to check) and {zip_path}")
    if (missing := [k for k, v in manifest.items() if not v]):
        print("No photos for: " + ", ".join(missing) + ". Add a shop product page or a direct image URL and rerun.")


if __name__ == "__main__":
    sys.exit(main())
