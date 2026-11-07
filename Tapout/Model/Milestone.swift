import Foundation

/// Moments worth one full-screen celebration each. Shown once, right after the unlock that reached them.
enum Milestone: String, CaseIterable, Identifiable {
    case firstLock, tenHours, sevenDayStreak, fiftyHours, hundredHours

    var id: Self { self }

    var title: String {
        switch self {
        case .firstLock: "First lock"
        case .tenHours: "First 10 hours"
        case .sevenDayStreak: "7 days in a row"
        case .fiftyHours: "50 hours"
        case .hundredHours: "100 hours"
        }
    }

    /// Every milestone reached so far, in order. Only finished locks count.
    static func reached(in history: [LockRecord], now: Date, calendar: Calendar) -> [Milestone] {
        let finished = history.filter { $0.end != nil }
        let total = Insights.totalLocked(history: finished, now: now)
        let streak = Insights.streak(history: finished, now: now, calendar: calendar)
        return allCases.filter { milestone in
            switch milestone {
            case .firstLock: !finished.isEmpty
            case .tenHours: total >= 10 * 3600
            case .sevenDayStreak: streak >= 7
            case .fiftyHours: total >= 50 * 3600
            case .hundredHours: total >= 100 * 3600
            }
        }
    }

    /// The line under the title. Time milestones compare the total with something from the owner's interests.
    func subtitle(totalLocked: TimeInterval, interests: [Interest]) -> String {
        switch self {
        case .firstLock:
            "The first of many."
        case .sevenDayStreak:
            "A week of locks in a row."
        case .tenHours, .fiftyHours, .hundredHours:
            Comparison.best(for: totalLocked, interests: interests)?.worth(totalLocked)
                ?? "\(TimeFormat.short(totalLocked)) phone-free."
        }
    }
}
