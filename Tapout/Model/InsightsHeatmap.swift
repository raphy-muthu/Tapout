import Foundation

/// The five-week heatmap on the living-glass Insights screen.
extension Insights {
    static let heatWeeks = 5

    struct HeatDay: Equatable, Identifiable, Sendable {
        let start: Date
        let lockedTime: TimeInterval
        let isToday: Bool
        /// Past days from the first lock on, and today. Closed days are faint and can't be picked, so
        /// the days before someone started don't read as misses.
        let isOpen: Bool

        var id: Date { start }
    }

    /// Five weeks of days in the calendar's order, oldest week first, `now`'s week last.
    static func heatmap(history: [LockRecord], now: Date, calendar: Calendar) -> [[HeatDay]] {
        let today = calendar.startOfDay(for: now)
        let firstDay = history.map(\.start).min().map { calendar.startOfDay(for: $0) }
        return (0..<heatWeeks).compactMap { index in
            guard let date = calendar.date(byAdding: .weekOfYear, value: index - (heatWeeks - 1), to: now) else {
                return nil
            }
            return days(weekOf: date, history: history, now: now, calendar: calendar).map { day in
                let started = firstDay.map { day.start >= $0 } ?? false
                return HeatDay(start: day.start, lockedTime: day.lockedTime, isToday: day.isToday,
                               isOpen: day.start <= today && (day.isToday || started))
            }
        }
    }

    /// The time a full-strength cell stands for: the busiest day shown, and at least an hour,
    /// so one short lock isn't drawn at full strength.
    static func heatPeak(_ weeks: [[HeatDay]]) -> TimeInterval {
        max(weeks.joined().map(\.lockedTime).max() ?? 0, 3600)
    }

    /// 0 for a day without a minute of locked time, otherwise from a clearly visible floor up to 1.
    static func heatStrength(_ time: TimeInterval, peak: TimeInterval) -> Double {
        guard time >= 60, peak > 0 else { return 0 }
        return 0.24 + 0.76 * min(1, time / peak)
    }
}
