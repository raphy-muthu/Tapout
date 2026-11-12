import Foundation

/// What the Live Activity and the widgets show, worked out from the App Group store at one moment.
/// They run outside Tapout's model, so they read the store the monitor and the app share.
struct LockSnapshot: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case unlocked
        /// A timer counting up from `countingFrom` shows the lock's time without pass time.
        case locked(countingFrom: Date)
        /// An emergency pass: apps are open until `relockAt`; then the locked timer resumes from `resumesFrom`.
        case open(relockAt: Date, resumesFrom: Date)
    }

    var state: State
    var modeName: String
    var placeName: String?
    /// Locked time since midnight, without pass time.
    var today: TimeInterval
    /// Locked time this week, and per day for the bars.
    var weekTotal: TimeInterval
    var days: [Insights.Day]

    static func make(store: SharedStore, now: Date, calendar: Calendar = .current) -> LockSnapshot {
        let history = store.lockHistory
        let running = history.last { $0.end == nil }
        let place = running?.placeUID.flatMap { uid in store.pairedTags.first { $0.uid == uid }?.name }
        let lockedSoFar = running?.lockedTime(now: now)
        let state: State
        switch store.session {
        case .unlocked:
            state = .unlocked
        case .locked(let since):
            // Without a record yet (a schedule just locked), the lock state's start is the best guess.
            // A start after `now` (the clock moved back) never gives a start in the future.
            state = .locked(countingFrom: now - max(0, lockedSoFar ?? now.timeIntervalSince(since)))
        case .emergency(let relockAt, _):
            if relockAt <= now {
                // The pass is over; the relock just hasn't been written yet (late monitor, or an entry
                // built just after the relock time). `lockedSoFar` already counts the time since then.
                state = .locked(countingFrom: now - max(0, lockedSoFar ?? 0))
            } else {
                state = .open(relockAt: relockAt, resumesFrom: relockAt - (lockedSoFar ?? 0))
            }
        }
        let today = calendar.dateInterval(of: .day, for: now)
            .map { Insights.lockedTime(in: $0, history: history, now: now) } ?? 0
        return LockSnapshot(
            state: state,
            modeName: store.activeModeName ?? "Focus",
            placeName: place,
            today: today,
            weekTotal: Insights.lockedTime(in: Insights.week(of: now, calendar: calendar), history: history, now: now),
            days: Insights.days(weekOf: now, history: history, now: now, calendar: calendar)
        )
    }

    /// The state to draw at `date`: once a pass's relock time comes, it reads as the lock it resumes,
    /// so a face never shows a countdown past 0:00 while it waits for the next entry.
    func state(at date: Date) -> State {
        if case .open(let relockAt, let resumesFrom) = state, relockAt <= date {
            return .locked(countingFrom: resumesFrom)
        }
        return state
    }

    /// While locked, widgets redraw this often (for the totals) over this long before asking for a reload.
    static let lockedRedraw: TimeInterval = 15 * 60
    static let lockedWindow: TimeInterval = 4 * 3600

    /// A widget timeline from the store: a running timer ticks on its own, but totals need redraws,
    /// a pass needs one at its relock time, and everything needs one at midnight. Unlocked, that is
    /// `now` and midnight; locked, every 15 minutes for 4 hours; during a pass, `now`, then the lock
    /// from the relock time on. The app and the monitor also reload the timelines after a change.
    static func timeline(store: SharedStore, now: Date, calendar: Calendar = .current) -> SnapshotTimeline {
        let first = make(store: store, now: now, calendar: calendar)
        let midnight = calendar.dateInterval(of: .day, for: now)?.end ?? now + 86_400
        func lockedDates(from start: Date) -> [Date] {
            (0...Int(lockedWindow / lockedRedraw)).map { start + Double($0) * lockedRedraw }
        }
        var dates: [Date]
        switch first.state {
        case .unlocked: dates = [now, midnight]
        case .locked: dates = lockedDates(from: now)
        case .open(let relockAt, _): dates = [now] + lockedDates(from: relockAt)
        }
        if let last = dates.last, midnight > now, midnight <= last { dates.append(midnight) }
        dates = Array(Set(dates)).sorted()
        return SnapshotTimeline(
            entries: dates.map { date in
                SnapshotTimeline.Entry(date: date, snapshot: date == now ? first : make(store: store, now: date, calendar: calendar))
            },
            reloadAfter: dates.last ?? midnight
        )
    }

    /// Made-up numbers for previews, the widget gallery and the widget placeholder only. Never shown
    /// as real data.
    static func sample(_ state: State) -> LockSnapshot {
        let bars: [TimeInterval] = [2700, 1800, 3720, 2280, 6000, 4200, 1200]
        let monday = Calendar.current.startOfDay(for: .now)
        return LockSnapshot(
            state: state,
            modeName: "Deep work",
            placeName: "Kitchen",
            today: 9600,
            weekTotal: bars.reduce(0, +),
            days: bars.enumerated().map { index, time in
                Insights.Day(start: monday + Double(index) * 86_400, letter: ["M", "T", "W", "T", "F", "S", "S"][index],
                             lockedTime: time, isToday: index == 4)
            }
        )
    }

    /// Placeholder content only (the widget placeholder and previews); not read from the store.
    static let placeholder = sample(.unlocked)

    /// Sample lock lengths for previews and the gallery: 47:12, 1:47:12 and 10:47:12.
    static let sampleLockLengths: [TimeInterval] = [2832, 6432, 38_832]

    /// A sample lock that has run for `length`, for previews and the gallery only.
    static func sampleLocked(for length: TimeInterval) -> LockSnapshot {
        sample(.locked(countingFrom: .now - length))
    }
}

/// The entries a widget timeline shows, and when WidgetKit should ask for the next one.
struct SnapshotTimeline: Sendable {
    struct Entry: Equatable, Sendable {
        var date: Date
        var snapshot: LockSnapshot
    }

    var entries: [Entry]
    var reloadAfter: Date
}
