import CoreGraphics
import Foundation
import Testing
@testable import Tapout

struct ModeDrawerTests {
    private let a = UUID(), b = UUID(), c = UUID()

    @Test func theActiveModeLeadsOnArrival() {
        #expect(ModeDrawer.order([a, b, c], held: [], active: b) == [b, a, c])
    }

    @Test func cardsHoldTheirPlacesWhenTheActiveModeChanges() {
        #expect(ModeDrawer.order([a, b, c], held: [b, a, c], active: c) == [b, a, c])
    }

    @Test func aNewModeGoesLast() {
        let new = UUID()
        #expect(ModeDrawer.order([a, b, new], held: [b, a], active: new) == [b, a, new])
    }

    @Test func aDeletedModeDropsOut() {
        #expect(ModeDrawer.order([a, c], held: [b, a, c], active: a) == [a, c])
    }

    @Test func oneDrawerAtATime() {
        #expect(ModeDrawer.toggled(a, open: nil) == a)
        #expect(ModeDrawer.toggled(b, open: a) == b)
    }

    @Test func tappingTheOpenDrawerClosesIt() {
        #expect(ModeDrawer.toggled(a, open: a) == nil)
    }
}

struct CardTiltTests {
    private let size = CGSize(width: 300, height: 100)

    @Test func theCentreDoesNotTilt() {
        let tilt = CardTilt.angles(at: CGPoint(x: 150, y: 50), in: size)
        #expect(tilt.x == 0 && tilt.y == 0)
    }

    @Test func theCornersTiltTheMost() {
        let topLeft = CardTilt.angles(at: .zero, in: size)
        #expect(topLeft.x == CardTilt.maxX && topLeft.y == -CardTilt.maxY)
        let bottomRight = CardTilt.angles(at: CGPoint(x: 300, y: 100), in: size)
        #expect(bottomRight.x == -CardTilt.maxX && bottomRight.y == CardTilt.maxY)
    }

    @Test func aTouchOutsideIsClamped() {
        let tilt = CardTilt.angles(at: CGPoint(x: 900, y: -40), in: size)
        #expect(tilt.x == CardTilt.maxX && tilt.y == CardTilt.maxY)
    }

    @Test func anUnmeasuredCardDoesNotTilt() {
        let tilt = CardTilt.angles(at: CGPoint(x: 10, y: 10), in: .zero)
        #expect(tilt.x == 0 && tilt.y == 0)
    }

    @Test func aMovingFingerLetsGo() {
        let start = CGPoint(x: 100, y: 100)
        #expect(!CardTilt.letsGo(from: start, to: CGPoint(x: 105, y: 106)))
        #expect(CardTilt.letsGo(from: start, to: CGPoint(x: 100, y: 120)))
    }
}

struct PairingOrbTests {
    @Test func scanningRipplesInSlate() {
        let look = PairingOrb.look(.scanning)
        #expect(look.tone == .slate && look.ring == 0 && look.rippleEvery == 1.1)
    }

    @Test func aReadTagSealsTheOrb() {
        let look = PairingOrb.look(.found(TagUID(hex: "04AA")))
        #expect(look.tone == .ember && look.ring == 1 && look.rippleEvery == nil)
    }

    @Test func aFailureIsAStillSlateOrb() {
        let look = PairingOrb.look(.failed("No tag found."))
        #expect(look.tone == .slate && look.ring == 0 && look.rippleEvery == nil)
    }
}

struct OnboardingOrbTests {
    @Test func eachStepFillsASixthOfTheRing() {
        let rings = (1...5).map { OnboardingOrb.look(step: $0, paired: false, largeText: false).ring }
        #expect(rings == [1, 2, 3, 4, 5].map { Double($0) / 6 })
    }

    @Test func theLastSixthWaitsForTheTag() {
        #expect(OnboardingOrb.look(step: 6, paired: false, largeText: false).ring == 5.0 / 6)
        let paired = OnboardingOrb.look(step: 6, paired: true, largeText: false)
        #expect(paired.ring == 1 && paired.tone == .ember && paired.rippleEvery == nil)
    }

    @Test func onlyThePairingStepRipples() {
        let ripples = (1...6).map { OnboardingOrb.look(step: $0, paired: false, largeText: false).rippleEvery != nil }
        #expect(ripples == [false, false, false, false, false, true])
    }

    @Test func theOrbIsSlateUntilPaired() {
        #expect((1...6).allSatisfy { OnboardingOrb.look(step: $0, paired: false, largeText: false).tone == .slate })
    }

    @Test func sizesFollowTheStep() {
        let sizes = (1...6).map { OnboardingOrb.look(step: $0, paired: false, largeText: false).size }
        #expect(sizes == [260, 190, 96, 96, 96, 230])
    }

    @Test func largeTextShrinksTheOrbAndHidesItOnBusySteps() {
        let sizes = (1...6).map { OnboardingOrb.look(step: $0, paired: false, largeText: true).size }
        #expect(sizes == [180, 120, 0, 0, 0, 150])
    }

    @Test func onlyScreenTimeCarriesASymbol() {
        let symbols = (1...6).map { OnboardingOrb.look(step: $0, paired: false, largeText: false).symbol }
        #expect(symbols == [nil, "hourglass", nil, nil, nil, nil])
    }
}

@MainActor
struct OnboardingPreviewTests {
    @Test func thePreviewStartsLikeAFreshInstall() {
        let model = OnboardingPreview.freshModel()
        #expect(model.places.isEmpty)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName])
    }

    @Test func eachPreviewForgetsTheLastOne() {
        let first = OnboardingPreview.freshModel()
        _ = first.pair(TagUID(hex: "04BB"), name: "Kitchen")
        #expect(OnboardingPreview.freshModel().places.isEmpty)
    }
}
