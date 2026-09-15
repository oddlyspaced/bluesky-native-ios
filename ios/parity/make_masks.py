#!/usr/bin/env python3
"""Builds check-parity masks.json files from declared bands, measured on the RN image only.

Masks hide only what the parity gate allows (check-parity/references/masking.md):
  status    the status bar (clock, battery)
  glyphs    icon glyph boxes: RN ink clusters in a band at least `minw` px wide, each widened to a
            fixed icon slot, so post counts and text next to the icons stay visible (licence
            substitution: Lucide icons)
  tail      a fixed slot from the RN "·" of a meta line, wide enough for any short relative time
            ("now" to "59m"): the relative time changes with the capture clock
  datetime  a fixed slot over the first RN ink cluster of the anchor date line (the time digits),
            for states whose apps cannot share one seed; the date and the who-can-reply label stay
            visible
  rect      an explicit fixed slot, with the reason in the spec (logo slot, FAB glyph, bar glyphs)

Rules (review findings N18, N19, F5):
- Every mask comes from the RN image or a fixed slot. The native image never widens a mask.
- Native ink inside a mask must lie in the RN ink area of the same mask: the bounding box of the
  RN ink inside that mask, widened by TOL px. For `tail` and `datetime` slots the clock text may
  change width, so the area is the slot's columns and the RN ink rows widened by TOL. Native ink
  in a mask with no RN ink, or outside that area, is native-only ink hidden by a mask: an error.
  Every app mask kind is checked (`glyphs`, `tail`, `datetime`, `rect`), and ink of any width.
  The `status` mask is measured too, but reported as a note: iOS draws that ink (the clock and the
  "◀ <previous app>" back breadcrumb, which depends on the app launched before the capture).
- A native ink cluster of any width that is partly inside and partly outside a mask is an error
  (the glyph does not fit the RN slot), unless RN has a cluster with the same box there. Clusters
  are searched in every band and around every mask.
- A screen whose masks cover more than 15% of its pixels is an error.

Ink is a pixel whose luma differs from the row background (sampled at x 6) by more than 40.

Usage: make_masks.py <spec.json> <state> <rn-dir> <native-dir> <out-masks.json>
Exit 0: masks written. Exit 1: masks written, but a check failed (listed on stderr).
"""
import json
import sys

from PIL import Image

W, H = 1206, 2622
GAP = 6
PAD = 4
TOL = 4
AROUND = 12
MAX_AREA = 0.15


def load(path):
    img = Image.open(path).convert("RGB")
    if img.size != (W, H):
        raise SystemExit(f"{path}: size {img.size}, expected {(W, H)}")
    return img.convert("L").load()


def clamp_box(box):
    x0, y0, x1, y1 = box
    return max(0, x0), max(0, y0), min(W, x1), min(H, y1)


def is_ink(px, x, y):
    # x 0-2 holds the native E2E fault-control column (rows 300-314), so the background is sampled at x 6.
    return abs(px[x, y] - px[6, y]) > 40


def ink_pixels(px, box):
    x0, y0, x1, y1 = clamp_box(box)
    return [(x, y) for y in range(y0, y1) for x in range(x0, x1) if is_ink(px, x, y)]


def ink_columns(px, box):
    x0, y0, x1, y1 = clamp_box(box)
    cols = {}
    for y in range(y0, y1):
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


def rect(x0, y0, x1, y1, reason, kind, pad=PAD):
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(W, x1 + pad + 1), min(H, y1 + pad + 1)
    return {"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
            "h": round((y1 - y0) / H, 5), "reason": reason, "px": [x0, y0, x1, y1], "kind": kind}


