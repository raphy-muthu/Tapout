import Foundation
import Testing
@testable import Tapout

struct EmergencyRelockTests {
    private static let relockAt = Date(timeIntervalSinceReferenceDate: 800_000_300)

    @Test func relocksAnOpenPassAndReportsHowLate() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .emergency(relockAt: Self.relockAt, duration: 300)

        let late = EmergencyRelock.perform(store: store, shields: shields, now: Self.relockAt + 12)

        #expect(late == 12)
        #expect(store.session == .locked(since: Self.relockAt))
        #expect(shields.applied == 1)
    }

    @Test func anEarlyCallbackStillRelocks() {
        let store = SharedStore.makeTest()
        store.session = .emergency(relockAt: Self.relockAt, duration: 300)
        #expect(EmergencyRelock.perform(store: store, shields: FakeShields(), now: Self.relockAt - 30) == -30)
        #expect(store.session == .locked(since: Self.relockAt))
    }

    @Test(arguments: [LockSession.unlocked, .locked(since: EmergencyRelockTests.relockAt)])
    func leavesOtherStatesAlone(_ session: LockSession) {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = session

        #expect(EmergencyRelock.perform(store: store, shields: shields, now: Self.relockAt) == nil)
        #expect(store.session == session)
        #expect(shields.applied == 0)
    }
}
