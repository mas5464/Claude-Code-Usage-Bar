# Enhanced Usage Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add accumulated all-time cost, reset countdowns, and current model name to the macOS menu bar app and WidgetKit widget, with a cost-forward title and split-panel menu layout.

**Architecture:** Extend `UsageState` with two optional fields (`model`, `total_cost_usd`); add a `CostScanner` class that async-scans `~/.claude/projects/**/*.jsonl` and writes the total into the state file; update the menu bar title to `◆ $14.1K │ 11%` and the dropdown to a split-panel custom NSView; update the widget to a two-column layout with cost left, usage right.

**Tech Stack:** Swift (AppKit, WidgetKit, Foundation), single-file architecture (`src/ClaudeUsageBar.swift` + `widget/ClaudeUsageBarWidget.swift`), `xcodebuild` via `build.sh`.

---

## File Map

| File | Changes |
|------|---------|
| `src/ClaudeUsageBar.swift` | Add `model`/`totalCostUSD` to `UsageState`; extend `StatusLineInput` to parse model; update `renderStatusLine()`; add `formatCountdown()`, `formatCost()`, `CostScanner`; update `AppDelegate.update()` for new title and split-panel menu |
| `widget/ClaudeUsageBarWidget.swift` | Add `model`/`totalCostUSD` to `WUsageState` and `UsageEntry`; rewrite `MediumWidgetView` as split columns; update `LargeWidgetView` header |

No new files. No build system changes.

---

## Task 1: Extend state schema + statusline model extraction

**Files:**
- Modify: `src/ClaudeUsageBar.swift:24-65` (structs `UsageState`, `StatusLineInput`, `renderStatusLine`)

- [ ] **Step 1: Update `UsageState` to include `model` and `totalCostUSD`**

Replace lines 24–31 with:

```swift
struct UsageState: Codable {
    let updatedAt:    Int
    let rateLimits:   RateLimits?
    let model:        String?
    let totalCostUSD: Double?
    enum CodingKeys: String, CodingKey {
        case updatedAt    = "updated_at"
        case rateLimits   = "rate_limits"
        case model        = "model"
        case totalCostUSD = "total_cost_usd"
    }
}
```

- [ ] **Step 2: Add `ModelInfo` struct and update `StatusLineInput`**

Replace lines 60–65 with:

```swift
struct ModelInfo: Codable {
    let id: String?
    let displayName: String?
    enum CodingKeys: String, CodingKey {
        case id          = "id"
        case displayName = "display_name"
    }
}

struct StatusLineInput: Codable {
    let rateLimits: RateLimits?
    let model:      ModelInfo?
    enum CodingKeys: String, CodingKey {
        case rateLimits = "rate_limits"
        case model      = "model"
    }
}
```

- [ ] **Step 3: Update `renderStatusLine()` to write `model` to state file**

Replace lines 141–151 with:

```swift
    let modelID = payload.model?.id ?? payload.model?.displayName
    // Preserve totalCostUSD written by CostScanner — JSONEncoder omits nil optionals,
    // which would silently wipe the field on every statusline invocation.
    var existingCostUSD: Double? = nil
    if let existingData = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
       let existingState = try? JSONDecoder().decode(UsageState.self, from: existingData) {
        existingCostUSD = existingState.totalCostUSD
    }
    let state = UsageState(
        updatedAt:    Int(Date().timeIntervalSince1970),
        rateLimits:   limits,
        model:        modelID,
        totalCostUSD: existingCostUSD
    )
    do {
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: homeDirectoryPath + "/.claude"),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: URL(fileURLWithPath: stateFilePath), options: .atomic)
    } catch {
        // Statusline rendering should not fail just because state persistence failed.
    }
```

- [ ] **Step 4: Verify statusline still writes state file with model**

```bash
echo '{"rate_limits":{"five_hour":{"used_percentage":15,"resets_at":1999999999},"seven_day":{"used_percentage":5,"resets_at":1999999999}},"model":{"id":"claude-sonnet-4-6","display_name":"Claude Sonnet 4.6"}}' \
  | bash build.sh --statusline-test 2>/dev/null || \
  swift src/ClaudeUsageBar.swift --statusline <<< \
  '{"rate_limits":{"five_hour":{"used_percentage":15,"resets_at":1999999999}},"model":{"id":"claude-sonnet-4-6"}}'
cat ~/.claude/.claude-usage-state.json
```

