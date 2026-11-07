import Foundation
@testable import Tapout

/// A fixed Gregorian calendar (UTC, Monday first, English symbols) and dates around the week of
/// Monday 26 October 2026, so Insights tests don't depend on the machine's settings.
enum TestDates {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }()

    static let modeID = UUID()

    /// `day` of October 2026 (26 = Monday) at `hour`:`minute` UTC.
    static func oct(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// A finished lock of `minutes`.
    static func lock(_ start: Date, minutes: Double, intention: String? = nil, done: Bool? = nil) -> LockRecord {
        LockRecord(start: start, end: start + minutes * 60, placeUID: nil, modeID: modeID,
                   intention: intention, intentionDone: done)
    }
}
