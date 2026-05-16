# Claude Status Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add live Claude system status (status.claude.com) to ClaudeUsageBar — badged icon on incidents, status section in menu, macOS push notifications with toggle.

**Architecture:** Poll `https://status.claude.com/api/v2/summary.json` every 5 minutes on a dedicated timer. Filter for "Claude Code" and "Claude API" components. Deduplicate notifications by incident ID via UserDefaults. All changes in one file: `src/ClaudeUsageBar.swift`, plus a `-framework UserNotifications` flag in `build.sh`.

**Tech Stack:** Swift, Cocoa, UserNotifications framework, URLSession, Statuspage public API.

---

## File Map

| File | Change |
|------|--------|
| `src/ClaudeUsageBar.swift` | Add structs, extend L, add icon fn, fetch logic, menu rendering |
| `build.sh` | Add `-framework UserNotifications` to swiftc invocation |

---

### Task 1: Status data models

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add structs after existing state structs (~line 29)

- [ ] **Step 1: Add API response structs after the `UsageState` struct**

In `src/ClaudeUsageBar.swift`, immediately after the closing `}` of `UsageState` (after line 29), insert:

```swift
// MARK: — Claude Status
struct StatusComponent: Codable {
    let id: String
    let name: String
    let status: String
}
struct StatusIncident: Codable {
    let id: String
    let name: String
    let status: String
}
struct StatusAPIResponse: Codable {
    let components: [StatusComponent]
    let incidents: [StatusIncident]
}
struct ClaudeStatus {
    let components: [StatusComponent]
    let incidents: [StatusIncident]
    let fetchedAt: Date
    var hasIssue: Bool {
        !incidents.isEmpty || components.contains { $0.status != "operational" }
    }
}
```

- [ ] **Step 2: Verify build compiles**

```bash
cd /Users/futhart/Dropbox/Studiolab/services/claude-usage-bar
swiftc src/ClaudeUsageBar.swift -o /tmp/cub_test -O 2>&1
```

Expected: no output (success). If errors appear, fix before continuing.

- [ ] **Step 3: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: add Claude status data models"
```

---

### Task 2: Extend localization struct

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — extend `L` struct and all 5 language cases

- [ ] **Step 1: Add status keys to the `L` struct definition**

In the `L` struct definition (around line 248), change:

```swift
    let heading, session, weekly, weeklySonnet, resets, updated, refresh, close, noData, noDataSub, stale: String
```

to:

```swift
    let heading, session, weekly, weeklySonnet, resets, updated, refresh, close, noData, noDataSub, stale: String
    let statusHeading, operational, degraded, outage, alertsToggle, statusLoading: String
