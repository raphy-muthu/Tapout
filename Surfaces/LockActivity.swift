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
        /// Draw the flat-color look (the Lab's Living glass switch). Absent when off, so an activity started by
        /// an older build keeps working.
        var flat: Bool?
        /// The timer ends into a mode's scheduled lock, so the apps stay shielded after its end. Absent when not.
        var handsOver: Bool?

        init(lockedFrom: Date, openUntil: Date?, modeName: String, placeName: String?, timerEndsAt: Date? = nil,
             flat: Bool? = nil, handsOver: Bool? = nil) {
            self.lockedFrom = lockedFrom
            self.openUntil = openUntil
            self.modeName = modeName
            self.placeName = placeName
            self.timerEndsAt = timerEndsAt
            self.flat = flat
            self.handsOver = handsOver
        }

        /// Whether a stale activity is stale because its timer ended (the timer's end is the stale date, see
        /// `LiveActivityPlan.staleDate`): the apps are open, so it reads "Time's up" rather than 0:00 left.
        /// A pass that went stale before the timer's end keeps the timer's reading.
        func timerIsOver(isStale: Bool) -> Bool {
            guard isStale, handsOver != true, let end = timerEndsAt else { return false }
            return end <= (openUntil ?? .distantFuture)
        }

        /// The timer end to count down to, or nil to count the lock up. A timer that handed over to a scheduled
        /// lock is over, but the lock isn't, so once stale at its end it counts up like any lock.
        func timerEnd(isStale: Bool) -> Date? {
            guard let end = timerEndsAt else { return nil }
            if isStale, handsOver == true, end <= (openUntil ?? .distantFuture) { return nil }
            return end
        }

        /// Stale because a pass ended before the timer. Nothing updates the activity until Tapout runs, and the
        /// timer may end meanwhile, so the faces show the end time, not a countdown that stops at 0:00 locked.
        func showsEndTime(isStale: Bool) -> Bool {
            guard isStale, let end = timerEnd(isStale: isStale), let open = openUntil else { return false }
            return open < end
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
    /// `handsOver`: the running timer ends into a scheduled lock (`ScheduledLock.handover`), which only the app can
    /// work out (the widgets can't read the modes).
    static func content(for snapshot: LockSnapshot, flat: Bool = false,
                        handsOver: Bool = false) -> LockActivityAttributes.ContentState? {
        let over: Bool? = handsOver && snapshot.timerEndsAt != nil ? true : nil
        func whole(_ date: Date) -> Date { Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded()) }
        switch snapshot.state {
        case .unlocked:
            return nil
        case .locked(let from):
            return .init(lockedFrom: whole(from), openUntil: nil, modeName: snapshot.modeName, placeName: snapshot.placeName,
                         timerEndsAt: snapshot.timerEndsAt.map(whole), flat: flat ? true : nil, handsOver: over)
        case .open(let relockAt, let resumesFrom):
            return .init(lockedFrom: whole(resumesFrom), openUntil: whole(relockAt), modeName: snapshot.modeName,
                         placeName: snapshot.placeName, timerEndsAt: snapshot.timerEndsAt.map(whole),
                         flat: flat ? true : nil, handsOver: over)
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

    static func decide(snapshot: LockSnapshot, enabled: Bool, current: LockActivityAttributes.ContentState?,
                       flat: Bool = false, handsOver: Bool = false) -> Action {
        guard enabled, let wanted = content(for: snapshot, flat: flat, handsOver: handsOver) else { return current == nil ? .none : .end }
        guard let current else { return .start(wanted) }
        return current == wanted ? .none : .update(wanted)
    }
}
