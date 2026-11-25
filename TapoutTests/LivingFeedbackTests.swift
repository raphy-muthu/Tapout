import Testing
@testable import Tapout

struct LivingFeedbackTests {
    @Test func theSwitchChoosesTheEngine() {
        #expect(HapticRoute.choose(livingGlass: true) == .engine)
        #expect(HapticRoute.choose(livingGlass: false) == .classic)
    }
}
