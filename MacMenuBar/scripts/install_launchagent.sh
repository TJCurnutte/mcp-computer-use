#!/bin/bash
# Install the Reflex LaunchAgent so the menu-bar app starts at login.
# Safe to re-run; no sudo is required.
set -euo pipefail

PLIST_NAME="com.curnutte.mcp-computer-use.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_PLIST="${SCRIPT_DIR}/../LaunchAgent/${PLIST_NAME}"
DEST_DIR="${HOME}/Library/LaunchAgents"
DEST_PLIST="${DEST_DIR}/${PLIST_NAME}"
APP_PATH="/Applications/Reflex.app"

echo "==> Installing Reflex LaunchAgent..."

if [[ ! -f "$SRC_PLIST" ]]; then
    echo "Error: LaunchAgent plist not found at $SRC_PLIST" >&2
    exit 1
fi

# The LaunchAgent only makes sense if the app is in /Applications. Warn but
# continue, because the user may be installing before the drag step.
if [[ ! -d "$APP_PATH" ]]; then
    echo "Warning: $APP_PATH not found. The LaunchAgent will be installed, but it" >&2
    echo "         will fail to run until the app is moved to /Applications." >&2
fi

mkdir -p "$DEST_DIR" || {
    echo "Error: Could not create $DEST_DIR" >&2
    exit 1
}

mkdir -p "${HOME}/.mcp-computer-use/logs" || {
    echo "Error: Could not create ~/.mcp-computer-use/logs" >&2
    exit 1
}

# Expand the __HOME__ placeholder so launchd gets absolute log paths.
sed -e "s|__HOME__|${HOME}|g" "$SRC_PLIST" > "$DEST_PLIST"
chmod 644 "$DEST_PLIST"

# Unload first in case an older version is already loaded.
launchctl unload "$DEST_PLIST" 2>/dev/null || true

if ! launchctl load -w "$DEST_PLIST"; then
    echo "Error: launchctl load failed for $DEST_PLIST" >&2
    exit 1
fi

echo "==> LaunchAgent installed and loaded: $DEST_PLIST"
