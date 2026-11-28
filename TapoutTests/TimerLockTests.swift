import Foundation
import Testing
@testable import Tapout

@MainActor
struct TimerLockTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let timer = TimerLock(start: TimerLockTests.start, duration: 45 * 60)

    // MARK: Countdown

    @Test func endsAtIsStartPlusDuration() {
        #expect(timer.endsAt == Self.start + 45 * 60)
    }

    @Test func remainingCountsDownAndFloorsAtZero() {
        #expect(timer.remaining(at: Self.start) == 45 * 60)
        #expect(timer.remaining(at: Self.start + 15 * 60) == 30 * 60)
        #expect(timer.remaining(at: timer.endsAt) == 0)
        #expect(timer.remaining(at: timer.endsAt + 600) == 0)
    }

    @Test func remainingNeverExceedsTheDurationWhenTheClockMovedBack() {
        #expect(timer.remaining(at: Self.start - 3600) == 45 * 60)
    }

    @Test func remainingFractionRunsFromOneToZero() {
        #expect(timer.remainingFraction(at: Self.start) == 1)
        #expect(timer.remainingFraction(at: Self.start + 22.5 * 60) == 0.5)
        #expect(timer.remainingFraction(at: timer.endsAt) == 0)
        #expect(timer.remainingFraction(at: timer.endsAt + 60) == 0)
    }

    @Test func remainingFractionNeverPassesOneWhenTheClockMovedBack() {
        #expect(timer.remainingFraction(at: Self.start - 3600) == 1)
    }

    @Test func aZeroDurationHasNothingLeft() {
        let empty = TimerLock(start: Self.start, duration: 0)
        #expect(empty.remainingFraction(at: Self.start) == 0)
    }

    // MARK: Due rule

    @Test func isDueAtTheEndByTheWallClock() {
        #expect(!timer.isDue(now: Self.start, early: 0))
        #expect(!timer.isDue(now: timer.endsAt - 1, early: 0))
        #expect(timer.isDue(now: timer.endsAt, early: 0))
        #expect(timer.isDue(now: timer.endsAt + 5, early: 0))
        #expect(!timer.isDue(now: timer.endsAt - 61, early: TimerLock.earlyTolerance))
        #expect(timer.isDue(now: timer.endsAt - 60, early: TimerLock.earlyTolerance))
        #expect(timer.isDue(now: timer.endsAt - 30, early: TimerLock.earlyTolerance))
    }

    /// Ending a timer opens apps, so a clock set back before the start keeps the lock (it used to end it).
    @Test func aClockSetBackNeverEndsTheTimer() {
        #expect(!timer.isDue(now: Self.start - 60, early: 0))
        #expect(!timer.isDue(now: timer.endsAt - timer.duration - 1, early: 0))
        #expect(!timer.isDue(now: Self.start - 86_400, early: TimerLock.earlyTolerance))
    }

    @Test func earlyToleranceMatchesTheEmergencyRelock() {
        #expect(TimerLock.earlyTolerance == EmergencyRelock.earlyTolerance)
    }

    // MARK: Range

    @Test func clampedKeepsTheDurationInRange() {
        #expect(TimerLock.clamped(0) == 5 * 60)
        #expect(TimerLock.clamped(60) == 5 * 60)
        #expect(TimerLock.clamped(5 * 60) == 5 * 60)
        #expect(TimerLock.clamped(45 * 60) == 45 * 60)
        #expect(TimerLock.clamped(12 * 3600) == 12 * 3600)
        #expect(TimerLock.clamped(13 * 3600) == 12 * 3600)
    }

    // MARK: Finish

    @Test func finishOpensADueLockedSession() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .locked(since: timer.start)
        store.timerLock = timer
        let now = timer.endsAt + 3

        let finished = TimerLock.finish(store: store, shields: shields, now: now, early: 0, accessApproved: true)

        #expect(finished?.timer == timer)
        #expect(finished?.handedOverTo == nil)
        #expect(shields.cleared == 1)
        #expect(store.session == .unlocked)
        #expect(store.lastUnlockAt == now)
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == timer)
    }

    @Test func finishWritesTheUnlockTimeBeforeTheSessionAndTheTimerLast() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .locked(since: timer.start)
        store.timerLock = timer
        // Shields come off first; at that moment nothing has been written yet.
        var atClear: (LockSession, Date?, TimerLock?, TimerLock?)?
        shields.onClear = { atClear = (store.session, store.lastUnlockAt, store.timerLock, store.finishedTimer) }

        _ = TimerLock.finish(store: store, shields: shields, now: timer.endsAt, early: 0, accessApproved: true)

        #expect(atClear?.0 == .locked(since: timer.start))
        #expect(atClear?.1 == nil)
        #expect(atClear?.2 == timer)
        #expect(atClear?.3 == nil)
    }

    @Test func finishAlsoEndsAPassThatOutlastedTheTimer() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .emergency(relockAt: timer.endsAt + 600, duration: 900)
        store.timerLock = timer

        let finished = TimerLock.finish(store: store, shields: shields, now: timer.endsAt, early: 0, accessApproved: true)

        #expect(finished?.timer == timer)
        #expect(finished?.handedOverTo == nil)
        #expect(store.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(store.finishedTimer == timer)
    }

    @Test func finishAcceptsACallbackWithinTheEarlyTolerance() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .locked(since: timer.start)
        store.timerLock = timer

        let finished = TimerLock.finish(store: store, shields: shields, now: timer.endsAt - 45, early: TimerLock.earlyTolerance, accessApproved: true)

        #expect(finished?.timer == timer)
        #expect(finished?.handedOverTo == nil)
        #expect(store.session == .unlocked)
    }

    @Test func finishBeforeTheEndDoesNothing() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        let session = LockSession.locked(since: timer.start)
        store.session = session
        store.timerLock = timer

        #expect(TimerLock.finish(store: store, shields: shields, now: timer.endsAt - 120, early: 0, accessApproved: true) == nil)
        #expect(shields.cleared == 0)
        #expect(store.session == session)
        #expect(store.lastUnlockAt == nil)
        #expect(store.timerLock == timer)
        #expect(store.finishedTimer == nil)
    }

    @Test func finishWithoutATimerDoesNothing() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        let session = LockSession.locked(since: timer.start)
        store.session = session

        #expect(TimerLock.finish(store: store, shields: shields, now: timer.endsAt + 60, early: 0, accessApproved: true) == nil)
        #expect(shields.cleared == 0)
        #expect(store.session == session)
        #expect(store.lastUnlockAt == nil)
        #expect(store.finishedTimer == nil)
    }

    @Test func finishWhenAlreadyUnlockedDoesNothing() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.timerLock = timer

        #expect(TimerLock.finish(store: store, shields: shields, now: timer.endsAt + 60, early: 0, accessApproved: true) == nil)
        #expect(shields.cleared == 0)
        #expect(store.session == .unlocked)
        #expect(store.lastUnlockAt == nil)
        #expect(store.timerLock == timer)
        #expect(store.finishedTimer == nil)
    }
}
