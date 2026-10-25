import FamilyControls
import Foundation
import Testing
@testable import Tapout

@MainActor
struct LockEngineTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let relock = FakeRelock()
    private let tag = TagUID(hex: "04A20F1B")

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, now: { [clock] in clock.now })
    }

    private func lockedEngine() -> LockEngine {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        _ = engine.handleTag(tag)
        return engine
    }

    @Test func freshEngineIsUnlockedWithFivePasses() {
        let engine = makeEngine()
        #expect(engine.session == .unlocked)
        #expect(engine.passesLeft == 5)
    }

    @Test func pairingTheSameTagTwiceIsRefused() {
        let engine = makeEngine()
        #expect(engine.pair(tag, name: "Desk"))
        #expect(!engine.pair(tag, name: "Desk again"))
        #expect(engine.pairedTags.count == 1)
    }

    @Test func unknownTagIsRejectedAndChangesNothing() {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        #expect(engine.handleTag(TagUID(hex: "FFFF")) == .rejected)
        #expect(engine.session == .unlocked)
        #expect(shields.applied == 0)
    }

    @Test func pairedTagLocksAndShields() {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        #expect(engine.handleTag(tag) == .locked)
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.applied == 1)
    }

    @Test func pairedTagUnlocksAndClearsEverything() {
        let engine = lockedEngine()
        #expect(engine.handleTag(tag) == .unlocked)
        #expect(engine.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(relock.cancelled == 1)
    }

    @Test func emergencyPassSpendsOneOpensAppsAndSchedulesRelock() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
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

    @Test func tagDuringAPassUnlocks() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(engine.handleTag(tag) == .unlocked)
        #expect(relock.cancelled == 1)
    }

    @Test func changingAppsWhileLockedReshields() {
        let engine = lockedEngine()
        engine.updateSelection(FamilyActivitySelection())
        #expect(shields.applied == 2)
    }

    @Test func stateSurvivesANewEngine() {
        _ = lockedEngine()
        let second = makeEngine()
        #expect(second.session == .locked(since: clock.now))
        #expect(second.pairedTags.count == 1)
    }

    @Test func actionsAreLogged() {
        let engine = lockedEngine()
        #expect(engine.log.map(\.message) == ["Paired Desk (04:A2:0F:1B)", "Locked with Desk"])
    }
}
