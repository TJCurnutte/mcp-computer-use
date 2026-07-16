#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo -n cp -R "$SCRIPT_DIR/build/Reflex.app" /Applications/
