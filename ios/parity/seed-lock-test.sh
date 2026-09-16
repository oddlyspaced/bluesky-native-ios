#!/bin/bash
# Tests seed-lock.sh against a fake lock in a temporary directory (review finding A77).
# It never touches the real lock: SEED_LOCK points into `mktemp -d`.
#
# Usage: ios/parity/seed-lock-test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export SEED_LOCK="$TMP/seed.lock"
export SEED_LOCK_WAIT=1
export SEED_LOCK_STALE=60
# shellcheck source=seed-lock.sh
. "$HERE/seed-lock.sh"

pass=0
fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok   $1"; pass=$((pass + 1))
  else echo "  FAIL $1: expected '$2', got '$3'"; fail=$((fail + 1)); fi
}

# Runs seed_lock_acquire in a subshell and reports "acquired" or "waited" after 3 s.
try_acquire() {
  ( seed_lock_acquire >"$TMP/log" 2>&1 && touch "$TMP/got" ) &
  local worker=$!
  local i
  for i in 1 2 3 4 5 6; do
    [ -f "$TMP/got" ] && break
    sleep 0.5
  done
  if [ -f "$TMP/got" ]; then
    wait "$worker" 2>/dev/null
    rm -f "$TMP/got"
    echo acquired
  else
    kill "$worker" 2>/dev/null
    wait "$worker" 2>/dev/null
    echo waited
  fi
}

echo "1 free lock"
check "acquires" acquired "$(try_acquire)"
check "owner file names this shell" "$$" "$(awk '{print $1}' "$SEED_LOCK.owner")"
check "lock directory is empty (the Android scripts rmdir it)" "" "$(ls -A "$SEED_LOCK")"
seed_lock_release
check "release removes the lock" "gone" "$([ -d "$SEED_LOCK" ] && echo here || echo gone)"
check "release removes the owner file" "gone" "$([ -f "$SEED_LOCK.owner" ] && echo here || echo gone)"

echo "2 holder is alive: the lock is not broken"
sleep 120 &
alive=$!
mkdir "$SEED_LOCK"
printf '%s %s %s\n' "$alive" "$(hostname -s)" "$(stat -f %m "$SEED_LOCK")" > "$SEED_LOCK.owner"
check "waits" waited "$(try_acquire)"
check "says who holds it" "yes" "$([ "$(grep -c "held by pid $alive" "$TMP/log")" -ge 1 ] && echo yes || echo no)"
kill "$alive" 2>/dev/null; wait "$alive" 2>/dev/null

echo "3 holder is alive but the lock is older than the staleness limit: still not broken"
touch -A -010000 "$SEED_LOCK"   # backdate the directory by one hour
sleep 120 &
alive=$!
printf '%s %s %s\n' "$alive" "$(hostname -s)" "$(stat -f %m "$SEED_LOCK")" > "$SEED_LOCK.owner"
check "waits" waited "$(try_acquire)"
kill "$alive" 2>/dev/null; wait "$alive" 2>/dev/null

echo "4 holder is gone: the lock is broken and taken"
sleep 0.1 &
dead=$!
wait "$dead" 2>/dev/null
printf '%s %s %s\n' "$dead" "$(hostname -s)" "$(stat -f %m "$SEED_LOCK")" > "$SEED_LOCK.owner"
check "acquires" acquired "$(try_acquire)"
check "reports the break" "yes" "$([ "$(grep -c "holder pid $dead is gone" "$TMP/log")" -ge 1 ] && echo yes || echo no)"
seed_lock_release

echo "5 foreign lock (no owner record, the Android scripts): fresh is kept, stale is broken"
mkdir "$SEED_LOCK"
check "fresh foreign lock waits" waited "$(try_acquire)"
touch -A -010000 "$SEED_LOCK"
check "stale foreign lock is broken" acquired "$(try_acquire)"
seed_lock_release

echo "6 owner record left by an earlier lock: it must not break a fresh lock"
mkdir "$SEED_LOCK"
sleep 0.1 &
dead=$!
wait "$dead" 2>/dev/null
# The record names a dead pid, but its stamp belongs to a lock taken an hour ago.
printf '%s %s %s\n' "$dead" "$(hostname -s)" "$(( $(date +%s) - 3600 ))" > "$SEED_LOCK.owner"
check "waits" waited "$(try_acquire)"
seed_lock_release

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
