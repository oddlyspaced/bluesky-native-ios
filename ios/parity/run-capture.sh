#!/bin/bash
# Captures one parity state for one build with the Pack's check-parity/scripts/capture.mjs.
#
# Usage: ios/parity/run-capture.sh <label rn|native> <state> [out-dir]
#   state: base | dark | xxxl | empty | mergefeed | interactions | errors
#
# Environment:
#   RESEED=false  skip the flow's seed step (run-pair.sh sets it for the second app of a pair)
#   NOLOCK=1      the caller already holds the seed lock (run-pair.sh)
#
# - Takes the shared seed lock (/tmp/bsky-seed.lock, stale after 20 min) for seed + Maestro.
# - Sets the simulator appearance or content size for the state and resets it afterwards.
# - Screenshots land in <out-dir>/<label>/ios/ (default out-dir: ios/parity/out/<state>).
# - For the native build it copies Documents/events.jsonl next to the screenshots and writes
#   events.normalized.jsonl while the seed is still live (normalize_events.py reads the PDS).
set -uo pipefail

LABEL=${1:?label rn|native}
STATE=${2:?state}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT=${3:-"$HERE/out/$STATE"}
mkdir -p "$OUT" && OUT="$(cd "$OUT" && pwd)"
UDID=${UDID:-7F73AB4A-2709-4033-89D2-35CE10E650F4}
PACK=${PACK:-../migration-pack}
CAPTURE="$PACK/skills/check-parity/scripts/capture.mjs"
LOCK=/tmp/bsky-seed.lock
NATIVE_ID=io.nativestarter.showcase.bluesky

if [ "${NOLOCK:-}" != "1" ]; then
  until mkdir "$LOCK" 2>/dev/null; do
    if [ -d "$LOCK" ] && [ $(( $(date +%s) - $(stat -f %m "$LOCK") )) -gt 1200 ]; then
      rmdir "$LOCK" 2>/dev/null; continue
    fi
    echo "waiting for seed lock"; sleep 10
  done
fi

reset_ui() {
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1
  xcrun simctl ui "$UDID" content_size large >/dev/null 2>&1
}
cleanup() {
  reset_ui
  if [ "${NOLOCK:-}" != "1" ]; then rmdir "$LOCK" 2>/dev/null; fi
}
trap cleanup EXIT

reset_ui
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 >/dev/null 2>&1

FLOW=capture.yml
ENV=()
case "$STATE" in
  base|base2) ;;
  dark) xcrun simctl ui "$UDID" appearance dark; ENV=(--env SUFFIX=-dark) ;;
  xxxl) xcrun simctl ui "$UDID" content_size extra-extra-extra-large; ENV=(--env SUFFIX=-xxxl) ;;
  empty) ENV=(--env "SEED=?users" --env SUFFIX=-empty) ;;
  mergefeed) FLOW=capture-mergefeed.yml ;;
  interactions) FLOW=capture-interactions.yml ;;
  errors) FLOW=capture-errors-native.yml ;;
  *) echo "unknown state $STATE"; exit 2 ;;
esac
if [ "${RESEED:-true}" = "false" ]; then
  case "$FLOW" in
    capture.yml|capture-mergefeed.yml) ENV+=(--env RESEED=false) ;;
    *) echo "RESEED=false is not supported for $FLOW (it changes or needs its own data)"; exit 2 ;;
  esac
fi

rm -rf "$OUT/$LABEL"
cd "$HERE/flows"
node "$CAPTURE" --flow "$FLOW" --platform ios --device "$UDID" --label "$LABEL" --out "$OUT" ${ENV[@]+"${ENV[@]}"}
code=$?

if [ "$LABEL" = "native" ]; then
  data=$(xcrun simctl get_app_container "$UDID" "$NATIVE_ID" data 2>/dev/null)
  if [ -n "$data" ] && [ -f "$data/Documents/events.jsonl" ]; then
    cp "$data/Documents/events.jsonl" "$OUT/native/ios/events.jsonl"
    python3 "$HERE/events/normalize_events.py" "$OUT/native/ios/events.jsonl" > "$OUT/native/ios/events.normalized.jsonl" \
      || echo "event normalisation failed"
  else
    echo "no native events.jsonl found"
  fi
fi
exit $code
