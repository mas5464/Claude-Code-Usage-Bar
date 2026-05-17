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
