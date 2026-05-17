# macOS WidgetKit Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Medium and Large WidgetKit widgets to ClaudeUsageBar that show Claude Code session/weekly usage and system status from the existing state file.

**Architecture:** Convert the swiftc-only build to an Xcode project (via xcodegen) with two targets — the existing menu bar app and a new widget extension. The widget reads `~/.claude/.claude-usage-state.json` directly (no App Groups; neither target is sandboxed). The main app triggers widget refreshes via `WidgetCenter.shared.reloadAllTimelines()` whenever it detects new state.

**Tech Stack:** Swift 5.9, WidgetKit, SwiftUI, xcodegen, xcodebuild, macOS 13+

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Create | `project.yml` | xcodegen spec — defines both targets, frameworks, embed phase |
| Create | `Resources/Info.plist` | Main app bundle metadata (replaces heredoc in build.sh) |
| Create | `widget/Info.plist` | Widget extension bundle metadata |
| Create | `widget/ClaudeUsageBarWidget.swift` | TimelineProvider + SwiftUI Medium/Large views |
| Modify | `src/ClaudeUsageBar.swift` | Add `import WidgetKit` + `WidgetCenter.shared.reloadAllTimelines()` |
| Modify | `build.sh` | Replace swiftc with xcodebuild; keep icon gen + DMG steps |
| Modify | `install.sh` | Replace inline swiftc build with call to `build.sh` |
| Generated | `ClaudeUsageBar.xcodeproj/` | Output of `xcodegen generate` — commit this |

---

## Task 1: Create `Resources/Info.plist` (main app)

The current Info.plist is a heredoc inside build.sh. Moving it to a real file so Xcode can reference it.

**Files:**
- Create: `Resources/Info.plist`

- [ ] **Step 1: Create the file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                   <string>ClaudeUsageBar</string>
  <key>CFBundleIdentifier</key>             <string>com.chrispiz.claude-usage-bar</string>
  <key>CFBundleVersion</key>                <string>1.1</string>
  <key>CFBundleExecutable</key>             <string>ClaudeUsageBar</string>
  <key>CFBundleIconFile</key>               <string>ClaudeUsageBar</string>
  <key>CFBundlePackageType</key>            <string>APPL</string>
  <key>CFBundleShortVersionString</key>     <string>1.1</string>
  <key>LSUIElement</key>                    <true/>
  <key>NSHighResolutionCapable</key>        <true/>
  <key>LSMinimumSystemVersion</key>         <string>13.0</string>
  <key>NSUserNotificationAlertStyle</key>   <string>alert</string>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
git add Resources/Info.plist
git commit -m "chore: add Info.plist as standalone file (prep for Xcode project)"
```

---

## Task 2: Create `widget/Info.plist`

Required metadata for the widget extension bundle. The `NSExtension` key is what tells macOS this is a WidgetKit extension.

**Files:**
- Create: `widget/Info.plist`

- [ ] **Step 1: Create the file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>               <string>ClaudeUsageBarWidget</string>
  <key>CFBundleIdentifier</key>         <string>com.chrispiz.claude-usage-bar.widget</string>
  <key>CFBundleVersion</key>            <string>1.1</string>
  <key>CFBundleExecutable</key>         <string>ClaudeUsageBarWidget</string>
  <key>CFBundlePackageType</key>        <string>XPC!</string>
  <key>CFBundleShortVersionString</key> <string>1.1</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
```

- [ ] **Step 2: Commit**

```bash
git add widget/Info.plist
git commit -m "chore: add widget extension Info.plist"
```

---

## Task 3: Create `widget/ClaudeUsageBarWidget.swift`

The full widget implementation: data model, timeline provider (reads state file + fetches system status), and SwiftUI views for Medium and Large families.

**Files:**
- Create: `widget/ClaudeUsageBarWidget.swift`

- [ ] **Step 1: Create the file**

Write the complete file at `widget/ClaudeUsageBarWidget.swift`:

