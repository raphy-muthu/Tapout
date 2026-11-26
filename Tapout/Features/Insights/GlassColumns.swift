import SwiftUI

/// A column of lit glass, used by the week chart and the shared recap.
struct GlassColumn: View {
    let color: Color
    var radius: CGFloat = 15
    var glows = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(color)
            .overlay(shape.fill(LinearGradient(stops: [
                .init(color: .white.opacity(0.6), location: 0),
                .init(color: .white.opacity(0.06), location: 0.36),
                .init(color: .black.opacity(0.34), location: 1),
            ], startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.05)],
                                                       startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: glows ? color.opacity(0.75) : .clear, radius: 14)
    }
}

/// This week as seven glass columns that a thumb can scrub. Today is lit until a day is picked.
/// Days after today are stubs and can't be picked.
struct ScrubColumns: View {
    let days: [Insights.Day]
    @Binding var selected: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// False for the first frame, so the columns rise from their stubs.
    @State private var risen = false

    private static let height: CGFloat = 228
    private static let stub: CGFloat = 16
    private static let rise: CGFloat = 148

    /// The days up to today, which can be picked.
    private var open: [Date] {
        let count = days.firstIndex(where: \.isToday).map { $0 + 1 } ?? days.count
        return days.prefix(count).map(\.start)
    }

    var body: some View {
        let peak = max(days.map(\.lockedTime).max() ?? 0, 1)
        let open = self.open
        let picked = selected.flatMap { open.contains($0) ? $0 : nil }
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.element.start) { index, day in
                    let lit = picked.map { $0 == day.start } ?? day.isToday
                    let full = Self.stub + Self.rise * day.lockedTime / peak
                    VStack(spacing: 8) {
                        Text(TimeFormat.short(day.lockedTime))
                            .font(.tCaption) // 12pt at the default size
                            .monospaced()
                            .foregroundStyle(Color.ink)
                            // Only the lit one shows, so it may be wider than its column. As large as the chart has room for.
                            .fixedSize()
                            .frame(minWidth: 0, maxWidth: .infinity) // the label overflows; the column doesn't widen
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .opacity(lit ? 1 : 0)
                        GlassColumn(color: lit ? .ember : .slate, glows: lit)
                            .opacity(lit ? 1 : (open.contains(day.start) ? 0.55 : 0.22))
                            .frame(height: risen || reduceMotion ? full : Self.stub)
                            .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.74)
                                .delay(Double(index) * 0.05), value: risen)
                        Text(day.letter)
                            .font(.tCaption)
                            .monospaced()
                            .foregroundStyle(lit ? Color.emberInk : Color.inkSecondary)
                            // As large as the fixed-height chart has room for.
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }
                    .offset(y: picked == day.start && !reduceMotion ? -8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .animation(reduceMotion ? Motion.reveal : Motion.scrub, value: picked)
            .scrubbable(
                onTap: { point in
                    guard let index = ChartScrub.index(at: point.x, width: proxy.size.width, count: days.count),
                          index < open.count else { return }
                    selected = ChartScrub.tapped(open[index], selected: picked)
                },
                onScrub: { _, point in
                    guard let index = ChartScrub.index(at: point.x, width: proxy.size.width, count: days.count),
                          !open.isEmpty else { return }
                    selected = open[min(index, open.count - 1)]
                }
            )
        }
        .frame(height: Self.height)
        .onAppear { risen = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phone-free time per day this week")
        .accessibilityValue(spoken(picked))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: selected = ChartScrub.stepped(from: picked, by: 1, through: open)
            case .decrement: selected = ChartScrub.stepped(from: picked, by: -1, through: open)
            @unknown default: break
            }
        }
    }

    private func spoken(_ picked: Date?) -> String {
        guard let day = days.first(where: { $0.start == picked }) else { return WeekBars.spoken(days) }
        let name = day.start.formatted(.dateTime.weekday(.wide))
        return day.lockedTime < 60 ? "\(name), no locks" : "\(name), \(TimeFormat.spoken(day.lockedTime))"
    }
}
