import SwiftUI

/// The last five weeks, one cell a day: the more phone-free time, the stronger the ember.
/// Tap a day, or drag along a week; the line underneath reads it out.
struct HeatmapCard: View {
    let weeks: [[Insights.HeatDay]]
    @Binding var selected: Date?
    let calendar: Calendar

    /// Rows are 44pt, and seven columns in this card are at least 44pt wide on a 375pt screen.
    private static let row: CGFloat = 44

    /// The picked day while it can still be picked, otherwise today.
    private var shown: Insights.HeatDay? {
        let days = weeks.joined()
        return days.first { $0.start == selected && $0.isOpen } ?? days.first(where: \.isToday)
    }

    var body: some View {
        let peak = Insights.heatPeak(weeks)
        let shown = self.shown
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Last 5 weeks")
                .font(.tFootnote.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, Space.sm)
                .accessibilityAddTraits(.isHeader)
            weekdays
            grid(peak: peak, shown: shown?.start)
            if let shown {
                Text("\(date(shown.start, weekday: .abbreviated, month: .abbreviated)) · \(time(shown))")
                    .font(.tFootnote.weight(.medium))
                    .monospaced()
                    .foregroundStyle(Color.emberInk)
                    .padding(.horizontal, Space.sm)
                    .padding(.top, Space.xxs)
                    // The cells already say this to VoiceOver.
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Space.xs)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSurface(.surface1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var weekdays: some View {
        HStack(spacing: 0) {
            ForEach(weeks.first ?? []) { day in
                Text(calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day.start) - 1])
                    .font(.tCaption)
                    .monospaced()
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityHidden(true)
    }

    private func grid(peak: TimeInterval, shown: Date?) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ForEach(weeks.indices, id: \.self) { index in
                    HStack(spacing: 0) {
                        ForEach(weeks[index]) { day in
                            cell(day, peak: peak, isShown: day.start == shown)
                        }
                    }
                }
            }
            .scrubbable(
                onTap: { pick(row: $0.y, column: $0.x, in: proxy.size) },
                onScrub: { start, point in pick(row: start.y, column: point.x, in: proxy.size) }
            )
        }
        .frame(height: Self.row * CGFloat(weeks.count))
    }

    private func cell(_ day: Insights.HeatDay, peak: TimeInterval, isShown: Bool) -> some View {
        let strength = day.isOpen ? Insights.heatStrength(day.lockedTime, peak: peak) : 0
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(Color.ink.opacity(day.isOpen ? 0.09 : 0.035))
            .overlay(shape.fill(Color.ember.opacity(strength)))
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.28 * strength), .white.opacity(0)],
                                               startPoint: .top, endPoint: .center)))
            .overlay(shape.strokeBorder(Color.ink, lineWidth: isShown ? 2 : 0))
            .shadow(color: .ember.opacity(strength > 0.6 ? 0.45 * strength : 0), radius: 6)
            .padding(3)
            .frame(maxWidth: .infinity)
            .frame(height: Self.row)
            // Only days with time on them are read, so empty days aren't read out like misses.
            .accessibilityElement()
            .accessibilityLabel("\(date(day.start, weekday: .wide, month: .wide)), \(TimeFormat.spoken(day.lockedTime))")
            .accessibilityAddTraits(isShown ? .isSelected : [])
            .accessibilityHidden(!day.isOpen || day.lockedTime < 60)
    }

    private func pick(row y: CGFloat, column x: CGFloat, in size: CGSize) {
        guard let row = ChartScrub.index(at: y, width: size.height, count: weeks.count),
              let column = ChartScrub.index(at: x, width: size.width, count: weeks[row].count),
              weeks[row][column].isOpen else { return }
        selected = weeks[row][column].start
    }

    private func date(_ date: Date, weekday: Date.FormatStyle.Symbol.Weekday, month: Date.FormatStyle.Symbol.Month) -> String {
        var style = Date.FormatStyle().weekday(weekday).month(month).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    private func time(_ day: Insights.HeatDay) -> String {
        day.lockedTime < 60 ? "no locks" : TimeFormat.short(day.lockedTime)
    }
}