Expected: JSON contains `"model":"claude-sonnet-4-6"`

- [ ] **Step 5: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: extend UsageState with model + totalCostUSD fields, extract model in statusline"
```

---

## Task 2: Add `formatCountdown()` and `formatCost()` helpers

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add two functions after `effectiveUsedPercentage` (after line 98)

- [ ] **Step 1: Add `formatCountdown()` after `effectiveUsedPercentage()`**

Insert after line 98 (after `func effectiveUsedPercentage`):

```swift
func formatCountdown(_ resetsAt: Int, now: Int = Int(Date().timeIntervalSince1970)) -> String {
    let delta = resetsAt - now
    guard delta > 0 else { return "" }
    if delta < 60       { return "< 1m" }
    if delta < 3600     { return "\(delta / 60)m" }
    if delta < 86400    { return "\(delta / 3600)h \((delta % 3600) / 60)m" }
    return "\(delta / 86400)d \((delta % 86400) / 3600)h"
}

func formatCost(_ usd: Double) -> String {
    if usd >= 1_000_000 { return String(format: "$%.1fM", usd / 1_000_000) }
    if usd >= 10_000    { return String(format: "$%.1fK", usd / 1_000) }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return "$\(formatter.string(from: NSNumber(value: Int(usd))) ?? "\(Int(usd))")"
}
```

- [ ] **Step 2: Manually verify in Swift REPL or by building**

```bash
swift -e '
func formatCountdown(_ r: Int, now: Int = Int(Date().timeIntervalSince1970)) -> String {
    let d = r - now; guard d > 0 else { return "" }
    if d < 60 { return "< 1m" }
    if d < 3600 { return "\(d/60)m" }
    if d < 86400 { return "\(d/3600)h \((d%3600)/60)m" }
    return "\(d/86400)d \((d%86400)/3600)h"
}
func formatCost(_ u: Double) -> String {
    if u >= 1_000_000 { return String(format: "$%.1fM", u/1_000_000) }
    if u >= 10_000    { return String(format: "$%.1fK", u/1_000) }
    return "$\(Int(u))"
}
let now = Int(Date().timeIntervalSince1970)
print(formatCountdown(now + 2200))    // "36m"
print(formatCountdown(now + 7500))    // "2h 5m"
print(formatCountdown(now + 600000))  // "6d 22h"
print(formatCost(9500))               // "$9500"
print(formatCost(14118.76))           // "$14.1K"
print(formatCost(1_234_567))          // "$1.2M"
'
```

Expected output lines: something like `36m`, `2h 5m`, `6d 22h`, `$9500`, `$14.1K`, `$1.2M`

- [ ] **Step 3: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: add formatCountdown() and formatCost() helpers"
```

---

## Task 3: CostScanner class

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — add `CostScanner` class and pricing table before `// MARK: — App Delegate`

- [ ] **Step 1: Add `CostScanner` class**

Insert before `// MARK: — App Delegate` (before line 307):

