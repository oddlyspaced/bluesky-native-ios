#!/usr/bin/env python3
"""Builds the review sheet an owner needs to sign off the drift rows.

Usage: parity/review-sheet.py [out-dir]        (default: review-sheet/)

`references/thresholds.md` says a drift is a decision, not a number: the reviewer opens the diff
image and both screenshots, names what differs, and accepts it in writing or sends the port back.
The screenshots for that live in two trees, under a directory per state, and the diff images are
not kept in git. This puts one image per drift row side by side - React Native, the port, and where
they differ - and an index that lists them, so the decision can be made in one sitting.

The same rule says the agent that wrote the port must not sign its own drift, so this script
produces the evidence and leaves every row blank. Record decisions in `plan/owner-signoff.md`.

Run it from the repository root, after a capture round. Output is not committed: the raw PNGs are
not in git either, and this is derived from them.
"""
import json
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / "review-sheet")
FUZZ, STRONG, MID = 12, 128, 48
SCALE = 3


def masked(path, screen):
    spec = json.load(open(path))
    return spec.get(screen, [])


def composite(rn_path, nat_path, masks_path, screen, name):
    """One row: React Native, the port, and a graded difference map."""
    rn = Image.open(rn_path).convert("RGB")
    nat = Image.open(nat_path).convert("RGB")
    w, h = rn.size
    a, b = rn.load(), nat.load()
    cover = [[False] * w for _ in range(h)]
    for m in masked(masks_path, screen):
        x0 = int(round(m["x"] * w)); y0 = int(round(m["y"] * h))
        x1 = min(w, x0 + int(round(m["w"] * w))); y1 = min(h, y0 + int(round(m["h"] * h)))
        for y in range(max(0, y0), y1):
            row = cover[y]
            for x in range(max(0, x0), x1):
                row[x] = True

    diff = Image.new("RGB", (w, h), (255, 255, 255))
    px = diff.load()
    differing = 0
    for y in range(h):
        row = cover[y]
        for x in range(w):
            if row[x]:
                px[x, y] = (232, 232, 238)
                continue
            p, q = a[x, y], b[x, y]
            d = max(abs(p[0] - q[0]), abs(p[1] - q[1]), abs(p[2] - q[2]))
            if d <= FUZZ:
                continue
            differing += 1
            px[x, y] = (206, 0, 0) if d > STRONG else ((255, 140, 0) if d > MID else (255, 226, 130))

    gap = 24
    sheet = Image.new("RGB", (w * 3 + gap * 2, h), (248, 248, 250))
    sheet.paste(rn, (0, 0)); sheet.paste(nat, (w + gap, 0)); sheet.paste(diff, (w * 2 + gap * 2, 0))
    OUT.mkdir(parents=True, exist_ok=True)
    sheet.resize((sheet.width // SCALE, sheet.height // SCALE), Image.LANCZOS).save(
        OUT / f"{name}.png", optimize=True)
    return f"{name}.png", 100 * differing / (w * h)


def android_rows():
    for state in ("base", "dark", "font2", "interactions", "empty", "error"):
        results = ROOT / f"android/parity/out/{state}/diff-masked/results.json"
        if not results.exists():
            continue
        for s in json.load(open(results))["screens"]:
            if s["status"] != "drift":
                continue
            name, _ = composite(
                ROOT / f"android/parity/out/{state}/rn/android/{s['name']}.png",
                ROOT / f"android/parity/out/{state}/native/android/{s['name']}.png",
                ROOT / f"android/parity/out/masks-{state}.json", s["name"],
                f"android-{state}-{s['name']}")
            yield "Android", state, s["name"], f"{100 * s['ratio']:.2f}%", name


def ios_rows():
    for state in ("base", "dark", "xxxl", "empty", "mergefeed", "interactions", "wrapped", "api"):
        rn_dir = ROOT / f"ios/parity/out/{state}/rn/ios"
        nat_dir = ROOT / f"ios/parity/out/{state}/native/ios"
        masks = ROOT / f"ios/parity/masks/{state}.json"
        if not (rn_dir.exists() and masks.exists()):
            continue
        for png in sorted(rn_dir.glob("*.png")):
            nat = nat_dir / png.name
            if not nat.exists():
                continue
            name, pct = composite(png, nat, masks, png.stem, f"ios-{state}-{png.stem}")
            if 1.0 < pct <= 2.0:
                yield "iOS", state, png.stem, f"{pct:.2f}%", name
            else:
                (OUT / name).unlink(missing_ok=True)


STYLE = """<style>
:root{--ink:#14161a;--muted:#5b6472;--line:#e3e6ea;--bg:#fbfbfc}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--ink:#e9ecf1;--muted:#9aa4b2;--line:#2a2f37;--bg:#14161a}}
body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
main{max-width:1200px;margin:0 auto;padding:40px 16px 96px}
h1{font-size:28px;margin:0 0 6px} .sub{color:var(--muted);margin:0 0 28px}
.rule{border:1px solid var(--line);border-radius:10px;padding:14px 18px;margin:0 0 32px;color:var(--muted)}
.row{border-top:1px solid var(--line);padding:26px 0}
.hd{display:flex;gap:14px;align-items:baseline;flex-wrap:wrap;margin-bottom:10px}
.hd b{font-size:17px} .pct{font-variant-numeric:tabular-nums;font-weight:600}
.tag{color:var(--muted);font-size:13px}
img{width:100%;height:auto;border:1px solid var(--line);border-radius:8px;display:block}
.cap{color:var(--muted);font-size:13px;margin:8px 0 0}
.key{display:flex;gap:18px;flex-wrap:wrap;font-size:13px;color:var(--muted);margin-top:8px}
.sw{display:inline-block;width:11px;height:11px;border-radius:2px;margin-right:5px;vertical-align:-1px}
</style>"""


def main():
    rows = list(android_rows()) + list(ios_rows())
    h = ["<!doctype html><meta charset=utf-8><title>Bluesky port: drift review</title>", STYLE,
         "<main><h1>Bluesky port: drift review</h1>",
         f"<p class=sub>{len(rows)} screens between 1% and 2% after masks. Nothing here is a fail.</p>",
         """<div class=rule><b>What this is for.</b> The Pack's thresholds say a drift is a decision,
not a number: open the diff, name what differs, then accept it in writing or send the port back.
Record the decision in <code>plan/owner-signoff.md</code>. The same rule says the agent that wrote
the port must not sign its own drift, which is why every row is blank.
<div class=key><span><span class=sw style="background:#ce0000"></span>strong, ink in one app only</span>
<span><span class=sw style="background:#ff8c00"></span>mid</span>
<span><span class=sw style="background:#ffe282"></span>faint, antialiasing</span>
<span><span class=sw style="background:#e8e8ee"></span>masked, excluded</span></div></div>"""]
    for plat, state, screen, pct, f in rows:
        h.append(f"<section class=row><div class=hd><b>{plat} · {state} · {screen}</b>"
                 f"<span class=pct>{pct}</span>"
                 f"<span class=tag>React Native · port · difference</span></div>"
                 f"<img loading=lazy src='{f}' alt='{plat} {state} {screen}'>"
                 f"<p class=cap>Left: React Native. Middle: the port. Right: where they differ.</p></section>")
    h.append("</main>")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "index.html").write_text("\n".join(h))
    print(f"{len(rows)} rows -> {OUT / 'index.html'}")


if __name__ == "__main__":
    main()
