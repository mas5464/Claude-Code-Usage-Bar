#!/usr/bin/env bash
# build.sh — compiles ClaudeUsageBar.app from source
# Requires: Xcode Command Line Tools (xcode-select --install)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClaudeUsageBar"
INSTALL_DIR="$HOME/Applications"
APP_DEST="$INSTALL_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DEST/Contents/MacOS"
BUILD_TMP="/tmp/${APP_NAME}_build"

echo "Building $APP_NAME ..."

# Preflight
if ! command -v swiftc &>/dev/null; then
  echo "Error: swiftc not found. Install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

# Prepare
rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
mkdir -p "$MACOS_DIR"

# Compile
swiftc "$SCRIPT_DIR/src/ClaudeUsageBar.swift" \
  -o "$BUILD_TMP/$APP_NAME" \
  -O \
  2>&1 | grep -v "^$" || true

cp "$BUILD_TMP/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Info.plist
mkdir -p "$APP_DEST/Contents"
cat > "$APP_DEST/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>           <string>ClaudeUsageBar</string>
  <key>CFBundleIdentifier</key>     <string>com.chrispiz.claude-usage-bar</string>
  <key>CFBundleVersion</key>        <string>1.0</string>
  <key>CFBundleExecutable</key>     <string>ClaudeUsageBar</string>
  <key>CFBundlePackageType</key>    <string>APPL</string>
  <key>LSUIElement</key>            <true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key> <string>13.0</string>
</dict>
</plist>
PLIST

rm -rf "$BUILD_TMP"

echo "  ✓ Built → $APP_DEST"
echo ""
echo "To launch:  open \"$APP_DEST\""
echo "To autostart: add it to System Settings → General → Login Items"
