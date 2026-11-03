import Foundation
import Testing
@testable import Tapout

struct ScheduleFormatTests {
    private let posix: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    @Test(arguments: [
        (ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020), "9–5"),
        (ModeSchedule(days: ModeSchedule.weekdays, start: 570, end: 1020), "9:30–5"),
        (ModeSchedule(days: ModeSchedule.everyDay, start: 1350, end: 420), "10:30–7"),
        (ModeSchedule(days: ModeSchedule.everyDay, start: 0, end: 720), "12–12"),
    ])
    func shortFormFitsATile(_ schedule: ModeSchedule, _ expected: String) {
        #expect(ScheduleFormat.short(schedule) == expected)
    }

    @Test func rangeFollowsTheLocale() {
        let schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020)
        #expect(ScheduleFormat.range(schedule, locale: Locale(identifier: "de_DE")) == "09:00 – 17:00")
    }

    @Test func namedDayGroups() {
        #expect(ScheduleFormat.days(ModeSchedule.weekdays, calendar: posix) == "weekdays")
        #expect(ScheduleFormat.days(ModeSchedule.weekend, calendar: posix) == "weekends")
        #expect(ScheduleFormat.days(ModeSchedule.everyDay, calendar: posix) == "every day")
    }

    @Test func otherDaysListMondayFirst() {
        #expect(ScheduleFormat.days([1, 4, 2], calendar: posix) == "Mon, Wed, Sun")
    }

    @Test func consecutiveDaysCompressToARange() {
        #expect(ScheduleFormat.days([2, 3, 4, 5, 6, 7], calendar: posix) == "Mon–Sat")
        #expect(ScheduleFormat.days([2, 3, 4, 6], calendar: posix) == "Mon–Wed, Fri")
    }

    @Test func shortRunsListIndividually() {
        #expect(ScheduleFormat.days([2, 3], calendar: posix) == "Mon, Tue")
    }

    @Test func noDaysIsManual() {
        #expect(ScheduleFormat.days([], calendar: posix) == "manual")
    }

    @Test func rangesDoNotWrapFromSundayToMonday() {
        #expect(ScheduleFormat.days([1, 2, 3], calendar: posix) == "Mon, Tue, Sun")
    }

    @Test func clockMinutesRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = ClockMinutes.date(570, on: Date(timeIntervalSinceReferenceDate: 800_000_000), calendar: calendar)
        #expect(calendar.component(.hour, from: date) == 9)
        #expect(ClockMinutes.minutes(of: date, calendar: calendar) == 570)
    }
}
