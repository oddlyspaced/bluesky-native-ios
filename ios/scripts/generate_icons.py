#!/usr/bin/env python3
"""Generate IconGlyph.generated.swift from Lucide icons (ISC licence).

Why Lucide: the RN app's own glyphs (assets/icons, the Central icon system by
Iconists) are licensed to Bluesky for its own use only and cannot be
redistributed (ASSETS.md section 2). Lucide is openly licensed, drawn on the same
24x24 grid with a 2pt stroke and round caps, so sizes and weights line up.

Usage:
  npm pack lucide-static@1.46.0 && tar -xzf lucide-static-1.46.0.tgz
  python3 ios/scripts/generate_icons.py <path-to-extracted-package>

The script converts every SVG element (path, circle, ellipse, rect, line,
polyline, polygon) to path data, writes the Swift file and copies the licence.
"""
import pathlib
import re
import shutil
import sys
import xml.etree.ElementTree as ET

# (Swift case, Lucide icon name, role in the RN app it stands in for)
ICONS = [
    ("menu", "menu", "Menu_Stroke2_Corner0_Rounded, home header drawer button"),
    ("hashtag", "hash", "Hashtag_Stroke2_Corner0_Rounded, home header feeds button"),
    ("camera", "camera", "Camera_Stroke2_Corner0_Rounded, composer prompt"),
    ("image", "image", "Image_Stroke2_Corner2_Rounded, composer prompt"),
    ("reply", "message-square", "Reply, post controls"),
    ("repost", "repeat-2", "Repost_Stroke2_Corner3_Rounded, post controls"),
    ("heart", "heart", "Heart2 stroke and filled, post controls"),
    ("bookmark", "bookmark", "Bookmark and BookmarkFilled, post controls"),
    ("share", "forward", "ArrowShareRight_Stroke2_Corner2_Rounded, post controls and profile"),
    ("more", "ellipsis", "DotGrid3x1_Stroke2_Corner0_Rounded, post controls and profile"),
    ("home", "house", "HomeOpen stroke and filled, bottom bar"),
    ("search", "search", "MagnifyingGlass stroke and filled, bottom bar"),
    ("chat", "message-circle-more", "Message stroke and filled, bottom bar"),
    ("bell", "bell", "Bell stroke and filled, bottom bar"),
    ("compose", "square-pen", "EditBig_Stroke2_Corner2_Rounded, compose FAB"),
    ("back", "arrow-left", "ArrowLeft_Stroke2_Corner0_Rounded, thread header"),
    ("sliders", "sliders-vertical", "SettingsSliderVertical_Stroke2_Corner0_Rounded, thread header"),
    ("globe", "earth", "Earth_Stroke2_Corner0_Rounded, who can reply"),
    ("info", "info", "InfoCircleIcon, Discover fallback header"),
    ("quote", "quote", "CloseQuote_Stroke2_Corner1_Rounded, repost menu"),
    ("chevronRight", "chevron-right", "ChevronRight_Stroke2_Corner0_Rounded, end of feed buttons"),
    ("cornerDownRight", "corner-down-right", "ArrowCornerDownRight, replied-to row"),
    ("pin", "pin", "PinIcon, pinned post reason"),
    ("trash", "trash-2", "Trash_Stroke2_Corner0_Rounded, post not found tombstone"),
    ("personX", "user-x", "PersonX_Stroke2_Corner0_Rounded, blocked post tombstone"),
    ("eyeSlash", "eye-off", "EyeSlash_Stroke2_Corner0_Rounded, show more replies"),
    ("circlePlus", "circle-plus", "CirclePlus_Stroke2_Corner0_Rounded, read more replies"),
    ("arrowTopCircle", "circle-arrow-up", "ArrowTopCircle_Stroke2_Corner0_Rounded, continue thread"),
    ("warning", "triangle-alert", "Warning_Stroke2_Corner0_Rounded, error messages"),
    ("rotateCounterClockwise", "rotate-ccw", "ArrowRotateCounterClockwise, retry buttons"),
    ("rotateClockwise", "rotate-cw", "ArrowRotateClockwise, error message retry"),
    ("lock", "lock", "Lock_Stroke2_Corner0_Rounded, signed-in-only author"),
    ("group", "users", "Group3_Stroke2_Corner0_Rounded, who can reply (some people)"),
    ("circleBan", "ban", "CircleBanSign_Stroke2_Corner0_Rounded, replies disabled"),
    ("magnifyingGlass", "search", "MagnifyingGlass2_Stroke2_Corner0_Rounded, following empty state"),
]

NUM = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"


def f(value: str) -> float:
    return float(value)


