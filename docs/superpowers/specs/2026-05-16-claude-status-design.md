# Claude Status Integration — Design Spec
Date: 2026-05-16

## Overview

Add Claude system status from `status.claude.com` to the ClaudeUsageBar macOS menu bar app. Shows live status for Claude Code and Claude API components, changes the menu bar icon when there's an active incident, and sends macOS push notifications for new incidents (with a menu toggle to disable).

---

## Architecture

### Data Models

Two new Codable structs decode the Statuspage API response. A non-Codable `ClaudeStatus` aggregates the filtered result and lives in memory on `AppDelegate`:

```swift
struct StatusComponent: Codable {
    let id: String
    let name: String
    let status: String  // "operational" | "degraded_performance" | "partial_outage" | "major_outage"
}

struct StatusIncident: Codable {
    let id: String
    let name: String
    let status: String  // "investigating" | "identified" | "monitoring" | "resolved"
}

struct ClaudeStatus {
    let components: [StatusComponent]   // filtered: Claude Code + Claude API only
    let incidents: [StatusIncident]     // active only (status != "resolved")
    let fetchedAt: Date
    var hasIssue: Bool {
        !incidents.isEmpty || components.contains { $0.status != "operational" }
    }
}
```

`ClaudeStatus` is **not persisted to disk**. In-memory cache is sufficient between 5-minute poll cycles. If the app starts cold, the first fetch completes before the menu is likely opened.

### API Endpoint

`GET https://status.claude.com/api/v2/summary.json`

Response contains `components[]` and `incidents[]` arrays. Filter strategy:
- **Components**: keep entries where `name` contains "Claude Code" or "Claude API"
- **Incidents**: keep entries where `status != "resolved"`

No authentication required. Public Statuspage API.

---

## Polling Strategy

A dedicated `statusTimer: Timer?` fires every **300 seconds** (5 minutes), independent of the existing 60-second usage timer.

```
App launch → fetchClaudeStatus() immediately
           → statusTimer starts (300s repeating)
Menu opens → fetchClaudeStatus() if last fetch > 300s ago
```

`fetchClaudeStatus()` uses `URLSession.shared.dataTask` (async, non-blocking). On completion:
1. Decode JSON, apply component and incident filters
2. Diff new incident IDs against `UserDefaults["seenIncidentIDs"]` (a `[String]`)
3. For each unseen incident: fire `UNUserNotificationCenter` notification if alerts enabled
4. Append new IDs to `UserDefaults["seenIncidentIDs"]`
5. Update `self.claudeStatus` on main thread
6. Call `self.update()` to refresh icon and menu

Error handling: on network failure or decode error, `claudeStatus` retains its last known value. No error state shown in UI unless `claudeStatus` is nil (first launch, no data yet).

---

## User Notifications

Uses `UNUserNotificationCenter`. Permission is requested once on first launch (standard macOS flow). Notification content:
- **Title**: "Claude incident detected"
- **Body**: incident name (e.g., "Elevated error rates on requests to multiple models")

Notification fires only once per incident ID (deduplicated via `UserDefaults`). Resolved incidents are not notified.

### Alerts Toggle

`UserDefaults["statusAlertsEnabled"]` (Bool, default: `true`).

The toggle appears as a standard `NSMenuItem` with a checkmark in the status section of the menu. Toggling it writes to `UserDefaults` immediately. No app restart required.

---

## UI Changes

### Menu Bar Icon

When `claudeStatus?.hasIssue == true`: composite a 6×6pt filled circle (red: `NSColor.systemRed`) in the top-right corner of the existing 18pt Claude Code icon, using a composed `NSImage`. When `hasIssue == false` or `claudeStatus == nil`: icon unchanged.

Implementation: a new `makeStatusBadgedIcon(size:)` function returns the composed image. Called from `update()` when setting `statusItem.button?.image`.

### Menu Layout

New section inserted **between** the setup-status section and the usage section:

```
Claude Code — Usage Limits          ← existing heading
─────────────────────────
[setup status if any]               ← existing
─────────────────────────
Sistema Claude                      ← new heading
  ✓ Claude Code     Operacional     ← green checkmark.circle
  ⚠ Claude API      Degradado       ← yellow exclamationmark.triangle
    ↳ Elevated error rates...       ← incident name, gray 11pt
🔔 Alertas de incidentes  ✓         ← toggle with checkmark
─────────────────────────
Session (5h)              72%       ← existing usage rows
...
```

Status indicators use SF Symbols:
- `operational` → `checkmark.circle` (green tint)
- `degraded_performance` → `exclamationmark.triangle` (yellow tint)
- `partial_outage` / `major_outage` → `xmark.circle` (red tint)

If `claudeStatus == nil` (first launch, no data yet): status section shows a single gray "Obteniendo estado..." line.

### Localization

The existing `L` struct gains new keys for all 5 languages (en, es, pt, fr, de):

| Key | en | es |
|-----|----|----|
| `statusHeading` | "Claude System Status" | "Sistema Claude" |
| `operational` | "Operational" | "Operacional" |
| `degraded` | "Degraded" | "Degradado" |
| `outage` | "Outage" | "Interrumpido" |
| `alertsToggle` | "Incident Alerts" | "Alertas de incidentes" |
| `statusLoading` | "Fetching status..." | "Obteniendo estado..." |

---

## Implementation Scope

Changes are confined to `src/ClaudeUsageBar.swift`:
1. Add `StatusComponent`, `StatusIncident`, `ClaudeStatus` structs
2. Add `statusTimer`, `claudeStatus` properties to `AppDelegate`
3. Add `fetchClaudeStatus()` method
4. Add `makeStatusBadgedIcon(size:)` function
5. Extend `L` struct with status keys
6. Update `applicationDidFinishLaunching` to start `statusTimer` and request notification permission
7. Update `update()` to render the status section and set the badged icon
8. Add `toggleAlerts()` `@objc` method

**Out of scope:**
- Persisting status to disk
- Showing historical incidents
- Any component other than Claude Code and Claude API
- Statusline (`--statusline` mode) changes

---

## Open Questions

None. All requirements confirmed with user.
