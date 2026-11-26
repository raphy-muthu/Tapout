import Foundation
import Testing
@testable import Tapout

struct HeatmapTests {
    private let calendar = TestDates.calendar
    private func oct(_ day: Int, _ hour: Int) -> Date { TestDates.oct(day, hour) }
    private func lock(_ start: Date, _ minutes: Double) -> LockRecord { TestDates.lock(start, minutes: minutes) }

    @Test func coversFiveWeeksEndingWithThisOne() {
        let weeks = Insights.heatmap(history: [], now: oct(28, 12), calendar: calendar)
        #expect(weeks.count == 5)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks[0][0].start == oct(28, 0) - 30 * 86_400) // Monday 28 September
        #expect(weeks[4][0].start == oct(26, 0))
        #expect(weeks.flatMap { $0 }.filter(\.isToday).map(\.start) == [oct(28, 0)])
    }

    @Test func daysAfterTodayAreClosed() {
        let week = Insights.heatmap(history: [lock(oct(1, 9), 30)], now: oct(28, 12), calendar: calendar)[4]
        #expect(week.map(\.isOpen) == [true, true, true, false, false, false, false])
    }

    @Test func daysBeforeTheFirstLockAreClosed() {
        let days = Insights.heatmap(history: [lock(oct(21, 9), 30), lock(oct(27, 9), 30)],
                                    now: oct(28, 12), calendar: calendar).flatMap { $0 }
        let open = days.filter(\.isOpen).map(\.start)
        #expect(open.first == oct(21, 0))
        #expect(open.last == oct(28, 0))
        #expect(open.count == 8) // empty days after the first lock stay open
    }

    @Test func aNewOwnerOnlyHasToday() {
        let days = Insights.heatmap(history: [], now: oct(28, 12), calendar: calendar).flatMap { $0 }
        #expect(days.filter(\.isOpen).map(\.start) == [oct(28, 0)])
    }

    @Test func aFirstLockOlderThanTheGridOpensEveryPastDay() {
        let days = Insights.heatmap(history: [lock(oct(1, 9) - 60 * 86_400, 30)], now: oct(28, 12), calendar: calendar)
            .flatMap { $0 }
        #expect(days.filter(\.isOpen).count == 31)
    }

    @Test func eachDayCarriesItsOwnTimeAndARunningLockCountsToNow() {
        let running = LockRecord(start: oct(28, 11), end: nil, placeUID: nil, modeID: TestDates.modeID)
        let week = Insights.heatmap(history: [lock(oct(26, 9), 45), running], now: oct(28, 12), calendar: calendar)[4]
        #expect(week[0].lockedTime == 45 * 60)
        #expect(week[1].lockedTime == 0)
        #expect(week[2].lockedTime == 3600)
    }

    @Test func thePeakIsTheBusiestDayButAtLeastAnHour() {
        let short = Insights.heatmap(history: [lock(oct(27, 9), 5)], now: oct(28, 12), calendar: calendar)
        let long = Insights.heatmap(history: [lock(oct(27, 9), 150)], now: oct(28, 12), calendar: calendar)
        #expect(Insights.heatPeak(short) == 3600)
        #expect(Insights.heatPeak(long) == 150 * 60)
    }

    @Test func strengthStartsVisibleAndTopsOutAtThePeak() {
        #expect(Insights.heatStrength(0, peak: 3600) == 0)
        #expect(Insights.heatStrength(59, peak: 3600) == 0)
        #expect(Insights.heatStrength(60, peak: 3600) > 0.2)
        #expect(Insights.heatStrength(1800, peak: 3600) > Insights.heatStrength(60, peak: 3600))
        #expect(Insights.heatStrength(3600, peak: 3600) == 1)
        #expect(Insights.heatStrength(9000, peak: 3600) == 1)
    }
}

struct ChartScrubTests {
    private let days = (26...28).map { TestDates.oct($0, 0) }

    @Test func theColumnUnderTheFingerIsClampedToTheChart() {
        #expect(ChartScrub.index(at: 0, width: 350, count: 7) == 0)
        #expect(ChartScrub.index(at: 49, width: 350, count: 7) == 0)
        #expect(ChartScrub.index(at: 50, width: 350, count: 7) == 1)
        #expect(ChartScrub.index(at: 350, width: 350, count: 7) == 6)
        #expect(ChartScrub.index(at: -20, width: 350, count: 7) == 0)
        #expect(ChartScrub.index(at: 900, width: 350, count: 7) == 6)
        #expect(ChartScrub.index(at: 10, width: 0, count: 7) == nil)
        #expect(ChartScrub.index(at: 10, width: 350, count: 0) == nil)
    }

    @Test func onlyASidewaysDragScrubs() {
        #expect(ChartScrub.isSideways(dx: 9, dy: 2))
        #expect(ChartScrub.isSideways(dx: -9, dy: 2))
        #expect(!ChartScrub.isSideways(dx: 2, dy: -9))
        #expect(!ChartScrub.isSideways(dx: 6, dy: 6)) // a tie scrolls
    }

    @Test func tappingTheSelectedDayClearsIt() {
        #expect(ChartScrub.tapped(days[0], selected: nil) == days[0])
        #expect(ChartScrub.tapped(days[1], selected: days[0]) == days[1])
        #expect(ChartScrub.tapped(days[1], selected: days[1]) == nil)
    }

    @Test func steppingMovesOneDayFromTheSelectionOrToday() {
        #expect(ChartScrub.stepped(from: nil, by: -1, through: days) == days[1])
        #expect(ChartScrub.stepped(from: days[1], by: -1, through: days) == days[0])
        #expect(ChartScrub.stepped(from: days[0], by: -1, through: days) == days[0])
        #expect(ChartScrub.stepped(from: days[2], by: 1, through: days) == days[2])
        #expect(ChartScrub.stepped(from: TestDates.oct(1, 0), by: 1, through: days) == days[2]) // stale: from today
        #expect(ChartScrub.stepped(from: nil, by: 1, through: []) == nil)
    }
}
