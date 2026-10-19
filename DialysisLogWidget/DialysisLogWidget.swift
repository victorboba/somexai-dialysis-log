import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

struct DialysisLogWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Today", systemImage: "drop.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if entry.snapshot.prescribedCount > 0 {
                Text("\(entry.snapshot.todayCount) of \(entry.snapshot.prescribedCount)")
                    .font(.system(size: family == .systemSmall ? 30 : 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("exchanges done").font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(entry.snapshot.todayCount)")
                    .font(.system(size: family == .systemSmall ? 38 : 46, weight: .bold, design: .rounded))
                Text("recorded today").font(.caption2).foregroundStyle(.secondary)
            }

            if entry.snapshot.hasTodayUF {
                Text("\(entry.snapshot.todayUF) mL off")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.snapshot.todayUF < 0 ? .orange : .secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct DialysisLogWidget: Widget {
    let kind = "DialysisLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            DialysisLogWidgetView(entry: entry)
        }
        .configurationDisplayName(AppConfig.appName)
        .description("\(AppConfig.entryNounPlural) this week and your latest one.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DialysisLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        DialysisLogWidget()
    }
}
