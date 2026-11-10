import FamilyControls
import Foundation
import Testing
@testable import Tapout

struct ShieldPlanTests {
    @Test func emptySelectionsShieldNothing() {
        let plan = ShieldPlan(blocking: FamilyActivitySelection(), allowing: FamilyActivitySelection())
        #expect(plan.isEmpty)
        #expect(plan.allowedApplications.isEmpty)
    }

    @Test func aStoreWithoutModesGivesAnEmptyPlan() {
        #expect(SharedStore.makeTest().activeShieldPlan.isEmpty)
    }

    @Test func relockAppliesTheStoresPlan() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        let relockAt = Date(timeIntervalSinceReferenceDate: 800_000_300)
        store.session = .emergency(relockAt: relockAt, duration: 300)
        _ = EmergencyRelock.perform(store: store, shields: shields, now: relockAt)
        #expect(shields.plans == [store.activeShieldPlan])
    }
}
