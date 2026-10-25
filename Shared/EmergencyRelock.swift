import Foundation

/// The relock step itself, shared by the app (when it is open at the relock time)
/// and the monitor extension (when it is not).
enum EmergencyRelock {
    /// Relocks an open emergency pass. Returns seconds past the relock time (negative = early),
    /// or nil when no pass was open. Relocking early is allowed; strict beats late.
    static func perform(store: SharedStore, shields: some Shielding, now: Date) -> TimeInterval? {
        guard case .emergency(let relockAt, _) = store.session else { return nil }
        shields.apply(store.selection)
        store.session = .locked(since: relockAt)
        return now.timeIntervalSince(relockAt)
    }
}
