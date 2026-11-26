import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: LockSnapshot
    /// Draw the flat-color faces (the Lab's Living glass switch).
    var flat = false
}

/// Timelines from `LockSnapshot.timeline`; the app and the monitor also reload them after a change.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder, flat: LivingGlassMirror.isOn())
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let now = Date.now
        completion(context.isPreview ? placeholder(in: context)
                   : SnapshotEntry(date: now, snapshot: .make(store: .appGroup(), now: now), flat: LivingGlassMirror.isOn()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let timeline = LockSnapshot.timeline(store: .appGroup(), now: .now)
        let flat = LivingGlassMirror.isOn()
        let entries = timeline.entries.map { SnapshotEntry(date: $0.date, snapshot: $0.snapshot, flat: flat) }
        completion(Timeline(entries: entries, policy: .after(timeline.reloadAfter)))
    }
}