```swift
// MARK: — Cost Scanner

class CostScanner {
    private let projectsDir: String
    private let stateFile: String
    private var workItem: DispatchWorkItem?

    struct Pricing {
        let input, cacheCreate, cacheRead, output: Double // USD per million tokens
    }

    private let pricingTable: [(match: String, rates: Pricing)] = [
        ("opus-4",    Pricing(input: 15.00, cacheCreate: 18.75, cacheRead: 1.50, output: 75.00)),
        ("sonnet-4",  Pricing(input:  3.00, cacheCreate:  3.75, cacheRead: 0.30, output: 15.00)),
        ("haiku-4",   Pricing(input:  0.80, cacheCreate:  1.00, cacheRead: 0.08, output:  4.00)),
        ("opus-3",    Pricing(input: 15.00, cacheCreate: 18.75, cacheRead: 1.50, output: 75.00)),
        ("sonnet-3",  Pricing(input:  3.00, cacheCreate:  3.75, cacheRead: 0.30, output: 15.00)),
        ("haiku-3",   Pricing(input:  0.25, cacheCreate:  0.30, cacheRead: 0.03, output:  1.25)),
    ]
    private let fallbackPricing = Pricing(input: 3.00, cacheCreate: 3.75, cacheRead: 0.30, output: 15.00)

    init() {
        projectsDir = homeDirectoryPath + "/.claude/projects"
        stateFile   = stateFilePath
    }

    func pricing(for modelID: String) -> Pricing {
        let m = modelID.lowercased()
        return pricingTable.first { m.contains($0.match) }?.rates ?? fallbackPricing
    }

    func scan() {
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.doScan() }
        workItem = item
        DispatchQueue.global(qos: .background).async(execute: item)
    }

    private func doScan() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: projectsDir),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        var total = 0.0
        var lastModel = ""

        for case let url as URL in enumerator {
            guard !workItem!.isCancelled else { return }
            guard url.pathExtension == "jsonl" else { continue }
            guard let lines = try? String(contentsOf: url, encoding: .utf8) else { continue }

            for line in lines.split(separator: "\n", omittingEmptySubsequences: true) {
                guard !workItem!.isCancelled else { return }
                guard let data = line.data(using: .utf8),
                      let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      obj["type"] as? String == "assistant",
                      let msg  = obj["message"] as? [String: Any]
                else { continue }

                if let m = msg["model"] as? String, !m.isEmpty { lastModel = m }
                guard let usage = msg["usage"] as? [String: Any] else { continue }

                let p = pricing(for: lastModel)
                let inp  = (usage["input_tokens"]                   as? Double ?? Double(usage["input_tokens"]                   as? Int ?? 0))
                let cc   = (usage["cache_creation_input_tokens"]    as? Double ?? Double(usage["cache_creation_input_tokens"]    as? Int ?? 0))
                let cr   = (usage["cache_read_input_tokens"]        as? Double ?? Double(usage["cache_read_input_tokens"]        as? Int ?? 0))
                let out  = (usage["output_tokens"]                  as? Double ?? Double(usage["output_tokens"]                  as? Int ?? 0))
                total += (inp * p.input + cc * p.cacheCreate + cr * p.cacheRead + out * p.output) / 1_000_000
            }
        }

        guard !workItem!.isCancelled else { return }
        mergeCostIntoStateFile(total)
    }

    private func mergeCostIntoStateFile(_ cost: Double) {
        let url = URL(fileURLWithPath: stateFile)
        var dict: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            dict = obj
        }
        dict["total_cost_usd"] = cost
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .sortedKeys) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 2: Wire CostScanner into AppDelegate**

In `AppDelegate` class body, add a property after `var lastStateUpdatedAt: Int = 0` (line 317):

```swift
    let costScanner = CostScanner()
    var costTimer: Timer?
```

In `applicationDidFinishLaunching`, after the `update()` call (after line 328), add:

```swift
        costScanner.scan()
        costTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.costScanner.scan()
        }
```

- [ ] **Step 3: Build to verify compilation**

```bash
bash build.sh 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Verify scanner runs on launch**

```bash
open dist/ClaudeUsageBar.app
sleep 8
python3 -c "import json; d=json.load(open('$HOME/.claude/.claude-usage-state.json')); print('total_cost_usd:', d.get('total_cost_usd'))"
```

Expected: prints a number (e.g. `total_cost_usd: 14118.76`)

- [ ] **Step 5: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: add CostScanner — async JSONL cost accumulator"
```

---

## Task 4: Cost-forward menu bar title

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — `AppDelegate.update()` lines 347–437

- [ ] **Step 1: Replace the title-setting block in `update()`**

Find this block in `update()` (around lines 375–379):

```swift
            if let f = fh {
                statusItem.button?.title = " \(effectiveUsedPercentage(f, now: now))%\(stale)"
            } else {
                statusItem.button?.title = " --\(stale)"
            }
