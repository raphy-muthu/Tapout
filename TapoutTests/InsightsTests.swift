import Foundation
import Testing
@testable import Tapout

struct InsightsTests {
    private let calendar = TestDates.calendar
    private func oct(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestDates.oct(day, hour, minute) }
    private func lock(_ start: Date, _ minutes: Double, _ intention: String? = nil, _ done: Bool? = nil) -> LockRecord {
        TestDates.lock(start, minutes: minutes, intention: intention, done: done)
    }

    @Test func lockedTimeClipsToTheIntervalAndCountsARunningLock() {
        let overnight = lock(oct(25, 23), 120) // Sunday 23:00 to Monday 01:00
        let running = LockRecord(start: oct(26, 10), end: nil, placeUID: nil, modeID: TestDates.modeID)
        let monday = calendar.dateInterval(of: .day, for: oct(26, 12))!
        let time = Insights.lockedTime(in: monday, history: [overnight, running], now: oct(26, 10, 30))
        #expect(time == 90 * 60)
    }

    @Test func daysRunMondayToSundayAndMarkToday() {
        let history = [lock(oct(26, 9), 60), lock(oct(28, 9), 30)]
        let days = Insights.days(weekOf: oct(28, 12), history: history, now: oct(28, 12), calendar: calendar)
        #expect(days.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(days[0].lockedTime == 3600)
        #expect(days[2].lockedTime == 1800)
        #expect(days[2].isToday)
        #expect(days.filter(\.isToday).count == 1)
    }

    @Test func countAndLongestUseThisWeeksFinishedLocks() {
        let history = [
            lock(oct(25, 9), 200), // last week
            lock(oct(26, 9), 40),
            lock(oct(27, 9), 90),
            LockRecord(start: oct(28, 9), end: nil, placeUID: nil, modeID: TestDates.modeID),
        ]
        #expect(Insights.lockCount(weekOf: oct(28, 10), history: history, calendar: calendar) == 2)
        #expect(Insights.longest(weekOf: oct(28, 10), history: history, calendar: calendar) == TimeInterval(90 * 60))
    }

    @Test func longestIsNilBeforeTheFirstLock() {
        #expect(Insights.longest(weekOf: oct(28, 10), history: [], calendar: calendar) == nil)
        #expect(Insights.lockCount(weekOf: oct(28, 10), history: [], calendar: calendar) == 0)
    }

    @Test func bestTimeWaitsForEightLocks() {
        let history = (20...26).map { lock(oct($0, 14), 30) }
        #expect(Insights.bestTime(history: history, now: oct(28, 12), calendar: calendar) == .progress(have: 7, need: 8))
    }

    @Test func bestTimePicksTheBusiestBlock() {
        let afternoons = (20...24).map { lock(oct($0, 14), 30) }
        let mornings = (25...27).map { lock(oct($0, 9), 30) }
        #expect(Insights.bestTime(history: afternoons + mornings, now: oct(28, 12), calendar: calendar) == .value(.afternoons))
    }

    @Test func bestTimeWaitsForAClearBlock() {
        let history = [9, 14, 19, 23].flatMap { hour in [lock(oct(20, hour), 30), lock(oct(21, hour), 30)] }
        #expect(history.count == 8)
        #expect(Insights.bestTime(history: history, now: oct(28, 12), calendar: calendar) == .progress(have: 2, need: 3))
    }

    @Test func bestTimeLooksBack28Days() {
        let now = oct(28, 12)
        let recent = (20...26).map { lock(oct($0, 14), 30) }
        let inside = lock(now - 27 * 86_400, 30)
        let outside = lock(now - 29 * 86_400, 30)
        #expect(Insights.bestTime(history: recent + [outside], now: now, calendar: calendar) == .progress(have: 7, need: 8))
        #expect(Insights.bestTime(history: recent + [inside], now: now, calendar: calendar) == .value(.afternoons))
    }

    @Test func timeBlockBoundaries() {
        let blocks: [(Int, TimeBlock)] = [
            (0, .nights), (4, .nights), (5, .mornings), (11, .mornings), (12, .afternoons),
            (16, .afternoons), (17, .evenings), (21, .evenings), (22, .nights), (23, .nights),
        ]
        for (hour, block) in blocks {
            #expect(TimeBlock.of(hour: hour) == block)
        }
    }

    @Test func goalsWaitForThreeAnswers() {
        let history = [
            lock(oct(26, 9), 30, "Essay", true),
            lock(oct(27, 9), 30, "Notes", false),
            lock(oct(27, 15), 30, "Reading", nil),
        ]
        #expect(Insights.goals(history: history, now: oct(28, 12)) == .progress(have: 2, need: 3))
    }

    @Test func goalsCountTheDoneOnes() {
        let history = [
            lock(oct(25, 9), 30, "Essay", true),
            lock(oct(26, 9), 30, "Essay", true),
            lock(oct(27, 9), 30, "Notes", false),
            lock(oct(27, 15), 30),
        ]
        #expect(Insights.goals(history: history, now: oct(28, 12)) == .value(Insights.Goals(done: 2, answered: 3)))
    }

    @Test func streakStaysAliveUntilMidnight() {
        let history = [lock(oct(26, 9), 30), lock(oct(27, 9), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 2)
    }

    @Test func streakCountsToday() {
        let history = [lock(oct(26, 9), 30), lock(oct(27, 9), 30), lock(oct(28, 7), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 3)
    }

    @Test func streakBreaksOnAGap() {
        let history = [lock(oct(24, 9), 30), lock(oct(26, 9), 30), lock(oct(27, 9), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 2)
    }

    @Test func passTimeIsNotPhoneFree() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let lock = LockRecord(start: start, end: start + 3600, placeUID: nil, modeID: UUID(),
                              passes: [DateInterval(start: start + 600, duration: 300)])
        #expect(Insights.totalLocked(history: [lock], now: start + 7200) == 3300)
        #expect(Insights.lockedTime(in: DateInterval(start: start, end: start + 3600), history: [lock], now: start + 7200) == 3300)
        #expect(Insights.longest(weekOf: start, history: [lock], calendar: .current) == 3300)
    }
}
