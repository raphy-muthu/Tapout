import Foundation
import Testing
@testable import Tapout

struct SharedStoreTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func freshInstallDefaults() {
        let store = SharedStore.makeTest()
        #expect(store.session == .unlocked)
        #expect(store.passesLeft == 5)
        #expect(store.pairedTags.isEmpty)
        #expect(store.relockStrategy == .warning)
        #expect(store.log.isEmpty)
    }

    @Test(arguments: [
        LockSession.unlocked,
        .locked(since: SharedStoreTests.start),
        .emergency(relockAt: SharedStoreTests.start + 300, duration: 300),
    ])
    func sessionRoundTrips(_ session: LockSession) {
        let store = SharedStore.makeTest()
        store.session = session
        #expect(store.session == session)
    }

    @Test func aSecondStoreOnTheSameSuiteSeesTheSameValues() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let first = SharedStore.makeTest(suite: suite)
        first.passesLeft = 2
        first.pairedTags = [PairedTag(uid: TagUID(hex: "04A2"), name: "Desk", pairedAt: Self.start)]
        first.relockStrategy = .pastStart

        let second = SharedStore.makeTest(suite: suite)
        #expect(second.passesLeft == 2)
        #expect(second.pairedTags.map(\.name) == ["Desk"])
        #expect(second.relockStrategy == .pastStart)
    }

    @Test func passesCanReachZero() {
        let store = SharedStore.makeTest()
        store.passesLeft = 0
        #expect(store.passesLeft == 0)
    }

    @Test func corruptPassesCountAsNoneLeft() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let store = SharedStore.makeTest(suite: suite)
        UserDefaults(suiteName: suite)!.set(Data("not json".utf8), forKey: "passesLeft")
        #expect(store.passesLeft == 0)
    }

    @Test func corruptSessionReadsAsUnlocked() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let store = SharedStore.makeTest(suite: suite)
        UserDefaults(suiteName: suite)!.set(Data("not json".utf8), forKey: "session")
        #expect(store.session == .unlocked)
    }

    @Test func logKeepsTheNewestEntries() {
        let store = SharedStore.makeTest()
        for index in 0..<(SharedStore.logLimit + 5) {
            store.appendLog("entry \(index)", source: .app, at: Self.start)
        }
        #expect(store.log.count == SharedStore.logLimit)
        #expect(store.log.first?.message == "entry 5")
        #expect(store.log.last?.message == "entry \(SharedStore.logLimit + 4)")
    }

    @Test func clearLogEmptiesIt() {
        let store = SharedStore.makeTest()
        store.appendLog("x", source: .monitor, at: Self.start)
        store.clearLog()
        #expect(store.log.isEmpty)
    }
}
