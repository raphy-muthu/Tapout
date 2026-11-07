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

    @Test func newKeysStartEmpty() {
        let store = SharedStore.makeTest()
        #expect(store.modes.isEmpty)
        #expect(store.activeModeID == nil)
        #expect(store.defaultPlace == nil)
        #expect(store.lockHistory.isEmpty)
    }

    @Test func modesPlacesAndHistoryRoundTrip() {
        let store = SharedStore.makeTest()
        let kitchen = TagUID(hex: "04A1")
        let mode = Mode(
            name: "Deep work",
            schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020),
            unlockPlaces: [kitchen]
        )
        store.modes = [mode]
        store.activeModeID = mode.id
        store.defaultPlace = kitchen
        store.lockHistory = [LockRecord(start: Self.start, end: Self.start + 60, placeUID: kitchen, modeID: mode.id)]

        #expect(store.modes == [mode])
        #expect(store.activeModeID == mode.id)
        #expect(store.defaultPlace == kitchen)
        #expect(store.lockHistory == [LockRecord(start: Self.start, end: Self.start + 60, placeUID: kitchen, modeID: mode.id)])
    }

    @Test func lockIntentionRoundTripsAndIsNilWhenAbsent() throws {
        let store = SharedStore.makeTest()
        let modeID = UUID()
        let withIntention = LockRecord(start: Self.start, end: Self.start + 60, placeUID: nil, modeID: modeID,
                                       intention: "History essay, first paragraph", intentionDone: true)
        let without = LockRecord(start: Self.start, end: nil, placeUID: nil, modeID: modeID)
        store.lockHistory = [withIntention, without]
        #expect(store.lockHistory == [withIntention, without])
        #expect(store.lockHistory[1].intention == nil)
        #expect(store.lockHistory[1].intentionDone == nil)

        // History saved before these fields existed has no keys for them.
        let json = Data(#"{"start":0,"modeID":"\#(modeID.uuidString)"}"#.utf8)
        let old = try JSONDecoder().decode(LockRecord.self, from: json)
        #expect(old.intention == nil)
        #expect(old.intentionDone == nil)
    }

    @Test func unreadableDataIsKeptBeforeFallingBack() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let store = SharedStore.makeTest(suite: suite)
        UserDefaults(suiteName: suite)!.set(Data("not json".utf8), forKey: "modes")
        #expect(store.modes == [])
        store.modes = [Mode(name: "Focus")]
        #expect(UserDefaults(suiteName: suite)!.data(forKey: "modes.unreadable") == Data("not json".utf8))
    }

    @Test func phase3bKeysDefaultAndRoundTrip() {
        let store = SharedStore.makeTest()
        #expect(store.currentIntention == nil)
        #expect(store.interests.isEmpty)
        #expect(store.seenMilestones.isEmpty)
        store.currentIntention = "Essay"
        store.interests = [.reading]
        store.seenMilestones = ["firstLock"]
        #expect(store.currentIntention == "Essay")
        #expect(store.interests == [.reading])
        #expect(store.seenMilestones == ["firstLock"])
    }
}
