import Testing
@testable import Tapout

struct RejectedTagTests {
    @Test func unknownTagWhileUnlockedOffersPairing() {
        let rejected = RejectedTag.unknown(tryPlaces: ["Kitchen", "Desk", "Car"], locked: false)
        #expect(rejected.title == "That's not one of your tags.")
        #expect(rejected.hint == "Try Kitchen or Desk.")
        #expect(rejected.canPair)
    }

    @Test func unknownTagWhileLockedNeverOffersPairing() {
        #expect(!RejectedTag.unknown(tryPlaces: ["Kitchen"], locked: true).canPair)
        #expect(RejectedTag.unknown(tryPlaces: ["Kitchen"], locked: true).hint == "Try Kitchen.")
    }

    @Test func noPlacesPointsToPlacesWhileUnlocked() {
        #expect(RejectedTag.unknown(tryPlaces: [], locked: false).hint == "Pair one in Places.")
        #expect(RejectedTag.unknown(tryPlaces: [], locked: true).hint == nil)
    }

    @Test func wrongPlaceNamesTheMode() {
        let rejected = RejectedTag.wrongPlace(mode: "Sleep", tryPlaces: ["Bedroom"])
        #expect(rejected.title == "Not for Sleep.")
        #expect(rejected.hint == "Try Bedroom.")
        #expect(!rejected.canPair)
    }
}