```

Replace with:

```swift
            let pct5h = fh.map { effectiveUsedPercentage($0, now: now) }
            let pctStr = pct5h.map { "\($0)%" } ?? "--"
            let costStr = state.totalCostUSD.map { formatCost($0) }

            if let btn = statusItem.button {
                if let cost = costStr {
                    let full = NSMutableAttributedString()
                    let costColor = NSColor(calibratedRed: 0.627, green: 0.910, blue: 0.565, alpha: 1.0)
                    let sepColor  = NSColor.secondaryLabelColor
                    let usageColor: NSColor = {
                        let p = pct5h ?? 0
                        if p < 70 { return NSColor(calibratedRed: 0.298, green: 0.851, blue: 0.392, alpha: 1.0) }
                        if p < 90 { return NSColor.systemOrange }
                        return NSColor.systemRed
                    }()
                    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                    full.append(NSAttributedString(string: " \(cost)", attributes: [.foregroundColor: costColor, .font: font]))
                    full.append(NSAttributedString(string: "  │  ", attributes: [.foregroundColor: sepColor, .font: font]))
                    full.append(NSAttributedString(string: "\(pctStr)\(stale)", attributes: [.foregroundColor: usageColor, .font: font]))
                    btn.attributedTitle = full
                } else {
                    btn.title = " \(pctStr)\(stale)"
                }
            }
```

- [ ] **Step 2: Build and visually check the title**

```bash
bash build.sh 2>&1 | grep -E "SUCCEEDED|error:"
open dist/ClaudeUsageBar.app
```

Expected: menu bar shows `◆ $14.1K  │  11%` (cost in green, separator in gray, pct in usage color).

- [ ] **Step 3: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: cost-forward menu bar title with attributed string colors"
```

---

## Task 5: Split-panel menu dropdown

**Files:**
- Modify: `src/ClaudeUsageBar.swift` — `AppDelegate.update()` and `NSMenu` helpers

- [ ] **Step 1: Add `addSplitPanel` to `NSMenu` extension**

Add this method inside the `extension NSMenu` block (after the `addPlain` method, before the closing `}`):

