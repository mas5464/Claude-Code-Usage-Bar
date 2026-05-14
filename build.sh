#!/usr/bin/env bash
# build.sh — compiles ClaudeUsageBar.app and packages a DMG
# Requires: Xcode Command Line Tools (xcode-select --install)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClaudeUsageBar"
DIST_DIR="$SCRIPT_DIR/dist"
APP_DEST="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DEST/Contents/MacOS"
RESOURCES_DIR="$APP_DEST/Contents/Resources"
BUILD_TMP="/tmp/${APP_NAME}_build"
DMG_STAGING="/tmp/${APP_NAME}_dmg"
DMG_DEST="$DIST_DIR/$APP_NAME.dmg"
ICONSET_DIR="$BUILD_TMP/$APP_NAME.iconset"

echo "Building $APP_NAME ..."

# Preflight
if ! command -v swiftc &>/dev/null; then
  echo "Error: swiftc not found. Install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi
if ! command -v iconutil &>/dev/null; then
  echo "Error: iconutil not found. Install Xcode Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

# Prepare
rm -rf "$BUILD_TMP" "$APP_DEST" "$DMG_STAGING"
mkdir -p "$BUILD_TMP" "$DIST_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Compile
swiftc "$SCRIPT_DIR/src/ClaudeUsageBar.swift" \
  -o "$BUILD_TMP/$APP_NAME" \
  -O

cp "$BUILD_TMP/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Build the macOS bundle icon from the same Claude Code mark used in the menu bar.
cp "$SCRIPT_DIR/Resources/claudecode-color.svg" "$RESOURCES_DIR/claudecode-color.svg"
swiftc "$SCRIPT_DIR/src/IconGenerator.swift" \
  -o "$BUILD_TMP/IconGenerator" \
  -O
"$BUILD_TMP/IconGenerator" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$APP_NAME.icns"

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
  <key>CFBundleIconFile</key>       <string>ClaudeUsageBar</string>
  <key>CFBundlePackageType</key>    <string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key>            <true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key> <string>13.0</string>
</dict>
</plist>
PLIST

if command -v codesign &>/dev/null; then
  codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$APP_DEST" >/dev/null
fi

rm -rf "$BUILD_TMP"

echo "  ✓ Built → $APP_DEST"
echo ""

if command -v hdiutil &>/dev/null; then
  echo "Packaging DMG ..."
  mkdir -p "$DMG_STAGING"
  cp -R "$APP_DEST" "$DMG_STAGING/"
  ln -s /Applications "$DMG_STAGING/Applications"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_DEST" >/dev/null
  rm -rf "$DMG_STAGING"
  echo "  ✓ DMG → $DMG_DEST"
else
  echo "  ⚠ hdiutil not found; DMG was not created."
fi

echo ""
echo "Release artifact: $DMG_DEST"
