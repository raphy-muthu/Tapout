import Foundation

/// One lock, for counts and totals in Places, Modes and Insights. `end` is nil while it runs.
struct LockRecord: Codable, Equatable, Sendable {
    let start: Date
    var end: Date?
    let placeUID: TagUID?
    let modeID: UUID
    /// What the lock was for ("History essay, first paragraph"). Optional; Phase 3B sets it.
    var intention: String? = nil
    /// The answer to "Did you do it?" on unlock. nil = no intention, not asked, or skipped.
    var intentionDone: Bool? = nil
}
