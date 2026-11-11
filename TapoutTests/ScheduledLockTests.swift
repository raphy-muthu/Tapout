import Foundation
import Testing
@testable import Tapout

struct ScheduledLockTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let mode = Mode(name: "Focus", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))

    /// 2026-11-09 is a Monday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    private func decide(at now: Date, access: Bool = true, apps: Bool = true, tag: Bool = true) -> ScheduledLock.Decision {
        ScheduledLock.decide(mode: mode, store: store, now: now, accessApproved: access, hasApps: apps, hasTag: tag, calendar: calendar)
    }

    @Test(arguments: [true, false, nil] as [Bool?])
    func accessRuleTrustsLiveStatusFirst(mirrored: Bool?) {
        #expect(ScheduledLock.accessApproved(live: .approved, mirrored: mirrored))
        #expect(!ScheduledLock.accessApproved(live: .denied, mirrored: mirrored))
        #expect(ScheduledLock.accessApproved(live: .notDetermined, mirrored: mirrored) == (mirrored ?? true))
    }

    @Test func locksAtTheStartOfAWindow() {
        #expect(decide(at: date(9, 13, 0, 5)) == .lock(mode))
    }

    @Test func aCallbackAMinuteEarlyStillLocks() {
        #expect(decide(at: date(9, 12, 59, 30)) == .lock(mode))
    }

    @Test func skipsQuietlyOnAnotherDay() {
        guard case .skipQuietly = decide(at: date(14, 13)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func skipsQuietlyWhenAlreadyLocked() {
        store.session = .locked(since: date(9, 12))
        guard case .skipQuietly = decide(at: date(9, 13)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func skipsAWindowTheOwnerUnlockedIn() {
        store.lastUnlockAt = date(9, 13, 30)
        guard case .skipQuietly = decide(at: date(9, 14)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func anUnlockBeforeTheWindowDoesNotCount() {
        store.lastUnlockAt = date(9, 12)
        #expect(decide(at: date(9, 13)) == .lock(mode))
    }

    @Test func skipsAWindowTheScheduleWasSavedIn() {
        store.scheduleSavedAt = [mode.id.uuidString: date(9, 14)]
        guard case .skipQuietly = decide(at: date(9, 14, 1)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func tellsWhenScreenTimeIsOff() {
        #expect(decide(at: date(9, 13), access: false) == .skip(.noAccess, mode))
    }

    @Test func tellsWhenTheModeHasNoApps() {
        #expect(decide(at: date(9, 13), apps: false) == .skip(.noApps, mode))
    }

    @Test func tellsWhenNoTagIsPaired() {
        #expect(decide(at: date(9, 13), tag: false) == .skip(.noTag, mode))
    }

    @Test func quietSkipsWinOverNoTag() {
        guard case .skipQuietly = decide(at: date(14, 13), tag: false) else {
            Issue.record("expected a quiet skip")
            return
        }
        store.session = .locked(since: date(9, 12))
        guard case .skipQuietly = decide(at: date(9, 13), tag: false) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func startMakesTheModeActiveThenLocksThenShields() {
        let other = Mode(name: "Other")
        store.modes = [other, mode]
        store.activeModeID = other.id
        let shields = FakeShields()
        ScheduledLock.start(mode, store: store, shields: shields, now: date(9, 13))
        #expect(store.activeModeID == mode.id)
        #expect(store.session == .locked(since: date(9, 13)))
        #expect(shields.plans == [store.activeShieldPlan])
    }

    @Test func startDoesNothingWhenAlreadyLocked() {
        let other = Mode(name: "Other")
        store.modes = [other, mode]
        store.activeModeID = other.id
        store.session = .locked(since: date(9, 12))
        let shields = FakeShields()
        let started = ScheduledLock.start(mode, store: store, shields: shields, now: date(9, 13))
        #expect(!started)
        #expect(store.activeModeID == other.id)
        #expect(store.session == .locked(since: date(9, 12)))
        #expect(shields.applied == 0)
    }

    @Test func quietSkipsWinOverMissingAccess() {
        store.session = .locked(since: date(9, 12))
        guard case .skipQuietly = decide(at: date(9, 13), access: false) else {
            Issue.record("expected a quiet skip when locked")
            return
        }
        store.session = .unlocked
        store.lastUnlockAt = date(9, 13, 30)
        guard case .skipQuietly = decide(at: date(9, 14), apps: false) else {
            Issue.record("expected a quiet skip when unlocked in the window")
            return
        }
    }

    @Test func missingAccessIsReportedBeforeMissingApps() {
        #expect(decide(at: date(9, 13), access: false, apps: false) == .skip(.noAccess, mode))
    }

    @Test func anUnlockExactlyAtTheStartCounts() {
        store.lastUnlockAt = date(9, 13)
        guard case .skipQuietly = decide(at: date(9, 13, 0, 5)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func aSaveExactlyAtTheStartStillLocks() {
        store.scheduleSavedAt = [mode.id.uuidString: date(9, 13)]
        #expect(decide(at: date(9, 13, 0, 5)) == .lock(mode))
    }

    @Test func anotherModesSaveIsIgnored() {
        store.scheduleSavedAt = [UUID().uuidString: date(9, 14)]
        #expect(decide(at: date(9, 14, 1)) == .lock(mode))
    }

    @Test func tooEarlyIsNotTheWindow() {
        guard case .skipQuietly = decide(at: date(9, 12, 57)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }
}
