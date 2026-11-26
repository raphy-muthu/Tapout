import SwiftUI

/// Named `AppTab` because SwiftUI already has a `Tab` type.
enum AppTab: CaseIterable {
    case home, modes, places, insights

    var title: String {
        switch self {
        case .home: "Home"
        case .modes: "Modes"
        case .places: "Places"
        case .insights: "Insights"
        }
    }
}

/// The floating capsule tab bar from design/screens/TabBar.dc.html.
struct FloatingTabBar: View {
    @Binding var active: AppTab
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.glassControls) private var glass
    @Environment(\.accent) private var accent
    @Environment(\.isLocked) private var isLocked
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection

    var body: some View {
        let light = colorScheme == .light
        HStack(spacing: Space.xxs) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard tab != active else { return }
                    Haptics.select()
                    withAnimation(glass && !reduceMotion ? Motion.ui : nil) { active = tab }
                } label: {
                    icon(for: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(tab == active ? (glass && isLocked ? accent.ink : Color.ink) : Color.inkTertiary)
                        .background {
                            if tab == active {
                                if glass {
                                    selectedPane.matchedGeometryEffect(id: "tab", in: selection)
                                } else {
                                    Capsule(style: .continuous).fill(Color.surface2)
                                }
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == active ? .isSelected : [])
            }
        }
        .padding(Space.xs)
        .frame(height: 64)
        .background { barSurface }
        .shadow(color: .black.opacity(light ? 0.10 : 0.4), radius: light ? 10 : 12, y: light ? 4 : 8)
        .padding(.horizontal, Space.lg)
    }

    /// The sliding, glowing selection.
    private var selectedPane: some View {
        let shape = Capsule(style: .continuous)
        return shape.fill(accent.fill.opacity(0.24))
            .overlay { shape.strokeBorder(accent.fill.opacity(0.55), lineWidth: 1) }
            .shadow(color: accent.fill.opacity(0.55), radius: 10)
    }

    @ViewBuilder
    private var barSurface: some View {
        if glass {
            GlassPane(shape: Capsule(style: .continuous), tint: .surface1)
        } else {
            Capsule(style: .continuous).fill(Color.surface1)
        }
    }

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeGlyph()
        case .modes: Image(systemName: "slider.horizontal.3").font(.system(size: 20))
        case .places: PinGlyph()
        case .insights: Image(systemName: "chart.bar").font(.system(size: 20))
        }
    }
}

/// The spec's custom Home icon: a ring inside a dashed ring.
private struct HomeGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.6).frame(width: 14, height: 14)
            Circle().stroke(style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])).frame(width: 20, height: 20)
        }
        .frame(width: 24, height: 24)
    }
}

#Preview {
    @Previewable @State var tab = AppTab.home
    VStack { Spacer(); FloatingTabBar(active: $tab) }
        .background(Color.bg)
}
