import Foundation
import Testing
@testable import Tapout

/// The security and bug sweep (2026-11-27): moving the clock can't end or stretch a lock, the model refuses
/// changes during a lock, and the smaller fixes that came with them.
struct ClockRulesTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let boot = ClockAnchor(boot: "boot-a", seconds: 1_000)

    private static func at(_ seconds: TimeInterval, boot: String = "boot-a") -> ClockAnchor {
        ClockAnchor(boot: boot, seconds: 1_000 + seconds)
    }

    @Test func anchorsMeasureRealTimeOnlyWithinOneBoot() {
        #expect(Self.boot.elapsed(until: Self.at(90)) == 90)
        #expect(Self.boot.elapsed(until: Self.at(90, boot: "boot-b")) == nil)
        #expect(Self.boot.elapsed(until: nil) == nil)
    }

    @Test func theRealClockIsReadable() {
        // On the simulator and on a phone the boot session exists, so locks get an anchor.
        #expect(ClockAnchor.current() != nil)
    }

    @Test func aClockSetForwardDoesNotEndATimer() {
        let timer = TimerLock(start: Self.start, duration: 45 * 60, anchor: Self.boot)
        // Five real minutes in, the clock says a day later.
        #expect(!timer.isDue(now: Self.start + 86_400, early: 0, clock: Self.at(300)))
        #expect(timer.realRemaining(clock: Self.at(300)) == TimeInterval(2400))
    }

    @Test func aClockSetBackDoesNotStretchATimer() {
        let timer = TimerLock(start: Self.start, duration: 45 * 60, anchor: Self.boot)
        #expect(timer.isDue(now: Self.start - 3600, early: 0, clock: Self.at(45 * 60)))
    }

    @Test func afterARestartTheWallClockDecidesAndASetBackClockKeepsTheLock() {
        let timer = TimerLock(start: Self.start, duration: 45 * 60, anchor: Self.boot)
        let restarted = Self.at(10, boot: "boot-b")
        #expect(!timer.isDue(now: Self.start - 60, early: 0, clock: restarted))
        #expect(timer.isDue(now: timer.endsAt, early: 0, clock: restarted))
    }

    @Test func aPassThatReallyRanItsLengthIsOverWhateverTheClockSays() {
        let relockAt = Self.start + 300
        // The clock was moved back so the relock looks four minutes away.
        #expect(!EmergencyRelock.isDue(relockAt: relockAt, duration: 300, now: relockAt - 240, early: 0))
        #expect(EmergencyRelock.isDue(relockAt: relockAt, duration: 300, now: relockAt - 240, early: 0, realElapsed: 300))
        #expect(!EmergencyRelock.isDue(relockAt: relockAt, duration: 300, now: relockAt - 240, early: 0, realElapsed: 120))
    }

    @Test func aMovedClockRebooksTheEndOnlyWhenItDisagrees() {
        let now = Self.start
        #expect(ClockRearm.target(wallEnd: now + 600, realRemaining: 600, now: now) == nil)
        #expect(ClockRearm.target(wallEnd: now + 600, realRemaining: nil, now: now) == nil)
        #expect(ClockRearm.target(wallEnd: now - 3600, realRemaining: 600, now: now) == now + 600)
    }

    @Test func aRelockScheduleCanPinItsTimeZone() {
        let schedule = RelockPlan.schedule(relockAt: Self.start + 300, now: Self.start, strategy: .warning, pinZone: true)
        #expect(schedule.intervalEnd.timeZone == Calendar.current.timeZone)
        let plain = RelockPlan.schedule(relockAt: Self.start + 300, now: Self.start, strategy: .warning)
        #expect(plain.intervalEnd.timeZone == nil)
    }
}

@MainActor
struct EngineClockTests {
    private final class Clocks {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        var real: TimeInterval = 0
        var anchor: ClockAnchor { ClockAnchor(boot: "boot-a", seconds: 1_000 + real) }
    }

