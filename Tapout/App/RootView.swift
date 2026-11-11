import FamilyControls
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
    @State private var engine: LockEngine
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
    @State private var screenTimeNeeded = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.onboardedKey) private var hasOnboarded = false

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.scenePhase) private var scenePhase

    init(engine: LockEngine, model: AppModel) {
        _engine = State(initialValue: engine)
        _model = State(initialValue: model)
    }

    var body: some View {
        let accent = Accent.for(engine.session.lockState)
        NavigationStack(path: $path) {
            ZStack {
                screen
                    .safeAreaInset(edge: .bottom, spacing: Space.md) {
                        // Tucked away while typing, so the intention field and Scan fit above the keyboard on small iPhones.
                        if !keyboardUp { FloatingTabBar(active: $tab) }
                    }
                if showingLockMoment {
                    LockMomentView(placeName: lockPlaceName, session: engine.session, intention: model.currentIntention) {
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
                    SettingsView(model: model, passesLeft: engine.passesLeft, onOpenTab: open)
                }
            }
        }
        // Fraunces styles are read once per render, so rebuild the screens when Bold Text changes.
        // The id sits on the stack, not on RootView, so engine, model and tab survive; it comes
        // before the presentations so an open cover or sheet isn't dismissed by the change.
        .id(legibilityWeight)
        // Presentations sit inside the environment modifiers below, so covers and sheets get the accent,
        // the lock state and the appearance too.
        .fullScreenCover(item: $cover, onDismiss: runAfterCover) { cover in
            switch cover {
            case .rejected(let rejected):
                RejectedView(rejected: rejected, onTryAgain: { afterCover = .scan }, onPair: { afterCover = .pair })
            case .emergencyPass:
                EmergencyPassView(passesLeft: engine.passesLeft) {
                    do {
                        let relockAt = try withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) {
                            try engine.useEmergencyPass()
                        }
                        model.startPass(until: relockAt)
                        return true
                    } catch {
                        return false
                    }
                }
            case .milestone(let milestone):
                MilestoneView(milestone: milestone,
                              subtitle: milestone.subtitle(totalLocked: model.totalLocked, interests: model.interests))
            }
        }
        .sheet(item: $intentionCheck, onDismiss: {
            checkScreenTime()
            if !scanning { showMilestone() }
        }) { check in
            IntentionCheckSheet(check: check) { done in
                model.answerIntention(forLockStartedAt: check.id, done: done)
            }
        }
        .sheet(isPresented: $pairing, onDismiss: checkScreenTime) {
            PairPlaceSheet(model: model)
        }
        // Below the id, so turning on Bold Text in Settings can't reset the draft. On its own host,
        // because two full-screen covers on one view can conflict.
        .background {
            Color.clear.fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
                OnboardingView(model: model) { hasOnboarded = true }
            }
        }
        // Its own host too, for the same reason. It needs onboarding done, so the two never overlap.
        .background {
            Color.clear.fullScreenCover(isPresented: $screenTimeNeeded) {
                ScreenTimeAgainView { screenTimeNeeded = false }
            }
        }
        .onChange(of: screenTimeNeeded) { wasNeeded, needed in
            // The page closed: access came back, by its own button or by the check.
            if wasNeeded && !needed {
                engine.syncShields()
                model.syncSchedules()
            }
        }
        // A lock the monitor started (a schedule) gets its record here; for the app's own lock,
        // unlock, pass and relock the record is already right, so this changes nothing.
        .onChange(of: engine.session) { _, session in model.reconcile(with: session) }
        // The foreground read of the status can be stale, so a revoke is also caught as it publishes.
        .onReceive(AuthorizationCenter.shared.$authorizationStatus) { _ in checkScreenTime() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.syncShields()
                model.reconcile(with: engine.session)
                model.syncSchedules()
                checkScreenTime()
            }
        }
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .environment(\.isLocked, engine.session.lockState == .locked)
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
            // The lock state is the truth: it survives quitting, and the monitor can relock while Tapout is closed.
            engine.syncShields()
            model.reconcile(with: engine.session)
            model.syncSchedules()
            checkScreenTime()
            // Schedules made before notifications were asked for still lock while Tapout is closed.
            // Its own task, so the clock doesn't wait for the owner to answer the prompt.
            if hasOnboarded, model.hasRunnableSchedule, !Self.isDemo { Task { await NoticePermission.request() } }
            await runClock()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(
                engine: engine,
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

    /// Screen Time access can be turned off in Settings; until it's back, nothing can be shielded.
    /// Waits while another cover or sheet is up, so two presentations never fight; their dismissals check again.
    private func checkScreenTime() {
        let status = ScreenTimeAccess.status
        let approved = status == .approved
        model.noteScreenTimeAccess(status)
        let needed = hasOnboarded && !approved
        // Approved clears the flag even under a cover or sheet; only showing the page waits.
        guard needed else { screenTimeNeeded = false; return }
        guard cover == nil, intentionCheck == nil, !pairing, !scanning else { return }
        screenTimeNeeded = true
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
        let unlocking = engine.session.lockState == .locked
        // The simulator stand-in finds a place that works, unless launched with -mockUnknownTag.
        let known = unlocking ? model.unlockPlacesForActiveMode.first?.uid : model.defaultPlace?.uid
        let uid: TagUID
        do {
            uid = try await TagScanners.live(known: known).scan(prompt: TagScanPrompt.pair)
        } catch {
            return // cancelled, or no tag: the system NFC sheet already said so
        }
        // A schedule may have locked while the tag was being read. Drop the read rather than act on old state.
        engine.reload()
        guard (engine.session.lockState == .locked) == unlocking else { return }
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
        guard engine.lock() else { return }
        model.startLock(placeUID: place.uid, intention: intentionDraft)
        intentionDraft = ""
        lockPlaceName = place.name
        showingLockMoment = true // the lock moment plays the lock haptic
    }

    private func unlock() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { engine.unlock() }
        if let record = model.finishLock(), let intention = record.intention {
            intentionCheck = IntentionCheck(id: record.start, intention: intention)
        }
        if intentionCheck == nil { showMilestone() }
    }

    /// After an unlock (and its "Did you do it?" sheet), celebrate the milestones not shown yet, one at a time.
    /// One that can't show now stays unseen for the next unlock.
    private func showMilestone() {
        guard cover == nil, !screenTimeNeeded, engine.session == .unlocked,
              let milestone = model.unseenMilestone() else { return }
        model.markSeen(milestone)
        afterCover = .milestone
        cover = .milestone(milestone)
    }

    private func runAfterCover() {
        let action = afterCover
        afterCover = nil
        checkScreenTime()
        guard !screenTimeNeeded else { return }
        switch action {
        case .scan: Task { await scan() }
        case .pair: pairing = true
        case .milestone: showMilestone()
        case nil: break
        }
    }

    /// `-demoData` screenshots shouldn't stop for the notification prompt.
    private static var isDemo: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-demoData")
        #else
        false
        #endif
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let relocked = withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { engine.tick() }
            if relocked { Haptics.lock() }
        }
    }
}
