import Foundation

/// A lock that ends by itself. It sits beside an ordinary `.locked` session in the App Group store,
/// so everything that reads the session keeps working; the timer only adds the end.
struct TimerLock: Codable, Equatable, Sendable {
    static let minimum: TimeInterval = 5 * 60
    static let maximum: TimeInterval = 12 * 3600
    /// A monitor callback this much before the end still finishes the timer; strict beats late.
    static let earlyTolerance: TimeInterval = 60

    let start: Date
    let duration: TimeInterval

    var endsAt: Date { start + duration }

    /// Seconds left, 0 when over. A clock set back never shows more than `duration`.
    func remaining(at now: Date) -> TimeInterval {
        min(duration, max(0, endsAt.timeIntervalSince(now)))
    }

    /// 0...1, share of the timer still left, for the orb ring.
    func remainingFraction(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, remaining(at: now) / duration)
    }

    /// Same rule as `EmergencyRelock.isDue`: due a little before the end, or when the clock was set back
    /// so far that the end is further away than the timer is long (it would otherwise stretch).
    /// `early` is how soon before the end counts: the monitor allows `earlyTolerance`; the app waits for the exact time.
    func isDue(now: Date, early: TimeInterval) -> Bool {
        EmergencyRelock.isDue(relockAt: endsAt, duration: duration, now: now, early: early)
    }

    /// `duration` clamped to `minimum...maximum`.
    static func clamped(_ duration: TimeInterval) -> TimeInterval {
        min(maximum, max(minimum, duration))
    }

    /// What `finish` did: the timer that ended, and the mode whose scheduled lock took over, if any.
    struct Finish: Equatable {
        let timer: TimerLock
        let handedOverTo: Mode?
    }

    /// The finish step the app and the monitor both run. If the store holds a due timer and the session is
    /// `.locked` or `.emergency`, it ends the timer and returns what happened. Otherwise it returns nil and writes nothing.
    /// - When a mode's scheduled window is running and its schedule would lock now (`ScheduledLock.handover`,
    ///   checked before anything is written, so the timer's own end never counts as an unlock), the lock carries on
    ///   as that mode's scheduled lock: the mode becomes active, the session is locked from now, its shields
    ///   replace the timer mode's (no clear first, so no gap), and no unlock time is written.
    /// - Otherwise it clears the shields, stamps `lastUnlockAt` and unlocks. The order is `LockEngine.unlock`'s:
    ///   the unlock time first, so a monitor start landing between the writes sees the unlock; then the session.
    /// Either way the timer moves to `finishedTimer` last (the app closes the record later).
    /// `accessApproved` is what the caller can see of Screen Time access, as for a schedule start.
    static func finish(
        store: SharedStore,
        shields: some Shielding,
        now: Date,
        early: TimeInterval,
        accessApproved: Bool,
        hasApps: ((Mode) -> Bool)? = nil,
        hasTag: Bool? = nil,
        calendar: Calendar = .current
    ) -> Finish? {
        guard let timer = store.timerLock, timer.isDue(now: now, early: early) else { return nil }
        switch store.session {
        case .locked, .emergency: break
        case .unlocked: return nil
        }
        let mode = ScheduledLock.handover(store: store, now: now, accessApproved: accessApproved,
                                          hasApps: hasApps, hasTag: hasTag, calendar: calendar)
        if let mode {
            store.activeModeID = mode.id
            store.activeModeName = mode.name
            store.session = .locked(since: now)
            shields.apply(store.activeShieldPlan)
        } else {
            shields.clear()
            store.lastUnlockAt = now
            store.session = .unlocked
        }
        store.finishedTimerHandover = mode?.name
        store.finishedTimer = timer
        store.timerLock = nil
        return Finish(timer: timer, handedOverTo: mode)
    }

    /// Whether the app already ended or closed `timer`, so a `finishedTimer` holding it is a late write to ignore.
    static func wasClosed(_ timer: TimerLock, store: SharedStore) -> Bool {
        store.lastClosedTimerStart.map { timer.start <= $0 } ?? false
    }

    /// A timer left behind an unlocked session (a crash inside `finish` or `LockEngine.unlock`). A due one that
    /// nobody has closed moves to `finishedTimer`, so its record still ends at its end; any other is dropped.
    /// Every new lock runs this first, so a stale timer never ends a lock that isn't it.
    static func settleStale(store: SharedStore, now: Date) {
        guard store.session == .unlocked, let timer = store.timerLock else { return }
        if store.finishedTimer == nil, timer.isDue(now: now, early: earlyTolerance), !wasClosed(timer, store: store) {
            store.finishedTimerHandover = nil
            store.finishedTimer = timer
        }
        store.timerLock = nil
    }
}

// MARK: - Monitor

extension TimerLock {
    /// The monitor's step at the timer activity's callbacks: finishes a due timer (with the monitor's
    /// `earlyTolerance`) and posts the "Time's up" notice, or the scheduled mode's notice on a hand-over.
    /// `accessApproved` is the monitor's access rule (`ScheduledLock.accessApproved`), passed in so tests can set it.
    /// Returns the log line.
    static func runMonitorEnd(store: SharedStore, shields: some Shielding, notifier: some LockNotifying, now: Date,
                              accessApproved: Bool, hasApps: ((Mode) -> Bool)? = nil, hasTag: Bool? = nil,
                              calendar: Calendar = .current) -> String {
        if let finish = finish(store: store, shields: shields, now: now, early: earlyTolerance,
                               accessApproved: accessApproved, hasApps: hasApps, hasTag: hasTag, calendar: calendar) {
            if let mode = finish.handedOverTo {
                let notice = ScheduleNotice.timerHandedOver(mode)
                notifier.post(title: notice.title, body: notice.body)
                return "timer: finished, handed over to \(mode.name)"
            }
            let notice = ScheduleNotice.timerFinished(duration: finish.timer.duration)
            notifier.post(title: notice.title, body: notice.body)
            return "timer: finished"
        }
        return store.timerLock == nil ? "timer: nothing to finish" : "timer: not due yet"
    }

    /// The monitor's step at the emergency relock callbacks. A due timer finishes first, so a pass's relock
    /// never re-locks a timer that is over; the pass relocks only if the session is still `.emergency`.
    /// Returns the log lines (the timer's only when a timer is running) and whether anything changed.
    static func runMonitorRelock(store: SharedStore, shields: some Shielding, notifier: some LockNotifying,
                                 now: Date, accessApproved: Bool, hasApps: ((Mode) -> Bool)? = nil,
                                 hasTag: Bool? = nil, calendar: Calendar = .current) -> (lines: [String], changed: Bool) {
        var lines: [String] = []
        var changed = false
        if store.timerLock != nil {
            let line = runMonitorEnd(store: store, shields: shields, notifier: notifier, now: now,
                                     accessApproved: accessApproved, hasApps: hasApps, hasTag: hasTag, calendar: calendar)
            lines.append(line)
            changed = line.hasPrefix("timer: finished")
        }
        if let late = EmergencyRelock.perform(store: store, shields: shields, now: now) {
            lines.append("relocked, \(Int(late))s after relock time")
            changed = true
        } else if case .emergency = store.session {
            lines.append("not due yet")
        } else {
            lines.append("nothing to relock")
        }
        return (lines, changed)
    }
}
