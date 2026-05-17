# macOS Widget — Design Spec
**Date:** 2026-05-17
**Status:** Approved

---

## Overview

Add a native macOS WidgetKit widget to ClaudeUsageBar that shows Claude Code usage (session and weekly) and system status directly on the macOS desktop or in Notification Center. Supports Medium (4×2) and Large (4×4) sizes.

---

## Architecture

### Project Structure

Convert from a `swiftc`-only build to a proper Xcode project with two targets:

| Target | Type | Source |
|---|---|---|
| `ClaudeUsageBar` | Main app (menu bar) | `src/ClaudeUsageBar.swift` (unchanged) |
| `ClaudeUsageBarWidget` | Widget Extension | `widget/ClaudeUsageBarWidget.swift` |

The widget extension is embedded inside the main app bundle at:
`ClaudeUsageBar.app/Contents/PlugIns/ClaudeUsageBarWidget.appex`

### Data Flow

No App Groups required. The app is not sandboxed today (`com.apple.security.app-sandbox` is not present), and the widget extension must also be built **without** that entitlement — widget extensions do not inherit the host app's sandbox state automatically. As long as neither target has the sandbox entitlement, the widget extension can read `~/.claude/.claude-usage-state.json` directly — the same file already written by the Claude Code `usage-statusline.sh` hook after every message.

**Critical:** Do not add `com.apple.security.app-sandbox` to either target's entitlements file. If it appears (e.g. from Xcode defaults), remove it explicitly.

```
Claude Code message
  → usage-statusline.sh hook
    → writes ~/.claude/.claude-usage-state.json
      → Widget TimelineProvider reads file
        → Widget renders updated data
```

The main app additionally calls `WidgetCenter.shared.reloadAllTimelines()` inside its existing `update()` method whenever it detects fresh state (it polls every 60s), pushing immediate widget refreshes without waiting for the scheduled timeline.

---

## Widget Sizes

### Medium (4×2) — Usage Only

Layout: two-column, session left / weekly right, separated by a vertical divider.

Each column contains:
- Label: `5H SESSION` / `7D WEEKLY` (10pt, gray, uppercase)
- Percentage: large bold number (34pt), color-coded green/orange/red using existing thresholds (< 70% green, < 90% orange, ≥ 90% red)
- Progress bar: 3px, color-matched to percentage
- Reset time: small gray text — "in 2h 14m" (session) or "Mon at 9:00 AM" (weekly)

Header row: Claude Code icon + "Claude Code" label (left), last-updated time (right).

### Large (4×4) — Usage + System Status

Layout: stacked vertically.

Top section (usage):
- Same session and weekly rows as medium, but stacked (not side by side)
- Each row: label + percentage (right-aligned, 30pt) + full-width 5px progress bar + reset time

Middle: 1px separator

Bottom section (system status):
- Section label: `SYSTEM STATUS` (10pt, gray, uppercase)
- One row per component (Claude Code, Claude API): colored dot + name + status text
- Dot colors: green = operational, yellow = degraded, red = outage/incident

Footer: "Updated HH:MM" right-aligned (10pt, dark gray).

---

## Color Thresholds

Consistent with the existing menu bar app and terminal statusline:

| Usage | Color |
|---|---|
| < 70% | Green (`#4cd964`) |
| 70–89% | Orange (`#ff9500`) |
| ≥ 90% | Red (`#ff3b30`) |

---

## Timeline & Refresh

- `TimelineProvider.getTimeline()` reads the state file and returns the current entry plus schedules the next refresh in **15 minutes**
- The main app calls `WidgetCenter.shared.reloadAllTimelines()` whenever `update()` runs and detects changed state, providing near-real-time updates
- Placeholder state shown when state file is missing or empty: "No usage data yet — send a message in Claude Code"

---

## File Changes

### New files
```
ClaudeUsageBar.xcodeproj/           ← Xcode project (two targets)
widget/
  ClaudeUsageBarWidget.swift        ← TimelineProvider + SwiftUI Medium/Large views
  Info.plist                        ← Widget extension metadata
```

### Modified files
```
src/ClaudeUsageBar.swift            ← Add WidgetCenter.reloadAllTimelines() in update()
build.sh                            ← Replace swiftc with xcodebuild; output unchanged
```

### Unchanged files
```
src/IconGenerator.swift
hooks/usage-statusline.sh
hooks/claude-usage-bar.1m.sh
install.sh
uninstall.sh
```

---

## Build

`build.sh` updated to:
```bash
xcodebuild -project ClaudeUsageBar.xcodeproj \
           -scheme ClaudeUsageBar \
           -configuration Release \
           -derivedDataPath /tmp/ClaudeUsageBar_build \
           CONFIGURATION_BUILD_DIR="$DIST_DIR"
```

Output remains identical to current:
- `dist/ClaudeUsageBar.app` (now contains `PlugIns/ClaudeUsageBarWidget.appex`)
- `dist/ClaudeUsageBar.dmg`

Requires full Xcode (not just Command Line Tools) due to widget extension target.

---

## Out of Scope

- Small widget size
- iPad / iOS widget
- App Groups or iCloud sync
- Configuration intent (no user-configurable options in widget)
- Sonnet weekly limit row in widget (low information density for the space; covered by menu bar app)
