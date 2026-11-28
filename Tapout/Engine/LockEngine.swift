import Foundation
import Observation

/// The real lock: shields, emergency passes and relock, kept in the App Group store, so the monitor
/// extension can relock while Tapout is closed and a lock survives quitting and restarts.
/// Which tags may lock or unlock is `AppModel.check`'s job; the engine trusts its caller.
@MainActor
@Observable
final class LockEngine {
    enum PassError: Error, Equatable {
        case notLocked, noPassesLeft
        case couldNotSchedule(String)
    }

    enum TimerError: Error, Equatable {
        case alreadyLocked
        case couldNotSchedule(String)
    }

    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60

    private(set) var session: LockSession = .unlocked
    private(set) var passesLeft = SharedStore.totalPasses
    private(set) var relockStrategy = RelockStrategy.warning
    private(set) var log: [LogEntry] = []
    /// A timer the engine just ended (and the mode it handed over to, if any), for the UI's "Time's up" moment.
    /// Cleared by `acknowledgeTimerFinish()`. A timer the monitor ended shows up as `store.finishedTimer` instead.
    private(set) var timerJustFinished: TimerLock.Finish?

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let shields: any Shielding
    @ObservationIgnored private let relock: any RelockScheduling
    @ObservationIgnored private let passes: any PassCounting
    @ObservationIgnored private let timers: any RelockScheduling
    @ObservationIgnored private let now: () -> Date
    /// Whether a mode blocks anything, for a timer's hand-over to a schedule. Only tests set it (no app tokens there).
    @ObservationIgnored private let modeHasApps: ((Mode) -> Bool)?
    @ObservationIgnored private let calendar: Calendar
    /// The monotonic clock (`ClockAnchor.current` on a phone). Tests leave it nil, so only the wall clock counts.
    @ObservationIgnored private let clock: () -> ClockAnchor?
    /// The wall-clock date a callback was last moved to after the clock changed, so it isn't moved again each time.
    @ObservationIgnored private var rearmedTo: [String: Date] = [:]

    init(
        store: SharedStore,
        shields: any Shielding,
        relock: any RelockScheduling,
        passes: any PassCounting = MemoryPassVault(),
        timers: any RelockScheduling = NoRelock(),
        now: @escaping () -> Date = Date.init,
        modeHasApps: ((Mode) -> Bool)? = nil,
        calendar: Calendar = .current,
        clock: @escaping () -> ClockAnchor? = { nil }
    ) {
        self.store = store
        self.shields = shields
        self.relock = relock
        self.passes = passes
        self.timers = timers
        self.now = now
        self.modeHasApps = modeHasApps
        self.calendar = calendar
        self.clock = clock
        reload()
    }

    /// Screen Time on an iPhone; stand-ins in the simulator, where shields and DeviceActivity don't run.
    static func live(store: SharedStore = .appGroup()) -> LockEngine {
        #if targetEnvironment(simulator)
        LockEngine(store: store, shields: NoShields(), relock: NoRelock(), passes: KeychainPassVault(), timers: NoRelock())
        #else
        LockEngine(store: store, shields: ShieldController(),
                   relock: RelockScheduler(usage: { SharedStore.appGroup().activeShieldPlan }),
                   passes: KeychainPassVault(), timers: RelockScheduler(activity: TimerPlan.activity),
                   clock: ClockAnchor.current)
        #endif
    }

    /// Passes spent, as last read from the vault. Only the engine changes the vault, and every
    /// change ends in `reload()`, so `tick()` can skip the Keychain.
    @ObservationIgnored private var vaultUsed = 0

    /// Re-reads the store and the pass vault. The monitor extension may have relocked while Tapout
    /// was in the background.
    func reload() {
        vaultUsed = passes.used()
        refresh()
    }

    /// Re-reads the store only. Assigns only what changed, so a quiet tick redraws nothing.
    private func refresh() {
        let newSession = store.session
        if newSession != session { session = newSession }
        let newPasses = max(0, min(store.passesLeft, SharedStore.totalPasses - vaultUsed))
        if newPasses != passesLeft { passesLeft = newPasses }
        let newStrategy = store.relockStrategy
        if newStrategy != relockStrategy { relockStrategy = newStrategy }
        let newLog = store.log
        if newLog != log { log = newLog }
    }

    /// The lower of the two counts, so losing either one never refills a pass. Reads the vault
    /// itself, so spending never relies on the cached count.
    private var currentPassesLeft: Int {
        max(0, min(store.passesLeft, SharedStore.totalPasses - passes.used()))
    }

    func setRelockStrategy(_ strategy: RelockStrategy) {
        store.relockStrategy = strategy
        reload()
    }

