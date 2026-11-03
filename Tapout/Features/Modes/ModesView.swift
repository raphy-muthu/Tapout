import SwiftUI

/// The Modes tab: the active mode, then every other mode.
struct ModesView: View {
    let model: AppModel

    @Environment(\.isLocked) private var isLocked
    @State private var editing: Mode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Modes", addLabel: "New mode") { editing = model.newMode() }
                Button { editing = model.activeMode } label: {
                    ActiveModeCard(
                        mode: model.activeMode,
                        unlockNames: model.unlockPlaceNames(for: model.activeMode),
                        lockedThisWeek: model.lockedThisWeek(model.activeMode)
                    )
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, Space.lg)
                SectionLabel(text: "Ready")
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.sm)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible())], spacing: Space.sm) {
                    ForEach(model.otherModes) { mode in
                        Button { editing = mode } label: { ModeTile(mode: mode) }
                            .buttonStyle(PressScaleStyle())
                    }
                    DashedTile(title: "New mode", vertical: true) { editing = model.newMode() }
                        .disabled(isLocked)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editing) { ModeEditor(model: model, mode: $0) }
    }
}

#if DEBUG
#Preview("Modes · dark") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Modes · light") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}

#Preview("Modes · locked") {
    ModesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.isLocked, true).preferredColorScheme(.dark)
}
#endif