    private let clocks = Clocks()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let relock = FakeRelock()
    private let timers = FakeRelock()

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, passes: MemoryPassVault(), timers: timers,
                   now: { [clocks] in clocks.now }, clock: { [clocks] in clocks.anchor })
    }

    @Test func movingTheClockPastATimersEndKeepsTheLock() throws {
        let engine = makeEngine()
        try engine.lockTimed(duration: 30 * 60)
        clocks.real += 60
        clocks.now += 3 * 3600
        engine.syncShields()
        engine.tick()
        #expect(store.session.lockState == .locked)
        #expect(store.timerLock != nil)
        // The monitor's end is booked again at the real end.
        #expect(timers.scheduled.last?.relockAt == clocks.now + 29 * 60)
        clocks.real += 29 * 60
        engine.tick()
        #expect(store.session == .unlocked)
    }

    @Test func movingTheClockBackBeforeATimerStartedKeepsTheLock() throws {
        let engine = makeEngine()
        try engine.lockTimed(duration: 30 * 60)
        clocks.real += 60
        clocks.now -= 3600
        engine.syncShields()
        #expect(store.session.lockState == .locked)
    }

    @Test func movingTheClockBackDuringAPassStillRelocksOnTime() throws {
        let engine = makeEngine()
        #expect(engine.lock())
        try engine.useEmergencyPass()
        #expect(store.passAnchor != nil)
        // At 4:30 real, the clock is moved back to make the pass look newer.
        clocks.real += 270
        clocks.now += 270 - 120
        #expect(!engine.tick())
        clocks.real += 30
        clocks.now += 30
        #expect(engine.tick())
        #expect(store.session.lockState == .locked)
        #expect(store.passAnchor == nil)
    }

    @Test func aLockTheMonitorLandsDuringASyncGetsItsShieldsBack() {
        let engine = makeEngine()
        // The monitor locks between the sync's read of the session and its clear.
        shields.onClear = { [store] in store.session = .locked(since: Date(timeIntervalSinceReferenceDate: 800_000_000)) }
        engine.syncShields()
        #expect(store.session.lockState == .locked)
        #expect(shields.applied == 1)
    }
}

struct ScheduleClockTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    /// An unlock stamped under a clock that was later set back can't hold off a scheduled lock.
    @Test func aFutureUnlockTimeDoesNotSkipAWindow() {
        let store = SharedStore.makeTest()
        let mode = Mode(name: "Work", schedule: ModeSchedule(days: ModeSchedule.everyDay, start: 9 * 60, end: 17 * 60))
        store.modes = [mode]
        store.lastUnlockAt = date(30, 12)
        let decision = ScheduledLock.decide(mode: mode, store: store, now: date(27, 9), accessApproved: true,
                                            hasApps: true, hasTag: true, calendar: calendar)
        #expect(decision == .lock(mode))
        store.lastUnlockAt = date(27, 9, 0) + 30
        let unlocked = ScheduledLock.decide(mode: mode, store: store, now: date(27, 9, 1), accessApproved: true,
                                            hasApps: true, hasTag: true, calendar: calendar)
        #expect(unlocked == .skipQuietly("unlocked during this window"))
    }

    @Test func pickerTimesSurviveASpringForwardDay() {
        // The editor builds its pickers on a fixed day, so 2:30 stays 2:30 whatever day it opens on.
        for minutes in stride(from: 0, to: 1440, by: 15) {
            #expect(ClockMinutes.minutes(of: ClockMinutes.date(minutes, calendar: calendar), calendar: calendar) == minutes)
        }
    }

    @Test func eighteenSchedulesFitButANineteenthDoesNot() {
        let schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 9 * 60, end: 17 * 60)
        let modes = (0..<ModeActivity.limit).map { Mode(name: "M\($0)", schedule: schedule) }
        #expect(!ModeActivity.fits(Mode(name: "New", schedule: schedule), in: modes))
        #expect(ModeActivity.fits(Mode(name: "Manual"), in: modes))
        var renamed = modes[3]
        renamed.name = "Renamed"
        #expect(ModeActivity.fits(renamed, in: modes))
    }

    @Test func aStreakSurvivesMidnightDaylightSaving() {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = TimeZone(identifier: "America/Santiago")!
        // Daylight saving starts at midnight on 2026-09-06 there.
        let history = (1...10).map { day -> LockRecord in
            let start = santiago.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
            return LockRecord(start: start, end: start + 1800, placeUID: nil, modeID: UUID())
        }
        let now = santiago.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 18))!
        #expect(Insights.streak(history: history, now: now, calendar: santiago) == 10)
        let week = Insights.days(weekOf: now, history: history, now: now, calendar: santiago)
        #expect(week.allSatisfy { santiago.startOfDay(for: $0.start) == $0.start })
    }
}

@MainActor
struct ModelLockGuardTests {
    private let store = SharedStore.makeTest()
    private let kitchen = TagUID(hex: "04A1B2C3D4E5F6")

    private func lockedModel() -> AppModel {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        store.session = .locked(since: .now)
        model.reload()
        return model
    }

