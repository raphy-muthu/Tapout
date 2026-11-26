import SwiftUI

/// The Modes tab: the active mode, then every other mode. With the Living glass switch on, a column of
/// glass cards that open like drawers.
struct ModesView: View {
    let model: AppModel

    @Environment(\.isLocked) private var isLocked
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.glassControls) private var glass
    @State private var editing: Mode?
    /// The open drawer; the active mode's on arrival.
    @State private var openDrawer: UUID?
    /// The drawers' order since arriving (see `ModeDrawer.order`).
    @State private var held: [UUID] = []
    @Namespace private var editorZoom

    init(model: AppModel) {
        self.model = model
        _openDrawer = State(initialValue: model.activeMode.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Modes", addLabel: "New mode") { editing = model.newMode() }
                if glass { drawers } else { tiles }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .modifier(StatusBarFade(isOn: glass))
        .sheet(item: $editing) { mode in
            ModeEditor(model: model, mode: mode)
                .environment(\.glassControls, glass)
                // A new mode has no card to grow from.
                .zoomDestination(mode.id, in: editorZoom, isOn: glass && model.isSaved(mode))
        }
        .onAppear { held = order }
        .onChange(of: model.modes.map(\.id)) { held = order }
    }

    private var order: [UUID] {
        ModeDrawer.order(model.modes.map(\.id), held: held, active: model.activeMode.id)
    }

    private var drawers: some View {
        VStack(spacing: Space.sm) {
            ForEach(order.compactMap { id in model.modes.first { $0.id == id } }) { mode in
                ModeDrawerCard(
                    mode: mode,
                    isActive: mode.id == model.activeMode.id,
                    isOpen: openDrawer == mode.id,
                    unlockNames: model.unlockPlaceNames(for: mode),
                    lockedThisWeek: model.lockedThisWeek(mode),
                    onToggle: { toggle(mode.id) },
                    onUse: { use(mode.id) },
                    onEdit: { editing = mode }
                )
                .zoomSource(mode.id, in: editorZoom)
                .fingerTilt()
            }
            DashedTile(title: "New mode") { editing = model.newMode() }
                .disabled(isLocked)
        }
        .padding(.top, Space.lg)
    }

    @ViewBuilder
    private var tiles: some View {
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
        LazyVGrid(columns: GridItem.tiles(typeSize), spacing: Space.sm) {
            ForEach(model.otherModes) { mode in
                Button { editing = mode } label: { ModeTile(mode: mode) }
                    .buttonStyle(PressScaleStyle())
            }
            DashedTile(title: "New mode", vertical: true) { editing = model.newMode() }
                .disabled(isLocked)
        }
    }

    private func toggle(_ id: UUID) {
        HapticEngine.shared.play(.detent)
        // Opening moves the cards below, so with Reduce Motion it happens at once.
        withAnimation(Motion.travel(Motion.ui, reduceMotion: reduceMotion)) {
            openDrawer = ModeDrawer.toggled(id, open: openDrawer)
        }
    }

    private func use(_ id: UUID) {
        guard !isLocked else { return }
        Haptics.select()
        withAnimation(Motion.travel(Motion.ui, reduceMotion: reduceMotion)) { model.setActiveMode(id) }
    }
}

#if DEBUG
#Preview("Modes · dark") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Modes · light") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}

#Preview("Modes · glass") {
    ModesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.glassControls, true).preferredColorScheme(.dark)
}

#Preview("Modes · locked") {
    ModesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.isLocked, true).preferredColorScheme(.dark)
}
#endif
