import Foundation

/// iOS can report Screen Time as not approved for a moment at launch and when Tapout comes back to
/// the foreground, before it reports the real status. The Screen Time page opens only once access
/// has stayed missing for `delay`, so that moment never flashes the page.
struct ScreenTimeGrace {
    static let delay: TimeInterval = 1.5

    enum Decision: Equatable {
        /// Access is fine, or isn't needed yet: hide the page.
        case clear
        /// Missing, but not for long enough: look again at that time.
        case wait(until: Date)
        /// Missing for the whole delay: open the page.
        case show
    }

    private var missingSince: Date?

    /// `needed` is true when onboarding is done and access is not approved.
    mutating func observe(needed: Bool, now: Date) -> Decision {
        guard needed else {
            missingSince = nil
            return .clear
        }
        let since = missingSince ?? now
        missingSince = since
        let due = since.addingTimeInterval(Self.delay)
        return now >= due ? .show : .wait(until: due)
    }
}
