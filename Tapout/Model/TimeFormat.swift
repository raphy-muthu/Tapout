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

    /// VoiceOver form: "47 minutes", "1 hour, 5 minutes", "30 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds < 60 ? [.second] : [.hour, .minute]
        return formatter.string(from: max(0, seconds.rounded(.down))) ?? ""
    }
}
