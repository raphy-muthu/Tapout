import SwiftUI

/// The Insights tab's week view, per design/screens/Insights.dc.html, with the honest-insights rules:
/// gated tiles show progress until there is enough data, and nothing counts misses.
struct InsightsView: View {
    let model: AppModel

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The Lab's Living glass switch, handed down by the root: scrubbable columns, the heatmap and the streak.
    @Environment(\.glassControls) private var glass
    @State private var recap: Image?
    /// The day picked on the week chart; nil shows the week.
    @State private var chartDay: Date?
    /// The day picked on the heatmap; nil reads today.
    @State private var heatDay: Date?

    /// Everything the shared image shows; when it changes the old image is dropped before the new render.
    private struct RecapKey: Equatable {
        var weekStart: Date
        var totalText: String
        var scheme: ColorScheme
        var interests: [Interest]
        var days: [Double]
        /// Which day is today, so the image redraws at midnight even when no time changed.
        var today: Int?
        var glass: Bool
    }

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
        let weekStart = Insights.week(of: now, calendar: calendar).start
        let days = Insights.days(weekOf: now, history: history, now: now, calendar: calendar)
        let recapKey = RecapKey(weekStart: weekStart, totalText: TimeFormat.short(total), scheme: colorScheme,
                                interests: Array(model.interests), days: days.map(\.lockedTime),
                                today: days.firstIndex(where: \.isToday), glass: glass)
        // A day picked last week isn't in `days` any more, so the screen falls back to the week.
        let picked = glass ? days.first { $0.start == chartDay } : nil
        let heroTime = picked?.lockedTime ?? total
        let heroCaption = picked == nil ? "phone-free this week" : "phone-free"
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(title: title(for: picked), total: total, weekStart: weekStart, days: days, comparison: comparison)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    // A total that moves once a minute at most, not a ticking clock, so plain Text: at this
                    // size FixedDigitText's slots split "13h" into "1 3h" and pull it off the left edge.
                    Text(TimeFormat.short(heroTime))
                        .font(.numberHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.ink)
                        .contentTransition(.numericText())
                        .animation(glass && !reduceMotion ? Motion.scrub : nil, value: picked?.start)
                    Text(heroCaption).font(.tBody).foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, Space.xl)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(TimeFormat.spoken(heroTime)) \(heroCaption)")
                if glass {
                    ScrubColumns(days: days, selected: $chartDay)
                        .padding(.top, Space.lg)
                    HeatmapCard(weeks: Insights.heatmap(history: history, now: now, calendar: calendar),
                                selected: $heatDay, calendar: calendar)
                        .padding(.top, Space.lg)
                }
                if let comparison {
                    // Always the week's, whatever day is picked.
                    ComparisonCard(comparison: comparison, total: total).padding(.top, glass ? Space.lg : 20)
                }
                if !glass {
                    WeekBars(days: days).padding(.top, Space.xl)
                }
                tiles(now: now, calendar: calendar).padding(.top, Space.lg)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
        .modifier(StatusBarFade(isOn: glass))
        .onChange(of: chartDay) { HapticEngine.shared.play(.scrub) }
        .onChange(of: heatDay) { HapticEngine.shared.play(.scrub) }
        // Re-render the 1x thumbnail only when something the image shows changes: at most once a minute.
        // The full-size image is rendered when the share sheet asks for it.
        .task(id: recapKey) {
            recap = nil
            let view = RecapView(weekStart: weekStart, total: total, days: days, comparison: comparison, glass: glass)
            if let image = RecapImage.render(view, colorScheme: colorScheme, scale: 1) { recap = Image(uiImage: image) }
        }
    }

    private func title(for picked: Insights.Day?) -> String {
        guard let picked else { return "This week" }
        return picked.isToday ? "Today" : picked.start.formatted(.dateTime.weekday(.wide))
    }

    private func header(title: String, total: TimeInterval, weekStart: Date, days: [Insights.Day],
                        comparison: Comparison?) -> some View {
        HStack {
            Text(title).font(.tHeadline).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            if total > 0 {
                let text = "\(TimeFormat.short(total)) phone-free this week, with Tapout."
                if let recap {
                    ShareLink(item: RecapShare(weekStart: weekStart, total: total, days: days,
                                               comparison: comparison, colorScheme: colorScheme, glass: glass),
                              message: Text(text),
                              preview: SharePreview("Your week", image: recap)) {
                        shareIcon
                    }
                    .accessibilityLabel("Share")
                } else {
                    ShareLink(item: text) { shareIcon }
                        .accessibilityLabel("Share")
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var shareIcon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.inkSecondary)
            .frame(width: 44, height: 44)
            .controlSurface(.surface1, in: Circle())
    }

    private func tiles(now: Date, calendar: Calendar) -> some View {
        let history = model.history
        let longest = Insights.longest(weekOf: now, history: history, calendar: calendar)
        // One tile per row at accessibility sizes, so captions like "longest" don't break mid-word.
        let row = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Space.sm)) : AnyLayout(HStackLayout(spacing: Space.sm))
        let locks = InsightTile(value: "\(Insights.lockCount(weekOf: now, history: history, calendar: calendar))",
                                caption: "locks")
        let longestTile = Group {
            if let longest {
                InsightTile(value: TimeFormat.short(longest), caption: "longest", spokenValue: TimeFormat.spoken(longest))
            } else {
                InsightTile(value: "0 of 1", caption: "lock to longest", pending: true)
            }
        }
        let bestTime = gatedTile(Insights.bestTime(history: history, now: now, calendar: calendar),
                                 caption: "best time", waiting: "locks to best time") { $0.title }
        let goals = gatedTile(Insights.goals(history: history, now: now),
                              caption: "goals done", waiting: "answers to goals") { "\($0.done) of \($0.answered)" }
        return VStack(spacing: Space.sm) {
            if glass {
                row {
                    streakTile(Insights.streak(history: history, now: now, calendar: calendar))
                    locks
                }
                .fixedSize(horizontal: false, vertical: true)
                row {
                    longestTile
                    bestTime
                }
                .fixedSize(horizontal: false, vertical: true)
                goals.fixedSize(horizontal: false, vertical: true)
            } else {
                row {
                    locks
                    longestTile
                }
                .fixedSize(horizontal: false, vertical: true)
                row {
                    bestTime
                    goals
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func streakTile(_ days: Int) -> some View {
        if days > 0 {
            InsightTile(value: days == 1 ? "1 day" : "\(days) days", caption: "streak")
        } else {
            InsightTile(value: "0 of 1", caption: "lock to a streak", pending: true)
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
