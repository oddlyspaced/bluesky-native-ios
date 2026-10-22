#!/bin/bash
# Captures one iOS parity state as a matched pair and writes its evidence.
#
#   ./run-round.sh <state> [out-root]
#   state: base | dark | xxxl | empty | mergefeed | interactions | wrapped | api
#
# This is the iOS counterpart of android/parity/run-round.sh. It exists because the iOS diff and
# mask steps were run by hand from the commands in PARITY.md, which is the reason method limit E8
# records the iOS event result as not reproducible from this repository.
#
# Steps, all under one hold of /tmp/bsky-seed.lock through run-pair.sh:
#   1. run-pair.sh captures the React Native build and then the port on the SAME seed, so the
#      relative timestamps and the anchor date agree. A pair captured on two different seeds is not
#      comparable on any date-bearing screen.
#   2. make_masks.py rebuilds the masks for the state from masks-spec.json and checks its own
#      limits (MAX_MASK, MAX_AREA, MAX_SLOT, MAX_RECT_MARGIN, and no native ink outside RN ink).
#   3. diff.mjs runs twice, raw and masked.
#   4. The masked results are copied to parity/evidence/<state>/, which is committed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
STATE=${1:?usage: run-round.sh <state> [out-root]}
ROOT=${2:-"$HERE/out"}
OUT="$ROOT/$STATE"
PACK=${PACK:-"$HERE/../../../../migration-pack"}
DIFF="$PACK/skills/check-parity/scripts/diff.mjs"
EV="$HERE/evidence/$STATE"

# SKIP_CAPTURE=1 measures the screenshots already in <out-root>/<state>/ instead of taking new
# ones. Use it only when that pair was captured in one run of run-pair.sh, because a pair captured
# across two runs does not share a seed and its date-bearing screens are not comparable.
if [ "${SKIP_CAPTURE:-}" = "1" ]; then
  echo "=== $STATE / capture pair SKIPPED, measuring what is in $OUT  $(date +%T)"
  pair_rc=0
else
  echo "=== $STATE / capture pair  $(date +%T)"
  "$HERE/run-pair.sh" "$STATE" "$OUT"
  pair_rc=$?
fi

# Judge the capture on what it produced, not on the exit code.
#
# `run-capture.sh` runs the mask check at the end of EACH side. When it runs for the React Native
# side, the port's screenshots are still the ones left over from the previous round, so an
# incomplete set there fails the React Native capture even though it took every screenshot it
# needed. That is a false failure, and acting on it discards a good pair.
#
# A real failure is a missing or empty screenshot. Both sides must hold the same set of names, and
# every file must be non-empty: a Maestro run whose driver died mid-screenshot leaves a 0-byte PNG.
rn_shots=$(cd "$OUT/rn/ios" 2>/dev/null && ls -- *.png 2>/dev/null | sort | tr '\n' ' ')
nat_shots=$(cd "$OUT/native/ios" 2>/dev/null && ls -- *.png 2>/dev/null | sort | tr '\n' ' ')
if [ -z "$rn_shots" ] || [ "$rn_shots" != "$nat_shots" ]; then
  echo "$STATE: the two sides did not produce the same screenshots." >&2
  echo "  rn:     ${rn_shots:-none}" >&2
  echo "  native: ${nat_shots:-none}" >&2
  echo "$STATE: stopping so a half-captured round is never measured (run-pair exit $pair_rc)." >&2
  exit 1
fi
for side in rn native; do
  for shot in $rn_shots; do
    [ -s "$OUT/$side/ios/$shot" ] || {
      echo "$STATE: $OUT/$side/ios/$shot is empty, so the capture did not complete." >&2
      exit 1
    }
  done
done
if [ $pair_rc -ne 0 ]; then
  echo "$STATE: run-pair reported exit $pair_rc, but both sides produced the same complete set"
  echo "$STATE: of screenshots ($rn_shots), so the round continues. See the note above."
fi

echo "=== $STATE / masks  $(date +%T)"
python3 "$HERE/make_masks.py" "$HERE/masks-spec.json" "$STATE" "$OUT/rn/ios" "$OUT/native/ios" \
  "$HERE/masks/$STATE.json" || {
  echo "$STATE: make_masks.py refused the masks. Nothing is measured against unchecked masks." >&2
  exit 1
}

echo "=== $STATE / diff  $(date +%T)"
node "$DIFF" --rn "$OUT/rn/ios" --native "$OUT/native/ios" --out "$OUT/diff-raw" >/dev/null
node "$DIFF" --rn "$OUT/rn/ios" --native "$OUT/native/ios" --out "$OUT/diff-masked" \
  --mask "$HERE/masks/$STATE.json" >/dev/null
rc=$?

mkdir -p "$EV"
cp "$OUT/diff-masked/results.json" "$EV/diff-masked-results.json" 2>/dev/null
cp "$OUT/diff-raw/results.json" "$EV/diff-raw-results.json" 2>/dev/null
cp "$HERE/masks/$STATE.json" "$EV/masks.json" 2>/dev/null

python3 - "$EV/diff-masked-results.json" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1]))
except Exception as e:
    print("no masked results:", e); sys.exit(0)
rows = r if isinstance(r, list) else r.get("screens", r.get("results", []))
for s in rows:
    name = s.get("screen") or s.get("name")
    ratio = s.get("ratio")
    status = s.get("status")
    if ratio is None: continue
    print(f"  {name:28s} {ratio*100:5.2f}%  {status}")
PY
echo "=== $STATE done $(date +%T) diff exit $rc"
