import Foundation
import Observation
import Testing
@testable import Tapout

private struct FailingVault: PassCounting {
    func used() -> Int { 0 }
    func setUsed(_ count: Int) -> Bool { false }
}

private final class CountingVault: PassCounting {
    private(set) var reads = 0
    private var count = 0
    func used() -> Int { reads += 1; return count }
    @discardableResult func setUsed(_ count: Int) -> Bool { self.count = count; return true }
}

private final class Flag: @unchecked Sendable { var set = false }

/// KVO on the store's session key. UserDefaults notifies synchronously on the writing thread.
private final class SessionWatcher: NSObject, @unchecked Sendable {
    private let store: SharedStore
    private let defaults: UserDefaults
    private(set) var unlockAtWhenUnlocked: Date?

    init(store: SharedStore, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
        super.init()
        defaults.addObserver(self, forKeyPath: "session", options: [], context: nil)
    }

    deinit { defaults.removeObserver(self, forKeyPath: "session") }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        if store.session == .unlocked { unlockAtWhenUnlocked = store.lastUnlockAt }
    }
}

@MainActor
struct LockEngineTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let relock = FakeRelock()
    private let vault = MemoryPassVault()

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, passes: vault, now: { [clock] in clock.now })
    }

    private func lockedEngine() -> LockEngine {
        let engine = makeEngine()
        engine.lock()
        return engine
    }

    @Test func theKeychainCountWinsWhenTheStoreForgets() {
        vault.setUsed(2)
        #expect(makeEngine().passesLeft == 3)
    }

    @Test func theStoreCountWinsWhenTheKeychainForgets() {
        store.passesLeft = 1
        #expect(makeEngine().passesLeft == 1)
    }

    @Test func spendingAPassWritesBoth() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(store.passesLeft == 4)
        #expect(vault.used() == 1)
    }

    @Test func noPassWhenTheKeychainSaysAllAreSpent() {
        vault.setUsed(5)
        let engine = lockedEngine()
        #expect(throws: LockEngine.PassError.noPassesLeft) { try engine.useEmergencyPass() }
    }

    @Test func spendingCountsFromTheLowerCopy() throws {
        vault.setUsed(3)
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(store.passesLeft == 1)
        #expect(vault.used() == 4)
    }

    @Test func aFailedKeychainWriteIsLoggedButStillSpends() throws {
        let failing = FailingVault()
        let engine = LockEngine(store: store, shields: shields, relock: relock, passes: failing, now: { [clock] in clock.now })
        engine.lock()
        try engine.useEmergencyPass()
        #expect(engine.log.map(\.message).contains("Keychain write failed"))
        #expect(store.passesLeft == 4)
    }

    @Test func aFailedScheduleWritesNeither() {
        let engine = lockedEngine()
        relock.failure = FakeError()
        _ = try? engine.useEmergencyPass()
        #expect(store.passesLeft == 5)
        #expect(vault.used() == 0)
    }

    @Test func freshEngineIsUnlockedWithFivePasses() {
        let engine = makeEngine()
        #expect(engine.session == .unlocked)
        #expect(engine.passesLeft == 5)
    }

    @Test func lockShieldsTheActivePlanAndStartsTheLock() {
        let engine = lockedEngine()
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.plans == [store.activeShieldPlan])
    }

    @Test func lockingAgainChangesNothing() {
        let engine = lockedEngine()
        let since = clock.now
        clock.now += 60
        engine.lock()
        #expect(engine.session == .locked(since: since))
        #expect(shields.applied == 1)
    }

    @Test func unlockClearsEverything() {
        let engine = lockedEngine()
        engine.unlock()
        #expect(engine.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(relock.cancelled == 1)
    }

    @Test func unlockingWhileUnlockedChangesNothing() {
        makeEngine().unlock()
        #expect(shields.cleared == 0)
        #expect(relock.cancelled == 0)
    }

    @Test func emergencyPassSpendsOneOpensAppsAndSchedulesRelock() throws {
        let engine = lockedEngine()
        let relockAt = try engine.useEmergencyPass()
        #expect(relockAt == clock.now + 300)
        #expect(engine.passesLeft == 4)
        #expect(shields.cleared == 1)
        #expect(engine.session == .emergency(relockAt: clock.now + 300, duration: 300))
        #expect(relock.scheduled == [.init(relockAt: clock.now + 300, now: clock.now, strategy: .warning)])
    }

    @Test func emergencyPassLogsWhatWasScheduled() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(engine.log.last?.message == "Scheduled: fake schedule")
    }

    @Test func passUsesTheChosenStrategy() throws {
        let engine = lockedEngine()
        engine.setRelockStrategy(.pastStart)
        try engine.useEmergencyPass()
        #expect(relock.scheduled.first?.strategy == .pastStart)
    }

    @Test func failedScheduleKeepsThePassAndTheLock() {
        let engine = lockedEngine()
        relock.failure = FakeError()
        #expect(throws: LockEngine.PassError.self) { try engine.useEmergencyPass() }
        #expect(engine.passesLeft == 5)
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.cleared == 0)
    }

    @Test func noPassesLeftIsRefused() {
        store.passesLeft = 0
        let engine = lockedEngine()
        #expect(throws: LockEngine.PassError.noPassesLeft) { try engine.useEmergencyPass() }
    }

    @Test func passNeedsALock() {
        let engine = makeEngine()
        #expect(throws: LockEngine.PassError.notLocked) { try engine.useEmergencyPass() }
    }

    @Test func relockNowEndsThePassEarly() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        clock.now += 60
        engine.relockNow()
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.applied == 2)
        #expect(relock.cancelled == 1)
    }

    @Test func tickRelocksAnExpiredPass() throws {
        let engine = lockedEngine()
        let start = clock.now
        try engine.useEmergencyPass()
        clock.now = start + 299
        #expect(!engine.tick())
        clock.now = start + 300
        #expect(engine.tick())
        #expect(engine.session == .locked(since: start + 300))
        #expect(shields.applied == 2)
        // The monitor schedule stays running, so its callback still shows up in the log.
        #expect(relock.cancelled == 0)
    }

    @Test func tickDoesNotReadTheVault() {
        let counting = CountingVault()
        let engine = LockEngine(store: store, shields: shields, relock: relock, passes: counting, now: { [clock] in clock.now })
        engine.lock()
        let before = counting.reads
        for _ in 0..<10 { engine.tick() }
        #expect(counting.reads == before)
    }

    /// After a pass, only the vault holds the lower count. `tick()` must still show one pass spent,
    /// which it can only do if `useEmergencyPass` refreshed the engine's cached vault count.
    @Test func cachedVaultCountIsRefreshedByAPass() throws {
        let counting = CountingVault()
        let engine = LockEngine(store: store, shields: shields, relock: relock, passes: counting, now: { [clock] in clock.now })
        engine.lock()
        try engine.useEmergencyPass()
        store.passesLeft = SharedStore.totalPasses
        engine.tick()
        #expect(engine.passesLeft == SharedStore.totalPasses - 1)
    }

    @Test func quietTickChangesNothingObservable() throws {
        let engine = lockedEngine()
        let changed = Flag()
        func track() {
            withObservationTracking {
                _ = engine.session
                _ = engine.passesLeft
                _ = engine.relockStrategy
                _ = engine.log
            } onChange: { changed.set = true }
        }
        track()
        engine.tick()
        #expect(!changed.set)
        store.session = .unlocked
        engine.tick()
        #expect(changed.set)
    }

    @Test func tickPicksUpARelockMadeByTheMonitor() throws {
        let engine = lockedEngine()
        let relockAt = clock.now + 300
        try engine.useEmergencyPass()
        _ = EmergencyRelock.perform(store: store, shields: FakeShields(), now: relockAt)
        #expect(!engine.tick())
        #expect(engine.session == .locked(since: relockAt))
    }

    @Test func unlockingDuringAPassCancelsTheRelock() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        engine.unlock()
        #expect(engine.session == .unlocked)
        #expect(relock.cancelled == 1)
    }

    @Test func syncShieldsPutsASurvivingLockBack() {
        store.session = .locked(since: clock.now)
        makeEngine().syncShields()
        #expect(shields.plans == [store.activeShieldPlan])
    }

    @Test func syncShieldsClearsWhenUnlocked() {
        makeEngine().syncShields()
        #expect(shields.cleared == 1)
    }

    @Test func syncShieldsOpensAPaidPass() {
        store.session = .emergency(relockAt: clock.now + 100, duration: 300)
        makeEngine().syncShields()
        #expect(shields.cleared == 1)
        #expect(shields.applied == 0)
    }

    @Test func syncShieldsRelocksAnExpiredPass() {
        let relockAt = clock.now - 10
        store.session = .emergency(relockAt: relockAt, duration: 300)
        makeEngine().syncShields()
        #expect(store.session == .locked(since: relockAt))
        #expect(shields.applied == 1)
    }

    @Test func lockWritesTheLockBeforeShielding() {
        var seen: LockSession?
        shields.onApply = { [store] in seen = store.session }
        makeEngine().lock()
        #expect(seen == .locked(since: clock.now))
    }

    @Test func unlockCancelsTheRelockLast() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        var seen: LockSession?
        relock.onCancel = { [store] in seen = store.session }
        engine.unlock()
        #expect(seen == .unlocked)
    }

    @Test func relockNowCancelsTheRelockLast() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        clock.now += 60
        var seen: LockSession?
        relock.onCancel = { [store] in seen = store.session }
        engine.relockNow()
        #expect(seen == .locked(since: clock.now))
    }

    @Test func stateSurvivesANewEngine() {
        _ = lockedEngine()
        #expect(makeEngine().session == .locked(since: clock.now))
    }

    @Test func actionsAreLogged() {
        let engine = lockedEngine()
        engine.unlock()
        #expect(engine.log.map(\.message) == ["Locked", "Unlocked"])
    }

    @Test func unlockRecordsWhen() {
        let engine = lockedEngine()
        clock.now += 60
        engine.unlock()
        #expect(store.lastUnlockAt == clock.now)
    }

    /// Watches the session key and notes what `lastUnlockAt` held the moment the session became unlocked.
    /// With the old order (session first) it is nil there, so the test fails.
    @Test func unlockWritesLastUnlockBeforeTheSession() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let watched = SharedStore(defaults: defaults)
        let watcher = SessionWatcher(store: watched, defaults: defaults)
        let engine = LockEngine(store: watched, shields: shields, relock: relock, passes: vault, now: { [clock] in clock.now })
        engine.lock()
        clock.now += 60
        engine.unlock()
        #expect(watcher.unlockAtWhenUnlocked == clock.now)
        withExtendedLifetime(watcher) {}
    }

    @Test func lockSaysWhetherItLocked() {
        let engine = makeEngine()
        #expect(engine.lock())
        #expect(!engine.lock())
    }
}

