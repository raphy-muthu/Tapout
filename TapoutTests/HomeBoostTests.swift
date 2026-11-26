import SwiftUI
import Testing
@testable import Tapout

struct BackdropPlanTests {
    @Test func thePoolsDriftAndBreathe() {
        #expect(BackdropPlan.pools(at: 0) != BackdropPlan.pools(at: 2))
    }

    @Test func aHeldTimeHoldsThePoolsStill() {
        #expect(BackdropPlan.pools(at: 0) == BackdropPlan.pools(at: 0))
    }

    @Test func poolsStayNearTheScreenAndNeverExceedThePeak() {
        for step in 0..<400 {
            for pool in BackdropPlan.pools(at: Double(step) * 0.5) {
                #expect((-0.2...1.2).contains(pool.x) && (-0.2...1.2).contains(pool.y))
                #expect(pool.radius > 0)
                #expect((0...1).contains(pool.strength))
            }
        }
    }

    @Test func lightModeIsSofterThanDark() {
        for tone in [OrbTone.slate, .ember] {
            #expect(BackdropPlan.peak(tone: tone, dark: false) < BackdropPlan.peak(tone: tone, dark: true))
        }
    }

    @Test func glassControlsAreOffUnlessAsked() {
        #expect(EnvironmentValues().glassControls == false)
    }
}
