import Foundation

/// The two accent states from the design system: ember owns locked, slate owns unlocked.
enum LockState {
    case locked, unlocked
}

/// What the phone is doing right now.
enum LockSession: Equatable {
    case unlocked
    case locked(since: Date)
    /// An emergency pass is open; apps relock at `relockAt`.
    case emergency(relockAt: Date, duration: TimeInterval)

    /// An emergency pass is part of a lock, so ember keeps the accent.
    var lockState: LockState {
        switch self {
        case .unlocked: .unlocked
        case .locked, .emergency: .locked
        }
    }

    /// Time locked so far. Zero when not locked.
    func elapsed(at date: Date) -> TimeInterval {
        guard case .locked(let since) = self else { return 0 }
        return max(0, date.timeIntervalSince(since))
    }

    /// Time until an emergency pass relocks. Zero otherwise.
    func remaining(at date: Date) -> TimeInterval {
        guard case .emergency(let relockAt, _) = self else { return 0 }
        return max(0, relockAt.timeIntervalSince(date))
    }

    /// Share of the emergency pass still left, 0...1; drives the orb ring.
    func remainingFraction(at date: Date) -> Double {
        guard case .emergency(_, let duration) = self, duration > 0 else { return 0 }
        return min(1, remaining(at: date) / duration)
    }
}
