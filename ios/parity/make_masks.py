#!/usr/bin/env python3
"""Builds check-parity masks.json files from declared bands, measured on both images.

Masks hide only what the parity gate allows (check-parity/references/masking.md):
  status   the status bar (clock, battery)
  glyphs   icon glyph boxes: ink clusters in a band, at least `minw` px wide, so post counts
           and text next to the icons stay visible (licence substitution: Lucide icons)
  tail     the last two ink clusters of a meta line: "·" and the relative time
  rect     an explicit rectangle, with the reason in the spec (logo slot, date line, FAB glyph)

Clusters are measured on the RN image and the native image and merged, so one mask covers
both. Ink is a pixel whose luma differs from the row background by more than 40.

Usage: make_masks.py <spec.json> <state> <rn-dir> <native-dir> <out-masks.json>
Prints the masked fraction per screen; the gate is at most 15% per screen.
"""
import json
import sys

from PIL import Image

W, H = 1206, 2622
GAP = 6
PAD = 4


def load(path):
    img = Image.open(path).convert("RGB")
    if img.size != (W, H):
        raise SystemExit(f"{path}: size {img.size}, expected {(W, H)}")
    return img.convert("L").load()


def ink_columns(px, box):
    x0, y0, x1, y1 = box
    cols = {}
    for y in range(y0, y1):
        # x 0-2 holds the native E2E fault-control column (rows 300-314), so sample at x 6.
        bg = px[6, y]
        for x in range(x0, x1):
            if abs(px[x, y] - bg) > 40:
                lo, hi = cols.get(x, (y, y))
                cols[x] = (min(lo, y), max(hi, y))
    return cols


def clusters(cols):
    out = []
    for x in sorted(cols):
        lo, hi = cols[x]
        if out and x - out[-1][1] <= GAP:
            c = out[-1]
            out[-1] = [c[0], x, min(c[2], lo), max(c[3], hi)]
        else:
            out.append([x, x, lo, hi])
    return out


def merge(a, b):
    items = sorted(a + b)
    out = []
    for c in items:
        if out and c[0] <= out[-1][1] + GAP:
            p = out[-1]
            out[-1] = [p[0], max(p[1], c[1]), min(p[2], c[2]), max(p[3], c[3])]
        else:
            out.append(list(c))
    return out


def rect(x0, y0, x1, y1, reason):
    x0, y0 = max(0, x0 - PAD), max(0, y0 - PAD)
    x1, y1 = min(W, x1 + PAD + 1), min(H, y1 + PAD + 1)
    return {"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
            "h": round((y1 - y0) / H, 5), "reason": reason, "px": [x0, y0, x1, y1]}


def build(band, rn, nat):
    kind = band["kind"]
    if kind == "status":
        return [{"x": 0, "y": 0, "w": 1, "h": round(180 / H, 5), "reason": "status bar: clock, battery, signal",
                 "px": [0, 0, W, 180]}]
    if kind == "rect":
        x0, y0, x1, y1 = band["box"]
        return [{"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
                 "h": round((y1 - y0) / H, 5), "reason": band["reason"], "px": [x0, y0, x1, y1]}]
    box = band["box"]
    both = merge(clusters(ink_columns(rn, box)), clusters(ink_columns(nat, box)))
    if kind == "glyphs":
        # Post control rows: the left group (reply, repost, like) carries counts, which stay
        # visible through `minw`. The right group (bookmark, share, more) has no text, so its
        # narrower glyphs (the "more" ellipsis) use `minw_right` from x >= `right_x`.
        minw = band.get("minw", 36)
        right_x = band.get("right_x", 900)
        minw_right = band.get("minw_right", 12)
        return [rect(c[0], c[2], c[1], c[3], band.get("reason", "icon glyph (Lucide substitute)"))
                for c in both
                if c[1] - c[0] + 1 >= (minw_right if c[0] >= right_x else minw)]
    if kind == "tail":
        per = []
        for px in (rn, nat):
            cs = clusters(ink_columns(px, box))
            if len(cs) >= 2:
                per.append((cs[-2][0], cs[-1][1], min(cs[-2][2], cs[-1][2]), max(cs[-2][3], cs[-1][3])))
        if not per:
            return []
        return [rect(min(p[0] for p in per), min(p[2] for p in per), max(p[1] for p in per),
                     max(p[3] for p in per), "relative timestamp (capture time)")]
    raise SystemExit(f"unknown band kind {kind}")


def coverage(rects):
    mask = bytearray(W * H)
    for r in rects:
        x0, y0, x1, y1 = r["px"]
        for y in range(y0, min(y1, H)):
            mask[y * W + x0:y * W + min(x1, W)] = b"\x01" * (min(x1, W) - x0)
    return sum(mask) / (W * H)


def main():
    spec_path, state, rn_dir, nat_dir, out = sys.argv[1:6]
    spec = json.load(open(spec_path))[state]
    result = {}
    for screen, bands in spec.items():
        rn = load(f"{rn_dir}/{screen}.png")
        nat = load(f"{nat_dir}/{screen}.png")
        rects = []
        for band in bands:
            rects += build(band, rn, nat)
        print(f"{screen}: {len(rects)} masks, {coverage(rects) * 100:.2f}% of the screen")
        result[screen] = [{k: v for k, v in r.items() if k != "px"} for r in rects]
    with open(out, "w") as fh:
        json.dump(result, fh, indent=1)


if __name__ == "__main__":
    main()
