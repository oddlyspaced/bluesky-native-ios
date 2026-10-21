#!/bin/bash
# Publishes one platform's port to its public repository.
#
# This working tree holds both ports and their shared evidence. Each public repository holds one
# platform: its own source, the shared `parity/`, `plan/` and `reviews/` that apply to it, and a
# LICENSE that exists only there. The first push was done by hand and could not be repeated, so
# the rule is written down here instead.
#
# Usage: tools/publish-port.sh <android|ios> [-m "<commit subject>"] [--dry-run]
#
# What goes in a platform's repository: every tracked file in this tree, less
#   * the other platform's directory;
#   * `.gitignore`, which describes this tree and not that one;
#   * `parity/baseline/rn/<other>-*`, the other platform's React Native baselines;
#   * `reviews/*-<other>-*`, the other platform's reviews;
#   * `README.md`, which each public repository owns: they are written for a reader who arrived
#     at one platform, name the other repository, and differ from each other and from the one
#     here. Edit them in place in the public repository.
# A file the public repository has and this rule does not produce is removed there, except the
# files it owns: LICENSE and README.md. The published history is its own, so this adds a commit
# on top of it rather than rewriting it.
#
# Nothing is pushed until the tree is checked for an absolute home directory, which is what leaked
# into the evidence once before (commit "Take this repository's home directory out of its
# evidence"). A hit fails the run and pushes nothing.
set -euo pipefail

PLATFORM=${1:?platform: android or ios}
shift || true
SUBJECT=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    -m) SUBJECT=${2:?message}; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$PLATFORM" in
  android) OTHER=ios ;;
  ios) OTHER=android ;;
  *) echo "platform must be android or ios" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE="git@github.com:oddlyspaced/bluesky-native-$PLATFORM.git"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cd "$HERE"
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR this tree has uncommitted changes. Commit them first, so the public repository" >&2
  echo "ERROR records the same state this one does." >&2
  exit 1
fi
LOCAL_HEAD=$(git rev-parse --short HEAD)
LOCAL_SUBJECT=$(git log -1 --pretty=%s)
[ -n "$SUBJECT" ] || SUBJECT="$LOCAL_SUBJECT"

# The file list, by the rule above.
git ls-files \
  | grep -v "^$OTHER/" \
  | grep -v '^\.gitignore$' \
  | grep -v "^parity/baseline/rn/$OTHER-" \
  | grep -v "^reviews/.*-$OTHER-" \
  | grep -v '^README\.md$' \
  | sort > "$WORK/include.txt"
echo "publishing $(wc -l < "$WORK/include.txt" | tr -d ' ') files to bluesky-native-$PLATFORM"

git clone -q "$REMOTE" "$WORK/pub"
cd "$WORK/pub"
# Drop everything tracked but the files the public repository owns, then lay the chosen files
# down: a file this tree no longer has disappears there too, instead of lingering.
git ls-files | grep -vE '^(LICENSE|README\.md)$' | while read -r f; do rm -f "$f"; done
find . -type d -empty -not -path './.git/*' -delete 2>/dev/null || true
while read -r f; do
  mkdir -p "$(dirname "$f")"
  cp "$HERE/$f" "$f"
done < "$WORK/include.txt"

if grep -rIl --exclude-dir=.git "/Users/$(whoami)" . >/dev/null 2>&1; then
  echo "ERROR an absolute home directory is in the files to publish:" >&2
  grep -rIl --exclude-dir=.git "/Users/$(whoami)" . | head -20 >&2
  echo "ERROR nothing pushed. Make the paths relative and run again." >&2
  exit 1
fi
echo "home-directory check: clean"

git add -A
if git diff --cached --quiet; then
  echo "bluesky-native-$PLATFORM is already up to date; nothing to push"
  exit 0
fi
git diff --cached --stat

if [ "$DRY_RUN" = 1 ]; then
  echo "--dry-run: not committing or pushing"
  exit 0
fi

git commit -q -m "$SUBJECT" -m "Published from the development tree at $LOCAL_HEAD." \
  -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01VyNuX6QzkHTdnGfBumeodk"
git push -q origin HEAD:main
echo "pushed $(git rev-parse --short HEAD) to bluesky-native-$PLATFORM"
