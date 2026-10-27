import argparse
import html
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://api.arasaac.org/v1"
STATIC = "https://static.arasaac.org/pictograms"
ROOT = Path(__file__).resolve().parent.parent
WORDS_JSON = ROOT / "assets" / "data" / "words.json"
RESULTS_JSON = ROOT / "tools" / "arasaac_results.json"
REVIEW_HTML = ROOT / "tools" / "image_review.html"


def get_json(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return []
        raise


def search(text):
    q = urllib.parse.quote(text)
    seen = {}
    for kind in ("bestsearch", "search"):
        for p in get_json(f"{API}/pictograms/en/{kind}/{q}"):
            seen.setdefault(p["_id"], p)
    return list(seen.values())


def keywords(p):
    out = []
    for k in p.get("keywords", []):
        for f in ("keyword", "plural"):
            if k.get(f):
                out.append(k[f])
    return out


def is_exact(p, text):
    t = text.strip().lower()
    return any(k.strip().lower() == t for k in keywords(p))


def download(pid, dest):
    url = f"{API}/pictograms/{pid}?resolution=500&download=true"
    with urllib.request.urlopen(url, timeout=60) as r:
        data = r.read()
    if not data.startswith(b"\x89PNG"):
        raise RuntimeError(f"not a PNG for id {pid}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)


def load_results():
    if RESULTS_JSON.exists():
        return json.loads(RESULTS_JSON.read_text(encoding="utf-8"))
    return {}


def write_review(words, results):
    rows = []
    for w in words:
        r = results.get(w["id"])
        if not r:
            continue
        img_path = ROOT / w["image"]
        rel = "../" + w["image"]
        status = r["status"]
        if img_path.exists():
            chosen = f'<img src="{html.escape(urllib.parse.quote(rel))}" alt="">'
        else:
            chosen = '<div class="none">no image</div>'
        chosen_id = r.get("chosen")
        chosen_label = f"#{chosen_id}" if chosen_id else ""
        alts = "".join(
            f'<figure><img src="{STATIC}/{a["id"]}/{a["id"]}_300.png" alt="" loading="lazy">'
            f'<figcaption>#{a["id"]}<br>{html.escape(a["label"])}</figcaption></figure>'
            for a in r.get("alternatives", [])
        ) or '<span class="muted">no candidates</span>'
        rows.append(
            f'<tr class="{status}"><td><b>{html.escape(w["en"])}</b><br>'
            f'<code>{html.escape(w["id"])}</code><br><span class="tag">{status}</span></td>'
            f'<td><figure>{chosen}<figcaption>{chosen_label}</figcaption></figure></td>'
            f'<td class="alts">{alts}</td></tr>'
        )
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ARASAAC Image Review</title>
<style>
:root {{ --bg:#fff; --fg:#1a1a1a; --muted:#666; --line:#ddd; --warn:#fff3cd; --skip:#eef3fb; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg:#161616; --fg:#eee; --muted:#999; --line:#333; --warn:#3a3214; --skip:#1b2533; }} }}
body {{ background:var(--bg); color:var(--fg); font:15px system-ui, sans-serif; margin:16px; }}
table {{ border-collapse:collapse; width:100%; }}
td {{ border-bottom:1px solid var(--line); padding:10px; vertical-align:top; }}
img {{ width:120px; height:120px; object-fit:contain; background:#fff; border:1px solid var(--line); border-radius:6px; }}
.alts img {{ width:90px; height:90px; }}
figure {{ display:inline-block; margin:0 8px 8px 0; text-align:center; }}
figcaption {{ font-size:12px; color:var(--muted); max-width:110px; }}
.none {{ width:120px; height:120px; display:flex; align-items:center; justify-content:center; border:2px dashed var(--line); border-radius:6px; color:var(--muted); }}
tr.no_match {{ background:var(--warn); }}
tr.skipped {{ background:var(--skip); }}
.tag {{ font-size:12px; color:var(--muted); }}
.muted {{ color:var(--muted); }}
</style></head><body>
<h1>ARASAAC Image Review</h1>
<p class="muted">Swap a pick: <code>python tools/fetch_arasaac.py --use word_id=ARASAAC_ID --force</code></p>
<table><tr><th>Word</th><th>Chosen</th><th>Alternatives</th></tr>
{''.join(rows)}
</table></body></html>
"""
    REVIEW_HTML.write_text(page, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--use", action="append", default=[])
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    data = json.loads(WORDS_JSON.read_text(encoding="utf-8"))
    words = data["words"]
    by_id = {w["id"]: w for w in words}
    results = load_results()
    saved, skipped, no_match = [], [], []

    for spec in args.use:
        wid, pid = spec.split("=", 1)
        w = by_id[wid]
        dest = ROOT / w["image"]
        if dest.exists() and not args.force:
            skipped.append(wid)
            continue
        download(int(pid), dest)
        r = results.setdefault(wid, {"alternatives": []})
        r["chosen"] = int(pid)
        r["status"] = "saved"
        saved.append(wid)

    if not args.use:
        targets = [by_id[i] for i in args.ids] if args.ids else words
        for w in targets:
            dest = ROOT / w["image"]
            existed = dest.exists()
            if existed and not args.ids:
                skipped.append(w["id"])
                continue
            found = search(w["en"])
            exact = [p for p in found if is_exact(p, w["en"])]
            others = [p for p in found if p not in exact]
            chosen = exact[0] if exact else None
            alt_pool = (exact[1:] + others)[:3]
            r = {
                "en": w["en"],
                "chosen": chosen["_id"] if chosen else None,
                "alternatives": [{"id": p["_id"], "label": ", ".join(keywords(p)[:2])} for p in alt_pool],
            }
            if existed:
                r["status"] = "skipped"
                skipped.append(w["id"])
            elif chosen:
                download(chosen["_id"], dest)
                r["status"] = "saved"
                saved.append(w["id"])
            else:
                r["status"] = "no_match"
                no_match.append(w["id"])
            results[w["id"]] = r
            time.sleep(0.2)

    RESULTS_JSON.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    write_review(words, results)
    print("saved:", ", ".join(saved) or "-")
    print("skipped (file exists):", ", ".join(skipped) or "-")
    print("no match:", ", ".join(no_match) or "-")
    print("review:", REVIEW_HTML)


if __name__ == "__main__":
    sys.exit(main())
