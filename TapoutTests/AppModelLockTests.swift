import FamilyControls
import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelLockTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let kitchen = TagUID(hex: "04AA01")
    private let desk = TagUID(hex: "04AA02")

    private func makeModel() -> AppModel {
        AppModel(store: store, now: { [clock] in clock.now })
    }

    /// A model with Kitchen and Desk paired.
    private func pairedModel() -> AppModel {
        let model = makeModel()
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        return model
    }

    @Test func startLockRecordsTheActiveModePlaceAndIntention() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "  History essay  ")
        let record = try #require(model.history.last)
        #expect(record.start == clock.now)
        #expect(record.end == nil)
        #expect(record.placeUID == kitchen)
        #expect(record.modeID == model.activeMode.id)
        #expect(record.intention == "History essay")
        #expect(model.currentIntention == "History essay")
    }

    @Test func blankIntentionIsNone() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "   ")
        #expect(model.history.last?.intention == nil)
        #expect(model.currentIntention == nil)
    }

    @Test func longIntentionIsCut() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: String(repeating: "a", count: 50))
        #expect(model.history.last?.intention?.count == AppModel.intentionLimit)
    }

    @Test func finishLockEndsTheRunningLockAndClearsTheIntention() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 1500
        let finished = model.finishLock()
        #expect(finished?.end == clock.now)
        #expect(finished?.intention == "Essay")
        #expect(model.history.last?.end == clock.now)
        #expect(model.currentIntention == nil)
    }

    @Test func finishLockWithNothingRunningReturnsNil() {
        #expect(makeModel().finishLock() == nil)
    }

    @Test func finishLockClearsAStaleIntention() {
        store.currentIntention = "Essay"
        let model = makeModel()
        #expect(model.currentIntention == "Essay")
        #expect(model.finishLock() == nil)
        #expect(model.currentIntention == nil)
        #expect(store.currentIntention == nil)
    }

    /// A pass opens apps for a while, but the lock is still the same lock.
    @Test func aPassAndARelockKeepTheOriginalRecord() throws {
        let model = pairedModel()
        let controller = LockEngine(store: store, shields: NoShields(), relock: NoRelock(), now: { [clock] in clock.now })
        let start = clock.now
        controller.lock()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 600
        try controller.useEmergencyPass()
        clock.now += LockEngine.emergencyDuration
        controller.tick()
        #expect(controller.session == .locked(since: clock.now))
        clock.now += 600
        controller.unlock()
        let finished = try #require(model.finishLock())
        #expect(finished.start == start)
        #expect(finished.intention == "Essay")
        #expect(finished.end == clock.now)
        #expect(model.history.count == 1)
    }

    @Test func startingALockDiscardsAnInterruptedOne() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 900
        model.startLock(placeUID: desk, intention: nil)
        let open = model.history.filter { $0.end == nil }
        #expect(open.count == 1)
        #expect(open.first?.start == clock.now)
        #expect(open.first?.placeUID == desk)
    }

    @Test func discardingInterruptedLocksKeepsFinishedOnes() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 600
        model.finishLock()
        clock.now += 600
        model.startLock(placeUID: desk, intention: "Reading")
        model.discardInterruptedLocks()
        #expect(model.history.count == 1)
        #expect(model.history.first?.intention == "Essay")
        #expect(model.currentIntention == nil)
    }

    @Test func answerIntentionSavesTheAnswer() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 600
        let finished = try #require(model.finishLock())
        model.answerIntention(forLockStartedAt: finished.start, done: true)
        #expect(model.history.last?.intentionDone == true)
    }

    @Test func answerIgnoresALockWithoutAnIntention() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        clock.now += 600
        let finished = try #require(model.finishLock())
        model.answerIntention(forLockStartedAt: finished.start, done: true)
        #expect(model.history.last?.intentionDone == nil)
    }

    @Test func recentIntentionsAreNewestFirstWithoutRepeats() {
        let model = pairedModel()
        for intention in ["A", "B", "A", "C", "D"] {
            model.startLock(placeUID: kitchen, intention: intention)
            clock.now += 60
            model.finishLock()
            clock.now += 60
        }
        #expect(model.recentIntentions == ["D", "C", "A"])
    }

    @Test func unknownTagIsUnknown() {
        #expect(pairedModel().check(TagUID(hex: "FF"), unlocking: false) == .unknown)
    }

    @Test func anyPairedTagLocks() {
        let model = pairedModel()
        var mode = model.activeMode
        mode.unlockPlaces = [kitchen]
        model.save(mode)
        #expect(model.check(desk, unlocking: false) == .accepted(model.places[1]))
    }

    @Test func unlockNeedsOneOfTheModesPlaces() {
        let model = pairedModel()
        var mode = model.activeMode
        mode.unlockPlaces = [kitchen]
        model.save(mode)
        #expect(model.check(desk, unlocking: true) == .wrongPlace(model.places[1]))
        #expect(model.check(kitchen, unlocking: true) == .accepted(model.places[0]))
        #expect(model.unlockPlacesForActiveMode.map(\.name) == ["Kitchen"])
    }

    @Test func modeWithoutPlacesUnlocksAnywhere() {
        let model = pairedModel()
        #expect(model.check(desk, unlocking: true) == .accepted(model.places[1]))
        #expect(model.unlockPlacesForActiveMode.map(\.name) == ["Kitchen", "Desk"])
    }

    @Test func completeOnboardingFillsTheStarterMode() {
        let model = makeModel()
        let schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)
        model.completeOnboarding(
            selection: FamilyActivitySelection(),
            alwaysAllowed: FamilyActivitySelection(),
            schedule: schedule,
            interests: [.sports, .music]
        )
        #expect(model.modes.count == 1)
        #expect(model.activeMode.name == AppModel.starterModeName)
        #expect(model.activeMode.schedule == schedule)
        #expect(model.interests == [.sports, .music])
        #expect(store.interests == [.sports, .music])
    }

    @Test func aPassIsNotedInTheRunningLock() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        let start = clock.now
        clock.now += 600
        model.startPass(until: clock.now + 300)
        #expect(try #require(model.history.last).passes == [DateInterval(start: start + 600, duration: 300)])
    }

    @Test func relockingEarlyEndsThePass() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        let passStart = clock.now
        model.startPass(until: passStart + 300)
        clock.now += 60
        model.endPass()
        #expect(try #require(model.history.last).passes == [DateInterval(start: passStart, duration: 60)])
    }

    @Test func unlockingDuringAPassEndsIt() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        model.startPass(until: clock.now + 300)
        clock.now += 100
        let record = try #require(model.finishLock())
        #expect(record.passes.first?.duration == 100)
        #expect(record.end == clock.now)
    }

    @Test func runningLockTimeLeavesOutThePass() {
        let model = pairedModel()
        #expect(model.runningLockTime(at: clock.now) == nil)
        model.startLock(placeUID: kitchen, intention: nil)
        clock.now += 600
        model.startPass(until: clock.now + 300)
        clock.now += 900
        #expect(model.runningLockTime(at: clock.now) == 1200)
    }

    @Test func reconcileWhileUnlockedDropsAnOpenRecord() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        model.reconcile(with: .unlocked)
        #expect(model.history.isEmpty)
        #expect(model.currentIntention == nil)
    }

    @Test func reconcileAddsARecordForALockWithoutOne() {
        let model = pairedModel()
        let since = clock.now - 600
        model.reconcile(with: .locked(since: since))
        #expect(model.history == [LockRecord(start: since, end: nil, placeUID: nil, modeID: model.activeMode.id)])
    }

    @Test func reconcileAddsTheOpenPassToo() throws {
        let model = pairedModel()
        let relockAt = clock.now + 200
        model.reconcile(with: .emergency(relockAt: relockAt, duration: 300))
        let record = try #require(model.history.last)
        #expect(record.start == relockAt - 300)
        #expect(record.passes == [DateInterval(start: relockAt - 300, end: relockAt)])
    }

    @Test func reconcileKeepsARunningRecord() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        model.reconcile(with: .locked(since: clock.now - 9999))
        #expect(model.history.count == 1)
        #expect(model.history.first?.start == clock.now)
    }

    @Test func aNewPassEndsAnOpenOneFirst() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        let first = clock.now
        model.startPass(until: clock.now + 300)
        clock.now += 60
        let second = clock.now
        model.startPass(until: clock.now + 300)
        let passes = try #require(model.history.last).passes
        #expect(passes == [DateInterval(start: first, end: second), DateInterval(start: second, end: second + 300)])
        #expect(passes[0].end <= passes[1].start)
    }

    @Test func reconcileAddsAPassTheAppMissed() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        clock.now += 600
        model.reconcile(with: .emergency(relockAt: clock.now + 300, duration: 300))
        #expect(model.history.count == 1)
        #expect(try #require(model.history.last).passes == [DateInterval(start: clock.now, end: clock.now + 300)])
    }

    @Test func reconcileEndsAPassRelockedEarly() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        model.startPass(until: clock.now + 300)
        clock.now += 60
        model.reconcile(with: .locked(since: clock.now))
        #expect(try #require(model.history.last).passes.first?.duration == 60)
    }

    @Test func reconcileKeepsOnlyTheNewestOpenRecord() {
        let model = pairedModel()
        let older = LockRecord(start: clock.now - 1000, end: nil, placeUID: nil, modeID: model.activeMode.id)
        let newer = LockRecord(start: clock.now - 500, end: nil, placeUID: nil, modeID: model.activeMode.id)
        store.lockHistory = [older, newer]
        model.reconcile(with: .locked(since: clock.now - 500))
        let open = model.history.filter { $0.end == nil }
        #expect(open.count == 1)
        #expect(open.first?.start == newer.start)
    }
}
