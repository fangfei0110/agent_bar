#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/debug"
BINARY="$BUILD_DIR/AgentVersionBarApp"
BUNDLE_ROOT="$ROOT/.run/AgentVersionBar.app"
BUNDLE_MACOS="$BUNDLE_ROOT/Contents/MacOS"
BUNDLE_RESOURCES="$BUNDLE_ROOT/Contents/Resources"
PLIST="$ROOT/AppBundle/Info.plist"
ICON="$ROOT/AppBundle/AppIcon.icns"

env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
    swift build -c debug --product AgentVersionBarApp --package-path "$ROOT"

mkdir -p "$BUNDLE_MACOS" "$BUNDLE_RESOURCES"
cp "$BINARY" "$BUNDLE_MACOS/AgentVersionBarApp"
cp "$PLIST" "$BUNDLE_ROOT/Contents/Info.plist"
cp -R "$ROOT/Sources/AgentVersionBarApp/Resources/ProviderIcons" "$BUNDLE_RESOURCES/"
if [[ -f "$ICON" ]]; then
    cp "$ICON" "$BUNDLE_RESOURCES/AppIcon.icns"
fi

# Restart the app so the running menu bar process picks up the new binary.
pkill -f "$BUNDLE_MACOS/AgentVersionBarApp" || true
open -n "$BUNDLE_ROOT"