```swift
import WidgetKit
import SwiftUI

// MARK: — Data model (mirrors src/ClaudeUsageBar.swift)

struct WLimit: Codable {
    let usedPercentage: Double
    let resetsAt: Int?
    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt       = "resets_at"
    }
}

struct WRateLimits: Codable {
    let fiveHour: WLimit?
    let sevenDay: WLimit?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct WUsageState: Codable {
    let updatedAt: Int
    let rateLimits: WRateLimits?
    enum CodingKeys: String, CodingKey {
        case updatedAt  = "updated_at"
        case rateLimits = "rate_limits"
    }
}

struct WStatusComponent: Codable {
    let name: String
    let status: String
}

struct WStatusResponse: Codable {
    let components: [WStatusComponent]
}

// MARK: — Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let fiveHour: WLimit?
    let sevenDay: WLimit?
    let updatedAt: Int?
    let claudeCodeStatus: String?
    let claudeAPIStatus: String?
}

// MARK: — Timeline Provider

struct Provider: TimelineProvider {
    let stateFilePath = (ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory())
        + "/.claude/.claude-usage-state.json"

    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(
            date: Date(),
            fiveHour: WLimit(usedPercentage: 72, resetsAt: nil),
            sevenDay: WLimit(usedPercentage: 45, resetsAt: nil),
            updatedAt: nil,
            claudeCodeStatus: "operational",
            claudeAPIStatus: "operational"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(readUsageEntry(claudeCodeStatus: nil, claudeAPIStatus: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let usage = readUsageEntry(claudeCodeStatus: nil, claudeAPIStatus: nil)
        let statusURL = URL(string: "https://status.claude.com/api/v2/summary.json")!

        URLSession.shared.dataTask(with: statusURL) { data, _, _ in
            var ccStatus: String? = nil
            var apiStatus: String? = nil
            if let data,
               let response = try? JSONDecoder().decode(WStatusResponse.self, from: data) {
                ccStatus  = response.components.first { $0.name.contains("Claude Code") }?.status
                apiStatus = response.components.first { $0.name.contains("Claude API")
                    && !$0.name.contains("Claude Code") }?.status
            }
            let entry = UsageEntry(
                date: usage.date,
                fiveHour: usage.fiveHour,
                sevenDay: usage.sevenDay,
                updatedAt: usage.updatedAt,
                claudeCodeStatus: ccStatus,
                claudeAPIStatus: apiStatus
            )
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }.resume()
    }

    private func readUsageEntry(claudeCodeStatus: String?, claudeAPIStatus: String?) -> UsageEntry {
        guard let data  = FileManager.default.contents(atPath: stateFilePath),
              let state = try? JSONDecoder().decode(WUsageState.self, from: data)
        else {
            return UsageEntry(date: Date(), fiveHour: nil, sevenDay: nil,
                              updatedAt: nil, claudeCodeStatus: nil, claudeAPIStatus: nil)
        }
        return UsageEntry(
            date: Date(),
            fiveHour: state.rateLimits?.fiveHour,
            sevenDay: state.rateLimits?.sevenDay,
            updatedAt: state.updatedAt,
            claudeCodeStatus: claudeCodeStatus,
            claudeAPIStatus: claudeAPIStatus
        )
    }
}

// MARK: — Helpers

func wEffectivePct(_ limit: WLimit, now: Int = Int(Date().timeIntervalSince1970)) -> Int {
    if let resetsAt = limit.resetsAt, resetsAt <= now { return 0 }
    return Int(limit.usedPercentage)
}

func wColor(for pct: Int) -> Color {
    if pct < 70 { return Color(red: 0.298, green: 0.851, blue: 0.392) }
    if pct < 90 { return Color(red: 1.0,   green: 0.584, blue: 0.0) }
    return             Color(red: 1.0,   green: 0.231, blue: 0.188)
}

func wResetLabel(_ limit: WLimit, now: Int = Int(Date().timeIntervalSince1970)) -> String {
    guard let ts = limit.resetsAt else { return "" }
    let diff = ts - now
    guard diff > 0 else { return "" }
    if diff >= 86400 {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let day  = DateFormatter(); day.dateFormat  = "EEEE"
        let time = DateFormatter(); time.timeStyle  = .short; time.dateStyle = .none
        return "Resets \(day.string(from: date)) at \(time.string(from: date))"
    }
    let h = diff / 3600, m = (diff % 3600) / 60
    return h > 0 ? "Resets in \(h)h \(m)m" : "Resets in \(m)m"
}

func wUpdatedLabel(_ ts: Int) -> String {
    let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
    return f.string(from: Date(timeIntervalSince1970: TimeInterval(ts)))
}

// MARK: — Shared sub-views

struct UsageRow: View {
    let label: String
    let limit: WLimit

    var body: some View {
        let pct   = wEffectivePct(limit)
        let color = wColor(for: pct)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(pct) / 100, height: 5)
                }
            }
            .frame(height: 5)
            let resetText = wResetLabel(limit)
            if !resetText.isEmpty {
                Text(resetText)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct StatusDotRow: View {
    let name: String
    let status: String?

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(statusLabel)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    private var dotColor: Color {
        switch status {
        case "operational":          return .green
        case "degraded_performance": return .yellow
        default:                     return status == nil ? .gray : .red
        }
    }

    private var statusLabel: String {
        switch status {
        case "operational":          return "Online"
        case "degraded_performance": return "Issues"
        case nil:                    return "Unknown"
        default:                     return "Down"
        }
    }
}

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No usage data")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Send a message in Claude Code")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — Medium widget view

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.fiveHour == nil && entry.sevenDay == nil {
            NoDataView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Claude Code", systemImage: "terminal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let ts = entry.updatedAt {
                        Text(wUpdatedLabel(ts))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 10)

                HStack(alignment: .top, spacing: 14) {
                    if let fh = entry.fiveHour {
                        UsageRow(label: "5h Session", limit: fh)
                    }
                    if entry.fiveHour != nil && entry.sevenDay != nil {
                        Divider()
                    }
                    if let sd = entry.sevenDay {
                        UsageRow(label: "7d Weekly", limit: sd)
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: — Large widget view

struct LargeWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.fiveHour == nil && entry.sevenDay == nil {
            NoDataView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Claude Code Usage", systemImage: "terminal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let ts = entry.updatedAt {
                        Text(wUpdatedLabel(ts))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 14)

                VStack(spacing: 14) {
                    if let fh = entry.fiveHour { UsageRow(label: "5h Session", limit: fh) }
                    if let sd = entry.sevenDay { UsageRow(label: "7d Weekly",  limit: sd) }
                }

                Divider().padding(.vertical, 12)

                Text("System Status")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.bottom, 8)

                VStack(spacing: 7) {
                    StatusDotRow(name: "Claude Code", status: entry.claudeCodeStatus)
                    StatusDotRow(name: "Claude API",  status: entry.claudeAPIStatus)
                }

                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: — Entry view dispatcher

struct ClaudeUsageBarWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: UsageEntry

    var body: some View {
        Group {
            switch family {
            case .systemLarge:  LargeWidgetView(entry: entry)
            default:            MediumWidgetView(entry: entry)
            }
        }
        .widgetBackground()
    }
}

// macOS 13 / 14 compatibility shim for containerBackground
extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(.background, for: .widget)
        } else {
            self
        }
    }
}

// MARK: — Widget configuration

@main
struct ClaudeUsageBarWidget: Widget {
    let kind = "ClaudeUsageBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClaudeUsageBarWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Code Usage")
        .description("Session and weekly usage limits for Claude Code.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
```

