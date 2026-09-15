#!/bin/bash
# Captures every parity state in both builds (errors: native only). Each run takes the seed lock.
HERE="$(cd "$(dirname "$0")" && pwd)"
for st in dark xxxl empty interactions; do
  for label in rn native; do
    rm -rf "$HERE/out/$st/$label"
    echo "=== $label $st $(date +%T)"
    "$HERE/run-capture.sh" $label $st 2>&1 | grep -E "FAILED|Maestro failed|screenshot\(s\)|Assertion" | head -5
    ls "$HERE/out/$st/$label/ios/" 2>/dev/null | tr '\n' ' '; echo
  done
done
rm -rf "$HERE/out/errors/native"
echo "=== native errors $(date +%T)"
"$HERE/run-capture.sh" native errors 2>&1 | grep -E "FAILED|Maestro failed|screenshot\(s\)|Assertion" | head -5
ls "$HERE/out/errors/native/ios/" 2>/dev/null | tr '\n' ' '; echo
echo "done $(date +%T)"
