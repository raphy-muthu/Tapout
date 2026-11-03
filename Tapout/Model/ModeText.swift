import Foundation

enum Copy {
    /// "1 lock", "3 locks".
    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}

/// Wording on mode cards and tiles.
enum ModeText {
    static func apps(_ mode: Mode) -> String {
        Copy.count(mode.blockedCount, "app", "apps")
    }

    /// "6 apps · weekdays", "2 apps · manual".
    static func subtitle(_ mode: Mode) -> String {
        "\(apps(mode)) · \(mode.schedule.map { ScheduleFormat.days($0.days) } ?? "manual")"
    }

    /// Unlock place names in pairing order, shortened for a tile.
    static func unlockSummary(_ names: [String]) -> String {
        switch names.count {
        case 0: "Any place"
        case 1: names[0]
        default: "\(names[0]) +\(names.count - 1)"
        }
    }
}
