#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/../MCPMenuBar/build"
APP_DIR_ABS="$(cd "$APP_DIR" && pwd)"
APP_PATH="$APP_DIR_ABS/Reflex.app"
OUTPUT_DMG="$APP_DIR_ABS/Reflex.dmg"
VOLNAME="Reflex"
BACKGROUND_IMG="$SCRIPT_DIR/background.png"
INSTRUCTIONS="$SCRIPT_DIR/Instructions.txt"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run MacMenuBar/MCPMenuBar/build_app.sh first." >&2
    exit 1
fi

if [[ ! -f "$BACKGROUND_IMG" ]]; then
    echo "Error: background image not found at $BACKGROUND_IMG" >&2
    exit 1
fi

# Size of the .app plus a comfortable margin for the DMG filesystem.
SIZE=$(du -sm "$APP_PATH" | cut -f1)
SIZE=$((SIZE + 20))

TMP_DIR=$(mktemp -d)
TMP_DMG="$TMP_DIR/temp.dmg"
DEV=""
MOUNTPOINT=""

cleanup() {
    if [[ -n "$DEV" ]]; then
        hdiutil detach "$DEV" -force -quiet >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Make sure any previous transient mount of the same name is gone.
hdiutil detach "/Volumes/$VOLNAME" -force -quiet >/dev/null 2>&1 || true

# Create a read/write DMG.
hdiutil create -size "${SIZE}m" -fs HFS+ -volname "$VOLNAME" -type UDIF -o "$TMP_DMG" >/dev/null

# Attach and determine the mount point.
OUT=$(hdiutil attach "$TMP_DMG" -noverify 2>&1)
DEV=$(echo "$OUT" | tail -1 | awk '{print $1}')

# Give the mount a moment to settle, then find where it mounted.
sleep 0.5
MOUNTPOINT=$(mount | grep "on /Volumes/$VOLNAME " | awk '{print $3}' | head -1)

if [[ -z "$MOUNTPOINT" ]]; then
    echo "Error: could not determine mount point for $VOLNAME" >&2
    exit 1
fi

# Copy the app and create the Applications alias.
cp -R "$APP_PATH" "$MOUNTPOINT/Reflex.app"
ln -s /Applications "$MOUNTPOINT/Applications"

# Install the background image used by the DMG window.
mkdir -p "$MOUNTPOINT/.background"
cp "$BACKGROUND_IMG" "$MOUNTPOINT/.background/background.png"

# Try to configure the DMG window layout with Finder. If this is running in a
# non-GUI environment the AppleScript may not complete, in which case we fall
# back to a plain text instructions file.
TIMEOUT=${MCP_MENUBAR_BUILD_TIMEOUT:-60}
LAYOUT_OK=false
if command -v osascript >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    if python3 - "$VOLNAME" "$MOUNTPOINT" "$TIMEOUT" <<'PY'
import os, subprocess, sys, time
volname, mountpoint, timeout = sys.argv[1], sys.argv[2], int(sys.argv[3])
script = '''tell application "Finder"
    tell disk "''' + volname + '''"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set text size of theViewOptions to 14
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "Reflex.app" of container window to {120, 200}
        set position of item "Applications" of container window to {420, 200}
        update
        close
    end tell
end tell'''
try:
    subprocess.run(['osascript', '-e', script], check=True, timeout=timeout)
    print('LAYOUT_OK')
except Exception as e:
    print('LAYOUT_FAILED:', e)
    sys.exit(1)
PY
    then
        LAYOUT_OK=true
    fi
fi

if [[ "$LAYOUT_OK" != true ]]; then
    echo "Warning: could not configure DMG window layout; adding instructions file." >&2
    rm -f "$MOUNTPOINT/.DS_Store"
    cp "$INSTRUCTIONS" "$MOUNTPOINT/Instructions.txt"
fi

# Hide the .background folder and any .DS_Store from the user.
chflags hidden "$MOUNTPOINT/.background" >/dev/null 2>&1 || true
if [[ -f "$MOUNTPOINT/.DS_Store" ]]; then
    chflags hidden "$MOUNTPOINT/.DS_Store" >/dev/null 2>&1 || true
fi

# Detach the read/write image.
hdiutil detach "$DEV" -force -quiet >/dev/null

# Compress to a read-only, zlib-compressed DMG.
rm -f "$OUTPUT_DMG"
hdiutil convert "$TMP_DMG" -format UDZO -o "$OUTPUT_DMG" -ov >/dev/null

# Attempt to internet-enable the DMG. This verb is not present in modern macOS
# versions, so we silently skip if it is not available.
if hdiutil internet-enable -yes "$OUTPUT_DMG" >/dev/null 2>&1; then
    echo "Internet-enabled: $OUTPUT_DMG"
fi

echo "Built: $OUTPUT_DMG"
