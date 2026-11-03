import Foundation

/// Totals over the lock history.
enum LockStats {
    static func lockCount(at place: TagUID, in history: [LockRecord]) -> Int {
        history.filter { $0.placeUID == place }.count
    }

    /// Time locked in `modeID` during the week that contains `now`. A lock still running counts up to `now`.
    static func lockedTime(modeID: UUID, weekOf now: Date, in history: [LockRecord], calendar: Calendar = .current) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return history.filter { $0.modeID == modeID }.reduce(0) { total, record in
            let start = max(record.start, week.start)
            let end = min(record.end ?? now, week.end)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
