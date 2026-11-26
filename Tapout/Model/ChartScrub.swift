import Foundation

/// The rules for picking a day on a chart or heatmap with a finger or VoiceOver.
enum ChartScrub {
    /// The column under `x` in a strip of `count` equal columns, clamped to the strip.
    static func index(at x: Double, width: Double, count: Int) -> Int? {
        guard width > 0, count > 0 else { return nil }
        return min(count - 1, max(0, Int((x * Double(count) / width).rounded(.down))))
    }

    /// A drag scrubs only when it starts out more sideways than up or down, so the page can still scroll.
    static func isSideways(dx: Double, dy: Double) -> Bool {
        abs(dx) > abs(dy)
    }

    /// A tap selects the day; tapping the selected day clears it.
    static func tapped(_ day: Date, selected: Date?) -> Date? {
        day == selected ? nil : day
    }

    /// One day earlier or later than the selection, or than the last day when nothing here is selected.
    /// `days` are the pickable days, oldest first.
    static func stepped(from selected: Date?, by step: Int, through days: [Date]) -> Date? {
        guard !days.isEmpty else { return nil }
        let current = selected.flatMap { days.firstIndex(of: $0) } ?? days.count - 1
        return days[min(days.count - 1, max(0, current + step))]
    }
}