```

- [ ] **Step 2: Update the Spanish case in `L.detect()`**

Replace the `case "es":` line with:

```swift
case "es": return L(heading:"Claude Code — Límites de uso",session:"Sesión (5h)",weekly:"Semana (todo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Actualizado",refresh:"Actualizar",close:"Cerrar",noData:"Sin datos de uso",noDataSub:"Envía un mensaje en Claude Code",stale:" (desactualizado)",statusHeading:"Sistema Claude",operational:"Operacional",degraded:"Degradado",outage:"Interrumpido",alertsToggle:"Alertas de incidentes",statusLoading:"Obteniendo estado...")
```

- [ ] **Step 3: Update the Portuguese case**

Replace the `case "pt":` line with:

```swift
case "pt": return L(heading:"Claude Code — Limites de uso",session:"Sessão (5h)",weekly:"Semana (tudo)",weeklySonnet:"Semana (Sonnet)",resets:"↻",updated:"Atualizado",refresh:"Atualizar",close:"Fechar",noData:"Sem dados de uso",noDataSub:"Envie uma mensagem no Claude Code",stale:" (desatualizado)",statusHeading:"Status Claude",operational:"Operacional",degraded:"Degradado",outage:"Interrompido",alertsToggle:"Alertas de incidentes",statusLoading:"Obtendo status...")
```

- [ ] **Step 4: Update the French case**

Replace the `case "fr":` line with:

```swift
case "fr": return L(heading:"Claude Code — Limites d'utilisation",session:"Session (5h)",weekly:"Semaine (tout)",weeklySonnet:"Semaine (Sonnet)",resets:"↻",updated:"Mis à jour",refresh:"Actualiser",close:"Fermer",noData:"Aucune donnée",noDataSub:"Envoyez un message dans Claude Code",stale:" (périmé)",statusHeading:"Statut Claude",operational:"Opérationnel",degraded:"Dégradé",outage:"Panne",alertsToggle:"Alertes d'incidents",statusLoading:"Chargement...")
```

- [ ] **Step 5: Update the German case**

Replace the `case "de":` line with:

```swift
case "de": return L(heading:"Claude Code — Nutzungslimits",session:"Sitzung (5h)",weekly:"Woche (alle)",weeklySonnet:"Woche (Sonnet)",resets:"↻",updated:"Aktualisiert",refresh:"Aktualisieren",close:"Schließen",noData:"Keine Daten",noDataSub:"Sende eine Nachricht in Claude Code",stale:" (veraltet)",statusHeading:"Claude-Status",operational:"Betriebsbereit",degraded:"Beeinträchtigt",outage:"Ausfall",alertsToggle:"Störungsmeldungen",statusLoading:"Wird geladen...")
```

- [ ] **Step 6: Update the default (English) case**

Replace the `default:` line with:

```swift
default:   return L(heading:"Claude Code — Usage Limits",session:"Session (5h)",weekly:"Weekly (all)",weeklySonnet:"Weekly (Sonnet)",resets:"↻",updated:"Updated",refresh:"Refresh",close:"Close",noData:"No usage data yet",noDataSub:"Send a message in Claude Code",stale:" (stale)",statusHeading:"Claude System Status",operational:"Operational",degraded:"Degraded",outage:"Outage",alertsToggle:"Incident Alerts",statusLoading:"Fetching status...")
```

- [ ] **Step 7: Verify build compiles**

```bash
swiftc src/ClaudeUsageBar.swift -o /tmp/cub_test -O 2>&1
```

Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: add status localization keys to L struct"
```

---

### Task 3: Badged icon function

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add `makeStatusBadgedIcon` after `makeClaudeCodeIcon`

- [ ] **Step 1: Add `makeStatusBadgedIcon` after `makeClaudeCodeIcon` (~line 244)**

After the closing `}` of `makeClaudeCodeIcon`, add:

```swift
func makeStatusBadgedIcon(size: CGFloat) -> NSImage {
    let base = makeClaudeCodeIcon(size: size)
    let result = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        base.draw(in: rect)
        let dotSize: CGFloat = 6
        let dotRect = NSRect(x: rect.maxX - dotSize, y: rect.maxY - dotSize,
                             width: dotSize, height: dotSize)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        return true
    }
    return result
}
```

- [ ] **Step 2: Verify build compiles**

```bash
swiftc src/ClaudeUsageBar.swift -o /tmp/cub_test -O 2>&1
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: add status-badged icon function"
```

---

### Task 4: Fetch logic, timer, notifications

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add `import UserNotifications`, properties on AppDelegate, `fetchClaudeStatus()`, `toggleAlerts()`, update `applicationDidFinishLaunching`, update `menuNeedsUpdate`
- Modify: `build.sh` — add `-framework UserNotifications`

- [ ] **Step 1: Add `import UserNotifications` at the top of the file**

After `import Cocoa` (line 1), add:

```swift
import UserNotifications
```

- [ ] **Step 2: Add properties to `AppDelegate`**

In the `AppDelegate` class body, after `let stateFile = stateFilePath` (around line 267), add:

```swift
    var statusTimer: Timer?
    var claudeStatus: ClaudeStatus?
    let statusFetchURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
```

- [ ] **Step 3: Add `fetchClaudeStatus()` method to `AppDelegate`**

Add this method inside `AppDelegate`, after `func fmt(...)`:

