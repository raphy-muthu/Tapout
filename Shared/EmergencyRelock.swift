import Foundation

/// The relock step itself, shared by the app (when it is open at the relock time)
/// and the monitor extension (when it is not).
enum EmergencyRelock {
    /// A callback this much before the relock time still relocks; strict beats late.
    static let earlyTolerance: TimeInterval = 60

    /// The one rule for "this pass is over", used by the app and the monitor.
    /// Due a little before the relock time, or when the clock was set back so far that the
    /// relock time is further away than the pass is long (the pass would otherwise stretch).
    /// `early` is how soon before the relock time counts: the monitor allows `earlyTolerance` for a
    /// callback that comes a little early; the app, which owns the timer, waits for the exact time.
    /// `realElapsed` is the pass's real age by the monotonic clock (`ClockAnchor`), when known: a pass that has
    /// really lasted its length is over even if the clock was moved back to keep it open. Relocking early is the
    /// safe side, so any one of the three signs is enough.
    static func isDue(relockAt: Date, duration: TimeInterval, now: Date, early: TimeInterval = earlyTolerance,
                      realElapsed: TimeInterval? = nil) -> Bool {
        if let realElapsed, realElapsed >= duration - early { return true }
        return now >= relockAt - early || relockAt.timeIntervalSince(now) > duration
    }

    /// Whether an emergency pass is open and over. False for any other state.
    static func isDue(session: LockSession, now: Date, early: TimeInterval = earlyTolerance,
                      realElapsed: TimeInterval? = nil) -> Bool {
        guard case .emergency(let relockAt, let duration) = session else { return false }
        return isDue(relockAt: relockAt, duration: duration, now: now, early: early, realElapsed: realElapsed)
    }

    /// The open pass's real age, from the anchor saved when it was used and `clock` (the monotonic clock now).
    static func realElapsed(store: SharedStore, clock: ClockAnchor?) -> TimeInterval? {
        store.passAnchor?.elapsed(until: clock)
    }

    /// Real seconds until the open pass is over by the monotonic clock, or nil when unknown.
    static func realRemaining(store: SharedStore, clock: ClockAnchor?) -> TimeInterval? {
        guard case .emergency(_, let duration) = store.session,
              let elapsed = realElapsed(store: store, clock: clock) else { return nil }
        return max(0, duration - elapsed)
    }

    /// Relocks an open emergency pass that is due. Returns seconds past the relock time (negative = early),
    /// or nil when no pass was open or it is not due yet (for example a stale callback from an
    /// earlier pass's interval arriving just after a second pass opened).
    static func perform(store: SharedStore, shields: some Shielding, now: Date, clock: ClockAnchor? = nil) -> TimeInterval? {
        guard case .emergency(let relockAt, let duration) = store.session,
              isDue(relockAt: relockAt, duration: duration, now: now,
                    realElapsed: realElapsed(store: store, clock: clock)) else { return nil }
        shields.apply(store.activeShieldPlan)
        store.session = .locked(since: relockAt)
        store.passAnchor = nil
        return now.timeIntervalSince(relockAt)
    }
}