- [ ] **Step 2: Verify it compiles standalone**

```bash
swiftc -parse widget/ClaudeUsageBarWidget.swift \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macosx13.0 2>&1
```

Expected: no errors (parse-only check, no linking needed).

- [ ] **Step 3: Commit**

```bash
git add widget/ClaudeUsageBarWidget.swift
git commit -m "feat: add WidgetKit widget source (Medium + Large)"
```

---

## Task 4: Create `project.yml` (xcodegen config)

This file is the source of truth for the Xcode project structure. xcodegen reads it and generates `ClaudeUsageBar.xcodeproj/`.

**Files:**
- Create: `project.yml`

- [ ] **Step 1: Create the file**

```yaml
name: ClaudeUsageBar
options:
  bundleIdPrefix: com.chrispiz
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15"
  generateEmptyDirectories: true

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    ENABLE_HARDENED_RUNTIME: NO
    DEBUG_INFORMATION_FORMAT: dwarf-with-dsym

targets:
  ClaudeUsageBar:
    type: application
    platform: macOS
    sources:
      - src/ClaudeUsageBar.swift
    resources:
      - path: Resources/claudecode-color.svg
        buildPhase: resources
    info:
      path: Resources/Info.plist
      properties: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.chrispiz.claude-usage-bar
        PRODUCT_NAME: ClaudeUsageBar
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
    dependencies:
      - target: ClaudeUsageBarWidget
        embed: true
        codeSign: false
    preBuildScripts:
      - name: Generate App Icon
        script: |
          set -euo pipefail
          BUILD_TMP="${DERIVED_FILE_DIR}/icon_build"
          ICONSET="${BUILD_TMP}/ClaudeUsageBar.iconset"
          ICNS="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Resources/ClaudeUsageBar.icns"
          rm -rf "$BUILD_TMP" && mkdir -p "$BUILD_TMP"
          swiftc "${SRCROOT}/src/IconGenerator.swift" -o "${BUILD_TMP}/IconGenerator" -O
          "${BUILD_TMP}/IconGenerator" "$ICONSET"
          iconutil -c icns "$ICONSET" -o "$ICNS"
        basedOnDependencyAnalysis: false
    frameworks:
      - sdk: Cocoa.framework
      - sdk: UserNotifications.framework
      - sdk: WidgetKit.framework

  ClaudeUsageBarWidget:
    type: app-extension
    platform: macOS
    sources:
      - widget/ClaudeUsageBarWidget.swift
    info:
      path: widget/Info.plist
      properties: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.chrispiz.claude-usage-bar.widget
        PRODUCT_NAME: ClaudeUsageBarWidget
        SKIP_INSTALL: YES
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../../../../Frameworks"
    frameworks:
      - sdk: WidgetKit.framework
      - sdk: SwiftUI.framework
```

