import Testing
@testable import Tapout

struct HapticPatternTests {
    @Test func lockKeepsTheSpecRule() {
        let events = HapticPattern.lock.events
        let taps = events.filter { $0.kind == .transient }
        #expect(taps.count == 2)
        #expect(taps[0].time == 0)
        #expect(taps[1].time == 0.09)
        #expect(taps.allSatisfy { $0.intensity == 1 })
    }

    @Test func lockEndsWithASoftSwellUnderTheBloom() {
        let swell = HapticPattern.lock.events.last
        #expect(swell?.kind == .continuous)
        #expect((swell?.time ?? 0) > 0.09)
        #expect((swell?.intensity ?? 1) < 0.5)
    }

    @Test func unlockIsOneSoftTapThenAFadingEcho() {
        let events = HapticPattern.unlock.events
        #expect(events.count == 2)
        #expect(events[0].time == 0)
        #expect(events[1].intensity < events[0].intensity)
    }

    @Test func detentAndScrubAreSingleTicks() {
        #expect(HapticPattern.detent.events.count == 1)
        #expect(HapticPattern.scrub.events.count == 1)
        #expect(HapticPattern.scrub.events[0].intensity < HapticPattern.detent.events[0].intensity)
    }

    @Test func pairedIsTheLockPairAtLowerIntensity() {
        let paired = HapticPattern.paired.events
        let lock = HapticPattern.lock.events.filter { $0.kind == .transient }
        #expect(paired.map(\.time) == lock.map(\.time))
        #expect(zip(paired, lock).allSatisfy { $0.intensity < $1.intensity })
    }

    @Test func everyPatternIsWellFormed() {
        for pattern in HapticPattern.allCases {
            let events = pattern.events
            #expect(!events.isEmpty)
            #expect(events.map(\.time) == events.map(\.time).sorted())
            #expect(events.allSatisfy { $0.time >= 0 && (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) })
            #expect(events.filter { $0.kind == .continuous }.allSatisfy { $0.duration > 0 })
        }
    }

    @Test func fallbacksMapToTheExistingHaptics() {
        #expect(HapticPattern.lock.fallback == .lock)
        #expect(HapticPattern.paired.fallback == .lock)
        #expect(HapticPattern.unlock.fallback == .unlock)
        #expect(HapticPattern.detent.fallback == .select)
        #expect(HapticPattern.scrub.fallback == .select)
    }
}
