import Foundation
import Testing
@testable import Tapout

struct LockStatsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }()
    private let mode = UUID()
    private let kitchen = TagUID(hex: "04A1")

    /// Wednesday 28 October 2026, 12:00 UTC.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))! }

    @Test func countsLocksAtOnePlace() {
        let history = [
            LockRecord(start: now - 5 * 3600, end: now - 4 * 3600, placeUID: kitchen, modeID: mode),
            LockRecord(start: now - 3 * 3600, end: now - 2 * 3600, placeUID: TagUID(hex: "04B2"), modeID: mode),
            LockRecord(start: now - 3600, end: now - 1800, placeUID: kitchen, modeID: mode),
        ]
        #expect(LockStats.lockCount(at: kitchen, in: history) == 2)
    }

    @Test func weekTotalClipsAtTheWeekStartAndCountsTheRunningLock() {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let history = [
            LockRecord(start: weekStart - 3600, end: weekStart + 3600, placeUID: nil, modeID: mode), // 1h inside
            LockRecord(start: now - 7200, end: now - 3600, placeUID: nil, modeID: mode), // 1h
            LockRecord(start: now - 1800, end: nil, placeUID: nil, modeID: mode), // running, 30m so far
            LockRecord(start: now - 7200, end: now, placeUID: nil, modeID: UUID()), // another mode
            LockRecord(start: weekStart - 86_400, end: weekStart - 82_800, placeUID: nil, modeID: mode), // last week
        ]
        #expect(LockStats.lockedTime(modeID: mode, weekOf: now, in: history, calendar: calendar) == 9000)
    }
}
