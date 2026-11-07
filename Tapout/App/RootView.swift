import SwiftUI

/// Screens pushed over the tabs. The tab bar belongs to the root, so pushed screens cover it.
enum Route: Hashable {
    case settings
}

/// Full-screen moments over everything.
enum Cover: Identifiable {
    case rejected(RejectedTag)
    case emergencyPass
    case milestone(Milestone)

    var id: String {
        switch self {
        case .rejected: "rejected"
        case .emergencyPass: "emergencyPass"
        case .milestone(let milestone): "milestone-\(milestone.rawValue)"
        }
    }
}

/// What to do once a cover has gone, so a scan or sheet never starts while it is still leaving.
private enum AfterCover {
    case scan, pair, milestone
}

/// Tabs, the floating tab bar, navigation, tag scans, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var model: AppModel
    @State private var tab = AppTab.home
    @State private var path: [Route] = []
    @State private var showingLockMoment = false
    @State private var lockPlaceName = ""
    @State private var intentionDraft = ""
    @State private var intentionCheck: IntentionCheck?
    @State private var cover: Cover?
    @State private var afterCover: AfterCover?
    @State private var pairing = false
    @State private var scanning = false
    @State private var keyboardUp = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.onboardedKey) private var hasOnboarded = false

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight

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
                        // Tucked away while typing, so the intention field and Scan fit above the keyboard on small iPhones.
                        if !keyboardUp { FloatingTabBar(active: $tab) }
                    }
                if showingLockMoment {
                    LockMomentView(placeName: lockPlaceName, session: controller.session, intention: model.currentIntention) {
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
        // Fraunces styles are read once per render, so rebuild the screens when Bold Text changes.
        // The id sits on the stack, not on RootView, so controller, model and tab survive; it comes
        // before the presentations so an open cover or sheet isn't dismissed by the change.
        .id(legibilityWeight)
        // Presentations sit inside the environment modifiers below, so covers and sheets get the accent,
        // the lock state and the appearance too.
        .fullScreenCover(item: $cover, onDismiss: runAfterCover) { cover in
            switch cover {
            case .rejected(let rejected):
                RejectedView(rejected: rejected, onTryAgain: { afterCover = .scan }, onPair: { afterCover = .pair })
            case .emergencyPass:
                EmergencyPassView(passesLeft: controller.passesLeft) {
                    let before = controller.passesLeft
                    withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) { controller.useEmergencyPass() }
                    return controller.passesLeft < before
                }
            case .milestone(let milestone):
                MilestoneView(milestone: milestone,
                              subtitle: milestone.subtitle(totalLocked: model.totalLocked, interests: model.interests))
            }
        }
        .sheet(item: $intentionCheck, onDismiss: { if !scanning { showMilestone() } }) { check in
            IntentionCheckSheet(check: check) { done in
                model.answerIntention(forLockStartedAt: check.id, done: done)
            }
        }
        .sheet(isPresented: $pairing) {
            PairPlaceSheet(model: model)
        }
        // Below the id, so turning on Bold Text in Settings can't reset the draft. On its own host,
        // because two full-screen covers on one view can conflict.
        .background {
            Color.clear.fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
                OnboardingView(model: model) { hasOnboarded = true }
            }
        }
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .environment(\.isLocked, controller.session.lockState == .locked)
        .environment(\.accent, accent)
        .tint(accent.line)
        .preferredColorScheme(appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { keyboardUp = false }
        }
        .task {
            // Lock state isn't persisted yet, so a lock left open by a crash can't still be running.
            if controller.session == .unlocked { model.discardInterruptedLocks() }
            await runClock()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(
                controller: controller,
                model: model,
                intentionDraft: $intentionDraft,
                onScan: { Task { await scan() } },
                onEmergencyPass: { if !scanning { cover = .emergencyPass } },
                onOpenSettings: openSettings
            )
        case .modes:
            ModesView(model: model)
        case .places:
            PlacesView(model: model)
        case .insights:
            InsightsView(model: model)
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

    /// Reads a tag, then locks, unlocks, or shows why it can't.
    private func scan() async {
        guard !scanning else { return }
        scanning = true
        defer { scanning = false }
        Haptics.prepare()
        let unlocking = controller.session.lockState == .locked
        // The simulator stand-in finds a place that works, unless launched with -mockUnknownTag.
        let known = unlocking ? model.unlockPlacesForActiveMode.first?.uid : model.defaultPlace?.uid
        let uid: TagUID
        do {
            uid = try await TagScanners.live(known: known).scan(prompt: TagScanPrompt.pair)
        } catch {
            return // cancelled, or no tag: the system NFC sheet already said so
        }
        let tryPlaces = (unlocking ? model.unlockPlacesForActiveMode : model.places).map(\.name)
        switch model.check(uid, unlocking: unlocking) {
        case .accepted(let place):
            if unlocking { unlock() } else { lock(at: place) }
        case .unknown:
            Haptics.mismatch()
            cover = .rejected(.unknown(tryPlaces: tryPlaces, locked: unlocking))
        case .wrongPlace:
            Haptics.mismatch()
            cover = .rejected(.wrongPlace(mode: model.activeMode.name, tryPlaces: tryPlaces))
        }
    }

    private func lock(at place: PairedTag) {
        controller.simulateTagRead()
        model.startLock(placeUID: place.uid, intention: intentionDraft)
        intentionDraft = ""
        lockPlaceName = place.name
        showingLockMoment = true // the lock moment plays the lock haptic
    }

    private func unlock() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { controller.simulateTagRead() }
        if let record = model.finishLock(), let intention = record.intention {
            intentionCheck = IntentionCheck(id: record.start, intention: intention)
        }
        if intentionCheck == nil { showMilestone() }
    }

    /// After an unlock (and its "Did you do it?" sheet), celebrate the milestones not shown yet, one at a time.
    /// One that can't show now stays unseen for the next unlock.
    private func showMilestone() {
        guard cover == nil, controller.session == .unlocked, let milestone = model.unseenMilestone() else { return }
        model.markSeen(milestone)
        afterCover = .milestone
        cover = .milestone(milestone)
    }

    private func runAfterCover() {
        let action = afterCover
        afterCover = nil
        switch action {
        case .scan: Task { await scan() }
        case .pair: pairing = true
        case .milestone: showMilestone()
        case nil: break
        }
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
