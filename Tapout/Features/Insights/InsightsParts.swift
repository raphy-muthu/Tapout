import SwiftUI

/// "As long as an entire NFL game", with the interest's symbol on an ember-glow disc.
struct ComparisonCard: View {
    let comparison: Comparison
    let total: TimeInterval

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: comparison.symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.emberInk)
                .frame(width: 56, height: 56)
                .background(Color.emberGlow, in: Circle())
                .accessibilityHidden(true)
            Text(comparison.asLongAs(total))
                .font(.tTitle)
                .foregroundStyle(Color.ink)
        }
        .card(padding: 20)
    }
}

/// Phone-free time per day this week. Today's bar is ember and labelled; the others stay quiet.
struct WeekBars: View {
    let days: [Insights.Day]

    var body: some View {
        let peak = max(days.map(\.lockedTime).max() ?? 0, 1)
        VStack(spacing: Space.sm) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.start) { day in
                    VStack(spacing: 6) {
                        Text(TimeFormat.short(day.lockedTime))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(Color.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(day.isToday ? 1 : 0)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(day.isToday ? Color.ember : Color.surface2)
                            .frame(height: 20 + 120 * day.lockedTime / peak)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 168)
            HStack(spacing: 10) {
                ForEach(days, id: \.start) { day in
                    Text(day.letter)
                        .font(.tCaption)
                        .foregroundStyle(day.isToday ? Color.ink : Color.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phone-free time per day this week")
        .accessibilityValue(spokenDays)
    }

    /// Only days with time on them, so future and empty days aren't read out like misses.
    private var spokenDays: String {
        let locked = days.filter { $0.lockedTime >= 60 }
        guard !locked.isEmpty else { return "No locks yet" }
        return locked.map { "\($0.start.formatted(.dateTime.weekday(.wide))), \(TimeFormat.spoken($0.lockedTime))" }
            .joined(separator: "; ")
    }
}

/// A value over a caption. `pending` values are progress toward an insight ("3 of 8"), shown quieter.
/// Word values like "Mornings" stay in `numberMedium` on purpose; don't "fix" them to SF Pro.
struct InsightTile: View {
    let value: String
    let caption: String
    var pending = false
    /// For VoiceOver, when `value` is abbreviated ("1h 50m").
    var spokenValue: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.numberMedium)
                .foregroundStyle(pending ? Color.inkTertiary : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.surface1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(spokenValue ?? value) \(caption)")
    }
}