/// Timer locks: started without a tag, ended by the clock.
@MainActor
struct LockEngineTimerTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let relock = FakeRelock()
    private let timers = FakeRelock()

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, passes: MemoryPassVault(),
                   timers: timers, now: { [clock] in clock.now })
    }

    @Test func lockTimedLocksStoresTheTimerAndSchedulesItsEnd() throws {
        store.relockStrategy = .pastStart
        let engine = makeEngine()
        let timer = try engine.lockTimed(duration: 45 * 60)
        #expect(timer == TimerLock(start: clock.now, duration: 45 * 60))
        #expect(store.timerLock == timer)
        #expect(store.session == .locked(since: clock.now))
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.applied == 1)
        #expect(timers.scheduled == [FakeRelock.Call(relockAt: timer.endsAt, now: clock.now, strategy: .pastStart)])
        #expect(relock.scheduled.isEmpty)
        #expect(engine.log.last?.message == "Timer lock, 45 min")
    }

    @Test func lockTimedClampsTheDuration() throws {
        let engine = makeEngine()
        #expect(try engine.lockTimed(duration: 60).duration == TimerLock.minimum)
    }

    @Test func lockTimedKeepsAPendingFinishedMarker() throws {
        // The earlier timer's record is closed at its own end by the app, not dropped.
        let earlier = TimerLock(start: clock.now - 7200, duration: 3600)
        store.finishedTimer = earlier
        _ = try makeEngine().lockTimed(duration: 30 * 60)
        #expect(store.finishedTimer == earlier)
    }

    @Test func lockTimedRefusesWhileLockedAndWritesNothing() {
        let engine = makeEngine()
        engine.lock()
        #expect(throws: LockEngine.TimerError.alreadyLocked) { try engine.lockTimed(duration: 30 * 60) }
        #expect(store.timerLock == nil)
        #expect(timers.scheduled.isEmpty)
        #expect(shields.applied == 1)
    }

    @Test func aSchedulingFailureLeavesTheEngineUnlockedWithNoTimer() {
        timers.failure = FakeError()
        let engine = makeEngine()
        #expect(throws: LockEngine.TimerError.couldNotSchedule(String(describing: FakeError()))) {
            try engine.lockTimed(duration: 30 * 60)
        }
        #expect(store.session == .unlocked)
        #expect(store.timerLock == nil)
        #expect(shields.applied == 0)
    }

    @Test func unlockClearsTheTimerAndCancelsItsSchedule() throws {
        let engine = makeEngine()
        _ = try engine.lockTimed(duration: 30 * 60)
        engine.unlock()
        #expect(store.timerLock == nil)
        #expect(timers.cancelled == 1)
        #expect(store.session == .unlocked)
    }

    @Test func tickWaitsForTheExactEnd() throws {
        let engine = makeEngine()
        let timer = try engine.lockTimed(duration: 30 * 60)
        clock.now = timer.endsAt - 1
        #expect(!engine.tick())
        #expect(store.session == .locked(since: timer.start))
        #expect(store.timerLock == timer)
        #expect(engine.timerJustFinished == nil)
        #expect(shields.cleared == 0)
    }

    @Test func tickAtTheEndFinishesTheTimer() throws {
        let engine = makeEngine()
        let timer = try engine.lockTimed(duration: 30 * 60)
        clock.now = timer.endsAt
        #expect(!engine.tick())
        #expect(store.session == .unlocked)
        #expect(engine.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == timer)
        #expect(store.lastUnlockAt == timer.endsAt)
        #expect(engine.timerJustFinished?.timer == timer)
        #expect(timers.cancelled == 1)
        #expect(engine.log.contains { $0.message == "Timer finished" })
        engine.acknowledgeTimerFinish()
        #expect(engine.timerJustFinished == nil)
        #expect(store.finishedTimer == timer)
    }

    @Test func aTimerEndingDuringAPassLeavesAppsOpen() throws {
        let engine = makeEngine()
        let timer = try engine.lockTimed(duration: 30 * 60)
        clock.now = timer.endsAt - 120
        try engine.useEmergencyPass()
        let applied = shields.applied
        clock.now = timer.endsAt
        #expect(!engine.tick())
        #expect(store.session == .unlocked)
        #expect(shields.applied == applied)
        #expect(relock.cancelled == 1)
        #expect(engine.timerJustFinished?.timer == timer)
        // The pass's relock time passes later: nothing locks again.
        clock.now = timer.endsAt + 600
        #expect(!engine.tick())
        #expect(store.session == .unlocked)
        #expect(shields.applied == applied)
    }

    @Test func syncShieldsAfterARestartPastTheEndFinishesInsteadOfShielding() throws {
        let timer = try makeEngine().lockTimed(duration: 30 * 60)
        let applied = shields.applied
        clock.now = timer.endsAt + 3600
        let engine = makeEngine()
        engine.syncShields()
        #expect(shields.applied == applied)
        #expect(store.session == .unlocked)
        #expect(store.finishedTimer == timer)
        #expect(engine.timerJustFinished?.timer == timer)
    }

    @Test func aStaleTimerWhileUnlockedIsClearedByBothSyncAndTick() {
        let stale = TimerLock(start: clock.now - 3600, duration: 1800)
        store.timerLock = stale
        store.finishedTimer = stale
        let engine = makeEngine()
        engine.syncShields()
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == stale)
        #expect(engine.timerJustFinished == nil)
        store.timerLock = stale
        engine.tick()
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == stale)
    }

    @Test func aStaleDueTimerWithNoMarkerMovesToFinished() {
        // A crash inside the finish step after the session was unlocked: the timer's record must still close.
        let stale = TimerLock(start: clock.now - 3600, duration: 1800)
        store.timerLock = stale
        let engine = makeEngine()
        engine.syncShields()
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == stale)
    }

    @Test func aStaleTimerThatIsNotDueIsDropped() {
        let stale = TimerLock(start: clock.now - 600, duration: 1800)
        store.timerLock = stale
        makeEngine().tick()
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == nil)
    }

    @Test func aStaleTimerTheAppAlreadyClosedIsDropped() {
        let stale = TimerLock(start: clock.now - 3600, duration: 1800)
        store.timerLock = stale
        store.lastClosedTimerStart = stale.start
        makeEngine().tick()
        #expect(store.timerLock == nil)
        #expect(store.finishedTimer == nil)
    }

    @Test func aTagLockClearsAStaleTimerSoItIsNeverEndedAsTheTimer() {
        let stale = TimerLock(start: clock.now - 600, duration: 1800)
        store.timerLock = stale
        let engine = makeEngine()
        let lockedAt = clock.now
        #expect(engine.lock())
        #expect(store.timerLock == nil)
        clock.now = stale.endsAt + 60
        engine.tick()
        #expect(store.session == .locked(since: lockedAt))
        #expect(store.finishedTimer == nil)
    }

    @Test func unlockMarksTheTimerAsClosed() throws {
        let engine = makeEngine()
        let timer = try engine.lockTimed(duration: 30 * 60)
        engine.unlock()
        #expect(store.lastClosedTimerStart == timer.start)
    }

    @Test func anOrdinaryLockIsUntouched() {
        let engine = makeEngine()
        engine.lock()
        clock.now += 13 * 3600
        #expect(!engine.tick())
        engine.syncShields()
        #expect(store.session == .locked(since: clock.now - 13 * 3600))
        #expect(shields.cleared == 0)
        #expect(engine.timerJustFinished == nil)
        #expect(store.finishedTimer == nil)
        #expect(timers.scheduled.isEmpty)
    }
}
