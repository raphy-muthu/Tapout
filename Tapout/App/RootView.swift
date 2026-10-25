import SwiftUI

/// Tabs, the floating tab bar, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var tab = AppTab.home
    @State private var showingSettings = false
    @State private var showingLockMoment = false

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(controller: MockLockController = MockLockController()) {
        _controller = State(initialValue: controller)
    }

    var body: some View {
        let accent = Accent.for(controller.session.lockState)
        ZStack {
            screen
                .safeAreaInset(edge: .bottom, spacing: Space.md) {
                    FloatingTabBar(active: $tab)
                }
            if showingLockMoment {
                LockMomentView(placeName: MockData.placeName, session: controller.session) {
                    withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { showingLockMoment = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, accent)
        .tint(accent.line)
        .sheet(isPresented: $showingSettings) {
            #if DEBUG
            LabView()
            #else
            PlaceholderView(title: "Settings")
            #endif
        }
        .task { await runClock() }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(controller: controller, onScan: scan, onOpenSettings: { showingSettings = true })
        case .modes:
            PlaceholderView(title: "Modes")
        case .places:
            PlaceholderView(title: "Places")
        case .insights:
            PlaceholderView(title: "Insights")
        }
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
