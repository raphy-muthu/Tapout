import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct RelockPlanTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func warningRunsFifteenMinutesAndWarnsAtTheRelockTime() {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: .warning, calendar: calendar)
        #expect(calendar.date(from: schedule.intervalStart) == now)
        #expect(calendar.date(from: schedule.intervalEnd) == now + 900)
        #expect(schedule.warningTime == DateComponents(minute: 10, second: 0))
        #expect(schedule.repeats == false)
    }

    @Test func pastStartEndsAtTheRelockTime() {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: .pastStart, calendar: calendar)
        #expect(calendar.date(from: schedule.intervalStart) == now - 600)
        #expect(calendar.date(from: schedule.intervalEnd) == now + 300)
        #expect(schedule.warningTime == nil)
        #expect(schedule.repeats == false)
    }

    @Test(arguments: RelockStrategy.allCases)
    func everyIntervalMeetsTheFifteenMinuteMinimum(_ strategy: RelockStrategy) throws {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: strategy, calendar: calendar)
        let start = try #require(calendar.date(from: schedule.intervalStart))
        let end = try #require(calendar.date(from: schedule.intervalEnd))
        #expect(end.timeIntervalSince(start) >= RelockPlan.minimumInterval)
    }
}
