import Foundation
import Testing
@testable import Tapout

@MainActor
struct DemoDataTests {
    @Test func seedsTheSpecsSampleData() {
        let store = SharedStore.makeTest()
        DemoData.seed(store)
        let model = AppModel(store: store)

        #expect(model.modes.map(\.name) == ["Deep work", "Evenings", "Weekend", "Sleep"])
        #expect(model.activeMode.name == "Deep work")
        #expect(model.activeMode.schedule == ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020))
        #expect(model.unlockPlaceNames(for: model.activeMode) == ["Kitchen"])
        #expect(model.places.map(\.name) == ["Kitchen", "Desk", "Car", "Bedroom"])
        #expect(model.defaultPlace?.name == "Kitchen")
        let modeIDs = Set(model.modes.map(\.id))
        #expect(!model.history.isEmpty)
        #expect(model.history.allSatisfy { modeIDs.contains($0.modeID) })
    }

    @Test func seedsIntentionsAndInterests() {
        let store = SharedStore.makeTest()
        DemoData.seed(store)
        let model = AppModel(store: store)
        #expect(model.interests == [.sports, .movies])
        #expect(model.history.contains { $0.intention != nil && $0.intentionDone != nil })
    }

    @Test func seedsThreePassesLikeTheSpecs() {
        let store = SharedStore.makeTest()
        DemoData.seed(store)
        #expect(store.passesLeft == 3)
    }
}
