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

    var body: some View {
        let light = colorScheme == .light
        HStack(spacing: Space.xxs) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard tab != active else { return }
                    Haptics.select()
                    active = tab
                } label: {
                    icon(for: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(tab == active ? Color.ink : Color.inkTertiary)
                        .background {
                            if tab == active { Capsule(style: .continuous).fill(Color.surface2) }
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
        .background(Color.surface1, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(light ? 0.10 : 0.4), radius: light ? 10 : 12, y: light ? 4 : 8)
        .padding(.horizontal, Space.lg)
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
