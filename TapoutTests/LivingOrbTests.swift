import SwiftUI
import Testing
@testable import Tapout

struct LivingOrbTests {
    @Test func glassNeedsTheFlagAndFullMotion() {
        #expect(LivingOrbChoice.choose(flag: true, level: .full, shaderAvailable: true) == .glass)
        #expect(LivingOrbChoice.choose(flag: false, level: .full, shaderAvailable: true) == .classic)
        #expect(LivingOrbChoice.choose(flag: true, level: .still, shaderAvailable: true) == .classic)
        #expect(LivingOrbChoice.choose(flag: false, level: .still, shaderAvailable: true) == .classic)
    }

    @Test func glassNeedsTheShaderInTheLibrary() {
        #expect(LivingOrbChoice.choose(flag: true, level: .full, shaderAvailable: false) == .classic)
    }

    /// With the flag off the Metal library must not be probed at all.
    @Test func theShaderIsNotProbedWithTheFlagOff() {
        var probes = 0
        func probe() -> Bool { probes += 1; return true }
        #expect(LivingOrbChoice.choose(flag: false, level: .full, shaderAvailable: probe()) == .classic)
        #expect(probes == 0)
        #expect(LivingOrbChoice.choose(flag: true, level: .full, shaderAvailable: probe()) == .glass)
        #expect(probes == 1)
    }

    /// The NFC sheet, Control Center and the app switcher make the scene inactive; only the background stills the orb.
    @Test func onlyTheBackgroundStillsTheOrb() {
        #expect(LivingOrbChoice.sceneCountsAsActive(.active))
        #expect(LivingOrbChoice.sceneCountsAsActive(.inactive))
        #expect(!LivingOrbChoice.sceneCountsAsActive(.background))
    }
}

struct OrbWarmthPlanTests {
    /// Warmth starts in the tone it was given and settles in its own; with none it is settled at once.
    @Test func warmthStartsWhereItIsToldAndSettlesInItsOwn() {
        #expect(OrbWarmthPlan.shown(tone: .ember, from: .slate, settled: false) == .slate)
        #expect(OrbWarmthPlan.shown(tone: .ember, from: .slate, settled: true) == .ember)
        #expect(OrbWarmthPlan.shown(tone: .slate, from: nil, settled: false) == .slate)
    }

    @Test func warmthIsWiderThanTheOrbsOwnGlow() {
        #expect(OrbWarmthPlan.side(orb: 300) == 780)
    }

    @Test func lightModeIsSofter() {
        #expect(OrbWarmthPlan.strength(dark: true) == 1)
        #expect(OrbWarmthPlan.strength(dark: false) == 0.55)
    }
}

@MainActor
struct OrbToneMemoryTests {
    @Test func swapReturnsTheToneShownBefore() {
        let memory = OrbToneMemory()
        #expect(memory.swap(.slate) == nil)
        #expect(memory.swap(.slate) == .slate)
        #expect(memory.swap(.ember) == .slate)
        #expect(memory.swap(.slate) == .ember)
    }
}

struct OrbEntranceTests {
    /// Only a real change since the orb was last shown swings the warmth and ripples.
    @Test func aChangedToneSwingsFromThePreviousOne() {
        #expect(OrbEntrance.decide(previous: .slate, tone: .ember) == OrbEntrance(warmFrom: .slate, ripples: true))
        #expect(OrbEntrance.decide(previous: .ember, tone: .slate) == OrbEntrance(warmFrom: .ember, ripples: true))
    }

    /// A tab return, a trip to the background or the keyboard shows the same tone again: settled, no ripple.
    @Test func theSameToneAppearsSettled() {
        #expect(OrbEntrance.decide(previous: .ember, tone: .ember) == OrbEntrance(warmFrom: nil, ripples: false))
        #expect(OrbEntrance.decide(previous: .slate, tone: .slate) == OrbEntrance(warmFrom: nil, ripples: false))
    }

    /// The first orb since launch has nothing to change from.
    @Test func theFirstOrbAppearsSettled() {
        #expect(OrbEntrance.decide(previous: nil, tone: .ember) == OrbEntrance(warmFrom: nil, ripples: false))
    }

    /// The lock moment and Time's up know the change themselves; that wins over the memory.
    @Test func aKnownChangeWinsOverTheMemory() {
        // Time's up: Home already showed slate underneath, but the cover knows it was ember.
        #expect(OrbEntrance.decide(known: .ember, remembered: .slate, tone: .slate)
                == OrbEntrance(warmFrom: .ember, ripples: true))
        // The lock moment appears slate and warms from slate once it turns ember: the start is kept.
        #expect(OrbEntrance.decide(known: .slate, remembered: nil, tone: .slate)
                == OrbEntrance(warmFrom: .slate, ripples: false))
        // Nothing known: the memory decides.
        #expect(OrbEntrance.decide(known: nil, remembered: .ember, tone: .ember)
                == OrbEntrance(warmFrom: nil, ripples: false))
    }
}
