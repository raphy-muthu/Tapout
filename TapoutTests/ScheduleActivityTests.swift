import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct ScheduleActivityTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// 2026-11-09 is a Monday; the 13th is a Friday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)
    private let fridayNights = ModeSchedule(days: [6], start: 22 * 60, end: 6 * 60)

    @Test func aWeekdayWindowContainsItsAfternoon() {
        #expect(afternoons.window(containing: date(9, 14), calendar: calendar)
            == DateInterval(start: date(9, 13), end: date(9, 17)))
    }

    @Test func beforeTheStartIsOutside() {
        #expect(afternoons.window(containing: date(9, 12, 59), calendar: calendar) == nil)
    }

    @Test func anUnscheduledDayIsOutside() {
        #expect(afternoons.window(containing: date(14, 14), calendar: calendar) == nil)
    }

    @Test func anOvernightWindowRunsPastMidnight() {
        #expect(fridayNights.window(containing: date(14, 2), calendar: calendar)
            == DateInterval(start: date(13, 22), end: date(14, 6)))
    }

    @Test func anOvernightWindowBelongsToItsStartDay() {
        // Saturday night is not scheduled, so Sunday 2 AM is outside.
        #expect(fridayNights.window(containing: date(15, 2), calendar: calendar) == nil)
        #expect(fridayNights.window(containing: date(13, 21, 59), calendar: calendar) == nil)
    }

    @Test func aTooShortScheduleNeverRuns() {
        let short = ModeSchedule(days: ModeSchedule.everyDay, start: 600, end: 610)
        #expect(short.window(containing: date(9, 10, 5), calendar: calendar) == nil)
    }

    @Test func activityNamesRoundTrip() {
        let id = UUID()
        #expect(ModeActivity.modeID(of: ModeActivity.name(for: id)) == id)
        #expect(ModeActivity.modeID(of: RelockPlan.activity) == nil)
    }

    @Test func theDeviceScheduleRepeatsDailyFromStartToEnd() {
        let schedule = ModeActivity.deviceSchedule(for: fridayNights)
        #expect(schedule.intervalStart.hour == 22)
        #expect(schedule.intervalStart.minute == 0)
        #expect(schedule.intervalEnd.hour == 6)
        #expect(schedule.repeats)
    }

    @Test func thePlanSkipsManualAndShortSchedulesAndStopsAtTheLimit() {
        let manual = Mode(name: "Manual")
        let short = Mode(name: "Short", schedule: ModeSchedule(days: [2], start: 600, end: 610))
        let many = (0..<25).map { Mode(name: "M\($0)", schedule: afternoons) }
        let plan = ModeActivity.plan(for: [manual, short] + many)
        #expect(plan.count == ModeActivity.limit)
        #expect(plan.first?.name == ModeActivity.name(for: many[0].id))
        #expect(plan.first?.schedule == afternoons)
    }

    @Test func springForwardDayKeepsWallClockTimes() {
        let schedule = ModeSchedule(days: ModeSchedule.everyDay, start: 13 * 60, end: 17 * 60)
        #expect(schedule.window(containing: date(2027, 3, 14, 13, 30), calendar: calendar)
            == DateInterval(start: date(2027, 3, 14, 13), end: date(2027, 3, 14, 17)))
    }

    @Test func fallBackDayKeepsWallClockTimes() {
        let schedule = ModeSchedule(days: ModeSchedule.everyDay, start: 13 * 60, end: 17 * 60)
        #expect(schedule.window(containing: date(2026, 11, 1, 13, 30), calendar: calendar)
            == DateInterval(start: date(2026, 11, 1, 13), end: date(2026, 11, 1, 17)))
    }

    @Test func anOvernightWindowAcrossTheClockChangeEndsAtSixWallClock() {
        let schedule = ModeSchedule(days: ModeSchedule.everyDay, start: 22 * 60, end: 6 * 60)
        #expect(schedule.window(containing: date(2026, 11, 1, 3), calendar: calendar)
            == DateInterval(start: date(2026, 10, 31, 22), end: date(2026, 11, 1, 6)))
    }

    @Test func startIsInsideAndEndIsOutside() {
        #expect(afternoons.window(containing: date(9, 13), calendar: calendar) != nil)
        #expect(afternoons.window(containing: date(9, 17), calendar: calendar) == nil)
    }

    @Test func aScheduleWithNoDaysIsNotPlanned() {
        let noDays = Mode(name: "None", schedule: ModeSchedule(days: [], start: 13 * 60, end: 17 * 60))
        #expect(ModeActivity.plan(for: [noDays]).isEmpty)
    }
}
