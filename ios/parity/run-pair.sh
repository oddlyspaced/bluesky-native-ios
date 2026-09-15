#!/bin/bash
# Captures one state in both builds in the same run, under one seed lock (review finding N20).
#
# Usage: ios/parity/run-pair.sh <state> [out-dir]
#   state: base | dark | xxxl | empty | mergefeed | interactions
#
# The RN app runs first and seeds. For read-only states the native app runs on the same seed
# (RESEED=false), so both apps show the same posts and timestamps. `interactions` likes and
# reposts, so each app seeds its own data.
set -uo pipefail
STATE=${1:?state}
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT=${2:-"$HERE/out/$STATE"}
LOCK=/tmp/bsky-seed.lock

until mkdir "$LOCK" 2>/dev/null; do
  if [ -d "$LOCK" ] && [ $(( $(date +%s) - $(stat -f %m "$LOCK") )) -gt 1200 ]; then
    rmdir "$LOCK" 2>/dev/null; continue
  fi
  echo "waiting for seed lock"; sleep 10
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

echo "=== rn $STATE $(date +%T)"
NOLOCK=1 "$HERE/run-capture.sh" rn "$STATE" "$OUT"
rn=$?
reseed=false
[ "$STATE" = "interactions" ] && reseed=true
echo "=== native $STATE $(date +%T) (reseed $reseed)"
NOLOCK=1 RESEED=$reseed "$HERE/run-capture.sh" native "$STATE" "$OUT"
native=$?
echo "=== done $(date +%T) rn=$rn native=$native"
[ $rn -eq 0 ] && [ $native -eq 0 ]
