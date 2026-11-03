import FamilyControls
import Foundation

/// When a mode locks by itself. It locks at `start` and unlocks at `end` on each of `days`.
struct ModeSchedule: Codable, Equatable, Sendable {
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    var days: Set<Int>
    /// Minutes after midnight. An `end` before `start` runs past midnight.
    var start: Int
    var end: Int

    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    static let weekend: Set<Int> = [1, 7]
    static let everyDay: Set<Int> = Set(1...7)
    /// Monday first, for day chips and lists.
    static let displayOrder = [2, 3, 4, 5, 6, 7, 1]

    /// Minutes. DeviceActivity rejects schedule intervals shorter than this.
    static let minimumDuration = 15

    /// Minutes from `start` to `end`, counting past midnight. Equal times give 0.
    var duration: Int {
        (end - start + 1440) % 1440
    }

    /// Whether DeviceActivity can run it.
    var isRunnable: Bool {
        duration >= Self.minimumDuration
    }

    /// A schedule for the chosen days, or nil for a manual mode (no days).
    static func make(days: Set<Int>, start: Int, end: Int) -> ModeSchedule? {
        days.isEmpty ? nil : ModeSchedule(days: days, start: start, end: end)
    }
}

/// A named set of apps to block, an optional schedule, and the places that can end it.
struct Mode: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var schedule: ModeSchedule?
    /// Places that can unlock this mode. Empty means any paired place.
    var unlockPlaces: Set<TagUID>

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        schedule: ModeSchedule? = nil,
        unlockPlaces: Set<TagUID> = []
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.schedule = schedule
        self.unlockPlaces = unlockPlaces
    }

    /// Apps plus categories, for "6 apps" labels.
    var blockedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
}