```swift
    func fetchClaudeStatus() {
        let task = URLSession.shared.dataTask(with: statusFetchURL) { [weak self] data, _, error in
            guard let self, let data, error == nil,
                  let response = try? JSONDecoder().decode(StatusAPIResponse.self, from: data)
            else { return }

            let filtered = response.components.filter {
                $0.name.contains("Claude Code") || $0.name.contains("Claude API")
            }
            let active = response.incidents.filter { $0.status != "resolved" }
            let newStatus = ClaudeStatus(components: filtered, incidents: active, fetchedAt: Date())

            let defaults = UserDefaults.standard
            let seen = defaults.stringArray(forKey: "seenIncidentIDs") ?? []
            let alertsOn = defaults.object(forKey: "statusAlertsEnabled") as? Bool ?? true

            let unseen = active.filter { !seen.contains($0.id) }
            if alertsOn && !unseen.isEmpty {
                for incident in unseen {
                    let content = UNMutableNotificationContent()
                    content.title = "Claude incident detected"
                    content.body = incident.name
                    let req = UNNotificationRequest(
                        identifier: "claude-incident-\(incident.id)",
                        content: content,
                        trigger: nil
                    )
                    UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
                }
            }
            let allSeen = seen + unseen.map(\.id)
            defaults.set(allSeen, forKey: "seenIncidentIDs")

            DispatchQueue.main.async {
                self.claudeStatus = newStatus
                self.update()
            }
        }
        task.resume()
    }
```

- [ ] **Step 4: Add `toggleAlerts()` method to `AppDelegate`**

Add this method inside `AppDelegate`, after `fetchClaudeStatus()`:

```swift
    @objc func toggleAlerts() {
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: "statusAlertsEnabled") as? Bool ?? true
        defaults.set(!current, forKey: "statusAlertsEnabled")
        update()
    }
```

- [ ] **Step 5: Update `applicationDidFinishLaunching` to start status timer and request notification permission**

After `timer = Timer.scheduledTimer(...)` in `applicationDidFinishLaunching`, add:

```swift
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        fetchClaudeStatus()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.fetchClaudeStatus()
        }
```

- [ ] **Step 6: Update `menuNeedsUpdate` to trigger a status refresh if stale**

Replace:

```swift
    func menuNeedsUpdate(_ menu: NSMenu) { update() }
```

with:

```swift
    func menuNeedsUpdate(_ menu: NSMenu) {
        if let s = claudeStatus, Date().timeIntervalSince(s.fetchedAt) > 300 {
            fetchClaudeStatus()
        }
        update()
    }
```

- [ ] **Step 7: Add `UNUserNotificationCenterDelegate` conformance to `AppDelegate` so notifications show while app is in foreground**

Change the class declaration from:

```swift
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
```

to:

```swift
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
```

Add this method inside `AppDelegate`:

```swift
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
```

- [ ] **Step 8: Update `build.sh` to link UserNotifications framework**

Change the swiftc invocation in `build.sh` from:

```bash
swiftc "$SCRIPT_DIR/src/ClaudeUsageBar.swift" \
  -o "$BUILD_TMP/$APP_NAME" \
  -O
```

to:

```bash
swiftc "$SCRIPT_DIR/src/ClaudeUsageBar.swift" \
  -o "$BUILD_TMP/$APP_NAME" \
  -O \
  -framework UserNotifications
```

- [ ] **Step 9: Verify build compiles with UserNotifications framework**

```bash
swiftc src/ClaudeUsageBar.swift -o /tmp/cub_test -O -framework UserNotifications 2>&1
```

Expected: no output.

- [ ] **Step 10: Commit**

```bash
git add src/ClaudeUsageBar.swift build.sh
git commit -m "feat: add status fetch, polling timer, and incident notifications"
```

---

### Task 5: Menu status section + NSMenu helper

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add `addStatusRow` to NSMenu extension, update `update()`

- [ ] **Step 1: Add `addStatusRow` helper to the `NSMenu` extension**

In the `NSMenu` extension (after the `addRow` method), add:

```swift
    func addStatusRow(_ label: String, status: String, operational: String, degraded: String, outage: String) {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 22))

        let (symName, color): (String, NSColor)
        switch status {
        case "operational":
            symName = "checkmark.circle"; color = .systemGreen
        case "degraded_performance":
            symName = "exclamationmark.triangle"; color = .systemYellow
        default:
            symName = "xmark.circle"; color = .systemRed
        }

        let statusText: String
        switch status {
        case "operational":         statusText = operational
        case "degraded_performance": statusText = degraded
        default:                    statusText = outage
        }

        if let img = NSImage(systemSymbolName: symName, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            let colored = img.withSymbolConfiguration(cfg)
            let iv = NSImageView(frame: NSRect(x: 8, y: 3, width: 16, height: 16))
            iv.image = colored
            iv.contentTintColor = color
            view.addSubview(iv)
        }

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = .labelColor
        lbl.frame = NSRect(x: 30, y: 2, width: 140, height: 18)
        view.addSubview(lbl)

        let val = NSTextField(labelWithString: statusText)
        val.font = .systemFont(ofSize: 13)
        val.textColor = .secondaryLabelColor
        val.alignment = .right
        val.frame = NSRect(x: 170, y: 2, width: 66, height: 18)
        view.addSubview(val)

        item.view = view
        addItem(item)
    }
```

