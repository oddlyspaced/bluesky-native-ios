#!/bin/bash
# Captures one parity state for one build with the Pack's check-parity/capture.mjs.
#
# Usage: ios/parity/run-capture.sh <label rn|native> <state> [out-dir]
#   state: base | dark | xxxl | empty | interactions | errors
#
# - Takes the shared seed lock (/tmp/bsky-seed.lock) for the whole seed + Maestro run.
# - Sets the simulator appearance or content size for the state and resets it afterwards.
# - Screenshots land in <out-dir>/<label>/ios/ (default out-dir: ios/parity/out/<state>).
set -uo pipefail

LABEL=${1:?label rn|native}
STATE=${2:?state}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT=${3:-"$HERE/out/$STATE"}
# The script changes into flows/ before Maestro runs, so resolve the out directory first.
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"
UDID=${UDID:-7F73AB4A-2709-4033-89D2-35CE10E650F4}
PACK=${PACK:-../migration-pack}
CAPTURE="$PACK/skills/check-parity/scripts/capture.mjs"
LOCK=/tmp/bsky-seed.lock

until mkdir "$LOCK" 2>/dev/null; do
  if [ -d "$LOCK" ] && [ $(( $(date +%s) - $(stat -f %m "$LOCK") )) -gt 1200 ]; then
    rmdir "$LOCK" 2>/dev/null; continue
  fi
  echo "waiting for seed lock"; sleep 10
done

reset_ui() {
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1
  xcrun simctl ui "$UDID" content_size large >/dev/null 2>&1
}
cleanup() { reset_ui; rmdir "$LOCK" 2>/dev/null; }
trap cleanup EXIT

reset_ui
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 >/dev/null 2>&1

FLOW=capture.yml
EXTRA=()
case "$STATE" in
  base) ;;
  dark) xcrun simctl ui "$UDID" appearance dark; EXTRA=(-e SUFFIX=-dark) ;;
  xxxl) xcrun simctl ui "$UDID" content_size extra-extra-extra-large; EXTRA=(-e SUFFIX=-xxxl) ;;
  empty) EXTRA=(-e "SEED=?users" -e SUFFIX=-empty) ;;
  interactions) FLOW=capture-interactions.yml ;;
  errors) FLOW=capture-errors-native.yml ;;
  *) echo "unknown state $STATE"; exit 2 ;;
esac

mkdir -p "$OUT"
cd "$HERE/flows"
if [ ${#EXTRA[@]} -eq 0 ]; then
  node "$CAPTURE" --flow "$FLOW" --platform ios --device "$UDID" --label "$LABEL" --out "$OUT"
else
  # capture.mjs passes only PLATFORM and LABEL; extra variables go through MAESTRO_OPTS-style
  # wrapping: run Maestro directly with the same working directory and move the PNGs.
  (cd "$OUT" && maestro --device "$UDID" test -e PLATFORM=ios -e "LABEL=$LABEL" "${EXTRA[@]}" "$HERE/flows/$FLOW")
  code=$?
  mkdir -p "$OUT/$LABEL/ios"
  find "$OUT" -maxdepth 1 -name '*.png' -exec mv {} "$OUT/$LABEL/ios/" \;
  exit $code
fi
