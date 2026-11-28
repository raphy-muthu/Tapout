import FamilyControls
import SwiftUI
import WidgetKit

/// Screens pushed over the tabs. The tab bar belongs to the root, so pushed screens cover it.
enum Route: Hashable {
    case settings
}

/// Full-screen moments over everything.
enum Cover: Identifiable {
    case rejected(RejectedTag)
    case emergencyPass
    case milestone(Milestone)
    /// A timer lock ended; carries its length, and the mode whose scheduled lock took over, if any.
    case timerDone(TimeInterval, handedOverTo: String?)

    var id: String {
        switch self {
        case .rejected: "rejected"
        case .emergencyPass: "emergencyPass"
        case .milestone(let milestone): "milestone-\(milestone.rawValue)"
        case .timerDone: "timerDone"
        }
    }
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
    /// The owner's choice from a cover that closed while a Time's up was waiting; it runs after the Time's up.
    @State private var deferredAfterCover: AfterCover?
    @State private var pairing = false
    @State private var showingTimer = false
    /// Start succeeded in the timer sheet; the lock moment plays once the sheet has gone.
    @State private var timerStarted = false
    /// A finished timer's Time's up cover, waiting for other covers and sheets to go.
    @State private var pendingTimerDone: (duration: TimeInterval, handedOverTo: String?)?
    /// The finished timer's "Did you do it?", shown after its Time's up cover.
    @State private var pendingTimerCheck: IntentionCheck?
    @State private var scanning = false
    @State private var keyboardUp = false
    @State private var screenTimeNeeded = false
    @State private var screenTimeGrace = ScreenTimeGrace()
    @State private var screenTimeRecheck: Task<Void, Never>?
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppSettings.onboardedKey) private var hasOnboarded = false
    @AppStorage(AppSettings.liveActivityKey) private var liveActivity = true

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.scenePhase) private var scenePhase
    /// The Lab's switch (always off in Release): glass controls and the living background.
    @LivingGlassFlag private var livingGlass

    init(engine: LockEngine, model: AppModel) {
        _engine = State(initialValue: engine)
        _model = State(initialValue: model)
    }

    /// The page color, and with the switch on the breathing glow: full behind Home, softer behind the other tabs.
    private var backdrop: some View {
        GlassPageBackground(tone: engine.session.lockState == .locked ? .ember : .slate, isOn: livingGlass,
                            strength: tab == .home ? 1 : BackdropPlan.readingStrength)
    }

    var body: some View {
        let accent = Accent.for(engine.session.lockState)
        NavigationStack(path: $path) {
            ZStack {
                screen
                    .safeAreaInset(edge: .bottom, spacing: Space.md) {
                        // Tucked away while typing, so the intention field and Scan fit above the keyboard on small iPhones.
                        if !keyboardUp { FloatingTabBar(active: $tab).environment(\.glassControls, livingGlass) }
                    }
                if showingLockMoment {
                    LockMomentView(placeName: lockPlaceName, session: engine.session, intention: model.currentIntention,
                                   timer: model.timerLock) {
                        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { showingLockMoment = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .background { backdrop.ignoresSafeArea() }
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
                RejectedView(rejected: rejected, onTryAgain: { afterCover = .scan(unlocking: rejected.locked) },
                             onPair: { afterCover = .pair })
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
            case .timerDone(let duration, let handedOverTo):
                TimerDoneView(duration: duration, handedOverTo: handedOverTo) {}
            }
        }
        .sheet(item: $intentionCheck, onDismiss: {
            checkScreenTime()
            guard !showTimerDone() else { return }
            if !runDeferredAfterCover(), !scanning { showMilestone() }
        }) { check in
            IntentionCheckSheet(check: check) { done in
                model.answerIntention(forLockStartedAt: check.id, done: done)
            }
        }
        .sheet(isPresented: $pairing, onDismiss: {
            checkScreenTime()
            showTimerDone()
        }) {
            PairPlaceSheet(model: model)
                .environment(\.glassControls, livingGlass)
        }
        .sheet(isPresented: $showingTimer, onDismiss: {
            if timerStarted {
                timerStarted = false
                lockPlaceName = "Timer"
                showingLockMoment = true // the lock moment plays the lock haptic
            }
            checkScreenTime()
            showTimerDone()
        }) {
            TimerSheet(modeName: model.activeMode.name, hasApps: model.activeModeHasApps, hasTags: !model.places.isEmpty,
                       intention: $intentionDraft, recent: model.recentIntentions, onStart: startTimer)
        }
        // Below the id, so turning on Bold Text in Settings can't reset the draft. On its own host,
        // because two full-screen covers on one view can conflict.
        .background {
            Color.clear.fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
                OnboardingView(model: model) { hasOnboarded = true }
                    .environment(\.glassControls, livingGlass)
            }
        }
        // Its own host too, for the same reason. It needs onboarding done, so the two never overlap.
        .background {
            Color.clear.fullScreenCover(isPresented: $screenTimeNeeded) {
                ScreenTimeAgainView {
                    screenTimeGrace = ScreenTimeGrace()
                    screenTimeRecheck?.cancel()
                    screenTimeRecheck = nil
                    screenTimeNeeded = false
                }
            }
        }
        .onChange(of: screenTimeNeeded) { wasNeeded, needed in
            // The page closed: access came back, by its own button or by the check.
            if wasNeeded && !needed {
                // The monitor reads this mirror when it can't see the authorization itself.
                model.noteScreenTimeAccess(ScreenTimeAccess.status)
                engine.syncShields()
                closeFinishedTimer(heard: false)
                model.syncSchedules()
                showTimerDone()
            }
        }
        // A lock the monitor started (a schedule) gets its record here; for the app's own lock,
        // unlock, pass and relock the record is already right, so this changes nothing.
        // A timer the monitor ended while Tapout is open (its callback may come before the app's tick) is
        // caught here and gets the same Time's up as one the app ended; each timer is closed only once.
        .onChange(of: engine.session) { _, session in
            if let finish = model.sessionChanged(to: session) {
                engine.acknowledgeTimerFinish()
                present(finish, heard: scenePhase == .active)
            }
            refreshSurfaces()
        }
        .onChange(of: liveActivity) { _, _ in refreshSurfaces() }
        .onChange(of: livingGlass) { _, _ in refreshSurfaces() }
        .onChange(of: model.activeMode.name) { _, _ in refreshSurfaces() }
        .onChange(of: model.places.map(\.name)) { _, _ in refreshSurfaces() }
        // The foreground read of the status can be stale, so a revoke is also caught as it publishes.
        // `@Published` sends before it stores the new value, so read it on the next main-actor turn.
        .onReceive(AuthorizationCenter.shared.$authorizationStatus) { _ in
            Task { @MainActor in checkScreenTime() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.syncShields()
                // A timer that ended while Tapout was in the background or closed (the monitor finished it).
                closeFinishedTimer(heard: false)
                model.reconcile(with: engine.session)
                model.syncSchedules()
                checkScreenTime()
                refreshSurfaces()
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
            // A timer that ended while Tapout was closed (the monitor finished it, or syncShields just did).
            closeFinishedTimer(heard: false)
            model.reconcile(with: engine.session)
            model.syncSchedules()
            checkScreenTime()
            // Schedules made before notifications were asked for still lock while Tapout is closed.
            // Its own task, so the clock doesn't wait for the owner to answer the prompt.
            if hasOnboarded, model.hasRunnableSchedule, !Self.isDemo { Task { await NoticePermission.request() } }
            refreshSurfaces()
            await runClock()
        }
    }

    /// Widgets and the Live Activity read the store; tell them it changed. The Lab's switch goes to the App Group
    /// first, for them and the shield.
    private func refreshSurfaces() {
        LivingGlassMirror.set(livingGlass)
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityController.sync(model.lockSnapshot(at: .now), enabled: liveActivity, flat: livingGlass,
                                    handsOver: model.timerHandsOverToSchedule)
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
                onTimer: { if !scanning, engine.session == .unlocked { showingTimer = true } },
                onEmergencyPass: { if !scanning { cover = .emergencyPass } },
                onOpenSettings: openSettings
            )
            .environment(\.glassControls, livingGlass)
        case .modes:
            ModesView(model: model)
                .environment(\.glassControls, livingGlass)
        case .places:
            PlacesView(model: model)
                .environment(\.glassControls, livingGlass)
        case .insights:
            InsightsView(model: model)
                .environment(\.glassControls, livingGlass)
        }
    }

    /// Screen Time access can be turned off in Settings; until it's back, nothing can be shielded.
    /// Waits while another cover or sheet is up, so two presentations never fight; their dismissals check again.
    private func checkScreenTime() {
        let status = ScreenTimeAccess.status
        let approved = status == .approved
        model.noteScreenTimeAccess(status)
        let needed = hasOnboarded && !approved
        switch screenTimeGrace.observe(needed: needed, now: .now) {
        case .clear:
            // Approved clears the flag even under a cover or sheet; only showing the page waits.
            screenTimeRecheck?.cancel()
            screenTimeRecheck = nil
            screenTimeNeeded = false
        case .wait(let due):
            screenTimeRecheck?.cancel()
            screenTimeRecheck = Task {
                try? await Task.sleep(for: .seconds(max(0, due.timeIntervalSinceNow) + 0.05))
                guard !Task.isCancelled else { return }
                checkScreenTime()
            }
        case .show:
            // Waits while another cover or sheet is up, so two presentations never fight; their dismissals check again.
            guard cover == nil, intentionCheck == nil, !pairing, !showingTimer, !scanning else { return }
            screenTimeNeeded = true
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
        defer {
            scanning = false
            checkScreenTime()
            showTimerDone() // a timer that ended during the read
        }
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
        LivingFeedback.unlock()
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
        // A timer that ended under another cover takes its turn first; the owner's choice waits for it.
        let waiting = AfterCover.deferring(action, over: deferredAfterCover)
        if showTimerDone() {
            deferredAfterCover = waiting
            return
        }
        engine.reload()
        if let action, !action.stillApplies(locked: engine.session.lockState == .locked) { return }
        switch action {
        case .scan: Task { await scan() }
        case .pair: pairing = true
        case .milestone: showMilestone()
        case .timerCheck:
            if let check = pendingTimerCheck {
                // Its dismissal runs a waiting choice.
                pendingTimerCheck = nil
                intentionCheck = check
            } else if !runDeferredAfterCover() {
                showMilestone()
            }
        case nil: break
        }
    }

    /// Runs the choice that waited for a Time's up. Returns true when there was one.
    private func runDeferredAfterCover() -> Bool {
        guard let action = deferredAfterCover else { return false }
        deferredAfterCover = nil
        engine.reload()
        guard action.stillApplies(locked: engine.session.lockState == .locked) else { return false }
        switch action {
        case .scan: Task { await scan() }
        case .pair: pairing = true
        case .milestone, .timerCheck: return false
        }
        return true
    }

    /// Starts a timer lock from the sheet. The end is scheduled first; if that fails nothing locks and the
    /// sheet says so.
    private func startTimer(_ duration: TimeInterval) -> Bool {
        // A second Start while the first one is being handled: the first already locked.
        if timerStarted { return true }
        guard !scanning, engine.session == .unlocked, model.activeModeHasApps else { return false }
        // A timer that finished but isn't closed yet gets its record ended at its own end first, so the new
        // lock can't drop it. Its Time's up is skipped: the owner is already starting the next one.
        model.closeFinishedTimer()
        engine.acknowledgeTimerFinish()
        do {
            _ = try engine.lockTimed(duration: duration)
        } catch {
            return false
        }
        model.startLock(placeUID: nil, intention: intentionDraft)
        intentionDraft = ""
        timerStarted = true
        // The notice at the end needs permission. Its own task, so the lock doesn't wait for the answer.
        if !Self.isDemo { Task { await NoticePermission.request() } }
        return true
    }

    /// Closes a finished timer's record (at the timer's end time) and queues its Time's up cover and
    /// "Did you do it?". `closeFinishedTimer()` returns nil once done, so each timer is shown once.
    /// `heard` plays the unlock haptic, for a timer that ended while Tapout was open.
    private func closeFinishedTimer(heard: Bool) {
        engine.acknowledgeTimerFinish()
        guard let finish = model.closeFinishedTimer() else { return }
        present(finish, heard: heard)
    }

    /// Queues a closed timer's Time's up cover and "Did you do it?", with the unlock haptic when `heard`.
    /// A timer that handed over to a schedule opened nothing, so it gets no unlock haptic.
    private func present(_ finish: AppModel.TimerFinish, heard: Bool) {
        if finish.playsUnlockHaptic(heard: heard) { LivingFeedback.unlock() }
        if let record = finish.record, let intention = record.intention {
            pendingTimerCheck = IntentionCheck(id: record.start, intention: intention)
        }
        pendingTimerDone = (finish.timer.duration, finish.handedOverTo)
        showTimerDone()
    }

    /// Shows a waiting Time's up cover when nothing else is up. Returns true when it did.
    @discardableResult
    private func showTimerDone() -> Bool {
        guard let done = pendingTimerDone, cover == nil, intentionCheck == nil, !pairing, !showingTimer,
              !scanning, !screenTimeNeeded else { return false }
        pendingTimerDone = nil
        afterCover = .timerCheck
        cover = .timerDone(done.duration, handedOverTo: done.handedOverTo)
        return true
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
            if relocked { LivingFeedback.lock() }
            // The timer ran out while Tapout was open.
            if engine.timerJustFinished != nil { closeFinishedTimer(heard: true) }
        }
    }
}
