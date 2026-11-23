import Foundation

enum TimeFormat {
    /// Hero timer text: `m:ss` under an hour, `h:mm` from one hour. At most 5 characters.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total >= 3600 {
            return "\(total / 3600):" + String(format: "%02d", total % 3600 / 60)
        }
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// Compact duration for stats: "2h 40m", "40m", "1h".
    static func short(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds)) / 60
        let hours = minutes / 60
        switch (hours, minutes % 60) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }

    /// A timer's length, rounded to the minute: "45 min", "1 h", "1 h 30 min", "12 h".
    /// Same words as the "Time's up" notice in `ScheduleNotice`.
    static func length(_ seconds: TimeInterval) -> String {
        let minutes = roundedMinutes(seconds)
        switch (minutes / 60, minutes % 60) {
        case (0, let m): return "\(m) min"
        case (let h, 0): return "\(h) h"
        case (let h, let m): return "\(h) h \(m) min"
        }
    }

    /// VoiceOver form of `length`: "45 minutes", "1 hour, 30 minutes".
    static func spokenLength(_ seconds: TimeInterval) -> String {
        spoken(TimeInterval(roundedMinutes(seconds) * 60))
    }

    /// A time of day in the locale's short style: "3:45 PM", "15:45".
    static func clockTime(_ date: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }

    private static func roundedMinutes(_ seconds: TimeInterval) -> Int {
        max(0, Int((seconds / 60).rounded()))
    }

    /// VoiceOver form: "47 minutes", "1 hour, 5 minutes", "30 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds < 60 ? [.second] : [.hour, .minute]
        return formatter.string(from: max(0, seconds.rounded(.down))) ?? ""
    }
}
