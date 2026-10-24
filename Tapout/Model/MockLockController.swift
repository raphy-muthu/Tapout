import Foundation
import Observation

/// Stands in for the real NFC + Screen Time controller until Phase 4. Nothing is persisted.
@MainActor
@Observable
final class MockLockController {
    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60
    /// Five passes total, ever. They never refill.
    static let totalPasses = 5

    private(set) var session: LockSession
    private(set) var passesLeft: Int
    @ObservationIgnored private let now: () -> Date

    init(session: LockSession = .unlocked, passesLeft: Int = 3, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.passesLeft = passesLeft
        self.now = now
    }

    /// A paired tag was read: lock when unlocked, otherwise unlock.
    func simulateTagRead() {
        switch session {
        case .unlocked: session = .locked(since: now())
        case .locked, .emergency: session = .unlocked
        }
    }

    /// Spends one pass. Only works while locked with passes left.
    func useEmergencyPass() {
        guard case .locked = session, passesLeft > 0 else { return }
        passesLeft -= 1
        session = .emergency(relockAt: now() + Self.emergencyDuration, duration: Self.emergencyDuration)
    }

    /// Ends an emergency pass early.
    func relockNow() {
        guard case .emergency = session else { return }
        session = .locked(since: now())
    }

    /// Called every second; relocks when an emergency pass runs out.
    func tick() {
        if case .emergency(let relockAt, _) = session, now() >= relockAt {
            session = .locked(since: relockAt)
        }
    }
}

#if DEBUG
extension MockLockController {
    /// `-mockState locked|emergency` starts in that state, for screenshots.
    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> MockLockController {
        guard let index = arguments.firstIndex(of: "-mockState"), index + 1 < arguments.count else {
            return MockLockController()
        }
        let now = Date()
        switch arguments[index + 1] {
        case "locked":
            return MockLockController(session: .locked(since: now - (47 * 60 + 12)))
        case "emergency":
            return MockLockController(session: .emergency(relockAt: now + (4 * 60 + 32), duration: emergencyDuration), passesLeft: 2)
        default:
            return MockLockController()
        }
    }
}
#endif
