import Foundation
import Testing
@testable import Tapout

/// What the monitor extension runs at the timer's and the emergency relock's callbacks.
struct TimerMonitorTests {
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let notifier = FakeNotifier()
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let timer = TimerLock(start: TimerMonitorTests.start, duration: 45 * 60)

    private func lockWithTimer() {
        store.session = .locked(since: timer.start)
        store.timerLock = timer
    }

    @Test func theNoticeSaysHowLong() {
        #expect(ScheduleNotice.timerFinished(duration: 45 * 60) == ("Time's up", "45 min locked. Your apps are open."))
        #expect(ScheduleNotice.timerFinished(duration: 90 * 60) == ("Time's up", "1 h 30 min locked. Your apps are open."))
        #expect(ScheduleNotice.timerFinished(duration: 3600) == ("Time's up", "1 h locked. Your apps are open."))
    }

    @Test func theTimerCallbackFinishesADueTimerAndPostsTheNotice() {
        lockWithTimer()
        let line = TimerLock.runMonitorEnd(store: store, shields: shields, notifier: notifier, now: timer.endsAt - 30, accessApproved: true)
        #expect(line == "timer: finished")
        #expect(store.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(store.finishedTimer == timer)
        #expect(store.timerLock == nil)
        #expect(notifier.posted == ["Time's up|45 min locked. Your apps are open."])
    }

    @Test func anEarlyCallbackWaits() {
        lockWithTimer()
        let line = TimerLock.runMonitorEnd(store: store, shields: shields, notifier: notifier, now: timer.endsAt - 120, accessApproved: true)
        #expect(line == "timer: not due yet")
        #expect(store.session == .locked(since: timer.start))
        #expect(notifier.posted.isEmpty)
    }

    @Test func aCallbackWithNoTimerDoesNothing() {
        store.session = .locked(since: timer.start)
        let line = TimerLock.runMonitorEnd(store: store, shields: shields, notifier: notifier, now: timer.endsAt, accessApproved: true)
        #expect(line == "timer: nothing to finish")
        #expect(store.session == .locked(since: timer.start))
        #expect(shields.cleared == 0)
    }

    @Test func aPassRelockWithADueTimerFinishesTheTimerAndDoesNotRelock() {
        store.timerLock = timer
        store.session = .emergency(relockAt: timer.endsAt, duration: 5 * 60)
        let run = TimerLock.runMonitorRelock(store: store, shields: shields, notifier: notifier, now: timer.endsAt, accessApproved: true)
        #expect(run.lines == ["timer: finished", "nothing to relock"])
        #expect(run.changed)
        #expect(store.session == .unlocked)
        #expect(shields.applied == 0)
        #expect(store.finishedTimer == timer)
    }

    @Test func aPassRelockBeforeTheTimerEndsRelocksAndKeepsTheTimer() {
        store.timerLock = timer
        let relockAt = timer.endsAt - 600
        store.session = .emergency(relockAt: relockAt, duration: 5 * 60)
        let run = TimerLock.runMonitorRelock(store: store, shields: shields, notifier: notifier, now: relockAt, accessApproved: true)
        #expect(run.lines == ["timer: not due yet", "relocked, 0s after relock time"])
        #expect(store.session == .locked(since: relockAt))
        #expect(shields.applied == 1)
        #expect(store.timerLock == timer)
        #expect(notifier.posted.isEmpty)
    }

    @Test func aPassRelockWithoutATimerIsUnchanged() {
        let relockAt = timer.endsAt
        store.session = .emergency(relockAt: relockAt, duration: 5 * 60)
        let early = TimerLock.runMonitorRelock(store: store, shields: shields, notifier: notifier, now: relockAt - 120, accessApproved: true)
        #expect(early.lines == ["not due yet"])
        #expect(!early.changed)
        let run = TimerLock.runMonitorRelock(store: store, shields: shields, notifier: notifier, now: relockAt + 5, accessApproved: true)
        #expect(run.lines == ["relocked, 5s after relock time"])
        #expect(run.changed)
    }
}
