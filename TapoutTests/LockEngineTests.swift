import Foundation
import Testing
@testable import Tapout

private struct FailingVault: PassCounting {
    func used() -> Int { 0 }
    func setUsed(_ count: Int) -> Bool { false }
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
}
