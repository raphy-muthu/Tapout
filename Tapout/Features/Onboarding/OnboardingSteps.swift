import FamilyControls
import SwiftUI

/// Step 1, from design/screens/Main.dc.html.
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: Space.xxl) {
            OrbView(tone: .slate, size: 300)
            VStack(spacing: Space.xs) {
                Text("Tap to lock.").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("Tap again to get your phone back.").font(.tBody).foregroundStyle(Color.inkSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Step 2.
struct ScreenTimeStep: View {
    var body: some View {
        VStack(spacing: Space.xxl) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "hourglass")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Color.ink)
                    .frame(width: 200, height: 200)
                    .background(Color.surface1, in: RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .cardShadow()
                Image(systemName: "lock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.onEmber)
                    .frame(width: 64, height: 64)
                    .background(Color.ember, in: Circle())
                    .background(Circle().fill(Color.bg).padding(-6))
                    .offset(x: 10, y: 10)
            }
            .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text("Allow Screen Time").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("Tapout uses it to block apps on this iPhone.")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: 300)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Step 3: what to block, and what always stays open.
struct AppsStep: View {
    let selection: FamilyActivitySelection
    let alwaysAllowed: FamilyActivitySelection
    let onPickApps: () -> Void
    let onPickAllowed: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("What should wait?").font(.tLargeTitle).foregroundStyle(Color.ink)
                blockCard
                allowedCard
            }
        }
        .scrollIndicators(.hidden)
    }

    private var blockedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    private var blockCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Block", color: .emberInk)
                Spacer()
                Text("\(blockedCount)")
                    .font(.numberMedium)
                    .foregroundStyle(Color.ink)
                    + Text(blockedCount == 1 ? " app" : " apps").font(.tSubhead).foregroundStyle(Color.inkSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.sm), count: 4), spacing: Space.sm) {
                ForEach(Array(selection.applicationTokens.prefix(7)), id: \.self) { token in
                    tile { Label(token).labelStyle(.iconOnly) }
                        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                }
                Button(action: onPickApps) {
                    tile {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                            .strokeBorder(Color.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Choose apps")
            }
        }
        .card()
    }

    /// A square as wide as its grid column, whatever the content's own size.
    private func tile(@ViewBuilder content: () -> some View) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { content() }
    }

    private var allowedCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionLabel(text: "Always allowed", color: .slateInk)
            FlowLayout {
                // iOS never blocks the Phone app, so it is always listed.
                chip(Text("Phone"))
                ForEach(Array(alwaysAllowed.applicationTokens), id: \.self) { token in
                    chip(Label(token))
                }
                Button(action: onPickAllowed) {
                    Text("+ Add")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, Space.md)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .card()
    }

    private func chip(_ content: some View) -> some View {
        content
            .font(.tSubhead)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Space.md)
            .frame(minHeight: 44)
            .background(Color.surface2, in: Capsule(style: .continuous))
    }
}

/// Step 4 (new): when the first mode locks by itself.
struct FocusTimeStep: View {
    @Binding var window: FocusWindow?
    @Binding var days: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("When should it lock?").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("It locks on its own. Tap a tag to open early.")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(FocusWindow.allCases) { option in
                    row(option)
                    if option != FocusWindow.allCases.last {
                        Rectangle().fill(Color.surface2).frame(height: 1)
                    }
                }
            }
            .card(padding: Space.md)
            DayChips(days: $days)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func row(_ option: FocusWindow) -> some View {
        Button {
            Haptics.select()
            window = option
        } label: {
            HStack(spacing: Space.sm) {
                Text(option.title).font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                Text(ScheduleFormat.range(ModeSchedule(days: [], start: option.start, end: option.end)))
                    .font(.numberSmall)
                    .foregroundStyle(Color.inkSecondary)
                Image(systemName: window == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(window == option ? Color.slateInk : Color.inkTertiary)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(window == option ? .isSelected : [])
    }
}

/// Step 5: the first tag, and interests for Insights' comparisons.
struct PairStep: View {
    @Binding var interests: Set<Interest>

    var body: some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: 20) {
                ZStack {
                    Circle().strokeBorder(Color.slateLine, lineWidth: 2).opacity(0.6).frame(width: 216, height: 216)
                    Circle().fill(Color.slateGlow).frame(width: 164, height: 164).blur(radius: 20)
                    Circle().fill(Color.surface2).frame(width: 168, height: 168)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.ink)
                }
                .frame(width: 220, height: 220)
                .accessibilityHidden(true)
                VStack(spacing: Space.xxs) {
                    Text("Pair your first tag").font(.tTitle1).foregroundStyle(Color.ink)
                    Text("Hold the top of your phone to it.").font(.tSubhead).foregroundStyle(Color.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionLabel(text: "Your interests")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 3), spacing: Space.xs) {
                    ForEach(Interest.allCases, id: \.self) { interest in
                        ChoiceChip(title: interest.title, isOn: interests.contains(interest), fillsWidth: true) {
                            if interests.contains(interest) { interests.remove(interest) } else { interests.insert(interest) }
                        }
                    }
                }
            }
        }
        .padding(.top, Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension View {
    /// A step on the onboarding background, without the footer.
    func stepPreview(_ colorScheme: ColorScheme) -> some View {
        padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .background(Color.bg.ignoresSafeArea())
            .environment(\.accent, .for(.unlocked))
            .preferredColorScheme(colorScheme)
    }
}

#Preview("Welcome · dark") { WelcomeStep().stepPreview(.dark) }
#Preview("Welcome · light") { WelcomeStep().stepPreview(.light) }

#Preview("Screen Time · dark") { ScreenTimeStep().stepPreview(.dark) }
#Preview("Screen Time · light") { ScreenTimeStep().stepPreview(.light) }

#Preview("Apps · dark") {
    AppsStep(selection: FamilyActivitySelection(), alwaysAllowed: FamilyActivitySelection(), onPickApps: {}, onPickAllowed: {})
        .stepPreview(.dark)
}

#Preview("Apps · light") {
    AppsStep(selection: FamilyActivitySelection(), alwaysAllowed: FamilyActivitySelection(), onPickApps: {}, onPickAllowed: {})
        .stepPreview(.light)
}

#Preview("Focus time · dark") {
    FocusTimeStep(window: .constant(.afternoons), days: .constant(ModeSchedule.weekdays)).stepPreview(.dark)
}

#Preview("Focus time · light") {
    FocusTimeStep(window: .constant(.afternoons), days: .constant(ModeSchedule.weekdays)).stepPreview(.light)
}

#Preview("Pair · dark") { PairStep(interests: .constant([.sports, .movies])).stepPreview(.dark) }
#Preview("Pair · light") { PairStep(interests: .constant([.sports, .movies])).stepPreview(.light) }
