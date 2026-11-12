import Foundation
import Testing
@testable import Tapout

/// The widgets' timelines: whole stretches of entries, so WidgetKit redraws on its own and reloads
/// rarely.
struct SnapshotTimelineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let mode = Mode(name: "Deep work")

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func timeline(at now: Date) -> SnapshotTimeline {
        LockSnapshot.timeline(store: store, now: now, calendar: calendar)
    }

    @Test func unlockedRedrawsAtMidnightOnly() {
        let now = date(9, 14)
        store.lockHistory = [LockRecord(start: now - 7200, end: now - 3600, placeUID: nil, modeID: mode.id)]
        let result = timeline(at: now)
        #expect(result.entries.map(\.date) == [now, date(10, 0)])
        #expect(result.reloadAfter == date(10, 0))
        #expect(result.entries[0].snapshot == .make(store: store, now: now, calendar: calendar))
        #expect(result.entries[0].snapshot.today == 3600)
        #expect(result.entries[1].snapshot.today == 0)
    }

    @Test func lockedRedrawsEveryQuarterHourForFourHours() throws {
        let now = date(9, 14)
        store.session = .locked(since: now - 3600)
        store.lockHistory = [LockRecord(start: now - 3600, end: nil, placeUID: nil, modeID: mode.id)]
        let result = timeline(at: now)
        #expect(result.entries.map(\.date) == (0...16).map { now + Double($0) * 900 })
        #expect(result.reloadAfter == now + 4 * 3600)
        #expect(result.entries.allSatisfy { $0.snapshot.state == .locked(countingFrom: now - 3600) })
        #expect(result.entries[1].snapshot.today == 3600 + 900)
        let last = try #require(result.entries.last)
        #expect(last.snapshot.today == TimeInterval(5 * 3600))
    }

    @Test func lockedIncludesMidnightInsideTheWindow() throws {
        let now = date(9, 22, 10)
        store.session = .locked(since: now - 600)
        store.lockHistory = [LockRecord(start: now - 600, end: nil, placeUID: nil, modeID: mode.id)]
        let result = timeline(at: now)
        let expected = ((0...16).map { now + Double($0) * 900 } + [date(10, 0)]).sorted()
        #expect(result.entries.map(\.date) == expected)
        #expect(result.reloadAfter == now + 4 * 3600)
        let midnight = try #require(result.entries.first { $0.date == date(10, 0) })
        #expect(midnight.snapshot.today == TimeInterval(0))
        #expect(midnight.snapshot.state == .locked(countingFrom: now - 600))
    }

    @Test func midnightOnAQuarterHourIsntDoubled() {
        let now = date(9, 22)
        store.session = .locked(since: now)
        store.lockHistory = [LockRecord(start: now, end: nil, placeUID: nil, modeID: mode.id)]
        let result = timeline(at: now)
        #expect(result.entries.count == 17)
        #expect(result.entries.contains { $0.date == date(10, 0) })
    }

    @Test func aPassRelocksAtItsTimeThenRedrawsLikeALock() {
        let now = date(9, 14)
        let relockAt = now + 200
        store.session = .emergency(relockAt: relockAt, duration: 300)
        store.lockHistory = [LockRecord(start: now - 1000, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 100, end: relockAt)])]
        let result = timeline(at: now)
        #expect(result.entries.map(\.date) == [now] + (0...16).map { relockAt + Double($0) * 900 })
        #expect(result.reloadAfter == relockAt + 4 * 3600)
        #expect(result.entries[0].snapshot.state == .open(relockAt: relockAt, resumesFrom: now - 700))
        #expect(result.entries[1].snapshot.state == .locked(countingFrom: now - 700))
        #expect(result.entries.dropFirst().allSatisfy { $0.snapshot.state == .locked(countingFrom: now - 700) })
    }

    @Test func aPassPastItsRelockTimeGetsALockTimeline() {
        let now = date(9, 14)
        store.session = .emergency(relockAt: now - 60, duration: 300)
        store.lockHistory = [LockRecord(start: now - 1000, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 360, end: now - 60)])]
        let result = timeline(at: now)
        #expect(result.entries.count == 17)
        #expect(result.entries[1].date == now + 900)
        #expect(result.entries[0].snapshot.state == .locked(countingFrom: now - 700))
    }

    /// 2026-11-01 is 25 hours long in New York: clocks go from 2:00 back to 1:00.
    @Test func midnightOnADaylightSavingDay() {
        let now = Date(timeIntervalSince1970: 1_793_511_000) // 2026-11-01 05:30 UTC, 01:30 EDT
        let midnight = Date(timeIntervalSince1970: 1_793_595_600) // 2026-11-02 05:00 UTC, 00:00 EST
        #expect(calendar.dateComponents([.day, .hour, .minute], from: now) == DateComponents(day: 1, hour: 1, minute: 30))
        #expect(calendar.dateComponents([.day, .hour, .minute], from: midnight) == DateComponents(day: 2, hour: 0, minute: 0))
        let result = timeline(at: now)
        #expect(result.entries.map(\.date) == [now, midnight])
        #expect(result.reloadAfter == midnight)
    }

    @Test func aPassReadsAsTheLockOnceItsRelockTimeComes() {
        let relockAt = date(9, 14)
        let shot = LockSnapshot.sample(.open(relockAt: relockAt, resumesFrom: relockAt - 700))
        #expect(shot.state(at: relockAt - 1) == .open(relockAt: relockAt, resumesFrom: relockAt - 700))
        #expect(shot.state(at: relockAt) == .locked(countingFrom: relockAt - 700))
        #expect(LockSnapshot.sample(.unlocked).state(at: relockAt) == .unlocked)
        #expect(LockSnapshot.sample(.locked(countingFrom: relockAt)).state(at: relockAt + 60) == .locked(countingFrom: relockAt))
    }
}
