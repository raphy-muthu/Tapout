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
    /// While a timer lock is running (locked or in a pass, and not yet due), when it ends. The faces count
    /// down to it instead of up. A field, not a `State`, so every switch over the state keeps working.
    var timerEndsAt: Date?

    /// `history` is the store's lock history, read once by `timeline` for all its entries.
    static func make(store: SharedStore, now: Date, calendar: Calendar = .current,
                     history stored: [LockRecord]? = nil) -> LockSnapshot {
        let session = store.session
        let history = effectiveHistory(stored ?? store.lockHistory, store: store, session: session)
        let running = history.last { $0.end == nil }
        let place = running?.placeUID.flatMap { uid in store.pairedTags.first { $0.uid == uid }?.name }
        // A timer that has come due reads as the unlock it is about to be, even before the app or the
        // monitor has written it, and its record stops counting at the timer's end.
        let timer = store.timerLock.flatMap { timer -> TimerLock? in
            if case .unlocked = session { return nil }
            return timer
        }
        let overTimer = timer.flatMap { $0.isDue(now: now, early: 0) ? $0 : nil }
        let statsNow = overTimer.map { min(now, $0.endsAt) } ?? now
        let lockedSoFar = running?.lockedTime(now: now)
        let state: State
        switch session {
        case .unlocked:
            state = .unlocked
        case _ where overTimer != nil:
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
        let today = calendar.dateInterval(of: .day, for: statsNow)
            .map { Insights.lockedTime(in: $0, history: history, now: statsNow) } ?? 0
        return LockSnapshot(
            state: state,
            modeName: store.activeModeName ?? "Focus",
            placeName: place,
            today: today,
            weekTotal: Insights.lockedTime(in: Insights.week(of: statsNow, calendar: calendar), history: history, now: statsNow),
            days: Insights.days(weekOf: statsNow, history: history, now: statsNow, calendar: calendar),
            timerEndsAt: overTimer == nil ? timer?.endsAt : nil
        )
    }

    /// The history as the app will write it once it next runs. Only the app writes the history, so while Tapout
    /// is closed the monitor's changes aren't in it yet: a timer the monitor ended still has an open record, an
    /// unlock leaves one open, and a lock a schedule started has none. Without this the totals would keep counting.
    static func effectiveHistory(_ stored: [LockRecord], store: SharedStore, session: LockSession) -> [LockRecord] {
        var history = stored
        if let index = history.lastIndex(where: { $0.end == nil }) {
            let open = history[index]
            if let finished = store.finishedTimer, !TimerLock.wasClosed(finished, store: store), open.start < finished.endsAt {
                history[index].end = finished.endsAt
                history[index].endPass(at: finished.endsAt)
            } else if case .unlocked = session, let unlockedAt = store.lastUnlockAt, unlockedAt >= open.start {
                history[index].end = unlockedAt
                history[index].endPass(at: unlockedAt)
            }
        }
        if case .locked(let since) = session, !history.contains(where: { $0.end == nil }) {
            let lastEnd = history.compactMap(\.end).max()
            let start = max(since, lastEnd ?? since)
            history.append(LockRecord(start: start, end: nil, placeUID: nil, modeID: store.activeModeID ?? UUID()))
        }
        return history
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
        let history = store.lockHistory
        let first = make(store: store, now: now, calendar: calendar, history: history)
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
        // A timer lock ends the window at its end, with an entry that reads unlocked, when that is sooner.
        if let end = first.timerEndsAt, let last = dates.last, end <= last {
            dates = dates.filter { $0 < end } + [end]
        }
        if let last = dates.last, midnight > now, midnight <= last { dates.append(midnight) }
        dates = Array(Set(dates)).sorted()
        return SnapshotTimeline(
            entries: dates.map { date in
                SnapshotTimeline.Entry(date: date, snapshot: date == now ? first
                                       : make(store: store, now: date, calendar: calendar, history: history))
            },
            reloadAfter: dates.last ?? midnight
        )
    }

    /// Made-up numbers for previews, the widget gallery and the widget placeholder only. Never shown
    /// as real data.
    static func sample(_ state: State, timerEndsAt: Date? = nil) -> LockSnapshot {
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
            },
            timerEndsAt: timerEndsAt
        )
    }

    /// Placeholder content only (the widget placeholder and previews); not read from the store.
    static let placeholder = sample(.unlocked)

    /// Sample lock lengths for previews and the gallery: 47:12, 1:47:12 and 10:47:12.
    static let sampleLockLengths: [TimeInterval] = [2832, 6432, 38_832]

    /// Sample timer locks for previews and the gallery: (length, time left) of 45 min with 31 min left,
    /// and 10 h with all of it left (the widest the countdown gets).
    static let sampleTimers: [(length: TimeInterval, left: TimeInterval)] = [(2700, 1860), (36_000, 36_000)]

    /// A sample timer lock of `length` with `left` to go, for previews and the gallery only.
    static func sampleTimer(length: TimeInterval, left: TimeInterval) -> LockSnapshot {
        sample(.locked(countingFrom: .now - (length - left)), timerEndsAt: .now + left)
    }

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
