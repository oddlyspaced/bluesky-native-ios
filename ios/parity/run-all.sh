#!/bin/bash
# Captures every parity state in both builds (errors: native only). Each run takes the seed lock.
# The filter keeps the mask check and the event check visible, and every non-zero exit is reported,
# so no failed capture reads as a good run (review findings A73, A89).
HERE="$(cd "$(dirname "$0")" && pwd)"
FILTER="FAILED|Maestro failed|screenshot\(s\)|Assertion|^ERROR|^masks:"
failed=0

run_state() { # run_state <label> <state>
  echo "=== $1 $2 $(date +%T)"
  "$HERE/run-capture.sh" "$1" "$2" 2>&1 | grep -E "$FILTER" | head -8
  local code=${PIPESTATUS[0]}
  [ "$code" -eq 0 ] || { echo "!!! $1 $2 failed, exit $code"; failed=1; }
  ls "$HERE/out/$2/$1/ios/" 2>/dev/null | tr '\n' ' '; echo
}

for st in dark xxxl empty interactions; do
  for label in rn native; do
    rm -rf "$HERE/out/$st/$label"
    run_state $label $st
  done
done
rm -rf "$HERE/out/errors/native"
run_state native errors
echo "done $(date +%T), failed=$failed"
exit $failed
