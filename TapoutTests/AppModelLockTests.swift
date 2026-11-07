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
        let controller = MockLockController(now: { [clock] in clock.now })
        let start = clock.now
        controller.simulateTagRead()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 600
        controller.useEmergencyPass()
        clock.now += MockLockController.emergencyDuration
        controller.tick()
        #expect(controller.session == .locked(since: clock.now))
        clock.now += 600
        controller.simulateTagRead()
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
}
