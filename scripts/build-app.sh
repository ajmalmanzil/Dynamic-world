#!/bin/zsh
# Builds DynamicIsland.app into ./build (release by default; pass "debug" for a debug build).
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/DynamicIsland"

APP="build/DynamicIsland.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DynamicIsland"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS privacy prompts (Calendar) attach to a stable identity.
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
