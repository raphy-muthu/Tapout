import SwiftUI
import WidgetKit

/// Small on the Home Screen; circular and rectangular on the Lock Screen.
struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tapout.status", provider: SnapshotProvider()) { entry in
            StatusFamilyView(snapshot: entry.snapshot, date: entry.date)
        }
        .configurationDisplayName("Tapout")
        .description("Locked, or phone-free today.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private struct StatusFamilyView: View {
    let snapshot: LockSnapshot
    let date: Date
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularFace(snapshot: snapshot, date: date).containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            RectangularFace(snapshot: snapshot, date: date).containerBackground(.clear, for: .widget)
        default:
            SmallFace(snapshot: snapshot, date: date, tinted: renderingMode != .fullColor).containerBackground(Color.surface1, for: .widget)
        }
    }
}

private struct WeekFamilyView: View {
    let snapshot: LockSnapshot
    let date: Date
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        MediumFace(snapshot: snapshot, date: date, tinted: renderingMode != .fullColor)
            .containerBackground(Color.surface1, for: .widget)
    }
}

/// Medium on the Home Screen: this week.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tapout.week", provider: SnapshotProvider()) { entry in
            WeekFamilyView(snapshot: entry.snapshot, date: entry.date)
        }
        .configurationDisplayName("This week")
        .description("Phone-free time this week.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("Small · locked", as: .systemSmall) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
    SnapshotEntry(date: .now, snapshot: .sampleLocked(for: LockSnapshot.sampleLockLengths[1]))
    SnapshotEntry(date: .now, snapshot: .sampleLocked(for: LockSnapshot.sampleLockLengths[2]))
    SnapshotEntry(date: .now, snapshot: .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
    SnapshotEntry(date: .now, snapshot: .sample(.unlocked))
}

#Preview("Medium", as: .systemMedium) {
    WeekWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
}

#Preview("Circular", as: .accessoryCircular) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
    SnapshotEntry(date: .now, snapshot: .sampleLocked(for: LockSnapshot.sampleLockLengths[2]))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
    SnapshotEntry(date: .now, snapshot: .sampleLocked(for: LockSnapshot.sampleLockLengths[2]))
}