```swift
    func addSplitPanel(fiveHour: Limit?, sevenDay: Limit?, costUSD: Double?, model: String?, now: Int) {
        let item = NSMenuItem()
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 90
        let view = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

        // Divider line
        let divider = NSBox(frame: NSRect(x: panelWidth / 2, y: 8, width: 1, height: panelHeight - 16))
        divider.boxType = .separator
        view.addSubview(divider)

        // — LEFT COLUMN: cost + model —
        let leftX: CGFloat = 14
        let costLabel = NSTextField(labelWithString: costUSD.map { formatCost($0) } ?? "--")
        costLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        costLabel.textColor = NSColor(calibratedRed: 0.627, green: 0.910, blue: 0.565, alpha: 1.0)
        costLabel.frame = NSRect(x: leftX, y: panelHeight - 36, width: 120, height: 28)
        view.addSubview(costLabel)

        let allTimeLabel = NSTextField(labelWithString: "all-time cost")
        allTimeLabel.font = .systemFont(ofSize: 10)
        allTimeLabel.textColor = .tertiaryLabelColor
        allTimeLabel.frame = NSRect(x: leftX, y: panelHeight - 52, width: 120, height: 16)
        view.addSubview(allTimeLabel)

        if let m = model, !m.isEmpty {
            let shortModel = m.replacingOccurrences(of: "claude-", with: "")
            let modelLabel = NSTextField(labelWithString: shortModel)
            modelLabel.font = .systemFont(ofSize: 10)
            modelLabel.textColor = NSColor(calibratedRed: 0.565, green: 0.533, blue: 0.667, alpha: 1.0)
            modelLabel.frame = NSRect(x: leftX, y: 12, width: 120, height: 16)
            view.addSubview(modelLabel)
        }

        // — RIGHT COLUMN: 5h + 7d rows —
        let rightX: CGFloat = panelWidth / 2 + 12
        let colW:   CGFloat = panelWidth / 2 - 20

        func addUsageRow(label: String, limit: Limit?, yTop: CGFloat) {
            let pct   = limit.map { effectiveUsedPercentage($0, now: now) } ?? 0
            let color: NSColor = pct < 70
                ? NSColor(calibratedRed: 0.298, green: 0.851, blue: 0.392, alpha: 1.0)
                : pct < 90 ? .systemOrange : .systemRed

            let lbl = NSTextField(labelWithString: label)
            lbl.font = .systemFont(ofSize: 10, weight: .semibold)
            lbl.textColor = .secondaryLabelColor
            lbl.frame = NSRect(x: rightX, y: yTop - 14, width: 40, height: 13)
            view.addSubview(lbl)

            let pctLbl = NSTextField(labelWithString: limit != nil ? "\(pct)%" : "--")
            pctLbl.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            pctLbl.textColor = color
            pctLbl.frame = NSRect(x: rightX + 42, y: yTop - 16, width: 40, height: 16)
            view.addSubview(pctLbl)

            // progress bar (custom drawn)
            let barBg = NSView(frame: NSRect(x: rightX, y: yTop - 22, width: colW, height: 4))
            barBg.wantsLayer = true
            barBg.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
            barBg.layer?.cornerRadius = 2
            view.addSubview(barBg)

            if limit != nil {
                let fill = NSView(frame: NSRect(x: 0, y: 0, width: colW * CGFloat(pct) / 100, height: 4))
                fill.wantsLayer = true
                fill.layer?.backgroundColor = color.cgColor
                fill.layer?.cornerRadius = 2
                barBg.addSubview(fill)
            }

            if let limit, let ts = limit.resetsAt {
                let countdown = formatCountdown(ts, now: now)
                if !countdown.isEmpty {
                    let cdLbl = NSTextField(labelWithString: "⏰ \(countdown)")
                    cdLbl.font = .systemFont(ofSize: 10)
                    cdLbl.textColor = .tertiaryLabelColor
                    cdLbl.frame = NSRect(x: rightX + 86, y: yTop - 15, width: 52, height: 13)
                    view.addSubview(cdLbl)
                }
            }
        }

        addUsageRow(label: "5H", limit: fiveHour, yTop: panelHeight - 10)
        addUsageRow(label: "7D", limit: sevenDay,  yTop: panelHeight - 50)

        item.view = view
        addItem(item)
    }
```

- [ ] **Step 2: Replace usage rows in `update()` with split panel call**

In `AppDelegate.update()`, find this block (roughly lines 381–395):

```swift
            if let f = fh {
                m.addRow(l.session, value: "\(effectiveUsedPercentage(f, now: now))% \(l.used)", symbol: "clock")
                if let ts = f.resetsAt {
                    let rel = relativeReset(ts, now: now, l: l)
                    if !rel.isEmpty { m.addPlain(rel, size: 11, gray: true) }
                }
            }
            if let s = sd {
                m.addRow(l.weekly, value: "\(effectiveUsedPercentage(s, now: now))% \(l.used)", symbol: "calendar")
                if let ts = s.resetsAt {
                    let rel = relativeReset(ts, now: now, l: l)
                    if !rel.isEmpty { m.addPlain(rel, size: 11, gray: true) }
                }
            }
            m.addItem(.separator())
            m.addPlain("\(l.updated) \(fmt(state.updatedAt))", size: 11, gray: true)
```

Replace with:

```swift
            m.addSplitPanel(
                fiveHour: fh,
                sevenDay: sd,
                costUSD:  state.totalCostUSD,
                model:    state.model,
                now:      now
            )
            m.addItem(.separator())
            m.addPlain("\(l.updated) \(fmt(state.updatedAt))", size: 11, gray: true)
```

- [ ] **Step 3: Build and visually inspect the dropdown**

```bash
bash build.sh 2>&1 | grep -E "SUCCEEDED|error:"
open dist/ClaudeUsageBar.app
```

Click the menu bar icon. Expected: split panel with cost on left, two usage rows with progress bars and countdowns on right.

- [ ] **Step 4: Commit**

```bash
git add src/ClaudeUsageBar.swift
git commit -m "feat: split-panel menu dropdown with cost, model, progress bars, countdowns"
```

