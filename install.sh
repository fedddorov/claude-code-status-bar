#!/usr/bin/env bash
#
# Installer for the claude-code-status-bar status line.
# Copies statusline.sh into your Claude Code config dir and wires it up in
# settings.json without clobbering any other settings you already have.
#
set -euo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- dependency check ------------------------------------------------------
missing=()
for dep in jq awk sed; do
  command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Error: missing required dependencies: ${missing[*]}" >&2
  echo "Install them first (e.g. 'brew install jq' on macOS)." >&2
  exit 1
fi

# --- copy the script -------------------------------------------------------
mkdir -p "$CLAUDE_DIR"
cp "$SRC_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"
echo "✓ Installed statusline.sh -> $CLAUDE_DIR/statusline.sh"

# --- wire it into settings.json (preserving existing settings) -------------
SETTINGS="$CLAUDE_DIR/settings.json"
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Validate existing JSON before touching it.
if ! jq empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Error: $SETTINGS is not valid JSON. Aborting to avoid data loss." >&2
  exit 1
fi

backup="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$backup"

tmp="$(mktemp)"
jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline.sh"}' \
  "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ Updated $SETTINGS (backup at $backup)"
echo
echo "Done. Restart Claude Code (or start a new session) to see the status bar."
