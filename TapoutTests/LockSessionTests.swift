import Foundation
import Testing
@testable import Tapout

struct LockSessionTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func elapsedCountsUpWhileLocked() {
        #expect(LockSession.locked(since: t0).elapsed(at: t0 + 2832) == 2832)
        #expect(LockSession.locked(since: t0).elapsed(at: t0 - 5) == 0)
        #expect(LockSession.unlocked.elapsed(at: t0) == 0)
    }

    @Test func remainingCountsDownDuringEmergency() {
        let session = LockSession.emergency(relockAt: t0 + 300, duration: 300)
        #expect(session.remaining(at: t0 + 28) == 272)
        #expect(session.remainingFraction(at: t0 + 150) == 0.5)
        #expect(session.remaining(at: t0 + 400) == 0)
        #expect(session.remainingFraction(at: t0 + 400) == 0)
    }

    @Test func lockStatePicksTheAccent() {
        #expect(LockSession.unlocked.lockState == .unlocked)
        #expect(LockSession.locked(since: t0).lockState == .locked)
        #expect(LockSession.emergency(relockAt: t0, duration: 300).lockState == .locked)
    }
}
