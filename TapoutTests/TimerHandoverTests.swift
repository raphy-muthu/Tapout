import Foundation
import Testing
@testable import Tapout

/// A timer that ends inside a mode's scheduled window hands over to that mode's scheduled lock.
@MainActor
struct TimerHandoverTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let notifier = FakeNotifier()
    /// Weekdays 13:00–17:00.
    private let focus = Mode(name: "Focus", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))
    /// Weekdays 15:00–19:00.
    private let evenings = Mode(name: "Evenings", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 15 * 60, end: 19 * 60))
    /// No schedule: the timer's mode.
    private let manual = Mode(name: "Study")

    /// 2026-11-09 is a Monday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    private func handover(at now: Date, access: Bool = true, apps: Bool = true, tag: Bool = true) -> Mode? {
        ScheduledLock.handover(store: store, now: now, accessApproved: access, hasApps: { _ in apps }, hasTag: tag,
                               calendar: calendar)
    }

    /// A 45-minute timer on the manual mode, running in a locked session, ending at `end`.
    @discardableResult
    private func runTimer(endingAt end: Date, modes: [Mode]? = nil) -> TimerLock {
        store.modes = modes ?? [manual, focus]
        store.activeModeID = manual.id
        store.activeModeName = manual.name
        let timer = TimerLock(start: end - 45 * 60, duration: 45 * 60)
        store.timerLock = timer
        store.session = .locked(since: timer.start)
        return timer
    }

    private func finish(at now: Date, access: Bool = true, apps: Bool = true) -> TimerLock.Finish? {
        TimerLock.finish(store: store, shields: shields, now: now, early: 0, accessApproved: access,
                         hasApps: { _ in apps }, hasTag: true, calendar: calendar)
    }

    // MARK: The rule

    @Test func insideAWindowHandsOverToThatMode() {
        store.modes = [manual, focus]
        #expect(handover(at: date(9, 14)) == focus)
    }

    @Test func outsideEveryWindowThereIsNone() {
        store.modes = [manual, focus]
        #expect(handover(at: date(9, 12)) == nil)
        #expect(handover(at: date(9, 17, 0, 1)) == nil)
    }

    @Test func anUnscheduledDayHasNone() {
        store.modes = [manual, focus]
        #expect(handover(at: date(14, 14)) == nil) // Saturday
    }

    @Test func aWindowTheOwnerUnlockedInHasNone() {
        store.modes = [manual, focus]
        store.lastUnlockAt = date(9, 13, 10)
        #expect(handover(at: date(9, 14)) == nil)
    }

    @Test func anUnlockBeforeTheWindowStillHandsOver() {
        store.modes = [manual, focus]
        store.lastUnlockAt = date(9, 12, 59)
        #expect(handover(at: date(9, 14)) == focus)
    }

    @Test func aScheduleSavedDuringTheWindowHasNone() {
        store.modes = [manual, focus]
        store.scheduleSavedAt = [focus.id.uuidString: date(9, 13, 30)]
        #expect(handover(at: date(9, 14)) == nil)
    }

    @Test func screenTimeOffHasNone() {
        store.modes = [manual, focus]
        #expect(handover(at: date(9, 14), access: false) == nil)
    }

    @Test func aModeWithNoAppsHasNone() {
        store.modes = [manual, focus]
        #expect(handover(at: date(9, 14), apps: false) == nil)
    }

    @Test func noTagPairedHasNone() {
        store.modes = [manual, focus]
        #expect(handover(at: date(9, 14), tag: false) == nil)
    }

    @Test func withoutInjectionNoAppsAndNoTagsMeansNone() {
        // The store's own answers: the test modes block nothing and no tag is paired.
        store.modes = [manual, focus]
        #expect(ScheduledLock.handover(store: store, now: date(9, 14), accessApproved: true, calendar: calendar) == nil)
    }

    @Test func theRunningLockIsIgnored() {
        store.modes = [manual, focus]
        store.session = .locked(since: date(9, 12))
        #expect(handover(at: date(9, 14)) == focus)
    }

    @Test func theWindowThatStartedLatestWins() {
        store.modes = [manual, evenings, focus]
        #expect(handover(at: date(9, 16)) == evenings)
        store.modes = [manual, focus, evenings]
        #expect(handover(at: date(9, 16)) == evenings)
        // Only Focus is running before 15:00.
        #expect(handover(at: date(9, 14)) == focus)
    }

    @Test func equalStartsGoByModeOrder() {
        let twin = Mode(name: "Twin", schedule: focus.schedule)
        store.modes = [manual, twin, focus]
        #expect(handover(at: date(9, 14)) == twin)
    }

    @Test func aWindowThatCrossesMidnight() {
        let late = Mode(name: "Late", schedule: ModeSchedule(days: [2], start: 22 * 60, end: 2 * 60)) // Mondays
        store.modes = [manual, late]
        #expect(handover(at: date(10, 1)) == late) // Tuesday 01:00, in Monday's window
        #expect(handover(at: date(10, 2, 0, 1)) == nil)
        #expect(handover(at: date(9, 21)) == nil)
    }

    // MARK: The finish

    @Test func aHandOverKeepsTheLockUnderTheScheduledMode() {
        let timer = runTimer(endingAt: date(9, 14))
        store.lastUnlockAt = date(9, 9)
        let result = finish(at: timer.endsAt)
        #expect(result == TimerLock.Finish(timer: timer, handedOverTo: focus))
        #expect(store.session == .locked(since: timer.endsAt))
        #expect(store.activeModeID == focus.id)
        #expect(store.activeModeName == "Focus")
        #expect(store.lastUnlockAt == date(9, 9))
        #expect(shields.cleared == 0)
        #expect(shields.plans == [store.activeShieldPlan])
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == timer)
        #expect(store.finishedTimerHandover == "Focus")
    }

    @Test func theScheduledModesShieldsGoOnAfterTheModeSwitch() {
        let timer = runTimer(endingAt: date(9, 14))
        var atApply: (UUID?, LockSession, TimerLock?)?
        shields.onApply = { atApply = (store.activeModeID, store.session, store.finishedTimer) }
        _ = finish(at: timer.endsAt)
        #expect(atApply?.0 == focus.id)
        #expect(atApply?.1 == .locked(since: timer.endsAt))
        #expect(atApply?.2 == nil) // the timer markers come last
    }

    @Test func aTimerEndingAtTheWindowStartStillHandsOver() {
        // The timer's own end is never an unlock: nothing is stamped before the rule is read.
        let timer = runTimer(endingAt: date(9, 13))
        #expect(finish(at: timer.endsAt)?.handedOverTo == focus)
        #expect(store.lastUnlockAt == nil)
    }

    @Test func outsideEveryWindowTheAppsOpenAsBefore() {
        let timer = runTimer(endingAt: date(9, 12))
        store.finishedTimerHandover = "Old" // a leftover marker
        let result = finish(at: timer.endsAt)
        #expect(result == TimerLock.Finish(timer: timer, handedOverTo: nil))
        #expect(store.session == .unlocked)
        #expect(store.lastUnlockAt == timer.endsAt)
        #expect(store.activeModeID == manual.id)
        #expect(shields.cleared == 1)
        #expect(store.finishedTimerHandover == nil)
    }

    @Test func aWindowAlreadyUnlockedInOpensTheApps() {
        let timer = runTimer(endingAt: date(9, 15))
        store.lastUnlockAt = date(9, 13, 30) // a tag unlock earlier in this window
        #expect(finish(at: timer.endsAt)?.handedOverTo == nil)
        #expect(store.session == .unlocked)
    }

    @Test func screenTimeOffOpensTheApps() {
        let timer = runTimer(endingAt: date(9, 14))
        #expect(finish(at: timer.endsAt, access: false)?.handedOverTo == nil)
        #expect(store.session == .unlocked)
    }

    @Test func theTimersOwnModeCanBeTheScheduledOne() {
        let timer = runTimer(endingAt: date(9, 14), modes: [focus])
        store.activeModeID = focus.id
        store.activeModeName = focus.name
        #expect(finish(at: timer.endsAt)?.handedOverTo == focus)
        #expect(store.activeModeID == focus.id)
        #expect(store.session == .locked(since: timer.endsAt))
        #expect(shields.applied == 1)
        #expect(shields.cleared == 0)
    }

    @Test func aPassOpenAtTheEndHandsOverToo() {
        let timer = runTimer(endingAt: date(9, 14))
        store.session = .emergency(relockAt: timer.endsAt + 120, duration: 5 * 60)
        #expect(finish(at: timer.endsAt)?.handedOverTo == focus)
        #expect(store.session == .locked(since: timer.endsAt))
    }

    @Test func settlingAStaleTimerClearsAnOldHandOverMarker() {
        let stale = TimerLock(start: date(9, 12), duration: 30 * 60)
        store.timerLock = stale
        store.finishedTimerHandover = "Old"
        TimerLock.settleStale(store: store, now: date(9, 14))
        #expect(store.finishedTimer == stale)
        #expect(store.finishedTimerHandover == nil)
    }

    // MARK: Monitor

    @Test func theHandOverNoticeNamesTheMode() {
        #expect(ScheduleNotice.timerHandedOver(evenings) == ("Evenings", "Timer done. Locked until you tap a tag."))
    }

    @Test func theMonitorHandsOverAndSaysSo() {
        let timer = runTimer(endingAt: date(9, 14))
        let line = TimerLock.runMonitorEnd(store: store, shields: shields, notifier: notifier, now: timer.endsAt - 30,
                                           accessApproved: true, hasApps: { _ in true }, hasTag: true, calendar: calendar)
        #expect(line == "timer: finished, handed over to Focus")
        #expect(notifier.posted == ["Focus|Timer done. Locked until you tap a tag."])
        #expect(store.session == .locked(since: timer.endsAt - 30))
    }

    @Test func theMonitorWithoutAccessOpensTheApps() {
        let timer = runTimer(endingAt: date(9, 14))
        let line = TimerLock.runMonitorEnd(store: store, shields: shields, notifier: notifier, now: timer.endsAt,
                                           accessApproved: false, hasApps: { _ in true }, hasTag: true, calendar: calendar)
        #expect(line == "timer: finished")
        #expect(notifier.posted == ["Time's up|45 min locked. Your apps are open."])
        #expect(store.session == .unlocked)
    }

    @Test func aPassRelockWithADueTimerHandsOverAndDoesNotRelock() {
        let timer = runTimer(endingAt: date(9, 14))
        store.session = .emergency(relockAt: timer.endsAt, duration: 5 * 60)
        let run = TimerLock.runMonitorRelock(store: store, shields: shields, notifier: notifier, now: timer.endsAt,
                                             accessApproved: true, hasApps: { _ in true }, hasTag: true, calendar: calendar)
        #expect(run.lines == ["timer: finished, handed over to Focus", "nothing to relock"])
        #expect(run.changed)
        #expect(store.session == .locked(since: timer.endsAt))
    }

    // MARK: Engine

    private final class Clock {
        var now = Date()
    }

    private func makeEngine(_ clock: Clock, timers: FakeRelock = FakeRelock(), relock: FakeRelock = FakeRelock()) -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, passes: MemoryPassVault(), timers: timers,
                   now: { [clock] in clock.now }, modeHasApps: { _ in true }, calendar: calendar)
    }

    private func pairATag() {
        store.pairedTags = [PairedTag(uid: TagUID(hex: "04AA01"), name: "Desk", pairedAt: date(1, 9))]
    }

    @Test func theEngineHandsOverAtTheTimersEnd() throws {
        store.modes = [manual, focus]
        store.activeModeID = manual.id
        pairATag()
        let clock = Clock()
        clock.now = date(9, 13, 30)
        let timers = FakeRelock()
        let relock = FakeRelock()
        let engine = makeEngine(clock, timers: timers, relock: relock)
        let timer = try engine.lockTimed(duration: 45 * 60)
        clock.now = timer.endsAt
        #expect(!engine.tick())
        #expect(engine.timerJustFinished == TimerLock.Finish(timer: timer, handedOverTo: focus))
        #expect(engine.session == .locked(since: timer.endsAt))
        #expect(store.activeModeID == focus.id)
        #expect(store.lastUnlockAt == nil)
        #expect(timers.cancelled == 1)
        #expect(relock.cancelled == 1)
        #expect(engine.log.contains { $0.message == "Timer finished, handed over to Focus" })
    }

    @Test func theEngineUsesItsLastAccessCheck() throws {
        store.modes = [manual, focus]
        store.activeModeID = manual.id
        store.screenTimeApproved = false
        pairATag()
        let clock = Clock()
        clock.now = date(9, 13, 30)
        let engine = makeEngine(clock)
        let timer = try engine.lockTimed(duration: 45 * 60)
        clock.now = timer.endsAt
        engine.tick()
        #expect(engine.timerJustFinished?.handedOverTo == nil)
        #expect(engine.session == .unlocked)
    }

    // MARK: History

    private func makeModel(_ clock: Clock) -> AppModel {
        AppModel(store: store, now: { [clock] in clock.now })
    }

    /// The timer's record is open with an intention, as `startLock` leaves it.
    private func modelWithTimerRecord(endingAt end: Date) -> (AppModel, Clock, TimerLock) {
        let timer = runTimer(endingAt: end)
        let clock = Clock()
        clock.now = timer.start
        let model = makeModel(clock)
        model.startLock(placeUID: nil, intention: "Essay")
        return (model, clock, timer)
    }

    @Test func theTimersRecordEndsAtItsEndAndTheScheduledLockGetsItsOwn() throws {
        let (model, clock, timer) = modelWithTimerRecord(endingAt: date(9, 14))
        _ = finish(at: timer.endsAt)
        clock.now = timer.endsAt + 1
        let closed = try #require(model.closeFinishedTimer())
        #expect(closed.handedOverTo == "Focus")
        #expect(closed.record?.end == timer.endsAt)
        #expect(closed.record?.intention == "Essay")
        #expect(closed.record?.modeID == manual.id)
        #expect(store.finishedTimerHandover == nil)
        model.reconcile(with: store.session)
        #expect(model.history.count == 2)
        let scheduled = try #require(model.history.last)
        #expect(scheduled.end == nil)
        #expect(scheduled.start == timer.endsAt)
        #expect(scheduled.modeID == focus.id)
        #expect(scheduled.intention == nil)
        #expect(model.currentIntention == nil)
        #expect(model.activeMode == focus)
    }

    @Test func aMonitorHandOverWhileOpenIsCaughtOnTheSessionChange() throws {
        let (model, clock, timer) = modelWithTimerRecord(endingAt: date(9, 14))
        // The monitor's callback lands 30 s early, before the app's tick.
        let early = timer.endsAt - 30
        #expect(TimerLock.finish(store: store, shields: shields, now: early, early: TimerLock.earlyTolerance,
                                 accessApproved: true, hasApps: { _ in true }, hasTag: true,
                                 calendar: calendar)?.handedOverTo == focus)
        clock.now = early + 1
        let finish = try #require(model.sessionChanged(to: .locked(since: early)))
        #expect(finish.handedOverTo == "Focus")
        #expect(finish.record?.end == timer.endsAt)
        #expect(model.history.count == 2)
        // The scheduled lock's record never overlaps the timer's.
        #expect(model.history.last?.start == timer.endsAt)
        #expect(model.history.last?.modeID == focus.id)
        #expect(model.history.filter { $0.end == nil }.count == 1)
        #expect(model.sessionChanged(to: .locked(since: early)) == nil)
        #expect(model.history.count == 2)
    }

    @Test func aReconcileBeforeTheCloseLeavesTheScheduledRecordOpen() throws {
        let (model, clock, timer) = modelWithTimerRecord(endingAt: date(9, 14))
        _ = finish(at: timer.endsAt)
        clock.now = timer.endsAt
        model.reconcile(with: store.session)
        let closed = try #require(model.closeFinishedTimer())
        #expect(closed.handedOverTo == "Focus")
        #expect(model.history.count == 2)
        #expect(model.history.first?.end == timer.endsAt)
        #expect(model.history.last?.end == nil)
        #expect(model.history.last?.modeID == focus.id)
    }

    @Test func aHandOverTimerClosedAtLaunchShowsTimesUp() throws {
        // The monitor handed over while Tapout was closed; the app opens an hour later.
        let (model, clock, timer) = modelWithTimerRecord(endingAt: date(9, 14))
        _ = finish(at: timer.endsAt)
        clock.now = timer.endsAt + 3600
        let closed = try #require(model.closeFinishedTimer())
        #expect(closed.handedOverTo == "Focus")
        model.reconcile(with: store.session)
        #expect(model.runningLockTime(at: clock.now) == 3600)
        #expect(model.phoneFreeToday(calendar: calendar) == 45 * 60 + 3600)
    }

    @Test func aHandOverPlaysNoUnlockHapticButAnOpeningDoes() {
        let timer = TimerLock(start: date(9, 13), duration: 45 * 60)
        let handedOver = AppModel.TimerFinish(timer: timer, record: nil, handedOverTo: "Focus")
        let opened = AppModel.TimerFinish(timer: timer, record: nil)
        #expect(!handedOver.playsUnlockHaptic(heard: true))
        #expect(opened.playsUnlockHaptic(heard: true))
        #expect(!opened.playsUnlockHaptic(heard: false))
    }

    // MARK: Time's up

    @Test func timesUpSaysWhichModeIsLocked() {
        #expect(TimerDoneView.line(duration: 45 * 60, handedOverTo: "Evenings")
            == "45 min done. Evenings is locked until you tap a tag.")
        #expect(TimerDoneView.spokenLine(duration: 90 * 60, handedOverTo: "Evenings")
            == "\(TimeFormat.spokenLength(90 * 60)) done. Evenings is locked until you tap a tag.")
        #expect(TimerDoneView.line(duration: 45 * 60, handedOverTo: nil) == "45 min locked. Your apps are open.")
    }

    @Test func theHandOverDemoLeavesTheScheduledModeLocked() {
        store.modes = [manual, evenings]
        store.activeModeID = manual.id
        DemoData.seedFinishedTimer(store, handedOver: true, now: date(9, 16))
        #expect(store.finishedTimerHandover == "Evenings")
        #expect(store.activeModeID == evenings.id)
        if case .locked = store.session {} else { Issue.record("expected a locked session") }
        #expect(store.lastUnlockAt == nil)
        #expect(store.lockHistory.last?.modeID == manual.id)
    }
}
