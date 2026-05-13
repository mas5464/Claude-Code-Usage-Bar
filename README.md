Claude Code plan usage in your terminal statusline and macOS menu bar.

![screenshot](docs/screenshot.png)

```
5h:17%  7d:63% ← in your Claude Code terminal
```

---

## What it does

- **Terminal badge** — colored usage indicators in the Claude Code statusline after each message
- **Menu bar app** — native macOS menu bar app, live percentage with click-to-expand breakdown and reset times

Colors: 🟢 green `< 70%` · 🟠 orange `70–90%` · 🔴 red `≥ 90%`

The menu bar icon auto-tints for light/dark mode and the interface uses your macOS system language.

---

## Requirements

- macOS 13+
- [Claude Code](https://claude.ai/code) with a Pro or Team subscription
- `jq` — likely already installed (`which jq`), otherwise: `brew install jq`
- Xcode Command Line Tools — likely already installed (`xcode-select -p`), otherwise: `xcode-select --install`

---

## Install

### Option A — One-liner (recommended)

Compiles the app locally — no Gatekeeper issues, no extra permissions needed.

```bash
bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/install.sh)
```

Requires: `jq` + Xcode Command Line Tools (`xcode-select --install`, already present on most Macs).

The installer:
1. Copies scripts to `~/.claude/hooks/`
2. Adds `statusLine` to `~/.claude/settings.json`
3. Compiles and launches `ClaudeUsageBar.app` in `~/Applications/`

Then send any message in Claude Code — the badges appear after the first response.

### Option B — Pre-built binary

Download `ClaudeUsageBar.zip` from the [latest release](https://github.com/ChrisPiz/claude-usage-bar/releases/latest), unzip, move to `~/Applications/`, then:

```bash
# Remove Gatekeeper quarantine (required for unsigned apps downloaded from the web)
xattr -cr ~/Applications/ClaudeUsageBar.app
open ~/Applications/ClaudeUsageBar.app
```

You still need the hook script for the terminal badge and state file:

```bash
bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/install.sh)
```

Run it with `SKIP_BUILD=1` to skip the compile step if you already have the app:

```bash
SKIP_BUILD=1 bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/install.sh)
```

---

## Auto-start on login

Add the app to Login Items so it launches automatically:

**System Settings → General → Login Items → +** → select `~/Applications/ClaudeUsageBar.app`

---

## How it works

```
Claude Code → JSON via stdin → usage-statusline.sh ──→ ANSI badge (terminal)
                                        │
                                        └──→ ~/.claude/.claude-usage-state.json
                                                          │
                                       ClaudeUsageBar.app ──→ menu bar
```

After each message, Claude Code passes usage data to the `statusLine` script. That script formats the terminal badge and writes a state file. The menu bar app reads that file every 60 seconds.

---

## Caveman compatibility

If you use the [caveman](https://github.com/superpowers/caveman) Claude Code plugin, the caveman mode badge is automatically included in the statusline — no extra configuration needed.

```
[CAVEMAN:ULTRA]  5h:13%  7d:63%
```

---

## Custom statusline integration

If you already have a custom `statusLine` script, the installer won't overwrite it. Add this snippet to your existing script:

```bash
# claude-usage-bar usage badges
USAGE_HOOK="$HOME/.claude/hooks/usage-statusline.sh"
if [ -f "$USAGE_HOOK" ]; then
  usage_out=$(cat | "$USAGE_HOOK")
  printf '%s  %s\n' "$your_existing_output" "$usage_out"
fi
```

---

## SwiftBar / xbar (optional)

If you already use [SwiftBar](https://swiftbar.app) or [xbar](https://xbarapp.com), the installer also drops the plugin in your plugins folder automatically. Both the native app and the SwiftBar plugin can coexist.

Manual SwiftBar setup:
```bash
mkdir -p ~/Documents/SwiftBar
cp ~/.claude/hooks/claude-usage-bar.1m.sh ~/Documents/SwiftBar/
```

---

## Uninstall

```bash
bash ~/.claude/hooks/uninstall.sh
```

Or via curl:
```bash
bash <(curl -s https://raw.githubusercontent.com/ChrisPiz/claude-usage-bar/main/uninstall.sh)
```

---

## License

MIT
