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
# - Takes the shared seed lock (/tmp/bsky-seed.lock) for the seed and the Maestro run. seed-lock.sh
#   breaks a held lock only when the recorded holder process is gone, or when no holder is recorded
#   and the lock is older than the staleness limit (review finding A77).
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
NATIVE_ID=io.nativestarter.showcase.bluesky
# shellcheck source=seed-lock.sh
. "$HERE/seed-lock.sh"

if [ "${NOLOCK:-}" != "1" ]; then
  seed_lock_acquire
fi

reset_ui() {
  xcrun simctl ui "$UDID" appearance light >/dev/null 2>&1
  xcrun simctl ui "$UDID" content_size large >/dev/null 2>&1
}
cleanup() {
  reset_ui
  if [ "${NOLOCK:-}" != "1" ]; then seed_lock_release; fi
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
  # API setup states (review findings F7, F9): setupApi.js writes records after the seed.
  wrapped) FLOW=capture-wrapped.yml ;;
  api) FLOW=capture-api.yml ;;
  *) echo "unknown state $STATE"; exit 2 ;;
esac
if [ "${RESEED:-true}" = "false" ]; then
  case "$FLOW" in
    capture.yml|capture-mergefeed.yml|capture-wrapped.yml|capture-api.yml) ENV+=(--env RESEED=false) ;;
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
    # The normaliser writes the file itself and leaves none when it fails, so no run can read a
    # truncated list as evidence. A failure fails the capture (review finding A89).
    rm -f "$OUT/native/ios/events.normalized.jsonl"
    if ! python3 "$HERE/events/normalize_events.py" "$OUT/native/ios/events.jsonl" \
        "$OUT/native/ios/events.normalized.jsonl"; then
      echo "ERROR event normalisation failed: $OUT/native/ios/events.normalized.jsonl was not written" >&2
      code=1
    fi
  else
    echo "ERROR no native events.jsonl found in the app container" >&2
    code=1
  fi
fi
exit $code
