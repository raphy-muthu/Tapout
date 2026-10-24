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