    @Test func modesPlacesAndAllowedAppsCantChangeDuringALock() {
        let model = lockedModel()
        let before = store.modes
        var edited = model.activeMode
        edited.name = "Changed"
        model.save(edited)
        model.save(Mode(name: "Extra"))
        #expect(store.modes == before)
        #expect(!model.deleteMode(id: model.activeMode.id))
        #expect(model.pair(TagUID(hex: "04FFFFFFFFFFFF"), name: "New") == .locked)
        model.removePlace(kitchen)
        #expect(store.pairedTags.count == 1)
    }

    @Test func theActiveModeCantChangeDuringALock() {
        let store = self.store
        let model = AppModel(store: store)
        model.save(Mode(name: "Other"))
        let active = model.activeMode.id
        store.session = .locked(since: .now)
        model.setActiveMode(model.otherModes[0].id)
        #expect(store.activeModeID == active)
    }

    @Test func tagsWhoseIDChangesCantBePaired() {
        let model = AppModel(store: store)
        #expect(model.pair(TagUID(hex: "08A1B2C3"), name: "Badge") == .unstableTag)
        #expect(model.pair(TagUID(hex: ""), name: "Blank") == .unstableTag)
        #expect(model.pair(TagUID(hex: "04A1B2C3"), name: "Sticker") == .paired)
        #expect(!TagUID(hex: "08a1b2c3").isStable)
        #expect(TagUID(hex: "08A1B2C3D4E5F6").isStable)
    }

    /// The monitor changed the active mode (a timer handed over) since the model last reloaded.
    @Test func aTagIsCheckedAgainstTheModeThatIsLockedNow() {
        let model = AppModel(store: store)
        let office = TagUID(hex: "04000000000001")
        model.pair(kitchen, name: "Kitchen")
        model.pair(office, name: "Office")
        let strict = Mode(name: "Strict", unlockPlaces: [office])
        model.save(strict)
        store.activeModeID = strict.id // written by the monitor; the model hasn't reloaded
        #expect(model.check(kitchen, unlocking: true) == .wrongPlace(PairedTag(uid: kitchen, name: "Kitchen",
                                                                                pairedAt: model.places[0].pairedAt)))
        #expect(model.check(office, unlocking: true) != .unknown)
    }

    @Test func aDamagedModeListIsNotReplaced() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let store = SharedStore.makeTest(suite: suite)
        UserDefaults(suiteName: suite)!.set(Data("not json".utf8), forKey: "modes")
        let model = AppModel(store: store)
        #expect(model.modes.count == 1)
        #expect(UserDefaults(suiteName: suite)!.data(forKey: "modes") == Data("not json".utf8))
    }
}

struct SurfaceFixTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// A timer the monitor ended while Tapout was closed stops counting at its end in the widgets.
    @Test func widgetsStopCountingATimerTheMonitorEnded() {
        let store = SharedStore.makeTest()
        let timer = TimerLock(start: now - 3600, duration: 1800)
        store.lockHistory = [LockRecord(start: timer.start, end: nil, placeUID: nil, modeID: UUID())]
        store.finishedTimer = timer
        store.session = .unlocked
        let snapshot = LockSnapshot.make(store: store, now: now)
        #expect(snapshot.today == 1800)
        #expect(snapshot.state == .unlocked)
    }

    /// A lock a schedule started while Tapout was closed has no record yet, but still counts.
    @Test func widgetsCountAScheduledLockWithoutARecord() {
        let store = SharedStore.makeTest()
        store.session = .locked(since: now - 600)
        let snapshot = LockSnapshot.make(store: store, now: now)
        #expect(snapshot.today == 600)
    }

    @Test func aTimerThatHandsOverKeepsReadingLocked() {
        let state = LockActivityAttributes.ContentState(lockedFrom: now - 600, openUntil: nil, modeName: "Deep work",
                                                        placeName: nil, timerEndsAt: now, handsOver: true)
        #expect(!state.timerIsOver(isStale: true))
        #expect(state.timerEnd(isStale: true) == nil)
        #expect(state.timerEnd(isStale: false) == now)
    }

    @Test func aPassThatEndsBeforeItsTimerShowsTheEndTime() {
        let state = LockActivityAttributes.ContentState(lockedFrom: now - 600, openUntil: now, modeName: "Deep work",
                                                        placeName: nil, timerEndsAt: now + 900)
        #expect(state.showsEndTime(isStale: true))
        #expect(!state.showsEndTime(isStale: false))
    }

    @Test func aLongLockNeverFreezesAt24Hours() {
        let start = now - 30 * 3600
        let range = LockActivityTiming.countUp(from: start, now: now)
        #expect(range.upperBound >= now + 12 * 3600)
        #expect(LockActivityTiming.countUp(from: now, now: now).upperBound == now + 24 * 3600)
    }
}
