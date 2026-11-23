import Foundation
import Testing
@testable import Tapout

struct TimeFormatTests {
    @Test func underAnHourShowsMinutesAndSeconds() {
        #expect(TimeFormat.clock(0) == "0:00")
        #expect(TimeFormat.clock(47 * 60 + 12) == "47:12")
        #expect(TimeFormat.clock(59 * 60 + 59) == "59:59")
    }

    @Test func fromAnHourShowsHoursAndMinutes() {
        #expect(TimeFormat.clock(3600) == "1:00")
        #expect(TimeFormat.clock(3600 + 5 * 60 + 59) == "1:05")
    }

    @Test func clockRoundsDownAndNeverGoesNegative() {
        #expect(TimeFormat.clock(59.9) == "0:59")
        #expect(TimeFormat.clock(-5) == "0:00")
    }

    @Test func shortForm() {
        #expect(TimeFormat.short(2 * 3600 + 40 * 60) == "2h 40m")
        #expect(TimeFormat.short(40 * 60) == "40m")
        #expect(TimeFormat.short(3600) == "1h")
        #expect(TimeFormat.short(0) == "0m")
    }

    @Test func spokenForm() {
        #expect(TimeFormat.spoken(47 * 60 + 12) == "47 minutes")
        #expect(TimeFormat.spoken(3600 + 5 * 60) == "1 hour, 5 minutes")
        #expect(TimeFormat.spoken(30) == "30 seconds")
    }
}

struct TimerLengthFormatTests {
    @Test func lengthReadsMinutesAndHours() {
        #expect(TimeFormat.length(45 * 60) == "45 min")
        #expect(TimeFormat.length(5 * 60) == "5 min")
        #expect(TimeFormat.length(3600) == "1 h")
        #expect(TimeFormat.length(90 * 60) == "1 h 30 min")
        #expect(TimeFormat.length(12 * 3600) == "12 h")
    }

    @Test func lengthRoundsToTheMinute() {
        #expect(TimeFormat.length(45 * 60 + 29) == "45 min")
        #expect(TimeFormat.length(44 * 60 + 31) == "45 min")
        #expect(TimeFormat.length(-10) == "0 min")
    }

    @Test func lengthSpokenForm() {
        #expect(TimeFormat.spokenLength(45 * 60) == "45 minutes")
        #expect(TimeFormat.spokenLength(3600) == "1 hour")
        #expect(TimeFormat.spokenLength(90 * 60) == "1 hour, 30 minutes")
        #expect(TimeFormat.spokenLength(44 * 60 + 31) == "45 minutes")
    }

    @Test func clockTimeIsTheShortTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        let zone = TimeZone(identifier: "America/New_York")!
        calendar.timeZone = zone
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 15, minute: 45))!
        let text = TimeFormat.clockTime(date, locale: Locale(identifier: "en_US"), timeZone: zone)
        // iOS puts a narrow no-break space before AM/PM.
        #expect(text.replacingOccurrences(of: "\u{202F}", with: " ") == "3:45 PM")
        let gb = TimeFormat.clockTime(date, locale: Locale(identifier: "en_GB"), timeZone: zone)
        #expect(gb == "15:45")
    }

    @Test func presetsSitInsideTheTimerRange() {
        let expected: [TimeInterval] = [15 * 60, 30 * 60, 45 * 60, 3600, 2 * 3600]
        #expect(TimerSheet.presets == expected)
        for preset in TimerSheet.presets {
            #expect((TimerLock.minimum...TimerLock.maximum).contains(preset))
        }
    }

    @Test func wheelValuesSnapIntoRange() {
        #expect(TimerSheet.snapped(61) == TimerLock.minimum)
        #expect(TimerSheet.snapped(13 * 3600) == TimerLock.maximum)
        #expect(TimerSheet.snapped(45 * 60 + 20) == 45 * 60)
        #expect(TimerSheet.snapped(45 * 60 + 40) == 46 * 60)
    }
}
