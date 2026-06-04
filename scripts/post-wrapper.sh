#!/usr/bin/env bash
# Wraps `claude -p "/post"` for unattended launchd runs.
#
#   - per-day idempotency guard: if today's edition already exists in memory/,
#     exit silently. This makes RunAtLoad safe — a boot/wake catch-up never
#     produces a duplicate edition, it only runs if today's post hasn't yet.
#   - atomic mkdir lock (no flock dependency, macOS-friendly)
#   - 7-day log rotation
#   - macOS notification on failure
#
# Designed for launchd; safe to run manually. Mirrors the plannen mailbox-sync
# wrapper pattern.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

POST_DIR="$HOME/.post"
MEM_DIR="$POST_DIR/memory"
LOG_DIR="$POST_DIR/logs"
LOG="$LOG_DIR/post.log"
ERR="$LOG_DIR/post.err"
LOCK_DIR="/tmp/plannen-post.lock.d"
TODAY="$(date +%F)"

mkdir -p "$LOG_DIR" "$MEM_DIR"

# 7-day log rotation.
find "$LOG_DIR" -type f -name 'post.*' -mtime +7 -delete 2>/dev/null || true

# --- per-day guard ---------------------------------------------------------
# If today's edition is already composed, this run is a no-op. This is what
# makes RunAtLoad (boot/wake catch-up) safe: it only fills in a MISSED day.
if [[ -f "$MEM_DIR/$TODAY.html" ]]; then
  echo "=== $(date -Iseconds) skip — $TODAY edition already exists ===" >> "$LOG"
  exit 0
fi

# --- concurrency lock ------------------------------------------------------
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0   # a run is already in flight
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

notify_failure() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"The Plannen Post\"" >/dev/null 2>&1 || true
}

echo "=== $(date -Iseconds) start ($TODAY) ===" >> "$LOG"

# plannen-post is a dev plugin loaded via --plugin-dir; the slash command needs
# the plugin namespace prefix. bypassPermissions: unattended run on the user's
# own machine using MCPs they already trust.
OUTPUT="$(claude -p \
  --plugin-dir "$REPO_ROOT" \
  --permission-mode bypassPermissions \
  "/post" \
  2>>"$ERR")"
EXIT=$?

echo "$OUTPUT" >> "$LOG"
echo "=== $(date -Iseconds) end exit=$EXIT ===" >> "$LOG"

if [[ "$EXIT" -ne 0 ]]; then
  notify_failure "Post run exited $EXIT — see ~/.post/logs/post.err"
fi