---

## Task 6: Update widget — add cost + model, split-column layout

**Files:**
- Modify: `widget/ClaudeUsageBarWidget.swift`

- [ ] **Step 1: Add `model` and `totalCostUSD` to `WUsageState` and `UsageEntry`**

Replace lines 24–51 with:

```swift
struct WUsageState: Codable {
    let updatedAt:    Int
    let rateLimits:   WRateLimits?
    let model:        String?
    let totalCostUSD: Double?
    enum CodingKeys: String, CodingKey {
        case updatedAt    = "updated_at"
        case rateLimits   = "rate_limits"
        case model        = "model"
        case totalCostUSD = "total_cost_usd"
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
    let date:           Date
    let fiveHour:       WLimit?
    let sevenDay:       WLimit?
    let updatedAt:      Int?
    let claudeCodeStatus: String?
    let claudeAPIStatus:  String?
    let model:          String?
    let totalCostUSD:   Double?
}
```

- [ ] **Step 2: Update `readUsageEntry` to pass new fields**

Replace the `readUsageEntry` function (lines 105–120) with:

```swift
    private func readUsageEntry(claudeCodeStatus: String?, claudeAPIStatus: String?) -> UsageEntry {
        guard let data  = FileManager.default.contents(atPath: stateFilePath),
              let state = try? JSONDecoder().decode(WUsageState.self, from: data)
        else {
            return UsageEntry(date: Date(), fiveHour: nil, sevenDay: nil,
                              updatedAt: nil, claudeCodeStatus: nil, claudeAPIStatus: nil,
                              model: nil, totalCostUSD: nil)
        }
        return UsageEntry(
            date:             Date(),
            fiveHour:         state.rateLimits?.fiveHour,
            sevenDay:         state.rateLimits?.sevenDay,
            updatedAt:        state.updatedAt,
            claudeCodeStatus: claudeCodeStatus,
            claudeAPIStatus:  claudeAPIStatus,
            model:            state.model,
            totalCostUSD:     state.totalCostUSD
        )
    }
```

- [ ] **Step 3: Update `getTimeline` to pass new fields**

Replace the `entry` construction in `getTimeline` (lines 92–98):

```swift
            let entry = UsageEntry(
                date:             usage.date,
                fiveHour:         usage.fiveHour,
                sevenDay:         usage.sevenDay,
                updatedAt:        usage.updatedAt,
                claudeCodeStatus: ccStatus,
                claudeAPIStatus:  apiStatus,
                model:            usage.model,
                totalCostUSD:     usage.totalCostUSD
            )
```

Also update `placeholder` return in `getSnapshot` (line 77):

```swift
        completion(readUsageEntry(claudeCodeStatus: nil, claudeAPIStatus: nil))
```

And update the `placeholder` method (lines 64–73):

```swift
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(
            date: Date(),
            fiveHour: WLimit(usedPercentage: 72, resetsAt: nil),
            sevenDay: WLimit(usedPercentage: 45, resetsAt: nil),
            updatedAt: nil,
            claudeCodeStatus: "operational",
            claudeAPIStatus:  "operational",
            model: "sonnet-4-6",
            totalCostUSD: 14118.0
        )
    }
```

- [ ] **Step 4: Add `wFormatCost()` helper to widget**

Add after `wUpdatedLabel` function (after line 153):

```swift
func wFormatCost(_ usd: Double) -> String {
    if usd >= 1_000_000 { return String(format: "$%.1fM", usd / 1_000_000) }
    if usd >= 10_000    { return String(format: "$%.1fK", usd / 1_000) }
    return "$\(Int(usd))"
}

func wFormatCountdown(_ resetsAt: Int, now: Int = Int(Date().timeIntervalSince1970)) -> String {
    let delta = resetsAt - now
    guard delta > 0 else { return "" }
    if delta < 60    { return "< 1m" }
    if delta < 3600  { return "\(delta / 60)m" }
    if delta < 86400 { return "\(delta / 3600)h \((delta % 3600) / 60)m" }
    return "\(delta / 86400)d \((delta % 86400) / 3600)h"
}
```

