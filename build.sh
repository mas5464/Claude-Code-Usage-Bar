#!/usr/bin/env bash
# build.sh — compiles ClaudeUsageBar.app (with widget) and packages a DMG
# Requires: Xcode (not just CLT) + xcodegen (brew install xcodegen)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ClaudeUsageBar"
DIST_DIR="$SCRIPT_DIR/dist"
APP_DEST="$DIST_DIR/$APP_NAME.app"
BUILD_TMP="/tmp/${APP_NAME}_xcode"
DMG_STAGING="/tmp/${APP_NAME}_dmg"
DMG_DEST="$DIST_DIR/$APP_NAME.dmg"

echo "Building $APP_NAME ..."

# Preflight
if ! command -v xcodebuild &>/dev/null; then
  echo "Error: xcodebuild not found. Install Xcode from the App Store."
  exit 1
fi
if ! command -v xcodegen &>/dev/null; then
  echo "Error: xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

# Prepare
rm -rf "$BUILD_TMP" "$APP_DEST" "$DMG_STAGING"
mkdir -p "$DIST_DIR" "$BUILD_TMP"

# Generate app icon (requires display; do this outside Xcode build phase)
ICON_TMP="$BUILD_TMP/icon_prep"
ICONSET_DIR="$ICON_TMP/ClaudeUsageBar.iconset"
mkdir -p "$ICON_TMP"
swiftc "$SCRIPT_DIR/src/IconGenerator.swift" -o "$ICON_TMP/IconGenerator" -O
"$ICON_TMP/IconGenerator" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$SCRIPT_DIR/Resources/ClaudeUsageBar.icns"

# (Re)generate Xcode project from project.yml
xcodegen generate --quiet

# Build
xcodebuild \
  -project "$SCRIPT_DIR/ClaudeUsageBar.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_TMP" \
  clean build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  | grep -E "^(error:|warning:|Build succeeded|.*ClaudeUsageBar.*)" || true

BUILT_APP="$BUILD_TMP/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$BUILT_APP" ]; then
  echo "Error: build output not found at $BUILT_APP"
  exit 1
fi

cp -R "$BUILT_APP" "$APP_DEST"

if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DEST" >/dev/null
else
  codesign --force --deep --sign "-" "$APP_DEST" >/dev/null
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
