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
    /// Emergency passes inside this lock. Apps were open then, so that time isn't locked time.
    /// A running pass ends at its relock time; relocking early or unlocking shortens it.
    var passes: [DateInterval] = []

    /// Locked time without pass time, only inside `interval` when given.
    /// A running lock counts up to `now`, and nothing counts past `now`.
    func lockedTime(in interval: DateInterval? = nil, now: Date) -> TimeInterval {
        let end = min(self.end ?? now, now)
        guard end > start else { return 0 }
        var span = DateInterval(start: start, end: end)
        if let interval {
            guard let clipped = span.intersection(with: interval) else { return 0 }
            span = clipped
        }
        let open = passes.reduce(0) { total, pass in
            total + (pass.intersection(with: span)?.duration ?? 0)
        }
        return max(0, span.duration - open)
    }

    /// Ends the running pass at `date`, if it would otherwise run past it.
    mutating func endPass(at date: Date) {
        guard let last = passes.last, date < last.end else { return }
        passes[passes.count - 1] = DateInterval(start: last.start, end: max(last.start, date))
    }
}

extension LockRecord {
    private enum CodingKeys: String, CodingKey {
        case start, end, placeUID, modeID, intention, intentionDone, passes
    }

    /// Records saved before Phase 4 have no `passes`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        placeUID = try container.decodeIfPresent(TagUID.self, forKey: .placeUID)
        modeID = try container.decode(UUID.self, forKey: .modeID)
        intention = try container.decodeIfPresent(String.self, forKey: .intention)
        intentionDone = try container.decodeIfPresent(Bool.self, forKey: .intentionDone)
        passes = try container.decodeIfPresent([DateInterval].self, forKey: .passes) ?? []
    }
}
