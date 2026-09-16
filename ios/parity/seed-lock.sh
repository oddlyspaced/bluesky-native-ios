#!/bin/bash
# The shared seed lock for the parity captures (review finding A77).
#
# Source this file, then call `seed_lock_acquire` and `seed_lock_release`.
#
# The lock is a directory (`/tmp/bsky-seed.lock` by default). The Android captures take the
# same lock with `mkdir` and release it with `rmdir` (`android/parity/run-native.sh:32-35`,
# `run-pack.sh:42-47`, `capture-states.sh:24-36`), so the lock directory must stay empty.
# The holder's record therefore goes in a separate file, `<lock>.owner`, which holds
# "<pid> <host> <lock mtime at acquire>".
#
# A lock is broken only when one of these is true:
#   1. the owner record belongs to this lock (its recorded mtime matches the directory) and
#      the recorded process is gone. A live holder is never broken, whatever its age.
#   2. no owner record applies (an Android run, an older script, or a record left by an
#      earlier lock) and the lock is older than SEED_LOCK_STALE seconds. This staleness limit
#      is the second line of defence, not the first test.
#
# Environment:
#   SEED_LOCK        lock path            (default /tmp/bsky-seed.lock)
#   SEED_LOCK_STALE  staleness limit, s   (default 1200)
#   SEED_LOCK_WAIT   poll interval, s     (default 10)
SEED_LOCK=${SEED_LOCK:-/tmp/bsky-seed.lock}
SEED_LOCK_STALE=${SEED_LOCK_STALE:-1200}
SEED_LOCK_WAIT=${SEED_LOCK_WAIT:-10}

# Seconds since the lock directory was created, or 0 when it is gone.
seed_lock_age() {
  local mtime
  mtime=$(stat -f %m "$SEED_LOCK" 2>/dev/null) || return 0
  echo $(( $(date +%s) - mtime ))
}

seed_lock_break() {
  rm -f "$SEED_LOCK.owner" 2>/dev/null
  rmdir "$SEED_LOCK" 2>/dev/null
}

# Prints the holder pid when the owner record applies to the lock that is held now.
seed_lock_owner_pid() {
  local record pid stamp mtime
  record=$(cat "$SEED_LOCK.owner" 2>/dev/null) || return 1
  pid=$(echo "$record" | awk '{print $1}')
  stamp=$(echo "$record" | awk '{print $3}')
  mtime=$(stat -f %m "$SEED_LOCK" 2>/dev/null) || return 1
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  case "$stamp" in ''|*[!0-9]*) return 1 ;; esac
  # A record written for an earlier lock (another holder took the directory after it) does
  # not describe the holder now, so it must not be used to break the lock.
  [ $(( stamp > mtime ? stamp - mtime : mtime - stamp )) -le 5 ] || return 1
  echo "$pid"
}

seed_lock_acquire() {
  local pid age
  while ! mkdir "$SEED_LOCK" 2>/dev/null; do
    if pid=$(seed_lock_owner_pid); then
      if kill -0 "$pid" 2>/dev/null; then
        echo "waiting for the seed lock, held by pid $pid"
      else
        echo "seed lock: holder pid $pid is gone, breaking the lock"
        seed_lock_break
        continue
      fi
    else
      age=$(seed_lock_age)
      if [ "${age:-0}" -gt "$SEED_LOCK_STALE" ]; then
        echo "seed lock: no holder recorded and the lock is ${age}s old, breaking it"
        seed_lock_break
        continue
      fi
      echo "waiting for the seed lock (no holder recorded, ${age}s old)"
    fi
    sleep "$SEED_LOCK_WAIT"
  done
  printf '%s %s %s\n' "$$" "$(hostname -s)" "$(stat -f %m "$SEED_LOCK")" > "$SEED_LOCK.owner"
}

seed_lock_release() {
  rm -f "$SEED_LOCK.owner" 2>/dev/null
  rmdir "$SEED_LOCK" 2>/dev/null
}
