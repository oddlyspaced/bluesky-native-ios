#!/usr/bin/env python3
"""Builds check-parity masks.json files from declared bands, measured on the RN image only.

Masks hide only what the parity gate allows (check-parity/references/masking.md):
  status    the status bar (clock, battery)
  glyphs    icon glyph boxes: RN ink clusters in a band at least `minw` px wide, so post counts and
            text next to the icons stay visible (licence substitution: Lucide icons)
  tail      a fixed slot from the RN "·" of a meta line, wide enough for any short relative time
            ("now" to "59m"): the relative time changes with the capture clock
  datetime  a fixed slot over the first RN ink cluster of the anchor date line (the time digits),
            for states whose apps cannot share one seed; the date and the who-can-reply label stay
            visible
  rect      an explicit fixed slot, with the reason in the spec (logo slot, FAB glyph, bar glyphs)

Rules (review findings N18, N19):
- Every mask comes from the RN image or a fixed slot. The native image never widens a mask.
- The native image is checked: native ink in a glyphs, tail or datetime band that lies outside the
  RN-derived masks is an error, because a mask could otherwise hide a native-only glyph.
- A screen whose masks cover more than 15% of its pixels is an error.

Ink is a pixel whose luma differs from the row background by more than 40.

Usage: make_masks.py <spec.json> <state> <rn-dir> <native-dir> <out-masks.json>
Exit 0: masks written. Exit 1: masks written, but a check failed (listed on stderr).
"""
import json
import sys

from PIL import Image

W, H = 1206, 2622
GAP = 6
PAD = 4
MAX_AREA = 0.15


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


def rect(x0, y0, x1, y1, reason, pad=PAD):
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(W, x1 + pad + 1), min(H, y1 + pad + 1)
    return {"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
            "h": round((y1 - y0) / H, 5), "reason": reason, "px": [x0, y0, x1, y1]}


def covered(cluster, rects):
    """True when the cluster's columns and rows lie inside one mask."""
    x0, x1, y0, y1 = cluster
    return any(r["px"][0] <= x0 and x1 < r["px"][2] and r["px"][1] <= y0 and y1 < r["px"][3] for r in rects)


def build(band, rn):
    kind = band["kind"]
    if kind == "status":
        return [{"x": 0, "y": 0, "w": 1, "h": round(180 / H, 5), "reason": "status bar: clock, battery, signal",
                 "px": [0, 0, W, 180]}]
    if kind == "rect":
        x0, y0, x1, y1 = band["box"]
        return [{"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
                 "h": round((y1 - y0) / H, 5), "reason": band["reason"], "px": [x0, y0, x1, y1]}]
    box = band["box"]
    found = clusters(ink_columns(rn, box))
    if kind == "glyphs":
        # Post control rows: the left group (reply, repost, like) carries counts, which stay
        # visible through `minw`. The right group (bookmark, share, more) has no text, so its
        # narrower glyphs (the "more" ellipsis) use `minw_right` from x >= `right_x`.
        minw = band.get("minw", 36)
        right_x = band.get("right_x", 900)
        minw_right = band.get("minw_right", 12)
        return [rect(c[0], c[2], c[1], c[3], band.get("reason", "icon glyph (Lucide substitute)"))
                for c in found if c[1] - c[0] + 1 >= (minw_right if c[0] >= right_x else minw)]
    if kind == "tail":
        if len(found) < 2:
            return []
        dot = found[-2]
        slot = band.get("slot", 150)
        return [rect(dot[0], box[1], dot[0] + slot, box[3] - 1, "relative time (capture clock; slot for now..59m)", pad=0)]
    if kind == "datetime":
        if not found:
            return []
        first = found[0]
        slot = band.get("slot", 150)
        return [rect(first[0], box[1], first[0] + slot, box[3] - 1,
                     "anchor time digits (the apps need separate seeds in this state)", pad=0)]
    raise SystemExit(f"unknown band kind {kind}")


def native_escapes(band, nat, rects):
    """Native ink clusters in a measured band that no RN-derived mask covers, where the band's rule
    says such ink should be masked (a glyph of the band's width, or ink inside a time slot)."""
    kind = band["kind"]
    if kind not in ("glyphs", "tail", "datetime"):
        return []
    found = clusters(ink_columns(nat, band["box"]))
    if kind == "glyphs":
        minw = band.get("minw", 36)
        right_x = band.get("right_x", 900)
        minw_right = band.get("minw_right", 12)
        wide = [c for c in found if c[1] - c[0] + 1 >= (minw_right if c[0] >= right_x else minw)]
        return [c for c in wide if not covered(c, rects)]
    if kind == "tail":
        # The last two native clusters are the "·" and the time; both must sit in the RN slot.
        return [c for c in found[-2:] if not covered(c, rects)]
    return [c for c in found[:1] if not covered(c, rects)]


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
    errors = []
    for screen, bands in spec.items():
        rn = load(f"{rn_dir}/{screen}.png")
        nat = load(f"{nat_dir}/{screen}.png")
        rects = []
        per_band = []
        for band in bands:
            made = build(band, rn)
            rects += made
            per_band.append((band, made))
        for band, _ in per_band:
            for c in native_escapes(band, nat, rects):
                errors.append(f"{screen}: native ink x {c[0]}-{c[1]} y {c[2]}-{c[3]} in a {band['kind']} band "
                              f"{band['box']} lies outside the RN-derived masks")
        area = coverage(rects)
        print(f"{screen}: {len(rects)} masks, {area * 100:.2f}% of the screen")
        if area > MAX_AREA:
            errors.append(f"{screen}: masks cover {area * 100:.2f}%, above the 15% limit")
        result[screen] = [{k: v for k, v in r.items() if k != "px"} for r in rects]
    with open(out, "w") as fh:
        json.dump(result, fh, indent=1)
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
