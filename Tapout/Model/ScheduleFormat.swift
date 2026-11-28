import Foundation

/// Wording for mode schedules.
enum ScheduleFormat {
    /// Tile form: "9–5", "9:30–5". Twelve-hour without am/pm; the tile has no room for more.
    static func short(_ schedule: ModeSchedule) -> String {
        "\(compact(schedule.start))–\(compact(schedule.end))"
    }

    /// Editor form in the owner's locale: "09:00 – 17:00", "9:00 AM – 5:00 PM".
    static func range(_ schedule: ModeSchedule, locale: Locale = .current) -> String {
        "\(time(schedule.start, locale: locale)) – \(time(schedule.end, locale: locale))"
    }

    /// "weekdays", "weekends", "every day", "manual", or short day names Monday first. Runs of three or
    /// more days collapse: "Mon–Wed, Fri". A run never wraps from Sunday to Monday.
    static func days(_ days: Set<Int>, calendar: Calendar = .current) -> String {
        switch days {
        case []: return "manual"
        case ModeSchedule.everyDay: return "every day"
        case ModeSchedule.weekdays: return "weekdays"
        case ModeSchedule.weekend: return "weekends"
        default:
            let name = { (day: Int) in calendar.shortWeekdaySymbols[day - 1] }
            var runs: [[Int]] = []
            var previous: Int?
            for (position, day) in ModeSchedule.displayOrder.enumerated() where days.contains(day) {
                if let last = previous, last == position - 1 {
                    runs[runs.count - 1].append(day)
                } else {
                    runs.append([day])
                }
                previous = position
            }
            return runs
                .map { $0.count >= 3 ? "\(name($0[0]))–\(name($0[$0.count - 1]))" : $0.map(name).joined(separator: ", ") }
                .joined(separator: ", ")
        }
    }

    private static func compact(_ minutes: Int) -> String {
        let hour = minutes / 60 % 12 == 0 ? 12 : minutes / 60 % 12
        let minute = minutes % 60
        return minute == 0 ? "\(hour)" : "\(hour):" + String(format: "%02d", minute)
    }

    private static func time(_ minutes: Int, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60)))
    }
}

/// Converts between a schedule's minutes after midnight and the `Date` a `DatePicker` edits.
enum ClockMinutes {
    /// The pickers edit times on this fixed day, which has no daylight-saving change in any time zone, so a
    /// time in a skipped hour (2:30 on a spring-forward day) is never moved when the editor opens on that day.
    static func referenceDay(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: 2001, month: 1, day: 15, hour: 12)) ?? .now
    }

    static func date(_ minutes: Int, on day: Date? = nil, calendar: Calendar = .current) -> Date {
        let day = day ?? referenceDay(calendar: calendar)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
