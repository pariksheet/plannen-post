#!/usr/bin/env bash
# Render an HTML edition to a full-page PNG with local headless Chrome.
# This is the plannen-post "render capability" — wire it in ~/.post/profile.yaml:
#
#   render:
#     via: shell
#     command: "/Users/<you>/Music/plannen-post/scripts/render-png.sh {in} {out}"
#
# Usage: render-png.sh <input.html> <output.png>
# Deps: Google Chrome (or Chromium/Edge) + node/npm. puppeteer-core is installed
# once into ~/.post/render and reused.

set -euo pipefail

IN="${1:?usage: render-png.sh <input.html> <output.png>}"
OUT="${2:?usage: render-png.sh <input.html> <output.png>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOT="$SCRIPT_DIR/render-shot.js"
RENDER_DIR="$HOME/.post/render"
mkdir -p "$RENDER_DIR"

# One-time install of puppeteer-core into a stable dir (no bundled Chromium).
if [[ ! -d "$RENDER_DIR/node_modules/puppeteer-core" ]]; then
  ( cd "$RENDER_DIR" && npm init -y >/dev/null 2>&1 && npm i puppeteer-core >/dev/null 2>&1 )
fi

# Detect a local Chrome-family browser.
CHROME=""
for c in \
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  "/Applications/Chromium.app/Contents/MacOS/Chromium" \
  "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  "$(command -v google-chrome 2>/dev/null || true)" \
  "$(command -v chromium 2>/dev/null || true)"; do
  if [[ -n "$c" && -x "$c" ]]; then CHROME="$c"; break; fi
done
if [[ -z "$CHROME" ]]; then
  echo "render-png: no Chrome/Chromium/Edge found" >&2
  exit 3
fi

NODE_PATH="$RENDER_DIR/node_modules" CHROME_PATH="$CHROME" node "$SHOT" "$IN" "$OUT"
