import Foundation
import Testing
@testable import Tapout

struct LockSnapshotTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    /// Monday 2026-11-09, 2 PM.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 14))! }
    private let mode = Mode(name: "Deep work")
    private let kitchen = TagUID(hex: "04AA01")

    private func snapshot() -> LockSnapshot { .make(store: store, now: now, calendar: calendar) }

    @Test func unlockedShowsTodayAndTheWeek() {
        store.lockHistory = [LockRecord(start: now - 7200, end: now - 3600, placeUID: nil, modeID: mode.id)]
        let shot = snapshot()
        #expect(shot.state == .unlocked)
        #expect(shot.today == 3600)
        #expect(shot.weekTotal == 3600)
        #expect(shot.days.count == 7)
    }

    @Test func aLockCountsFromItsStartWithoutPasses() {
        store.session = .locked(since: now - 3600)
        store.lockHistory = [LockRecord(start: now - 3600, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 1800, duration: 600)])]
        #expect(snapshot().state == .locked(countingFrom: now - 3000))
    }

    @Test func aLockWithoutARecordCountsFromTheLockState() {
        store.session = .locked(since: now - 120)
        #expect(snapshot().state == .locked(countingFrom: now - 120))
    }

    @Test func aPassResumesTheTimerAfterTheRelock() {
        store.session = .emergency(relockAt: now + 200, duration: 300)
        store.lockHistory = [LockRecord(start: now - 1000, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 100, end: now + 200)])]
        #expect(snapshot().state == .open(relockAt: now + 200, resumesFrom: now - 700))
    }

    @Test func aPassPastItsRelockTimeShowsTheLock() {
        store.session = .emergency(relockAt: now - 60, duration: 300)
        store.lockHistory = [LockRecord(start: now - 1000, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 360, end: now - 60)])]
        #expect(snapshot().state == .locked(countingFrom: now - 700))
    }

    @Test func aLockStartInTheFutureIsClamped() {
        store.session = .locked(since: now + 300)
        #expect(snapshot().state == .locked(countingFrom: now))
    }

    @Test func namesTheActiveModeAndTheLocksPlace() {
        store.activeModeName = "Deep work"
        store.pairedTags = [PairedTag(uid: kitchen, name: "Kitchen", pairedAt: now - 86_400)]
        store.session = .locked(since: now - 60)
        store.lockHistory = [LockRecord(start: now - 60, end: nil, placeUID: kitchen, modeID: mode.id)]
        let shot = snapshot()
        #expect(shot.modeName == "Deep work")
        #expect(shot.placeName == "Kitchen")
    }

    // MARK: Timer lock

    @Test func aTimerLockGivesTheEndDate() {
        store.session = .locked(since: now - 900)
        store.timerLock = TimerLock(start: now - 900, duration: 2700)
        let shot = snapshot()
        #expect(shot.timerEndsAt == now + 1800)
        #expect(shot.state == .locked(countingFrom: now - 900))
    }

    @Test func noEndDateWithoutATimerLock() {
        store.session = .locked(since: now - 900)
        #expect(snapshot().timerEndsAt == nil)
    }

    @Test func noEndDateOnceTheTimerIsDue() {
        store.session = .locked(since: now - 2700)
        store.timerLock = TimerLock(start: now - 2700, duration: 2700)
        let shot = snapshot()
        #expect(shot.timerEndsAt == nil)
        #expect(shot.state == .unlocked)
    }

    @Test func noEndDateWhileUnlocked() {
        store.timerLock = TimerLock(start: now - 900, duration: 2700)
        #expect(snapshot().timerEndsAt == nil)
        #expect(snapshot().state == .unlocked)
    }

    @Test func aPassDuringATimerKeepsTheEndDate() {
        store.session = .emergency(relockAt: now + 200, duration: 300)
        store.timerLock = TimerLock(start: now - 900, duration: 2700)
        store.lockHistory = [LockRecord(start: now - 900, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 100, end: now + 200)])]
        let shot = snapshot()
        #expect(shot.timerEndsAt == now + 1800)
        #expect(shot.state == .open(relockAt: now + 200, resumesFrom: now - 600))
    }

    @Test func aTimerLockThatEndedDuringAPassReadsUnlocked() {
        store.session = .emergency(relockAt: now + 600, duration: 300)
        store.timerLock = TimerLock(start: now - 2700, duration: 2700)
        #expect(snapshot().state == .unlocked)
        #expect(snapshot().timerEndsAt == nil)
    }
}
