#!/usr/bin/env bash
# install.sh — claude-usage-bar installer
#
# Usage (from clone):  bash install.sh
# Usage (one-liner):   bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/Claude-Code-Usage-Bar/main/install.sh)

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/ChrisPiz/Claude-Code-Usage-Bar/main"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
JQ="/usr/bin/jq"

APP_NAME="ClaudeUsageBar"
INSTALL_DIR="$HOME/Applications"
APP_DEST="$INSTALL_DIR/$APP_NAME.app"

SWIFTBAR_DIR="$HOME/Documents/SwiftBar"
SWIFTBAR_LIBRARY="$HOME/Library/Application Support/SwiftBar"
XBAR_DIR="$HOME/Library/Application Support/xbar/plugins"

# ── Resolve script location ──────────────────────────────────────────────────
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  LOCAL_HOOKS="$SCRIPT_DIR/hooks"
  LOCAL_SRC="$SCRIPT_DIR/src"
  LOCAL_BUILD="$SCRIPT_DIR/build.sh"
else
  LOCAL_HOOKS=""
  LOCAL_SRC=""
  LOCAL_BUILD=""
fi

echo "claude-usage-bar installer"
echo ""

# ── Preflight checks ─────────────────────────────────────────────────────────
if ! command -v "$JQ" &>/dev/null && ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi
JQ=$(command -v jq)

if [ ! -f "$SETTINGS" ]; then
  echo "Error: ~/.claude/settings.json not found. Is Claude Code installed?"
  exit 1
fi

# ── Install hook scripts to ~/.claude/hooks/ ─────────────────────────────────
mkdir -p "$HOOKS_DEST"

install_script() {
  local name="$1"
  local dest="$HOOKS_DEST/$name"

  if [ -n "$LOCAL_HOOKS" ] && [ -f "$LOCAL_HOOKS/$name" ]; then
    cp "$LOCAL_HOOKS/$name" "$dest"
  else
    curl -fsSL "$REPO_RAW/hooks/$name" -o "$dest"
  fi
  chmod +x "$dest"
}

echo "Installing scripts to $HOOKS_DEST ..."
install_script "usage-statusline.sh"
install_script "claude-usage-bar.1m.sh"
echo "  ✓ usage-statusline.sh"
echo "  ✓ claude-usage-bar.1m.sh"

# ── Wire settings.json ───────────────────────────────────────────────────────
HOOK_PATH="$HOOKS_DEST/usage-statusline.sh"
HOOK_CMD="bash \"$HOOK_PATH\""

echo ""
echo "Configuring statusLine in settings.json ..."

CURRENT_CMD=$("$JQ" -r '.statusLine.command // .statusLine // empty' "$SETTINGS" 2>/dev/null || echo "")

if [ -z "$CURRENT_CMD" ]; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '. + {statusLine: {type: "command", command: $cmd}}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine configured"

elif echo "$CURRENT_CMD" | grep -q "usage-statusline.sh"; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine.command = $cmd' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ statusLine updated (already installed)"

elif echo "$CURRENT_CMD" | grep -q "caveman-statusline.sh"; then
  "$JQ" --arg cmd "$HOOK_CMD" \
    '.statusLine = {type: "command", command: $cmd}' \
    "$SETTINGS" > /tmp/claude-settings.tmp && mv /tmp/claude-settings.tmp "$SETTINGS"
  echo "  ✓ Replaced caveman statusLine (usage-statusline.sh includes caveman badge)"

else
  echo "  ⚠  Custom statusLine detected — NOT overwritten."
  echo ""
  echo "  Add this to your existing statusline script to include usage badges:"
  echo ""
  echo "    # claude-usage-bar integration"
  echo "    source \"$HOOK_PATH\""
  echo ""
  echo "  Or see README for manual merge instructions."
fi

# ── Build and launch native menu bar app ────────────────────────────────────
echo ""

if [ "${SKIP_BUILD:-0}" = "1" ]; then
  echo "SKIP_BUILD=1 — skipping app build."
  if [ -d "$APP_DEST" ]; then
    pkill -x ClaudeUsageBar 2>/dev/null || true
    open "$APP_DEST"
    echo "  ✓ Launched existing $APP_DEST"
  else
    echo "  ⚠  $APP_DEST not found. Download from:"
    echo "  https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest"
  fi
else
  echo "Building ClaudeUsageBar.app ..."
  if ! command -v xcodebuild &>/dev/null; then
    echo "  ⚠  Xcode not found — skipping native app build."
    echo "  Install Xcode from the App Store, then run: bash build.sh"
    echo "  Or download a pre-built release from:"
    echo "  https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest"
  elif ! command -v xcodegen &>/dev/null; then
    echo "  ⚠  xcodegen not found — skipping native app build."
    echo "  Install with: brew install xcodegen"
    echo "  Then run: bash build.sh"
  else
    if [ -n "$LOCAL_BUILD" ] && [ -f "$LOCAL_BUILD" ]; then
      bash "$LOCAL_BUILD"
    else
      curl -fsSL "$REPO_RAW/build.sh" | bash
    fi

    if [ -d "$SCRIPT_DIR/dist/$APP_NAME.app" ]; then
      mkdir -p "$INSTALL_DIR"
      rm -rf "$APP_DEST"
      cp -R "$SCRIPT_DIR/dist/$APP_NAME.app" "$APP_DEST"
      pkill -x ClaudeUsageBar 2>/dev/null || true
      open "$APP_DEST"
      echo "  ✓ ClaudeUsageBar.app built and launched → $APP_DEST"
      echo "  ℹ  Add to Login Items: System Settings → General → Login Items"
    fi
  fi
fi  # end SKIP_BUILD check

# ── Install SwiftBar plugin (optional) ──────────────────────────────────────
PLUGIN_SRC="$HOOKS_DEST/claude-usage-bar.1m.sh"

if [ -d "$SWIFTBAR_DIR" ] || [ -d "$SWIFTBAR_LIBRARY" ]; then
  echo ""
  TARGET_DIR="$SWIFTBAR_DIR"
  [ ! -d "$TARGET_DIR" ] && TARGET_DIR="$SWIFTBAR_LIBRARY"
  mkdir -p "$TARGET_DIR"
  cp "$PLUGIN_SRC" "$TARGET_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ SwiftBar plugin also installed → $TARGET_DIR"
elif [ -d "$XBAR_DIR" ]; then
  echo ""
  cp "$PLUGIN_SRC" "$XBAR_DIR/claude-usage-bar.1m.sh"
  echo "  ✓ xbar plugin also installed → $XBAR_DIR"
fi

echo ""
echo "Done! Send a message in Claude Code to see the usage badges."
