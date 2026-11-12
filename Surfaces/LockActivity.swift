import ActivityKit
import Foundation

/// The lock's Live Activity. Everything it shows is in the content state; no static attributes.
struct LockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// The locked timer counts up from here, so it leaves out pass time.
        var lockedFrom: Date
        /// During an emergency pass, apps are open until then. Also the activity's stale date, so it
        /// shows the locked timer again after the relock even if Tapout stays closed.
        var openUntil: Date?
        var modeName: String
        var placeName: String?
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

    /// nil while unlocked. Dates are whole seconds, so recomputing a snapshot doesn't cause updates.
    static func content(for snapshot: LockSnapshot) -> LockActivityAttributes.ContentState? {
        func whole(_ date: Date) -> Date { Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded()) }
        switch snapshot.state {
        case .unlocked:
            return nil
        case .locked(let from):
            return .init(lockedFrom: whole(from), openUntil: nil, modeName: snapshot.modeName, placeName: snapshot.placeName)
        case .open(let relockAt, let resumesFrom):
            return .init(lockedFrom: whole(resumesFrom), openUntil: whole(relockAt), modeName: snapshot.modeName, placeName: snapshot.placeName)
        }
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
