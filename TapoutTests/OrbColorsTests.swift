import Testing
@testable import Tapout

struct OrbColorsTests {
    @Test func theEndsAreTheTwoTones() {
        #expect(OrbColors.mixed(tone: 0, light: false) == .slate(light: false))
        #expect(OrbColors.mixed(tone: 1, light: false) == .ember(light: false))
    }

    @Test func toneIsClamped() {
        #expect(OrbColors.mixed(tone: -3, light: true) == .slate(light: true))
        #expect(OrbColors.mixed(tone: 7, light: true) == .ember(light: true))
    }

    @Test func halfwayIsBetweenTheTones() {
        let mid = OrbColors.mixed(tone: 0.5, light: false)
        let slate = OrbColors.slate(light: false), ember = OrbColors.ember(light: false)
        #expect(mid.mid.x > min(slate.mid.x, ember.mid.x) && mid.mid.x < max(slate.mid.x, ember.mid.x))
        #expect(mid.glowAlpha > min(slate.glowAlpha, ember.glowAlpha) && mid.glowAlpha < max(slate.glowAlpha, ember.glowAlpha))
    }

    @Test func emberMidIsTheEmberToken() {
        // #FF9F43, the orb's body color since Phase 1.
        let c = OrbColors.ember(light: false).mid
        #expect(abs(c.x - 1.0) < 0.001 && abs(c.y - 159.0 / 255) < 0.001 && abs(c.z - 67.0 / 255) < 0.001)
    }

    @Test func lightModeDeepensTheEdgeAndSoftensTheGlow() {
        #expect(OrbColors.ember(light: true).edge != OrbColors.ember(light: false).edge)
        #expect(OrbColors.ember(light: true).glowAlpha < OrbColors.ember(light: false).glowAlpha)
    }
}
