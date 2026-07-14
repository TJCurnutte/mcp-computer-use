#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

swift build -c release

mkdir -p build/MCPMenuBar.app/Contents/MacOS
cp .build/release/MCPMenuBar build/MCPMenuBar.app/Contents/MacOS/MCPMenuBar
chmod +x build/MCPMenuBar.app/Contents/MacOS/MCPMenuBar

cp Info.plist build/MCPMenuBar.app/Contents/Info.plist
printf 'APPL????' > build/MCPMenuBar.app/Contents/PkgInfo

mkdir -p build/MCPMenuBar.app/Contents/Resources/LaunchAgent
cp ../LaunchAgent/com.curnutte.mcp-computer-use.plist build/MCPMenuBar.app/Contents/Resources/LaunchAgent/

codesign -s - --force --deep build/MCPMenuBar.app

echo "Built: $SCRIPT_DIR/build/MCPMenuBar.app"
