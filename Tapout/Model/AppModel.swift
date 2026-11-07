import FamilyControls
import Foundation
import Observation

/// Modes, places, lock history and always-allowed apps, kept in the App Group store so the
/// monitor extension can run schedules in Phase 4. Lock state stays with the lock controller.
@MainActor
@Observable
final class AppModel {
    enum PairResult: Equatable {
        case paired
        case alreadyPaired(name: String)
    }

    /// The one mode a fresh install starts with.
    static let starterModeName = "Focus"

    private(set) var modes: [Mode] = []
    private(set) var activeModeID: UUID?
    private(set) var places: [PairedTag] = []
    private(set) var defaultPlaceID: TagUID?
    private(set) var history: [LockRecord] = []
    private(set) var alwaysAllowed = FamilyActivitySelection()
    private(set) var currentIntention: String?
    private(set) var interests: [Interest] = []
    private(set) var seenMilestones: Set<String> = []

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let now: () -> Date

    init(store: SharedStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        reload()
    }

    static func live() -> AppModel {
        AppModel(store: .appGroup())
    }

    /// Re-reads the store. Seeds the starter mode when there are none, so `activeMode` always exists.
    /// If the seed can't be written, the starter lives in memory until the next successful save.
    func reload() {
        if store.modes.isEmpty {
            let starter = Mode(name: Self.starterModeName)
            store.modes = [starter]
            store.activeModeID = starter.id
        }
        let stored = store.modes
        if stored.isEmpty {
            let starter = Mode(name: Self.starterModeName)
            modes = [starter]
            activeModeID = starter.id
        } else {
            modes = stored
            activeModeID = store.activeModeID
        }
        places = store.pairedTags
        defaultPlaceID = store.defaultPlace
        history = store.lockHistory
        alwaysAllowed = store.alwaysAllowed
        currentIntention = store.currentIntention
        interests = store.interests
        seenMilestones = Set(store.seenMilestones)
    }

    // MARK: Modes

    /// The chosen mode, or the first one if the chosen one is gone.
    var activeMode: Mode {
        modes.first { $0.id == activeModeID } ?? modes[0]
    }

    var otherModes: [Mode] {
        modes.filter { $0.id != activeMode.id }
    }

    /// A blank mode for the editor. It isn't stored until `save`.
    func newMode() -> Mode {
        Mode(name: "")
    }

    func isSaved(_ mode: Mode) -> Bool {
        modes.contains { $0.id == mode.id }
    }

    /// Adds the mode, or replaces the stored one with the same id.
    func save(_ mode: Mode) {
        var mode = mode
        mode.name = Self.cleaned(mode.name, fallback: "Mode")
        var all = store.modes
        if let index = all.firstIndex(where: { $0.id == mode.id }) {
            all[index] = mode
        } else {
            all.append(mode)
        }
        store.modes = all
        reload()
    }

    /// Refuses to delete the last mode. Deleting the active mode makes the first remaining one active.
    @discardableResult
    func deleteMode(id: UUID) -> Bool {
        var all = store.modes
        guard all.count > 1, all.contains(where: { $0.id == id }) else { return false }
        all.removeAll { $0.id == id }
        store.modes = all
        if store.activeModeID == id { store.activeModeID = all[0].id }
        reload()
        return true
    }

    func setActiveMode(_ id: UUID) {
        guard modes.contains(where: { $0.id == id }) else { return }
        store.activeModeID = id
        reload()
    }

    /// Names of the places that unlock `mode`, in pairing order. Empty means any place.
    func unlockPlaceNames(for mode: Mode) -> [String] {
        places.filter { mode.unlockPlaces.contains($0.uid) }.map(\.name)
    }

    func lockedThisWeek(_ mode: Mode, calendar: Calendar = .current) -> TimeInterval {
        LockStats.lockedTime(modeID: mode.id, weekOf: now(), in: history, calendar: calendar)
    }

    // MARK: Places

    /// The chosen default, or the first place if that one was removed.
    var defaultPlace: PairedTag? {
        places.first { $0.uid == defaultPlaceID } ?? places.first
    }

    var otherPlaces: [PairedTag] {
        places.filter { $0.uid != defaultPlace?.uid }
    }

    /// Only call while unlocked; the screens enforce that. The first place becomes the default.
    @discardableResult
    func pair(_ uid: TagUID, name: String) -> PairResult {
        if let existing = store.pairedTags.first(where: { $0.uid == uid }) {
            return .alreadyPaired(name: existing.name)
        }
        let fallback = "Place \(store.pairedTags.count + 1)"
        store.pairedTags.append(PairedTag(uid: uid, name: Self.cleaned(name, fallback: fallback), pairedAt: now()))
        if store.defaultPlace == nil { store.defaultPlace = uid }
        reload()
        return .paired
    }

    func renamePlace(_ uid: TagUID, to name: String) {
        let name = Self.cleaned(name, fallback: "")
        guard !name.isEmpty else { return }
        store.pairedTags = store.pairedTags.map { tag in
            var tag = tag
            if tag.uid == uid { tag.name = name }
            return tag
        }
        reload()
    }