def build(band, rn):
    kind = band["kind"]
    if kind == "status":
        return [{"x": 0, "y": 0, "w": 1, "h": round(180 / H, 5), "reason": "status bar: clock, battery, signal",
                 "px": [0, 0, W, 180], "kind": kind}]
    if kind == "rect":
        x0, y0, x1, y1 = band["box"]
        return [{"x": round(x0 / W, 5), "y": round(y0 / H, 5), "w": round((x1 - x0) / W, 5),
                 "h": round((y1 - y0) / H, 5), "reason": band["reason"], "px": [x0, y0, x1, y1], "kind": kind}]
    box = band["box"]
    found = clusters(ink_columns(rn, box))
    if kind == "glyphs":
        # Post control rows: the left group (reply, repost, like) carries counts, which stay
        # visible through `minw`. The right group (bookmark, share, more) has no text, so its
        # narrower glyphs (the "more" ellipsis) use `minw_right` from x >= `right_x`.
        minw = band.get("minw", 36)
        right_x = band.get("right_x", 900)
        minw_right = band.get("minw_right", 12)
        # Fixed slot: the icon's layout box at 3x, centred on the RN glyph. The Lucide glyph drawn
        # in the same box has a different ink extent, so the RN ink box alone is too tight.
        slot = band.get("slot", 72)
        out = []
        for c in found:
            if c[1] - c[0] + 1 < (minw_right if c[0] >= right_x else minw):
                continue
            cx, cy = (c[0] + c[1]) // 2, (c[2] + c[3]) // 2
            half = max(slot // 2, (c[1] - c[0]) // 2 + PAD, (c[3] - c[2]) // 2 + PAD)
            out.append(rect(cx - half, cy - half, cx + half, cy + half,
                            band.get("reason", "icon glyph (Lucide substitute), icon slot"), kind, pad=0))
        return out
    if kind == "tail":
        if len(found) < 2:
            return []
        dot = found[-2]
        slot = band.get("slot", 150)
        return [rect(dot[0], box[1], dot[0] + slot, box[3] - 1,
                     "relative time (capture clock; slot for now..59m)", kind, pad=0)]
    if kind == "datetime":
        if not found:
            return []
        first = found[0]
        slot = band.get("slot", 150)
        return [rect(first[0], box[1], first[0] + slot, box[3] - 1,
                     "anchor time digits (the apps need separate seeds in this state)", kind, pad=0)]
    raise SystemExit(f"unknown band kind {kind}")


def native_only_ink(mask, rn, nat):
    """Native ink pixels inside `mask` that lie outside the RN ink area of the same mask."""
    native = ink_pixels(nat, mask["px"])
    if not native:
        return None
    reference = ink_pixels(rn, mask["px"])
    if not reference:
        return native, None
    rx0 = min(x for x, _ in reference) - TOL
    rx1 = max(x for x, _ in reference) + TOL
    ry0 = min(y for _, y in reference) - TOL
    ry1 = max(y for _, y in reference) + TOL
    if mask["kind"] in ("tail", "datetime"):
        rx0, rx1 = mask["px"][0], mask["px"][2] - 1
    outside = [(x, y) for x, y in native if not (rx0 <= x <= rx1 and ry0 <= y <= ry1)]
    if not outside:
        return None
    return outside, (rx0, ry0, rx1, ry1)


def intersects(cluster, mask):
    x0, x1, y0, y1 = cluster
    mx0, my0, mx1, my1 = mask["px"]
    return x0 < mx1 and x1 >= mx0 and y0 < my1 and y1 >= my0


def covered(cluster, masks):
    """True when the cluster's columns and rows lie inside one mask."""
    x0, x1, y0, y1 = cluster
    return any(m["px"][0] <= x0 and x1 < m["px"][2] and m["px"][1] <= y0 and y1 < m["px"][3] for m in masks)


def ink_covered(px, cluster, masks):
    """True when every ink pixel in the cluster's box lies inside the union of `masks` (a glyph
    split over two rects, such as the bell left of and below the unread badge)."""
    x0, x1, y0, y1 = cluster
    for x, y in ink_pixels(px, [x0, y0, x1 + 1, y1 + 1]):
        if not any(m["px"][0] <= x < m["px"][2] and m["px"][1] <= y < m["px"][3] for m in masks):
            return False
    return True


def same_box(a, b):
    return all(abs(p - q) <= TOL for p, q in zip(a, b))


def edge_crossings(rn, nat, bands, masks):
    """Native clusters of any width that are partly inside a mask, searched in each measured band
    and in each mask widened by AROUND px. A crossing is allowed only when the RN image has a
    cluster with the same box (within TOL) in the same area: the shape crosses the mask in both
    apps, such as the FAB circle around its glyph slot or the bell around the badge cut-out."""
    areas = [b["box"] for b in bands if b["kind"] in ("glyphs", "tail", "datetime")]
    areas += [[m["px"][0] - AROUND, m["px"][1] - AROUND, m["px"][2] + AROUND, m["px"][3] + AROUND]
              for m in masks if m["kind"] != "status"]
    seen = set()
    out = []
    for area in areas:
        reference = clusters(ink_columns(rn, area))
        for c in clusters(ink_columns(nat, area)):
            key = tuple(c)
            if key in seen:
                continue
            seen.add(key)
            hit = [m for m in masks if m["kind"] != "status" and intersects(c, m)]
            if hit and not covered(c, hit) and not ink_covered(nat, c, hit) \
                    and not any(same_box(c, r) for r in reference):
                out.append((c, hit[0]))
    return out


def coverage(masks):
    mask = bytearray(W * H)
    for r in masks:
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
        masks = []
        for band in bands:
            masks += build(band, rn)
        for m in masks:
            found = native_only_ink(m, rn, nat)
            if found is None:
                continue
            pixels, area = found
            xs = [x for x, _ in pixels]
            ys = [y for _, y in pixels]
            where = f"x {min(xs)}-{max(xs)} y {min(ys)}-{max(ys)}"
            if m["kind"] == "status":
                # iOS draws the status bar, not the app: the clock (overridden to 9:41) and the
                # "◀ <previous app>" back breadcrumb, which names the app Maestro launched before.
                print(f"{screen}: note: {len(pixels)} native px ({where}) in the status bar differ from RN "
                      f"(system status bar, not app ink)")
                continue
            if area is None:
                errors.append(f"{screen}: {len(pixels)} native ink px ({where}) in a {m['kind']} mask {m['px']} "
                              f"with no RN ink")
            else:
                errors.append(f"{screen}: {len(pixels)} native ink px ({where}) in a {m['kind']} mask {m['px']} "
                              f"outside the RN ink area {list(area)}")
        for c, m in edge_crossings(rn, nat, bands, masks):
            errors.append(f"{screen}: native ink x {c[0]}-{c[1]} y {c[2]}-{c[3]} crosses the edge of a "
                          f"{m['kind']} mask {m['px']}")
        area = coverage(masks)
        print(f"{screen}: {len(masks)} masks, {area * 100:.2f}% of the screen")
        if area > MAX_AREA:
            errors.append(f"{screen}: masks cover {area * 100:.2f}%, above the 15% limit")
        result[screen] = [{k: v for k, v in r.items() if k not in ("px", "kind")} for r in masks]
    with open(out, "w") as fh:
        json.dump(result, fh, indent=1)
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
