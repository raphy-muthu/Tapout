import ActivityKit
import Foundation

/// The lock's Live Activity. Everything it shows is in the content state; no static attributes.
struct LockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// The locked timer counts up from here, so it leaves out pass time.
        var lockedFrom: Date
        /// During an emergency pass, apps are open until then. Also the activity's stale date (unless a timer
        /// ends first), so it shows the locked timer again after the relock even if Tapout stays closed.
        var openUntil: Date?
        var modeName: String
        var placeName: String?
        /// While a timer lock runs, when it ends: the activity counts down to it instead of up. Optional and
        /// decoded as nil when absent, so an activity started by an older build keeps working.
        var timerEndsAt: Date?

        init(lockedFrom: Date, openUntil: Date?, modeName: String, placeName: String?, timerEndsAt: Date? = nil) {
            self.lockedFrom = lockedFrom
            self.openUntil = openUntil
            self.modeName = modeName
            self.placeName = placeName
            self.timerEndsAt = timerEndsAt
        }

        /// Whether a stale activity is stale because its timer ended (the timer's end is the stale date, see
        /// `LiveActivityPlan.staleDate`): the apps are open, so it reads "Time's up" rather than 0:00 left.
        /// A pass that went stale before the timer's end keeps the timer's reading.
        func timerIsOver(isStale: Bool) -> Bool {
            guard isStale, let end = timerEndsAt else { return false }
            return end <= (openUntil ?? .distantFuture)
        }
    }
}

/// What to do with the Live Activity so it matches the lock. Pure, so it can be tested.
enum LiveActivityPlan {
    enum Action: Equatable {
        case none
        case start(LockActivityAttributes.ContentState)
        case update(LockActivityAttributes.ContentState)
        case end
    }

    /// nil while unlocked. Dates are whole seconds, so recomputing a snapshot doesn't cause updates. A
    /// changed end date makes the content differ, so `decide` updates the activity when a timer starts or ends.
    static func content(for snapshot: LockSnapshot) -> LockActivityAttributes.ContentState? {
        func whole(_ date: Date) -> Date { Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded()) }
        switch snapshot.state {
        case .unlocked:
            return nil
        case .locked(let from):
            return .init(lockedFrom: whole(from), openUntil: nil, modeName: snapshot.modeName, placeName: snapshot.placeName,
                         timerEndsAt: snapshot.timerEndsAt.map(whole))
        case .open(let relockAt, let resumesFrom):
            return .init(lockedFrom: whole(resumesFrom), openUntil: whole(relockAt), modeName: snapshot.modeName,
                         placeName: snapshot.placeName, timerEndsAt: snapshot.timerEndsAt.map(whole))
        }
    }

    /// When the activity's content goes out of date: a pass's relock or a timer's end, whichever comes first.
    /// Tapout may be closed then (the monitor ends the timer), so the views use the stale flag to read
    /// "Open" again after a pass, or "Time's up" after a timer. nil for a plain lock.
    static func staleDate(for state: LockActivityAttributes.ContentState) -> Date? {
        [state.openUntil, state.timerEndsAt].compactMap { $0 }.min()
    }

    /// What ActivityKit reports for an activity, reduced to what matters here.
    enum Phase: Equatable {
        case active, stale, over
    }

    /// Only running activities count as current. One iOS ended at its 8-hour limit can stay listed
    /// for a while and must not stop a new one from starting.
    static func countsAsCurrent(_ phase: Phase) -> Bool { phase != .over }

    static func decide(snapshot: LockSnapshot, enabled: Bool, current: LockActivityAttributes.ContentState?) -> Action {
        guard enabled, let wanted = content(for: snapshot) else { return current == nil ? .none : .end }
        guard let current else { return .start(wanted) }
        return current == wanted ? .none : .update(wanted)
    }
}