    /// Starts a lock and shields the active mode's apps. Returns false when already locked (a schedule may
    /// have locked while a tag was being read).
    /// The lock state is written first: if Tapout dies before the shields go on, `syncShields` at the
    /// next launch puts them on.
    @discardableResult
    func lock() -> Bool {
        guard store.session == .unlocked else { return false }
        TimerLock.settleStale(store: store, now: now(), clock: clock())
        store.session = .locked(since: now())
        shields.apply(store.activeShieldPlan)
        record("Locked")
        return true
    }

    /// Starts a lock that ends by itself after `duration` (clamped to `TimerLock.minimum...maximum`) and shields
    /// the active mode's apps. The end is scheduled first: a scheduling failure throws and writes nothing, so a
    /// timer never locks without a way to end. In the simulator (`NoRelock`) `tick()` ends it.
    func lockTimed(duration: TimeInterval) throws -> TimerLock {
        guard store.session == .unlocked else { throw TimerError.alreadyLocked }
        let start = now()
        TimerLock.settleStale(store: store, now: start, clock: clock())
        let timer = TimerLock(start: start, duration: TimerLock.clamped(duration), anchor: clock())
        do {
            try timers.schedule(relockAt: timer.endsAt, now: start, strategy: store.relockStrategy)
        } catch {
            record("Timer schedule failed: \(error)")
            throw TimerError.couldNotSchedule(String(describing: error))
        }
        // A pending `finishedTimer` is kept: the app closes that timer's record at its own end.
        store.timerLock = timer
        store.session = .locked(since: start)
        shields.apply(store.activeShieldPlan)
        record("Timer lock, \(Int((timer.duration / 60).rounded())) min")
        return timer
    }

    /// Ends the timer when it is due (the exact end time: the app owns the clock). Cancels the timer's
    /// schedule and an open pass's relock, so the pass's relock can't lock again. When a mode's scheduled window
    /// is running, the lock carries on as that mode's scheduled lock (`TimerLock.finish`); Screen Time access is
    /// the app's last check. Returns what happened.
    @discardableResult
    func finishTimerIfDue() -> TimerLock.Finish? {
        guard let finish = TimerLock.finish(store: store, shields: shields, now: now(), early: 0,
                                            accessApproved: store.screenTimeApproved ?? true,
                                            hasApps: modeHasApps, calendar: calendar, clock: clock()) else { return nil }
        timers.cancel()
        relock.cancel()
        timerJustFinished = finish
        if let mode = finish.handedOverTo {
            record("Timer finished, handed over to \(mode.name)")
        } else {
            record("Timer finished")
        }
        return finish
    }

    /// The UI showed the "Time's up" moment.
    func acknowledgeTimerFinish() {
        timerJustFinished = nil
    }

    /// A crash inside `TimerLock.finish` or `unlock` can leave a timer behind an unlocked session. A due one
    /// moves to `finishedTimer` for the app to close; any other is dropped (`TimerLock.settleStale`).
    private func clearStaleTimer() {
        TimerLock.settleStale(store: store, now: now(), clock: clock())
    }

    /// Ends the lock and any open pass. Does nothing while unlocked.
    func unlock() {
        guard store.session != .unlocked else { return }
        // The relock is cancelled last: if Tapout dies before then, the monitor's relock is still
        // scheduled and finds an unlocked store, so it does nothing.
        shields.clear()
        // A running timer is ended here, so a late monitor finish of it must not bring back Time's up.
        if let timer = store.timerLock { store.lastClosedTimerStart = timer.start }
        // The unlock time goes first, so a monitor start landing between the two writes sees the unlock.
        store.lastUnlockAt = now()
        store.session = .unlocked
        relock.cancel()
        store.passAnchor = nil
        store.timerLock = nil
        timers.cancel()
        record("Unlocked")
    }

    /// Makes the shields match the lock state: back on at launch for a lock that survived a quit or
    /// restart, off when unlocked, and back on after Screen Time access returns. An open pass is
    /// paid for, so its apps are opened (finishing a `useEmergencyPass` that died after writing the
    /// session); one past its relock time is relocked now.
    func syncShields() {
        finishTimerIfDue()
        clearStaleTimer()
        let date = now()
        var cleared = false
        switch store.session {
        case .locked: shields.apply(store.activeShieldPlan)
        case .unlocked:
            shields.clear()
            cleared = true
        case .emergency:
            if relockIfDue(at: date) == nil {
                shields.clear()
                cleared = true
            }
        }
        // The monitor may have locked between the read above and the clear: re-assert what the store now says.
        if cleared, case .locked = store.session {
            shields.apply(store.activeShieldPlan)
            record("Shields re-applied: a lock landed during the sync")
        }
        rearmIfClockMoved(at: date)
        // Home reads the engine's copy, so it must not stay stale after a foreground sync.
        reload()
    }