def fmt(value: float) -> str:
    text = f"{value:.4f}".rstrip("0").rstrip(".")
    return text if text not in ("-0", "") else "0"


def element_to_path(el: ET.Element) -> str:
    tag = el.tag.split("}")[-1]
    a = el.attrib
    if tag == "path":
        return a["d"]
    if tag == "circle":
        cx, cy, r = f(a["cx"]), f(a["cy"]), f(a["r"])
        return (f"M{fmt(cx - r)} {fmt(cy)}a{fmt(r)} {fmt(r)} 0 1 0 {fmt(2 * r)} 0"
                f"a{fmt(r)} {fmt(r)} 0 1 0 {fmt(-2 * r)} 0Z")
    if tag == "ellipse":
        cx, cy, rx, ry = f(a["cx"]), f(a["cy"]), f(a["rx"]), f(a["ry"])
        return (f"M{fmt(cx - rx)} {fmt(cy)}a{fmt(rx)} {fmt(ry)} 0 1 0 {fmt(2 * rx)} 0"
                f"a{fmt(rx)} {fmt(ry)} 0 1 0 {fmt(-2 * rx)} 0Z")
    if tag == "line":
        return f"M{a['x1']} {a['y1']}L{a['x2']} {a['y2']}"
    if tag in ("polyline", "polygon"):
        pts = re.findall(NUM, a["points"])
        pairs = [f"{pts[i]} {pts[i + 1]}" for i in range(0, len(pts), 2)]
        return "M" + "L".join(pairs) + ("Z" if tag == "polygon" else "")
    if tag == "rect":
        x, y = f(a.get("x", "0")), f(a.get("y", "0"))
        w, h = f(a["width"]), f(a["height"])
        rx = f(a.get("rx", a.get("ry", "0")))
        ry = f(a.get("ry", a.get("rx", "0")))
        if rx == 0:
            return f"M{fmt(x)} {fmt(y)}h{fmt(w)}v{fmt(h)}h{fmt(-w)}Z"
        return (f"M{fmt(x + rx)} {fmt(y)}H{fmt(x + w - rx)}A{fmt(rx)} {fmt(ry)} 0 0 1 {fmt(x + w)} {fmt(y + ry)}"
                f"V{fmt(y + h - ry)}A{fmt(rx)} {fmt(ry)} 0 0 1 {fmt(x + w - rx)} {fmt(y + h)}"
                f"H{fmt(x + rx)}A{fmt(rx)} {fmt(ry)} 0 0 1 {fmt(x)} {fmt(y + h - ry)}"
                f"V{fmt(y + ry)}A{fmt(rx)} {fmt(ry)} 0 0 1 {fmt(x + rx)} {fmt(y)}Z")
    raise SystemExit(f"unsupported SVG element: {tag}")


def main() -> None:
    package = pathlib.Path(sys.argv[1])
    icons_dir = package / "icons"
    version = __import__("json").loads((package / "package.json").read_text())["version"]
    root = pathlib.Path(__file__).resolve().parent.parent
    out_dir = root / "BlueskyNative/DesignSystem/Icons"

    lines = [
        "// Generated by ios/scripts/generate_icons.py. Do not edit by hand.",
        f"// Source: Lucide icons, lucide-static {version}, ISC licence (see LICENSE-lucide.txt).",
        "// The RN app's own glyphs are not redistributable (ASSETS.md section 2).",
        "",
        "enum IconGlyph: String, CaseIterable, Sendable {",
    ]
    bodies = []
    for case, name, role in ICONS:
        svg = icons_dir / f"{name}.svg"
        if not svg.exists():
            raise SystemExit(f"Lucide icon not found: {name}")
        tree = ET.parse(svg).getroot()
        paths = [element_to_path(el) for el in tree.iter() if el is not tree]
        lines.append(f"    /// Lucide `{name}`. Stands in for RN {role}.")
        lines.append(f"    case {case}")
        bodies.append((case, paths))
    lines += ["", "    /// Path data for each SVG element, on a 24x24 grid, stroked at 2pt.",
              "    var pathData: [String] {", "        switch self {"]
    for case, paths in bodies:
        joined = ", ".join(f'"{p}"' for p in paths)
        lines.append(f"        case .{case}: [{joined}]")
    lines += ["        }", "    }", "}", ""]
    (out_dir / "IconGlyph.generated.swift").write_text("\n".join(lines))
    shutil.copy(package / "LICENSE", out_dir / "LICENSE-lucide.txt")
    print(f"wrote {len(bodies)} glyphs from lucide-static {version}")


if __name__ == "__main__":
    main()