- [ ] **Step 2: Generate the Xcode project**

```bash
cd /Users/miguelsosa/Claude-Code-Usage-Bar
xcodegen generate
```

Expected output ends with: `✓ Generated: ClaudeUsageBar.xcodeproj`

- [ ] **Step 3: Verify the project has both targets**

```bash
xcodebuild -project ClaudeUsageBar.xcodeproj -list
```

Expected output includes:
```
Targets:
    ClaudeUsageBar
    ClaudeUsageBarWidget

Schemes:
    ClaudeUsageBar
```

- [ ] **Step 4: Commit**

```bash
git add project.yml ClaudeUsageBar.xcodeproj/
git commit -m "chore: add xcodegen project.yml and generated xcodeproj"
```

---

## Task 5: Modify `src/ClaudeUsageBar.swift` — add WidgetCenter refresh

Add `import WidgetKit` and call `WidgetCenter.shared.reloadAllTimelines()` when the main app detects new state data, so the widget updates promptly without waiting for the 15-minute scheduled refresh.

**Files:**
- Modify: `src/ClaudeUsageBar.swift`

- [ ] **Step 1: Add `import WidgetKit` at the top of the file**

Find the existing imports at line 1–2:
```swift
import Cocoa
import UserNotifications
```

Replace with:
```swift
import Cocoa
import UserNotifications
import WidgetKit
```

- [ ] **Step 2: Add `lastStateUpdatedAt` property to `AppDelegate`**

Find the existing property block in `AppDelegate` (around line 307–315):
```swift
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var setupStatus: SetupStatus = .failed
    var aboutWindow: NSWindow?
    let stateFile = stateFilePath
    var statusTimer: Timer?
    var claudeStatus: ClaudeStatus?
    let statusFetchURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    var isFetchingStatus = false
```

Replace with:
```swift
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var setupStatus: SetupStatus = .failed
    var aboutWindow: NSWindow?
    let stateFile = stateFilePath
    var statusTimer: Timer?
    var claudeStatus: ClaudeStatus?
    let statusFetchURL = URL(string: "https://status.claude.com/api/v2/summary.json")!
    var isFetchingStatus = false
    var lastStateUpdatedAt: Int = 0
```

- [ ] **Step 3: Add WidgetCenter call inside `update()` when new state is detected**

Find this block inside `update()` where the state file is read (around line 360–370):
```swift
        if let raw   = FileManager.default.contents(atPath: stateFile),
           let state = try? JSONDecoder().decode(UsageState.self, from: raw) {

            let now   = Int(Date().timeIntervalSince1970)
            let stale = (now - state.updatedAt) > 21600 ? l.stale : ""
```

Replace with:
```swift
        if let raw   = FileManager.default.contents(atPath: stateFile),
           let state = try? JSONDecoder().decode(UsageState.self, from: raw) {

            if state.updatedAt != lastStateUpdatedAt {
                lastStateUpdatedAt = state.updatedAt
                WidgetCenter.shared.reloadAllTimelines()
            }

            let now   = Int(Date().timeIntervalSince1970)
            let stale = (now - state.updatedAt) > 21600 ? l.stale : ""
```

- [ ] **Step 4: Verify the file still parses**

```bash
swiftc -parse src/ClaudeUsageBar.swift \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macosx13.0 2>&1
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: trigger widget refresh when main app detects new state"
```

---

