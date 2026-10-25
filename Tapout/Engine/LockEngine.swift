import FamilyControls
import Foundation
import Observation

/// The real lock: paired tags, shields, emergency passes and relock. Everything is kept in the
/// App Group store, so the monitor extension can relock while Tapout is closed.
/// Replaces `MockLockController` in Phase 4.
@MainActor
@Observable
final class LockEngine {
    enum TagOutcome: Equatable {
        case locked, unlocked, rejected
    }

    enum PassError: Error, Equatable {
        case notLocked, noPassesLeft
        case couldNotSchedule(String)
    }

    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60

    private(set) var session: LockSession = .unlocked
    private(set) var passesLeft = SharedStore.totalPasses
    private(set) var pairedTags: [PairedTag] = []
    private(set) var selection = FamilyActivitySelection()
    private(set) var relockStrategy = RelockStrategy.warning
    private(set) var log: [LogEntry] = []

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let shields: any Shielding
    @ObservationIgnored private let relock: any RelockScheduling
    @ObservationIgnored private let now: () -> Date

    init(
        store: SharedStore,
        shields: any Shielding,
        relock: any RelockScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.shields = shields
        self.relock = relock
        self.now = now
        reload()
    }

    static func live() -> LockEngine {
        LockEngine(store: .appGroup(), shields: ShieldController(), relock: RelockScheduler())
    }

    /// Re-reads the store. The monitor extension may have relocked while Tapout was in the background.
    func reload() {
        session = store.session
        passesLeft = store.passesLeft
        pairedTags = store.pairedTags
        selection = store.selection
        relockStrategy = store.relockStrategy
        log = store.log
    }

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        store.selection = newSelection
        if case .locked = store.session { shields.apply(newSelection) }
        record("Apps: \(newSelection.applicationTokens.count), categories: \(newSelection.categoryTokens.count)")
    }

    func setRelockStrategy(_ strategy: RelockStrategy) {
        store.relockStrategy = strategy
        reload()
    }

    /// Returns false when the tag is already paired.
    @discardableResult
    func pair(_ uid: TagUID, name: String) -> Bool {
        guard !store.pairedTags.contains(where: { $0.uid == uid }) else { return false }
        store.pairedTags.append(PairedTag(uid: uid, name: name, pairedAt: now()))
        record("Paired \(name) (\(uid.display))")
        return true
    }

    func unpair(_ tag: PairedTag) {
        store.pairedTags.removeAll { $0.uid == tag.uid }
        record("Unpaired \(tag.name)")
    }

    /// A tag was read: an unknown tag changes nothing; a paired one locks, or unlocks everything.
    func handleTag(_ uid: TagUID) -> TagOutcome {
        guard let tag = store.pairedTags.first(where: { $0.uid == uid }) else {
            record("Rejected unknown tag \(uid.display)")
            return .rejected
        }
        switch store.session {
        case .unlocked:
            shields.apply(store.selection)
            store.session = .locked(since: now())
            record("Locked with \(tag.name)")
            return .locked
        case .locked, .emergency:
            relock.cancel()
            shields.clear()
            store.session = .unlocked
            record("Unlocked with \(tag.name)")
            return .unlocked
        }
    }

    /// Spends one pass and opens apps for five minutes. The pass is only spent once the
    /// relock is scheduled, so a scheduling failure never leaves apps open for good.
    func useEmergencyPass() throws {
        guard case .locked = store.session else { throw PassError.notLocked }
        guard store.passesLeft > 0 else { throw PassError.noPassesLeft }
        let start = now()
        let relockAt = start + Self.emergencyDuration
        let strategy = store.relockStrategy
        do {
            try relock.schedule(relockAt: relockAt, now: start, strategy: strategy)
        } catch {
            record("Relock schedule failed: \(error)")
            throw PassError.couldNotSchedule(String(describing: error))
        }
        store.passesLeft -= 1
        // Session first: if the process dies before the shields drop, the monitor still sees an open pass
        // and re-shields at the relock time.
        store.session = .emergency(relockAt: relockAt, duration: Self.emergencyDuration)
        shields.clear()
        record("Emergency pass, relock at \(relockAt.formatted(date: .omitted, time: .standard)) via \(strategy.rawValue)")
        record("Scheduled: \(relock.scheduledSummary())")
    }

    func relockNow() {
        guard case .emergency = store.session else { return }
        relock.cancel()
        shields.apply(store.selection)
        store.session = .locked(since: now())
        record("Relocked early")
    }

    /// Call every second while Tapout is open. Relocks an expired pass if the monitor has not,
    /// and picks up anything the monitor changed. Returns true when it relocked.
    /// The monitor schedule is left running, so its callback still shows up in the log.
    @discardableResult
    func tick() -> Bool {
        let date = now()
        if case .emergency(let relockAt, _) = store.session, date >= relockAt,
           let late = EmergencyRelock.perform(store: store, shields: shields, now: date) {
            record("Relocked in app, \(Int(late))s after relock time")
            return true
        }
        reload()
        return false
    }

    #if DEBUG
    func resetPasses() {
        store.passesLeft = SharedStore.totalPasses
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
