import SwiftUI

/// The Insights tab's week view, per design/screens/Insights.dc.html, with the honest-insights rules:
/// gated tiles show progress until there is enough data, and nothing counts misses.
struct InsightsView: View {
    let model: AppModel

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: context.date, calendar: .current)
        }
    }

    @ViewBuilder
    private func content(now: Date, calendar: Calendar) -> some View {
        let history = model.history
        let total = Insights.lockedTime(in: Insights.week(of: now, calendar: calendar), history: history, now: now)
        let comparison = Comparison.best(for: total, interests: model.interests)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(total: total)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    // A total that moves once a minute at most, not a ticking clock, so plain Text: at this
                    // size FixedDigitText's slots split "13h" into "1 3h" and pull it off the left edge.
                    Text(TimeFormat.short(total))
                        .font(.numberHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.ink)
                    Text("phone-free this week").font(.tBody).foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, Space.xl)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(TimeFormat.spoken(total)) phone-free this week")
                if let comparison {
                    ComparisonCard(comparison: comparison, total: total).padding(.top, 20)
                }
                WeekBars(days: Insights.days(weekOf: now, history: history, now: now, calendar: calendar))
                    .padding(.top, Space.xl)
                tiles(now: now, calendar: calendar).padding(.top, Space.lg)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func header(total: TimeInterval) -> some View {
        HStack {
            Text("This week").font(.tHeadline).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            if total > 0 {
                ShareLink(item: "\(TimeFormat.short(total)) phone-free this week, with Tapout.") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: 44, height: 44)
                        .background(Color.surface1, in: Circle())
                        .cardShadow()
                }
                .accessibilityLabel("Share")
            }
        }
        .frame(height: 44)
    }

    private func tiles(now: Date, calendar: Calendar) -> some View {
        let history = model.history
        let longest = Insights.longest(weekOf: now, history: history, calendar: calendar)
        // One tile per row at accessibility sizes, so captions like "longest" don't break mid-word.
        let row = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Space.sm)) : AnyLayout(HStackLayout(spacing: Space.sm))
        return VStack(spacing: Space.sm) {
            row {
                InsightTile(value: "\(Insights.lockCount(weekOf: now, history: history, calendar: calendar))", caption: "locks")
                if let longest {
                    InsightTile(value: TimeFormat.short(longest), caption: "longest", spokenValue: TimeFormat.spoken(longest))
                } else {
                    InsightTile(value: "0 of 1", caption: "lock to longest", pending: true)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            row {
                gatedTile(Insights.bestTime(history: history, now: now, calendar: calendar),
                          caption: "best time", waiting: "locks to best time") { $0.title }
                gatedTile(Insights.goals(history: history, now: now),
                          caption: "goals done", waiting: "answers to goals") { "\($0.done) of \($0.answered)" }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func gatedTile<Value: Equatable>(_ gated: Gated<Value>, caption: String, waiting: String,
                                  text: (Value) -> String) -> some View {
        switch gated {
        case .value(let value):
            InsightTile(value: text(value), caption: caption)
        case .progress(let have, let need):
            InsightTile(value: "\(have) of \(need)", caption: waiting, pending: true)
        }
    }
}

#Preview("Insights · dark") {
    InsightsView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Insights · light") {
    InsightsView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}
