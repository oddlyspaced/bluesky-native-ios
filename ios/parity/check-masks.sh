#!/bin/bash
# Rebuilds the masks of one state from a captured pair and checks the committed file against them
# (review finding A73). run-capture.sh calls this after the second app of a pair, so no capture can
# report a parity number from a mask that the images no longer support.
#
# Usage: ios/parity/check-masks.sh <state> <rn-dir> <native-dir>
#
# Environment:
#   UPDATE=1     write masks/<state>.json from this capture instead of comparing it
#   MASKS_DIR    directory of the committed masks (default ios/parity/masks)
#
# Exit 0: the masks were rebuilt, every native-ink check passed, and the committed file matches.
# Exit 1: make_masks.py failed, or the committed file is stale. A stale mask is an error, not a
#         silent pass: the diff would then hide or expose pixels that this capture does not support.
set -uo pipefail
STATE=${1:?state}
RN=${2:?rn screenshot directory}
NAT=${3:?native screenshot directory}
HERE="$(cd "$(dirname "$0")" && pwd)"
MASKS_DIR=${MASKS_DIR:-"$HERE/masks"}
COMMITTED="$MASKS_DIR/$STATE.json"

if ! python3 -c "import json,sys; sys.exit(0 if sys.argv[1] in json.load(open(sys.argv[2])) else 3)" \
    "$STATE" "$HERE/masks-spec.json"; then
  echo "masks: $STATE has no entry in masks-spec.json, nothing to check"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 "$HERE/make_masks.py" "$HERE/masks-spec.json" "$STATE" "$RN" "$NAT" "$TMP/$STATE.json"
code=$?
if [ $code -ne 0 ]; then
  echo "ERROR make_masks.py failed for $STATE: a mask check did not pass (see the ERROR lines above)" >&2
fi

if [ "${UPDATE:-}" = "1" ]; then
  cp "$TMP/$STATE.json" "$COMMITTED" && echo "masks: wrote $COMMITTED from this capture"
  exit $code
fi

if [ ! -f "$COMMITTED" ]; then
  echo "ERROR no committed masks at $COMMITTED. Run UPDATE=1 $0 $STATE $RN $NAT and commit the file." >&2
  exit 1
fi

if diff -q "$COMMITTED" "$TMP/$STATE.json" >/dev/null 2>&1; then
  echo "masks: $COMMITTED matches the masks built from this capture"
else
  echo "ERROR $COMMITTED is stale: it differs from the masks built from this capture." >&2
  diff -u "$COMMITTED" "$TMP/$STATE.json" | head -40 >&2
  echo "ERROR rebuild it with UPDATE=1 $0 $STATE $RN $NAT and commit the new file." >&2
  code=1
fi
exit $code
