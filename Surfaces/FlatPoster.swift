import Foundation

/// The words and the color of a flat-color surface (the Living glass switch's widgets and Live Activity).
/// Pure, so it can be tested; the faces add the number.
struct FlatPoster: Equatable {
    /// Ember while locked; slate while apps are open.
    var tone: OrbTone
    var heading: String
    var footer: String?

    /// The Home Screen widgets.
    static func home(_ snapshot: LockSnapshot, date: Date) -> FlatPoster {
        switch snapshot.state(at: date) {
        case .locked:
            FlatPoster(tone: .ember, heading: snapshot.timerEndsAt == nil ? "Locked" : "Time left", footer: snapshot.modeName)
        case .open:
            FlatPoster(tone: .slate, heading: "Relocks in", footer: "Open")
        case .unlocked:
            FlatPoster(tone: .slate, heading: "Today", footer: "phone-free")
        }
    }

    /// The Live Activity, on the Lock Screen and in the expanded island.
    static func activity(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> FlatPoster {
        if state.timerIsOver(isStale: isStale) {
            FlatPoster(tone: .slate, heading: "Time's up", footer: state.modeName)
        } else if state.openUntil != nil && !isStale {
            FlatPoster(tone: .slate, heading: "Open · Relocks in", footer: state.modeName)
        } else {
            FlatPoster(tone: .ember, heading: "\(state.modeName) · \(state.timerEndsAt == nil ? "Locked" : "Time left")",
                       footer: state.placeName)
        }
    }

    /// A still total as lines, hours over minutes: "1h", "45m".
    static func stacked(_ seconds: TimeInterval) -> [String] {
        TimeFormat.short(seconds).split(separator: " ").map(String.init)
    }
}
