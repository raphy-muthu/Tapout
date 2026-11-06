import SwiftUI

/// The active mode's hero card, per the list view in design/screens/Modes.dc.html.
struct ActiveModeCard: View {
    let mode: Mode
    let unlockNames: [String]
    let lockedThisWeek: TimeInterval

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xxs) {
                        if isLocked { Image(systemName: "lock").font(.system(size: 12, weight: .bold)) }
                        Text(isLocked ? "Active now" : "Selected")
                    }
                    .font(.tCaption)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(isLocked ? Color.emberInk : Color.slateInk)
                    Text(mode.name).font(.tTitle1).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.8)
                    Text(ModeText.subtitle(mode)).font(.tSubhead).foregroundStyle(Color.inkSecondary).lineLimit(1).minimumScaleFactor(0.85)
                }
                Spacer(minLength: Space.sm)
                OrbView(tone: isLocked ? .ember : .slate, ring: isLocked ? 1 : 0, size: 104)
            }
            HStack(spacing: Space.xs) {
                StatTile(value: mode.schedule.map(ScheduleFormat.short) ?? "Manual", caption: "Schedule", isNumber: mode.schedule != nil)
                StatTile(value: ModeText.unlockSummary(unlockNames), caption: "Unlocks at", isNumber: false)
                StatTile(value: TimeFormat.short(lockedThisWeek), caption: "This week", isNumber: true)
            }
            .fixedSize(horizontal: false, vertical: true) // tiles share a height: Fraunces numbers are taller than SF Pro words
        }
        .card(radius: Radius.sheet)
    }
}

/// A small value-over-caption tile inside a card.
struct StatTile: View {
    let value: String
    let caption: String
    /// Numbers use Fraunces; words use SF Pro.
    let isNumber: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(isNumber ? .numberTile : .tHeadline)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0) // captions bottom-align across tiles whose values differ in height
            Text(caption).font(.caption).foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Space.sm)
        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A grid tile for every mode that isn't active.
struct ModeTile: View {
    let mode: Mode

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            OrbView(tone: .slate, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.name).font(.tHeadline).foregroundStyle(Color.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text(ModeText.apps(mode)).font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
@MainActor private func previewMode() -> Mode {
    DemoData.previewModel().activeMode
}

#Preview("Cards · dark") {
    let mode = previewMode()
    return VStack(spacing: Space.md) {
        ActiveModeCard(mode: mode, unlockNames: ["Kitchen"], lockedThisWeek: 5 * 3600 + 20 * 60)
        ActiveModeCard(mode: mode, unlockNames: ["Kitchen"], lockedThisWeek: 5 * 3600 + 20 * 60)
            .environment(\.isLocked, true)
        ModeTile(mode: mode).frame(width: 170)
    }
    .padding(Space.lg)
    .background(Color.bg)
    .preferredColorScheme(.dark)
}

#Preview("Cards · light") {
    let mode = previewMode()
    return VStack(spacing: Space.md) {
        ActiveModeCard(mode: mode, unlockNames: ["Kitchen"], lockedThisWeek: 5 * 3600 + 20 * 60)
        ActiveModeCard(mode: mode, unlockNames: ["Kitchen"], lockedThisWeek: 5 * 3600 + 20 * 60)
            .environment(\.isLocked, true)
        ModeTile(mode: mode).frame(width: 170)
    }
    .padding(Space.lg)
    .background(Color.bg)
    .preferredColorScheme(.light)
}
#endif