    /// Relocks an open pass that is over (by the wall clock or real elapsed time). Returns seconds past the relock time.
    private func relockIfDue(at date: Date) -> TimeInterval? {
        let anchor = clock()
        guard EmergencyRelock.isDue(session: store.session, now: date, early: 0,
                                    realElapsed: EmergencyRelock.realElapsed(store: store, clock: anchor)),
              let late = EmergencyRelock.perform(store: store, shields: shields, now: date, clock: anchor) else { return nil }
        record("Relocked in app, \(Int(late))s after relock time")
        return late
    }

    /// The monitor's end callbacks are booked in wall-clock time. If the date, time or time zone moved, moves them
    /// to the real end, so a timer or pass still ends on time while Tapout is closed.
    private func rearmIfClockMoved(at date: Date) {
        let anchor = clock()
        if let timer = store.timerLock,
           let target = ClockRearm.target(wallEnd: timer.endsAt, realRemaining: timer.realRemaining(clock: anchor), now: date) {
            rearm("timer", target: target, date: date, with: timers)
        }
        if case .emergency(let relockAt, _) = store.session,
           let target = ClockRearm.target(wallEnd: relockAt,
                                          realRemaining: EmergencyRelock.realRemaining(store: store, clock: anchor), now: date) {
            rearm("pass", target: target, date: date, with: relock)
        }
    }

    private func rearm(_ what: String, target: Date, date: Date, with scheduler: any RelockScheduling) {
        if let previous = rearmedTo[what], abs(previous.timeIntervalSince(target)) <= ClockRearm.slack { return }
        do {
            try scheduler.schedule(relockAt: target, now: date, strategy: store.relockStrategy)
            rearmedTo[what] = target
            record("Clock changed: \(what) end moved to \(target.formatted(date: .omitted, time: .standard))")
        } catch {
            record("Clock changed: could not move the \(what) end: \(error)")
        }
    }

    /// Spends one pass and opens apps for five minutes; returns the relock time. The pass is only spent
    /// once the relock is scheduled, so a scheduling failure never leaves apps open for good.
    @discardableResult
    func useEmergencyPass() throws -> Date {
        guard case .locked = store.session else { throw PassError.notLocked }
        guard currentPassesLeft > 0 else { throw PassError.noPassesLeft }
        let start = now()
        let relockAt = start + Self.emergencyDuration
        let strategy = store.relockStrategy
        do {
            try relock.schedule(relockAt: relockAt, now: start, strategy: strategy)
        } catch {
            record("Relock schedule failed: \(error)")
            throw PassError.couldNotSchedule(String(describing: error))
        }
        let left = currentPassesLeft - 1
        // Keychain first: it is the copy that survives a reinstall, so after a crash between the
        // two writes it is the one that is current.
        let saved = passes.setUsed(SharedStore.totalPasses - left)
        store.passesLeft = left
        if !saved { record("Keychain write failed") }
        store.passAnchor = clock()
        rearmedTo["pass"] = nil
        // Session first: if the process dies before the shields drop, the monitor still sees an open pass
        // and re-shields at the relock time.
        store.session = .emergency(relockAt: relockAt, duration: Self.emergencyDuration)
        shields.clear()
        record("Emergency pass, relock at \(relockAt.formatted(date: .omitted, time: .standard)) via \(strategy.rawValue)")
        record("Scheduled: \(relock.scheduledSummary())")
        return relockAt
    }

    /// Ends an emergency pass early.
    func relockNow() {
        guard case .emergency = store.session else { return }
        // The relock is cancelled last: if Tapout dies before then, the monitor still relocks.
        shields.apply(store.activeShieldPlan)
        store.session = .locked(since: now())
        store.passAnchor = nil
        relock.cancel()
        record("Relocked early")
    }

    /// Call every second while Tapout is open. Ends a due timer (see `timerJustFinished`), relocks an expired
    /// pass if the monitor has not, and picks up anything the monitor changed. Returns true when it relocked.
    /// The monitor schedule is left running, so its callback still shows up in the log.
    @discardableResult
    func tick() -> Bool {
        finishTimerIfDue()
        clearStaleTimer()
        if relockIfDue(at: now()) != nil { return true }
        // A lock the monitor started (or a relock) is re-asserted once, in case a sync cleared its shields.
        if case .locked = store.session, session != store.session {
            shields.apply(store.activeShieldPlan)
        }
        refresh()
        return false
    }

    #if DEBUG
    func resetPasses() {
        store.passesLeft = SharedStore.totalPasses
        // The Keychain vault never goes down through `setUsed`, so a reset deletes its item.
        if let keychain = passes as? KeychainPassVault {
            keychain.delete()
        } else {
            passes.setUsed(0)
        }
        record("Passes reset")
    }

    func clearLog() {
        store.clearLog()
        reload()
    }
    #endif

    private func record(_ message: String) {
        store.appendLog(message, source: .app, at: now())
        reload()
    }
}
