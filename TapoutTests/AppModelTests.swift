import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelTests {
    private let store = SharedStore.makeTest()
    private let kitchen = TagUID(hex: "04A1")
    private let desk = TagUID(hex: "04B2")

    @Test func freshInstallStartsWithOneActiveMode() {
        let model = AppModel(store: store)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName])
        #expect(model.activeMode.id == model.modes[0].id)
    }

    @Test func existingModesAreNotReseeded() {
        store.modes = [Mode(name: "Deep work")]
        #expect(AppModel(store: store).modes.map(\.name) == ["Deep work"])
    }

    @Test func activeModeFallsBackToTheFirst() {
        store.modes = [Mode(name: "A"), Mode(name: "B")]
        store.activeModeID = UUID()
        #expect(AppModel(store: store).activeMode.name == "A")
    }

    @Test func saveAddsANewModeAndReplacesAnExistingOne() {
        let model = AppModel(store: store)
        var mode = model.newMode()
        #expect(!model.isSaved(mode))
        mode.name = "  Evenings  "
        model.save(mode)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName, "Evenings"])
        mode.name = "Nights"
        model.save(mode)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName, "Nights"])
    }

    @Test func activeModeSurvivesANewModel() {
        let model = AppModel(store: store)
        let evenings = Mode(name: "Evenings")
        model.save(evenings)
        model.setActiveMode(evenings.id)
        #expect(AppModel(store: store).activeMode.id == evenings.id)
    }

    @Test func theLastModeCantBeDeleted() {
        let model = AppModel(store: store)
        #expect(!model.deleteMode(id: model.modes[0].id))
        #expect(model.modes.count == 1)
    }

    @Test func deletingTheActiveModeActivatesTheFirst() {
        let model = AppModel(store: store)
        let evenings = Mode(name: "Evenings")
        model.save(evenings)
        model.setActiveMode(evenings.id)
        #expect(model.deleteMode(id: evenings.id))
        #expect(model.activeMode.name == AppModel.starterModeName)
    }

    @Test func firstPairedPlaceBecomesDefault() {
        let model = AppModel(store: store)
        #expect(model.pair(kitchen, name: "Kitchen") == .paired)
        #expect(model.pair(desk, name: "Desk") == .paired)
        #expect(model.defaultPlace?.uid == kitchen)
        #expect(model.otherPlaces.map(\.name) == ["Desk"])
    }

    @Test func pairingATagTwiceIsRefused() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        #expect(model.pair(kitchen, name: "Desk") == .alreadyPaired(name: "Kitchen"))
        #expect(model.places.count == 1)
    }

    @Test func blankNamesGetANumberedPlace() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "   ")
        #expect(model.places.first?.name == "Place 1")
    }

    @Test func renamingTrimsAndIgnoresBlanks() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.renamePlace(kitchen, to: "  Pantry ")
        #expect(model.places.first?.name == "Pantry")
        model.renamePlace(kitchen, to: " ")
        #expect(model.places.first?.name == "Pantry")
    }

    @Test func removingAPlaceForgetsItEverywhere() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        model.save(Mode(name: "Deep work", unlockPlaces: [kitchen, desk]))
        model.removePlace(kitchen)
        #expect(model.places.map(\.name) == ["Desk"])
        #expect(model.defaultPlace?.uid == desk)
        #expect(model.modes.last?.unlockPlaces == [desk])
    }

    @Test func makeDefaultMovesTheHero() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        model.makeDefault(desk)
        #expect(model.defaultPlace?.uid == desk)
        #expect(model.otherPlaces.map(\.name) == ["Kitchen"])
    }

    @Test func unlockPlaceNamesFollowPairingOrderAndSkipUnknownTags() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        let mode = Mode(name: "Deep work", unlockPlaces: [desk, kitchen, TagUID(hex: "FFFF")])
        #expect(model.unlockPlaceNames(for: mode) == ["Kitchen", "Desk"])
    }
}
