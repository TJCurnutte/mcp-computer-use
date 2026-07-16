#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/../MCPMenuBar/build"
APP_DIR_ABS="$(cd "$APP_DIR" && pwd)"
APP_PATH="$APP_DIR_ABS/Reflex.app"
ZIP_PATH="$APP_DIR_ABS/Reflex.zip"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Run MacMenuBar/MCPMenuBar/build_app.sh first." >&2
    exit 1
fi

cd "$APP_DIR_ABS"
rm -f "$ZIP_PATH"

# -y stores symlinks as symlinks instead of resolving them
zip -ry "$ZIP_PATH" Reflex.app

echo "Built: $ZIP_PATH"
