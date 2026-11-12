import Foundation
import Testing
@testable import Tapout

struct LiveActivityPlanTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func shot(_ state: LockSnapshot.State) -> LockSnapshot { .sample(state) }

    @Test func nothingToDoWhileUnlockedWithoutOne() {
        #expect(LiveActivityPlan.decide(snapshot: shot(.unlocked), enabled: true, current: nil) == .none)
    }

    @Test func unlockingEndsIt() {
        let running = LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))
        #expect(LiveActivityPlan.decide(snapshot: shot(.unlocked), enabled: true, current: running) == .end)
    }

    @Test func turningItOffEndsIt() {
        let locked = shot(.locked(countingFrom: now))
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: false, current: LiveActivityPlan.content(for: locked)) == .end)
    }

    @Test func aLockStartsOne() throws {
        let state = try #require(LiveActivityPlan.content(for: shot(.locked(countingFrom: now))))
        #expect(state.lockedFrom == now)
        #expect(state.openUntil == nil)
        #expect(state.modeName == "Deep work")
        #expect(LiveActivityPlan.decide(snapshot: shot(.locked(countingFrom: now)), enabled: true, current: nil) == .start(state))
    }

    @Test func theSameStateChangesNothing() {
        let locked = shot(.locked(countingFrom: now))
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: true, current: LiveActivityPlan.content(for: locked)) == .none)
    }

    @Test func aPassUpdatesItWithTheRelockTime() throws {
        let running = LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))
        let open = shot(.open(relockAt: now + 300, resumesFrom: now + 60))
        let state = try #require(LiveActivityPlan.content(for: open))
        #expect(state.openUntil == now + 300)
        #expect(state.lockedFrom == now + 60)
        #expect(LiveActivityPlan.decide(snapshot: open, enabled: true, current: running) == .update(state))
    }

    @Test func timesAreWholeSecondsSoTinyDriftDoesntUpdate() {
        let a = LiveActivityPlan.content(for: shot(.locked(countingFrom: now + 0.0004)))
        let b = LiveActivityPlan.content(for: shot(.locked(countingFrom: now - 0.0004)))
        #expect(a == b)
    }

    @Test func afterTheRelockItUpdatesBackToLocked() throws {
        let open = LiveActivityPlan.content(for: shot(.open(relockAt: now + 300, resumesFrom: now + 60)))
        let locked = shot(.locked(countingFrom: now))
        let wanted = try #require(LiveActivityPlan.content(for: locked))
        #expect(wanted.openUntil == nil)
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: true, current: open) == .update(wanted))
    }

    @Test func turnedOffWithNoActivityDoesNothing() {
        #expect(LiveActivityPlan.decide(snapshot: shot(.locked(countingFrom: now)), enabled: false, current: nil) == .none)
    }

    @Test func onlyRunningActivitiesCountAsCurrent() {
        #expect(LiveActivityPlan.countsAsCurrent(.active))
        #expect(LiveActivityPlan.countsAsCurrent(.stale))
        #expect(!LiveActivityPlan.countsAsCurrent(.over))
    }
}
