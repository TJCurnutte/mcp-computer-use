#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

swift build -c release

mkdir -p build/Reflex.app/Contents/MacOS
cp .build/release/MCPMenuBar build/Reflex.app/Contents/MacOS/MCPMenuBar
chmod +x build/Reflex.app/Contents/MacOS/MCPMenuBar

cp Info.plist build/Reflex.app/Contents/Info.plist
printf 'APPL????' > build/Reflex.app/Contents/PkgInfo

mkdir -p build/Reflex.app/Contents/Resources/LaunchAgent
cp ../LaunchAgent/com.curnutte.mcp-computer-use.plist build/Reflex.app/Contents/Resources/LaunchAgent/

codesign -s - --force --deep build/Reflex.app

echo "Built: $SCRIPT_DIR/build/Reflex.app"
