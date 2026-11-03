import SwiftUI

/// Screens pushed over the tabs. The tab bar belongs to the root, so pushed screens cover it.
enum Route: Hashable {
    case settings
}

/// Tabs, the floating tab bar, navigation, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var model: AppModel
    @State private var tab = AppTab.home
    @State private var path: [Route] = []
    @State private var showingLockMoment = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(controller: MockLockController = MockLockController(), model: AppModel) {
        _controller = State(initialValue: controller)
        _model = State(initialValue: model)
    }

    var body: some View {
        let accent = Accent.for(controller.session.lockState)
        NavigationStack(path: $path) {
            ZStack {
                screen
                    .safeAreaInset(edge: .bottom, spacing: Space.md) {
                        FloatingTabBar(active: $tab)
                    }
                if showingLockMoment {
                    LockMomentView(placeName: model.defaultPlace?.name ?? MockData.placeName, session: controller.session) {
                        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { showingLockMoment = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView(model: model, passesLeft: controller.passesLeft, onOpenTab: open)
                }
            }
        }
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .environment(\.isLocked, controller.session.lockState == .locked)
        .environment(\.accent, accent)
        .tint(accent.line)
        .preferredColorScheme(appearance.colorScheme)
        .task { await runClock() }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(controller: controller, model: model, onScan: scan, onOpenSettings: openSettings)
        case .modes:
            ModesView(model: model)
        case .places:
            PlacesView(model: model)
        case .insights:
            PlaceholderView(title: "Insights")
        }
    }

    /// A quick double tap on the gear would otherwise push Settings twice.
    private func openSettings() {
        guard path.isEmpty else { return }
        path.append(.settings)
    }

    /// Settings links jump to a tab: pop back to the root, then switch.
    private func open(_ destination: AppTab) {
        path.removeAll()
        tab = destination
    }

    /// Phase 1 stand-in for a successful tag read. The overlay appears instantly,
    /// the way it will right after iOS's NFC sheet closes.
    private func scan() {
        Haptics.prepare()
        controller.simulateTagRead()
        showingLockMoment = true
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let before = controller.session
            withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { controller.tick() }
            if controller.session != before { Haptics.lock() }
        }
    }
}
