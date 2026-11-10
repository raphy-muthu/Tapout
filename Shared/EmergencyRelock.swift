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
    static func isDue(relockAt: Date, duration: TimeInterval, now: Date, early: TimeInterval = earlyTolerance) -> Bool {
        now >= relockAt - early || relockAt.timeIntervalSince(now) > duration
    }

    /// Whether an emergency pass is open and over. False for any other state.
    static func isDue(session: LockSession, now: Date, early: TimeInterval = earlyTolerance) -> Bool {
        guard case .emergency(let relockAt, let duration) = session else { return false }
        return isDue(relockAt: relockAt, duration: duration, now: now, early: early)
    }

    /// Relocks an open emergency pass that is due. Returns seconds past the relock time (negative = early),
    /// or nil when no pass was open or it is not due yet (for example a stale callback from an
    /// earlier pass's interval arriving just after a second pass opened).
    static func perform(store: SharedStore, shields: some Shielding, now: Date) -> TimeInterval? {
        guard case .emergency(let relockAt, let duration) = store.session,
              isDue(relockAt: relockAt, duration: duration, now: now) else { return nil }
        shields.apply(store.activeShieldPlan)
        store.session = .locked(since: relockAt)
        return now.timeIntervalSince(relockAt)
    }
}
