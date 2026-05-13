Claude Code plan usage in your macOS menu bar.

Independent project. Not affiliated with, endorsed by, or sponsored by Anthropic, Claude, or Claude Code.

![screenshot](docs/screenshot.png)

## What it does

- **Menu bar app** — native macOS menu bar app with live percentage, click-to-expand breakdown, and reset times
- **Silent Claude Code integration** — reads Claude Code usage data after each message without adding text to your terminal

Colors: 🟢 green `< 70%` · 🟠 orange `70–90%` · 🔴 red `≥ 90%`

The menu bar icon auto-tints for light/dark mode and the interface uses your macOS system language.

---

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) with a Pro or Team subscription

---

## Install

### Download the DMG

Download `ClaudeUsageBar.dmg` from the [latest release](https://github.com/ChrisPiz/Claude-Code-Usage-Bar/releases/latest), open it, and drag `ClaudeUsageBar.app` to `Applications`.

Open the app once. On first launch it configures Claude Code automatically by adding this statusline command to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar\" --statusline"
  }
}
```

Restart Claude Code, then send any message. The command runs silently and updates the menu bar app from Claude Code's usage data.

If you already have a custom Claude Code `statusLine`, the app will not overwrite it.

Unsigned local builds may require right-click → Open. Public releases should be signed and notarized.

---

## Auto-start on login

Add the app to Login Items so it launches automatically:

**System Settings → General → Login Items → +** → select `/Applications/ClaudeUsageBar.app`

---

## How it works

```
Claude Code → JSON via stdin → ClaudeUsageBar --statusline ──→ ~/.claude/.claude-usage-state.json
                                                                      │
                                                   ClaudeUsageBar.app ──→ menu bar
```

After each message, Claude Code passes usage data to the app's `--statusline` mode. It writes a state file without printing anything in the terminal. The menu bar app reads that file every 60 seconds.

---

## Caveman compatibility

If you use the [caveman](https://github.com/superpowers/caveman) Claude Code plugin, ClaudeUsageBar leaves your existing statusline alone when it detects a custom configuration.

---

## Custom statusline integration

If you already have a custom `statusLine` script, the app won't overwrite it. Add this snippet to your existing script:

```bash
# claude-usage-bar state update
USAGE_BAR="/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar"
if [ -x "$USAGE_BAR" ]; then
  cat | "$USAGE_BAR" --statusline >/dev/null
  printf '%s\n' "$your_existing_output"
fi
```

---

## Building a DMG

For maintainers:

```bash
bash build.sh
```

The build writes:

- `dist/ClaudeUsageBar.app`
- `dist/ClaudeUsageBar.dmg`

Set `CODE_SIGN_IDENTITY` to sign with a Developer ID certificate. Without it, the app is ad-hoc signed for local testing.

---

## Uninstall

Quit `ClaudeUsageBar`, delete it from `Applications`, and remove the `statusLine` entry from `~/.claude/settings.json`.

---

## License

MIT
