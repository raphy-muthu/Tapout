import Foundation
import Testing
@testable import Tapout

@MainActor
struct LockEngineDebugTests {
    private let store = SharedStore.makeTest()

    @Test func withoutArgumentsItReadsTheStore() {
        let since = Date(timeIntervalSinceReferenceDate: 800_000_000)
        store.session = .locked(since: since)
        #expect(LockEngine.fromLaunchArguments([], store: store).session == .locked(since: since))
    }

    @Test func mockLockedWritesALock() {
        let engine = LockEngine.fromLaunchArguments(["-mockState", "locked"], store: store)
        guard case .locked = store.session else {
            Issue.record("store not locked")
            return
        }
        #expect(engine.session == store.session)
    }

    @Test func mockEmergencyLeavesTheStoreAlone() {
        let engine = LockEngine.fromLaunchArguments(["-mockState", "emergency"], store: store)
        #expect(engine.passesLeft == 2)
        #expect(store.passesLeft == 5)
        #expect(store.session == .unlocked)
    }

    @Test func previewStartsWhereItIsTold() {
        let since = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let engine = LockEngine.preview(session: .locked(since: since), passesLeft: 3)
        #expect(engine.session == .locked(since: since))
        #expect(engine.passesLeft == 3)
    }
}
