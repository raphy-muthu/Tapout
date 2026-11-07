import Foundation

/// A derived value that needs enough data first. Below the minimum, screens show progress instead
/// ("3 of 8"), so a tile never shows a number built from a handful of locks.
enum Gated<Value: Equatable>: Equatable {
    case value(Value)
    case progress(have: Int, need: Int)
}

/// When a lock started, in four broad blocks.
enum TimeBlock: String, CaseIterable, Equatable {
    case mornings, afternoons, evenings, nights

    var title: String { rawValue.capitalized }

    /// Mornings 5–12, afternoons 12–17, evenings 17–22, nights 22–5.
    static func of(hour: Int) -> TimeBlock {
        switch hour {
        case 5..<12: .mornings
        case 12..<17: .afternoons
        case 17..<22: .evenings
        default: .nights
        }
    }
}

/// The numbers behind Insights, Home and milestones. Follows the honest-insights rules in
/// docs/superpowers/specs/2026-10-27-phase3b-design.md: minimum samples, streaks alive until midnight,
/// and nothing that counts misses.
enum Insights {
    static let bestTimeNeed = 8
    static let bestTimeBlockNeed = 3
    static let goalsNeed = 3
    /// Best time and goals look back four weeks.
    static let lookback: TimeInterval = 28 * 86_400

    struct Day: Equatable {
        let start: Date
        /// "M", "T", …
        let letter: String
        let lockedTime: TimeInterval
        let isToday: Bool
    }

    struct Goals: Equatable {
        let done: Int
        let answered: Int
    }

    /// Locked time inside `interval`. A running lock counts up to `now`.
    static func lockedTime(in interval: DateInterval, history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { total, record in
            let end = min(record.end ?? now, now)
            guard end > record.start,
                  let overlap = DateInterval(start: record.start, end: end).intersection(with: interval) else { return total }
            return total + overlap.duration
        }
    }

    /// All locked time so far.
    static func totalLocked(history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { $0 + max(0, min($1.end ?? now, now).timeIntervalSince($1.start)) }
    }

    static func week(of date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    /// One entry per day of `date`'s week, in the calendar's order.
    static func days(weekOf date: Date, history: [LockRecord], now: Date, calendar: Calendar) -> [Day] {
        let week = week(of: date, calendar: calendar)
        return (0..<7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let day = calendar.dateInterval(of: .day, for: start) else { return nil }
            let weekday = calendar.component(.weekday, from: start)
            return Day(
                start: start,
                letter: calendar.veryShortWeekdaySymbols[weekday - 1],
                lockedTime: lockedTime(in: day, history: history, now: now),
                isToday: calendar.isDate(start, inSameDayAs: now)
            )
        }
    }

    static func lockCount(weekOf date: Date, history: [LockRecord], calendar: Calendar) -> Int {
        finished(in: week(of: date, calendar: calendar), history: history).count
    }

    /// The longest finished lock this week; nil before the first one.
    static func longest(weekOf date: Date, history: [LockRecord], calendar: Calendar) -> TimeInterval? {
        finished(in: week(of: date, calendar: calendar), history: history)
            .compactMap { record in record.end.map { $0.timeIntervalSince(record.start) } }
            .max()
    }

    /// When the owner locks most, over the last four weeks. Needs 8 locks, and the winning block
    /// needs 3 of them. Ties go to the block with more locked time.
    static func bestTime(history: [LockRecord], now: Date, calendar: Calendar) -> Gated<TimeBlock> {
        let recent = finished(in: DateInterval(start: now - lookback, end: now), history: history)
        guard recent.count >= bestTimeNeed else { return .progress(have: recent.count, need: bestTimeNeed) }
        let blocks = Dictionary(grouping: recent) { TimeBlock.of(hour: calendar.component(.hour, from: $0.start)) }
        let ranked = blocks.map { block, locks in
            (block: block, count: locks.count, time: totalLocked(history: locks, now: now))
        }
        .sorted { ($0.count, $0.time) > ($1.count, $1.time) }
        guard let top = ranked.first, top.count >= bestTimeBlockNeed else {
            return .progress(have: ranked.first?.count ?? 0, need: bestTimeBlockNeed)
        }
        return .value(top.block)
    }

    /// How many answered intentions were done, over the last four weeks. Needs 3 answers.
    static func goals(history: [LockRecord], now: Date) -> Gated<Goals> {
        let answered = history.filter { $0.start >= now - lookback && $0.intentionDone != nil }
        guard answered.count >= goalsNeed else { return .progress(have: answered.count, need: goalsNeed) }
        return .value(Goals(done: answered.filter { $0.intentionDone == true }.count, answered: answered.count))
    }

    /// Days in a row with a finished lock. Until today has one, the streak runs to yesterday,
    /// so it never reads zero first thing in the morning.
    static func streak(history: [LockRecord], now: Date, calendar: Calendar) -> Int {
        let days = Set(history.filter { $0.end != nil }.map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Finished locks that started inside `interval`.
    private static func finished(in interval: DateInterval, history: [LockRecord]) -> [LockRecord] {
        history.filter { $0.end != nil && interval.contains($0.start) }
    }
}