- [ ] **Step 2: Update `update()` to set the icon and render the status section**

In `update()`, find the lines that set `statusItem.button?.image`. Currently `applicationDidFinishLaunching` sets it once:

```swift
            btn.image = makeClaudeCodeIcon(size: 18)
```

That initial set is fine. Now in `update()`, after `let m = NSMenu()` and before `m.addHeader(l.heading)`, add the icon update:

```swift
        if let btn = statusItem.button {
            btn.image = (claudeStatus?.hasIssue == true)
                ? makeStatusBadgedIcon(size: 18)
                : makeClaudeCodeIcon(size: 18)
        }
```

- [ ] **Step 3: Add the status section to the menu in `update()`**

In `update()`, after `addSetupStatus(to: m)` and the separator that follows it, add the status section. Find this block:

```swift
        m.addHeader(l.heading)
        m.addItem(.separator())
        addSetupStatus(to: m)

        guard let raw   = FileManager.default.contents(atPath: stateFile),
```

Replace with:

```swift
        m.addHeader(l.heading)
        m.addItem(.separator())
        addSetupStatus(to: m)

        // Status section
        m.addHeader(l.statusHeading)
        if let cs = claudeStatus {
            for comp in cs.components {
                m.addStatusRow(comp.name, status: comp.status,
                               operational: l.operational,
                               degraded: l.degraded,
                               outage: l.outage)
            }
            for incident in cs.incidents {
                m.addPlain("↳ \(incident.name)", size: 11, gray: true, indent: 30)
            }
        } else {
            m.addPlain(l.statusLoading, size: 11, gray: true)
        }
        let alertsOn = UserDefaults.standard.object(forKey: "statusAlertsEnabled") as? Bool ?? true
        let alertsItem = NSMenuItem(title: l.alertsToggle, action: #selector(toggleAlerts), keyEquivalent: "")
        alertsItem.target = self
        alertsItem.state = alertsOn ? .on : .off
        m.addItem(alertsItem)
        m.addItem(.separator())

        guard let raw   = FileManager.default.contents(atPath: stateFile),
```

- [ ] **Step 4: Verify build compiles**

```bash
swiftc src/ClaudeUsageBar.swift -o /tmp/cub_test -O -framework UserNotifications 2>&1
```

Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: render status section in menu and badge icon on incident"
```

---

### Task 6: Full build and smoke test

**Files:**
- Run: `build.sh`

- [ ] **Step 1: Run full build**

```bash
bash build.sh 2>&1
```

Expected output ends with:
```
  ✓ Built → .../dist/ClaudeUsageBar.app
  ✓ DMG → .../dist/ClaudeUsageBar.dmg
```

If compile errors appear, fix in `src/ClaudeUsageBar.swift` and re-run.

- [ ] **Step 2: Kill existing instance and launch the new build**

```bash
pkill -x ClaudeUsageBar 2>/dev/null || true
open dist/ClaudeUsageBar.app
```

- [ ] **Step 3: Smoke test checklist**

Open the menu bar item and verify:
- [ ] "Claude System Status" (or localized equivalent) heading appears in menu
- [ ] "Claude Code" and "Claude API" rows appear with status text and colored icons
- [ ] "Incident Alerts" toggle appears with checkmark (enabled by default)
- [ ] Clicking "Incident Alerts" toggles the checkmark off/on
- [ ] Icon in menu bar has no badge when status is operational
- [ ] (To test badge: temporarily hardcode `claudeStatus` with `hasIssue == true` or wait for a real incident)

- [ ] **Step 4: Verify notification permission dialog appeared on first launch**

macOS should have shown a permission dialog on first launch. Check System Settings → Notifications → ClaudeUsageBar.

- [ ] **Step 5: Final commit if any last fixes were made**

```bash
git add -p
git commit -m "fix: smoke test corrections"
```
