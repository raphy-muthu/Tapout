import Foundation

/// What the monitor does when a mode's daily window starts. Schedules only lock, never unlock.
enum ScheduledLock {
    enum Reason: Equatable {
        case noApps, noAccess, noTag
    }

    enum Decision: Equatable {
        case lock(Mode)
        /// The owner expects a lock, so a notification says why there isn't one.
        case skip(Reason, Mode)
        /// Nothing to say: another day, already locked, or unlocked or saved during this window.
        case skipQuietly(String)
    }

    /// What the process itself sees of Screen Time authorization.
    enum LiveAccess: Equatable {
        case approved, denied, notDetermined
    }

    /// Whether to lock. The extension may not see the app's authorization, so an undetermined status
    /// trusts the app's last check, and with none, tries to lock rather than skip.
    static func accessApproved(live: LiveAccess, mirrored: Bool?) -> Bool {
        switch live {
        case .approved: true
        case .denied: false
        case .notDetermined: mirrored ?? true
        }
    }

    /// A start callback this much early still counts as the window's start.
    static let earlyTolerance: TimeInterval = 60

    static func decide(
        mode: Mode?,
        store: SharedStore,
        now: Date,
        accessApproved: Bool,
        hasApps: Bool,
        hasTag: Bool,
        calendar: Calendar = .current
    ) -> Decision {
        guard let mode else { return .skipQuietly("mode not found") }
        guard let schedule = mode.schedule,
              let window = schedule.window(containing: now, calendar: calendar)
                ?? schedule.window(containing: now + earlyTolerance, calendar: calendar)
        else { return .skipQuietly("not a scheduled day") }
        guard store.session == .unlocked else { return .skipQuietly("already locked") }
        if let unlocked = store.lastUnlockAt, unlocked >= window.start {
            return .skipQuietly("unlocked during this window")
        }
        if let saved = store.scheduleSavedAt[mode.id.uuidString], saved > window.start {
            return .skipQuietly("saved during this window")
        }
        guard accessApproved else { return .skip(.noAccess, mode) }
        guard hasTag else { return .skip(.noTag, mode) }
        guard hasApps else { return .skip(.noApps, mode) }
        return .lock(mode)
    }

    /// Starts the lock: the scheduled mode becomes active, then the lock state is written, then the shields
    /// go on. No lock record here: the app adds it from the lock state (`AppModel.reconcile`), so only the
    /// app ever writes the history.
    /// Re-checks the lock state first: a tag lock in the app can land between `decide` and here, and the
    /// schedule must not overwrite that lock's mode. Returns false, writing nothing, when already locked.
    @discardableResult
    static func start(_ mode: Mode, store: SharedStore, shields: some Shielding, now: Date) -> Bool {
        guard store.session == .unlocked else { return false }
        store.activeModeID = mode.id
        store.activeModeName = mode.name
        store.session = .locked(since: now)
        shields.apply(store.activeShieldPlan)
        return true
    }

    /// The monitor's `intervalDidStart` for a mode activity: decide, then lock or say why not.
    /// `hasApps` is a parameter only so tests can answer it; Screen Time tokens can't be made in tests.
    /// `accessReadout` (the inputs of the access check) ends the lock and skip lines, for the iPhone run.
    /// Returns the line for the shared log.
    @discardableResult
    static func run(
        modeID: UUID,
        store: SharedStore,
        shields: some Shielding,
        notifier: some LockNotifying,
        now: Date,
        accessApproved: Bool,
        hasApps: ((Mode) -> Bool)? = nil,
        hasTag: Bool? = nil,
        accessReadout: String? = nil,
        calendar: Calendar = .current
    ) -> String {
        let mode = store.modes.first { $0.id == modeID }
        let readout = accessReadout.map { " (\($0))" } ?? ""
        let alwaysAllowed = store.alwaysAllowed
        let appsChosen = mode.map { hasApps?($0) ?? !ShieldPlan(blocking: $0.selection, allowing: alwaysAllowed).isEmpty } ?? false
        switch decide(mode: mode, store: store, now: now, accessApproved: accessApproved, hasApps: appsChosen,
                          hasTag: hasTag ?? !store.pairedTags.isEmpty, calendar: calendar) {
        case .lock(let mode):
            guard start(mode, store: store, shields: shields, now: now) else {
                return "Schedule skipped: already locked"
            }
            let notice = ScheduleNotice.locked(mode)
            notifier.post(title: notice.title, body: notice.body)
            return "Scheduled lock: \(mode.name)\(readout)"
        case .skip(let reason, let mode):
            let notice = ScheduleNotice.skipped(mode, reason)
            notifier.post(title: notice.title, body: notice.body)
            return "Schedule skipped: \(notice.body)\(readout)"
        case .skipQuietly(let why):
            return "Schedule skipped: \(why)"
        }
    }
}
