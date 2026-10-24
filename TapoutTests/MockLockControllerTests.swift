import Foundation
import Testing
@testable import Tapout

@MainActor
struct MockLockControllerTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()

    private func makeController(session: LockSession = .unlocked, passesLeft: Int = 3) -> MockLockController {
        MockLockController(session: session, passesLeft: passesLeft, now: { [clock] in clock.now })
    }

    @Test func startsUnlockedWithThreePasses() {
        let controller = makeController()
        #expect(controller.session == .unlocked)
        #expect(controller.passesLeft == 3)
    }

    @Test func tagReadLocksAtTheCurrentTime() {
        let controller = makeController()
        controller.simulateTagRead()
        #expect(controller.session == .locked(since: clock.now))
    }

    @Test func tagReadWhileLockedUnlocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.simulateTagRead()
        #expect(controller.session == .unlocked)
    }

    @Test func emergencyPassSpendsOneAndOpensForFiveMinutes() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        #expect(controller.passesLeft == 2)
        #expect(controller.session == .emergency(relockAt: clock.now + 300, duration: 300))
    }

    @Test func emergencyPassNeedsALockAndAPass() {
        let unlocked = makeController()
        unlocked.useEmergencyPass()
        #expect(unlocked.session == .unlocked)
        #expect(unlocked.passesLeft == 3)

        let since = clock.now
        let empty = makeController(session: .locked(since: since), passesLeft: 0)
        empty.useEmergencyPass()
        #expect(empty.session == .locked(since: since))
        #expect(empty.passesLeft == 0)
    }

    @Test func tickBeforeExpiryKeepsAppsOpen() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        clock.now += 299
        controller.tick()
        #expect(controller.session.lockState == .locked)
        #expect(controller.session != .locked(since: clock.now))
        if case .emergency = controller.session {} else { Issue.record("expected emergency") }
    }

    @Test func tickAtExpiryRelocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        let relockAt = clock.now + 300
        clock.now += 300
        controller.tick()
        #expect(controller.session == .locked(since: relockAt))
    }

    @Test func relockNowLocksImmediately() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        clock.now += 60
        controller.relockNow()
        #expect(controller.session == .locked(since: clock.now))
        #expect(controller.passesLeft == 2)
    }

    @Test func tagReadDuringEmergencyUnlocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        controller.simulateTagRead()
        #expect(controller.session == .unlocked)
    }
}