- [ ] **Step 5: Rewrite `MediumWidgetView` as split columns**

Replace lines 253–289 with:

```swift
// MARK: — Medium widget view

struct CostColumnView: View {
    let totalCostUSD: Double?
    let model: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("COST")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(totalCostUSD.map { wFormatCost($0) } ?? "--")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.627, green: 0.910, blue: 0.565))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("all-time")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Spacer()
            if let m = model, !m.isEmpty {
                Text(m.replacingOccurrences(of: "claude-", with: ""))
                    .font(.system(size: 9))
                    .foregroundStyle(Color(red: 0.565, green: 0.533, blue: 0.667))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

struct CompactUsageRow: View {
    let label: String
    let limit: WLimit?

    var body: some View {
        let pct   = limit.map { wEffectivePct($0) } ?? 0
        let color = limit != nil ? wColor(for: pct) : Color.secondary
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(limit != nil ? "\(pct)%" : "--")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let limit, let ts = limit.resetsAt {
                    let cd = wFormatCountdown(ts)
                    if !cd.isEmpty {
                        Text("⏰\(cd)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(.quaternary).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * CGFloat(pct) / 100, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

struct MediumWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        if entry.fiveHour == nil && entry.sevenDay == nil && entry.totalCostUSD == nil {
            NoDataView()
        } else {
            HStack(alignment: .top, spacing: 0) {
                CostColumnView(totalCostUSD: entry.totalCostUSD, model: entry.model)
                    .frame(maxWidth: .infinity)
                Divider().padding(.horizontal, 10)
                VStack(alignment: .leading, spacing: 10) {
                    Text("USAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    CompactUsageRow(label: "5H", limit: entry.fiveHour)
                    CompactUsageRow(label: "7D", limit: entry.sevenDay)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
    }
}
```

- [ ] **Step 6: Update `LargeWidgetView` to show cost in header**

Replace the header `HStack` in `LargeWidgetView` (lines 301–311) with:

```swift
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label("Claude Code Usage", systemImage: "terminal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        if let cost = entry.totalCostUSD {
                            Text(wFormatCost(cost))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.627, green: 0.910, blue: 0.565))
                        }
                    }
                    Spacer()
                    if let ts = entry.updatedAt {
                        Text(wUpdatedLabel(ts))
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 14)
```

- [ ] **Step 7: Build widget and verify compilation**

```bash
bash build.sh 2>&1 | grep -E "SUCCEEDED|error:"
```

Expected: `** BUILD SUCCEEDED **` with no errors.

- [ ] **Step 8: Commit**

```bash
git add widget/ClaudeUsageBarWidget.swift
git commit -m "feat: widget split-column layout with cost, model, compact usage rows, countdowns"
```

---

## Task 7: Full build + install + smoke test

- [ ] **Step 1: Clean build**

```bash
bash build.sh 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **` and `dist/ClaudeUsageBar.dmg` created.

- [ ] **Step 2: Install and verify**

```bash
bash install.sh
sleep 5
python3 -c "
import json
d = json.load(open('$HOME/.claude/.claude-usage-state.json'))
print('model:', d.get('model'))
print('total_cost_usd:', d.get('total_cost_usd'))
print('updated_at:', d.get('updated_at'))
"
```

Expected: model and total_cost_usd fields present.

- [ ] **Step 3: Trigger statusline hook and verify model field updates**

```bash
echo '{"rate_limits":{"five_hour":{"used_percentage":20,"resets_at":1999999999},"seven_day":{"used_percentage":3,"resets_at":1999999999}},"model":{"id":"claude-opus-4-7"}}' \
  | "/Applications/ClaudeUsageBar.app/Contents/MacOS/ClaudeUsageBar" --statusline
cat ~/.claude/.claude-usage-state.json
```

Expected: `"model":"claude-opus-4-7"` in state file. Menu bar should update within 60s (or open menu to force refresh).

- [ ] **Step 4: Final commit**

```bash
git add -A
git status
git commit -m "feat: enhanced usage bar — cost, countdown, model, split-panel menu + widget"
```