    /// Forgets the place everywhere. Modes that unlocked only there unlock at any place.
    func removePlace(_ uid: TagUID) {
        store.pairedTags.removeAll { $0.uid == uid }
        store.modes = store.modes.map { mode in
            var mode = mode
            mode.unlockPlaces.remove(uid)
            return mode
        }
        if store.defaultPlace == uid { store.defaultPlace = store.pairedTags.first?.uid }
        reload()
    }

    func makeDefault(_ uid: TagUID) {
        guard places.contains(where: { $0.uid == uid }) else { return }
        store.defaultPlace = uid
        reload()
    }

    func lockCount(at uid: TagUID) -> Int {
        LockStats.lockCount(at: uid, in: history)
    }

    // MARK: Always allowed

    func updateAlwaysAllowed(_ selection: FamilyActivitySelection) {
        store.alwaysAllowed = selection
        reload()
    }

    // MARK: Locks

    enum TagCheck: Equatable {
        /// A paired tag that may lock now, or unlock the active mode.
        case accepted(PairedTag)
        case unknown
        /// Paired, but the active mode only unlocks at other places.
        case wrongPlace(PairedTag)
    }

    /// The longest intention kept: enough for "History essay, first paragraph".
    static let intentionLimit = 40

    /// Whether `uid` may lock (while unlocked) or unlock the active mode (while locked).
    func check(_ uid: TagUID, unlocking: Bool) -> TagCheck {
        guard let place = places.first(where: { $0.uid == uid }) else { return .unknown }
        let allowed = activeMode.unlockPlaces
        if unlocking, !allowed.isEmpty, !allowed.contains(uid) { return .wrongPlace(place) }
        return .accepted(place)
    }

    /// The places that can unlock the active mode, in pairing order. Every place when the mode doesn't say.
    var unlockPlacesForActiveMode: [PairedTag] {
        let allowed = activeMode.unlockPlaces
        return allowed.isEmpty ? places : places.filter { allowed.contains($0.uid) }
    }

    /// Drops locks left open by a crash: nobody knows how long they really ran, so they don't count.
    /// Lock state isn't persisted yet, so an open record at launch can only be a stale one.
    func discardInterruptedLocks() {
        guard store.lockHistory.contains(where: { $0.end == nil }) || store.currentIntention != nil else { return }
        store.lockHistory.removeAll { $0.end == nil }
        store.currentIntention = nil
        reload()
    }

    /// Records the start of a lock with the active mode. A blank intention counts as none.
    func startLock(placeUID: TagUID?, intention: String?) {
        discardInterruptedLocks()
        let trimmed = intention?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let intention = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.intentionLimit))
        var all = store.lockHistory
        all.append(LockRecord(start: now(), end: nil, placeUID: placeUID, modeID: activeMode.id, intention: intention))
        store.lockHistory = all
        store.currentIntention = intention
        reload()
    }

    /// Ends the running lock and returns it, or nil when none was running.
    @discardableResult
    func finishLock() -> LockRecord? {
        var all = store.lockHistory
        guard let index = all.lastIndex(where: { $0.end == nil }) else {
            if store.currentIntention != nil {
                store.currentIntention = nil
                reload()
            }
            return nil
        }
        all[index].end = now()
        store.lockHistory = all
        store.currentIntention = nil
        reload()
        return all[index]
    }

    /// Saves the answer to "Did you do it?" for the lock that started at `start`.
    func answerIntention(forLockStartedAt start: Date, done: Bool) {
        store.lockHistory = store.lockHistory.map { record in
            var record = record
            if record.start == start, record.intention != nil { record.intentionDone = done }
            return record
        }
        reload()
    }

    /// Up to three recent intentions, newest first, without repeats.
    var recentIntentions: [String] {
        var seen = Set<String>()
        return Array(history.reversed().compactMap(\.intention).filter { seen.insert($0).inserted }.prefix(3))
    }

    // MARK: Onboarding

    /// Saves onboarding's answers: the active (starter) mode gets the apps and schedule.
    func completeOnboarding(
        selection: FamilyActivitySelection,
        alwaysAllowed: FamilyActivitySelection,
        schedule: ModeSchedule?,
        interests: [Interest]
    ) {
        var mode = activeMode
        mode.selection = selection
        mode.schedule = schedule
        save(mode)
        store.alwaysAllowed = alwaysAllowed
        store.interests = interests
        reload()
    }

    // MARK: Insights

    /// Locked time since midnight, for Home's "phone-free today".
    func phoneFreeToday(calendar: Calendar = .current) -> TimeInterval {
        guard let today = calendar.dateInterval(of: .day, for: now()) else { return 0 }
        return Insights.lockedTime(in: today, history: history, now: now())
    }

    var totalLocked: TimeInterval {
        Insights.totalLocked(history: history, now: now())
    }

    /// The first milestone reached that hasn't been shown yet.
    func unseenMilestone(calendar: Calendar = .current) -> Milestone? {
        Milestone.reached(in: history, now: now(), calendar: calendar).first { !seenMilestones.contains($0.rawValue) }
    }

    func markSeen(_ milestone: Milestone) {
        store.seenMilestones = seenMilestones.union([milestone.rawValue]).sorted()
        reload()
    }

    private static func cleaned(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