## Task 6: Update `build.sh` to use xcodebuild

Replace the swiftc-based build with xcodebuild. Keep icon generation (now handled by Xcode build script) removed from here, and keep DMG packaging unchanged.

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: Replace `build.sh` with the xcodebuild version**

```bash
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
mkdir -p "$DIST_DIR"

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
  | grep -E "^(error:|warning:|Build succeeded|ClaudeUsageBar)" || true

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
```

- [ ] **Step 2: Test the build**

```bash
bash build.sh 2>&1
```

Expected: ends with `Release artifact: dist/ClaudeUsageBar.dmg`

- [ ] **Step 3: Verify the widget extension is embedded**

```bash
ls dist/ClaudeUsageBar.app/Contents/PlugIns/
```

Expected: `ClaudeUsageBarWidget.appex`

- [ ] **Step 4: Commit**

```bash
git add build.sh
git commit -m "build: replace swiftc with xcodebuild, embed widget extension"
```

---

## Task 7: Update `install.sh` to use `build.sh`

The current `install.sh` has an inline `swiftc` build that no longer works after the Xcode project migration. Replace it with a call to `build.sh`, which handles the full build including the widget.

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Find the inline build block**

The block starts at approximately line 122 with:
```bash
echo "Building ClaudeUsageBar.app ..."
if ! command -v swiftc &>/dev/null; then
```
and ends around line 174 with the `fi  # end SKIP_BUILD check` comment.

Replace the entire `if [ "${SKIP_BUILD:-0}" = "1" ]; then ... fi  # end SKIP_BUILD check` block with:

```bash
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
```

Note: `install.sh` does not define `DIST_DIR`; the updated block above uses `$SCRIPT_DIR/dist/$APP_NAME.app` directly to avoid needing a new variable.

- [ ] **Step 2: Verify install.sh still passes bash syntax check**

```bash
bash -n install.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "fix: update install.sh to use xcodebuild via build.sh"
```

---

## Task 8: End-to-end build verification

Verify the full build and widget embedding before manual testing.

- [ ] **Step 1: Clean build from scratch**

```bash
bash build.sh
```

Expected: ends with `Release artifact: dist/ClaudeUsageBar.dmg`

- [ ] **Step 2: Verify widget is embedded**

```bash
ls dist/ClaudeUsageBar.app/Contents/PlugIns/
```

Expected: `ClaudeUsageBarWidget.appex`

- [ ] **Step 3: Verify widget extension Info.plist has the right extension point**

```bash
/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" \
  "dist/ClaudeUsageBar.app/Contents/PlugIns/ClaudeUsageBarWidget.appex/Contents/Info.plist"
```

Expected: `com.apple.widgetkit-extension`

- [ ] **Step 4: Launch the app**

```bash
pkill -x ClaudeUsageBar 2>/dev/null || true
open dist/ClaudeUsageBar.app
```

- [ ] **Step 5: Add widget in macOS**

Right-click desktop → Edit Widgets → search "Claude" → add Medium or Large widget. Verify usage data appears if a state file exists:

```bash
cat ~/.claude/.claude-usage-state.json
```

If the file doesn't exist, send a message in Claude Code to populate it, then the widget should update within 60 seconds (triggered by the main app's WidgetCenter call).

- [ ] **Step 6: Commit final state**

```bash
git add -A
git status  # review — should only be any generated files
git commit -m "feat: macOS WidgetKit widget (Medium + Large) with xcodebuild pipeline"
```

---

## Troubleshooting Reference

**Widget doesn't appear in widget gallery:**
- Check that `NSExtensionPointIdentifier` = `com.apple.widgetkit-extension` in the `.appex` Info.plist (Step 8.3)
- Ensure the `.appex` is in `Contents/PlugIns/` of the app bundle (Step 8.2)
- Try: `killall Widgetkit Simulator 2>/dev/null; killall NotificationCenter 2>/dev/null`

**Build error: "no such module 'WidgetKit'":**
- Confirm the widget target has `WidgetKit.framework` in its frameworks phase in `project.yml`
- Re-run `xcodegen generate` and rebuild

**Widget shows "No usage data":**
- The state file `~/.claude/.claude-usage-state.json` must exist. Send a message in Claude Code to populate it. The hook writes it after each message.

**Sandbox error reading state file:**
- Verify neither target has `com.apple.security.app-sandbox` in its entitlements. xcodegen should not add it with our `project.yml`, but double-check in Xcode → target → Signing & Capabilities.
