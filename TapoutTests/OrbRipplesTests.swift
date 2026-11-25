import Testing
@testable import Tapout

struct OrbRipplesTests {
    @Test func startsEmpty() {
        #expect(OrbRipples().ages(at: 10) == SIMD3(-1, -1, -1))
    }

    @Test func aRippleAgesFromItsStart() {
        var ripples = OrbRipples()
        ripples.add(at: 10)
        #expect(ripples.ages(at: 10.5) == SIMD3(0.5, -1, -1))
    }

    @Test func aFinishedRippleDisappears() {
        var ripples = OrbRipples()
        ripples.add(at: 10)
        #expect(ripples.ages(at: 10 + OrbRipples.lifetime + 0.01) == SIMD3(-1, -1, -1))
    }

    @Test func newestComesFirstAndTheOldestIsDroppedAtCapacity() {
        var ripples = OrbRipples()
        for t in [1.0, 1.1, 1.2, 1.3] { ripples.add(at: t) }
        let ages = ripples.ages(at: 1.4)
        #expect(abs(ages.x - 0.1) < 0.0001 && abs(ages.y - 0.2) < 0.0001 && abs(ages.z - 0.3) < 0.0001)
    }
}
