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

    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60

    private(set) var session: LockSession = .unlocked
    private(set) var passesLeft = SharedStore.totalPasses
    private(set) var relockStrategy = RelockStrategy.warning
    private(set) var log: [LogEntry] = []

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let shields: any Shielding
    @ObservationIgnored private let relock: any RelockScheduling
    @ObservationIgnored private let passes: any PassCounting
    @ObservationIgnored private let now: () -> Date

    init(
        store: SharedStore,
        shields: any Shielding,
        relock: any RelockScheduling,
        passes: any PassCounting = MemoryPassVault(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.shields = shields
        self.relock = relock
        self.passes = passes
        self.now = now
        reload()
    }

    /// Screen Time on an iPhone; stand-ins in the simulator, where shields and DeviceActivity don't run.
    static func live(store: SharedStore = .appGroup()) -> LockEngine {
        #if targetEnvironment(simulator)
        LockEngine(store: store, shields: NoShields(), relock: NoRelock(), passes: KeychainPassVault())
        #else
        LockEngine(store: store, shields: ShieldController(), relock: RelockScheduler(), passes: KeychainPassVault())
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
        store.session = .locked(since: now())
        shields.apply(store.activeShieldPlan)
        record("Locked")
        return true
    }

    /// Ends the lock and any open pass. Does nothing while unlocked.
    func unlock() {
        guard store.session != .unlocked else { return }
        // The relock is cancelled last: if Tapout dies before then, the monitor's relock is still
        // scheduled and finds an unlocked store, so it does nothing.
        shields.clear()
        // The unlock time goes first, so a monitor start landing between the two writes sees the unlock.
        store.lastUnlockAt = now()
        store.session = .unlocked
        relock.cancel()
        record("Unlocked")
    }

    /// Makes the shields match the lock state: back on at launch for a lock that survived a quit or
    /// restart, off when unlocked, and back on after Screen Time access returns. An open pass is
    /// paid for, so its apps are opened (finishing a `useEmergencyPass` that died after writing the
    /// session); one past its relock time is relocked now.
    func syncShields() {
        let date = now()
        switch store.session {
        case .locked: shields.apply(store.activeShieldPlan)
        case .unlocked: shields.clear()
        case .emergency:
            if EmergencyRelock.isDue(session: store.session, now: date, early: 0),
               let late = EmergencyRelock.perform(store: store, shields: shields, now: date) {
                record("Relocked in app, \(Int(late))s after relock time")
            } else {
                shields.clear()
            }
        }
        // Home reads the engine's copy, so it must not stay stale after a foreground sync.
        reload()
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
        relock.cancel()
        record("Relocked early")
    }

    /// Call every second while Tapout is open. Relocks an expired pass if the monitor has not,
    /// and picks up anything the monitor changed. Returns true when it relocked.
    /// The monitor schedule is left running, so its callback still shows up in the log.
    @discardableResult
    func tick() -> Bool {
        let date = now()
        if EmergencyRelock.isDue(session: store.session, now: date, early: 0),
           let late = EmergencyRelock.perform(store: store, shields: shields, now: date) {
            record("Relocked in app, \(Int(late))s after relock time")
            return true
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
