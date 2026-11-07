import FamilyControls
import Testing
@testable import Tapout

struct ScreenTimeAccessTests {
    @Test func errorsMapToOutcomes() {
        #expect(ScreenTimeAccess.outcome(for: FamilyControlsError.authorizationCanceled) == .declined)
        #expect(ScreenTimeAccess.outcome(for: FamilyControlsError.networkError) == .noConnection)
        #expect(ScreenTimeAccess.outcome(for: FamilyControlsError.restricted) == .unavailable)
        #expect(ScreenTimeAccess.outcome(for: FakeError()) == .unavailable)
    }

    @Test func copy() {
        #expect(ScreenTimeAccess.Outcome.granted.message == nil)
        #expect(ScreenTimeAccess.Outcome.declined.message == "Screen Time is off. Turn it on in Settings, then tap Allow.")
        #expect(ScreenTimeAccess.Outcome.noConnection.message == "No connection. Try again.")
        #expect(ScreenTimeAccess.Outcome.unavailable.message == "Screen Time isn't available on this iPhone.")
    }

    @Test func onlyADeclineOffersSettings() {
        #expect(ScreenTimeAccess.Outcome.declined.offersSettings)
        #expect(!ScreenTimeAccess.Outcome.granted.offersSettings)
        #expect(!ScreenTimeAccess.Outcome.noConnection.offersSettings)
        #expect(!ScreenTimeAccess.Outcome.unavailable.offersSettings)
    }
}
