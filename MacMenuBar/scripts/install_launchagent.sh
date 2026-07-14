#!/bin/bash
# Install the MCPMenuBar LaunchAgent so the menu-bar app starts at login.
set -e

PLIST_NAME="com.curnutte.mcp-computer-use.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_PLIST="${SCRIPT_DIR}/../LaunchAgent/${PLIST_NAME}"
DEST_DIR="${HOME}/Library/LaunchAgents"
DEST_PLIST="${DEST_DIR}/${PLIST_NAME}"

if [[ ! -f "$SRC_PLIST" ]]; then
    echo "Error: LaunchAgent plist not found at $SRC_PLIST" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
mkdir -p "${HOME}/.mcp-computer-use/logs"

cp "$SRC_PLIST" "$DEST_PLIST"
chmod 644 "$DEST_PLIST"

# Unload first in case an older version is already loaded.
launchctl unload "$DEST_PLIST" 2>/dev/null || true
launchctl load -w "$DEST_PLIST"

echo "LaunchAgent installed and loaded: $DEST_PLIST"
