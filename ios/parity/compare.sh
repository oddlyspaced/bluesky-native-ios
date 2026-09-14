#!/usr/bin/env bash
# Compares native iOS screenshots with the RN baseline screenshots.
#
# Usage: ios/parity/compare.sh <rn-shots-dir> [native-shots-dir]
#
# Prints, per screen, the differing-pixel count from
#   magick compare -metric AE -fuzz 5%
# and the ratio over 1206x2622 = 3,162,132 pixels, three ways:
#   raw      no masks
#   dynamic  status bar, relative timestamps, thread date line, and the logo slot masked
#   icons    "dynamic" plus every licence-substituted icon region masked
# Masks are rectangles in pixels (iPhone 17 Pro, 3x), measured on the RN baseline,
# painted black on BOTH images. `magick compare` exits 1 when images differ; that is not an error.
set -uo pipefail

RN_DIR=${1:?rn shots dir}
NATIVE_DIR=${2:-"$(cd "$(dirname "$0")" && pwd)/shots"}
OUT_DIR=${OUT_DIR:-"$(cd "$(dirname "$0")" && pwd)/diff"}
TOTAL=3162132
mkdir -p "$OUT_DIR"

STATUS_BAR="0,0 1206,180"

# Dynamic regions per screen.
dynamic_home=(
  "$STATUS_BAR"
  "530,673 720,725" "530,921 720,973" "530,1193 720,1245" "530,1466 720,1518" "530,1739 720,1791"  # "· 10s"
  "553,202 653,302"                                                                                  # logo slot
)
dynamic_thread=(
  "$STATUS_BAR"
  "40,644 500,696"      # "12:55 AM · Sep 15, 2026"
  "530,859 720,911"     # reply "· 10s"
  "1060,386 1172,498"   # anchor logo (RN GrowthHack butterfly, visible only in screenshots)
)
dynamic_profile=(
  "$STATUS_BAR"
  "530,1136 720,1188"   # "· 10s"
)

# Icon regions (Lucide substitutes for the upstream Central icons).
icons_common=(
  "60,2400 1000,2516"   # bottom bar icons (home, search, chat, bell)
)
icons_home=(
  "44,207 134,297" "1064,207 1154,297"                                  # menu, hashtag
  "975,505 1170,600"                                                    # camera, image
  "190,824 1170,880" "190,1072 1170,1128" "190,1345 1170,1401" "190,1617 1170,1673" "190,1890 1170,1946"  # post controls
  "71,2023 181,2133"                                                    # info icon
  "1005,2214 1095,2304"                                                 # FAB compose icon
)
icons_thread=(
  "44,204 134,294" "1064,204 1154,294"  # back, sliders
  "510,644 570,696"                     # globe
  "30,710 1170,780"                     # anchor controls
  "190,1012 1170,1068"                  # reply controls
)
icons_profile=(
  "973,511 1023,561" "1084,511 1134,561"  # share, more
  "190,1287 1170,1343"                    # post controls
  "1005,2214 1095,2304"                   # FAB compose icon
)

draw_args() {
  [ $# -eq 0 ] && return 0
  local args=()
  for r in "$@"; do args+=(-draw "rectangle $r"); done
  printf '%s\n' "${args[@]}"
}

measure() { # screen label rects...
  local screen=$1 label=$2; shift 2
  local a="$OUT_DIR/rn-$screen-$label.png" b="$OUT_DIR/native-$screen-$label.png"
  local draws=()
  while IFS= read -r line; do draws+=("$line"); done < <(draw_args "$@")
  if [ ${#draws[@]} -gt 0 ]; then
    magick "$RN_DIR/ios-$screen.png" -fill black "${draws[@]}" "$a"
    magick "$NATIVE_DIR/ios-$screen.png" -fill black "${draws[@]}" "$b"
  else
    cp "$RN_DIR/ios-$screen.png" "$a"
    cp "$NATIVE_DIR/ios-$screen.png" "$b"
  fi
  local px
  px=$(magick compare -metric AE -fuzz 5% "$a" "$b" "$OUT_DIR/diff-$screen-$label.png" 2>&1 >/dev/null | cut -d' ' -f1)
  printf '| %-7s | %-7s | %9s | %.4f |\n' "$screen" "$label" "$px" "$(echo "$px / $TOTAL" | bc -l)"
}

echo "| screen  | masks   | AE pixels | ratio  |"
echo "|---------|---------|-----------|--------|"
for screen in home thread profile; do
  eval "dyn=(\"\${dynamic_$screen[@]}\")"
  eval "ico=(\"\${icons_$screen[@]}\")"
  measure "$screen" raw
  measure "$screen" dynamic "${dyn[@]}"
  measure "$screen" icons "${dyn[@]}" "${ico[@]}" "${icons_common[@]}"
done
