#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/debug"
BINARY="$BUILD_DIR/AgentVersionBarApp"
BUNDLE_ROOT="$ROOT/.run/AgentVersionBar.app"
BUNDLE_MACOS="$BUNDLE_ROOT/Contents/MacOS"
BUNDLE_RESOURCES="$BUNDLE_ROOT/Contents/Resources"
PLIST="$ROOT/AppBundle/Info.plist"

env CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
    SWIFTPM_MODULECACHE_OVERRIDE=/tmp/swiftpm-module-cache \
    swift build -c debug --product AgentVersionBarApp --package-path "$ROOT"

mkdir -p "$BUNDLE_MACOS" "$BUNDLE_RESOURCES"
cp "$BINARY" "$BUNDLE_MACOS/AgentVersionBarApp"
cp "$PLIST" "$BUNDLE_ROOT/Contents/Info.plist"

open "$BUNDLE_ROOT"
