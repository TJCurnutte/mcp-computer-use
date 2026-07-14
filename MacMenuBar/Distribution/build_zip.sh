#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/../MCPMenuBar/build"
APP_DIR_ABS="$(cd "$APP_DIR" && pwd)"
APP_PATH="$APP_DIR_ABS/MCPMenuBar.app"
ZIP_PATH="$APP_DIR_ABS/MCPMenuBar.zip"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run MCPMenuBar/build_app.sh first." >&2
    exit 1
fi

cd "$APP_DIR_ABS"
rm -f "$ZIP_PATH"

# -y stores symlinks as symlinks instead of resolving them
zip -ry "$ZIP_PATH" MCPMenuBar.app

echo "Built: $ZIP_PATH"
