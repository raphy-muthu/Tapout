import Foundation
import Testing
@testable import Tapout

struct LockRecordTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let mode = UUID()

    private func record(end: TimeInterval? = nil, passes: [(TimeInterval, TimeInterval)] = []) -> LockRecord {
        LockRecord(start: t0, end: end.map { t0 + $0 }, placeUID: nil, modeID: mode,
                   passes: passes.map { DateInterval(start: t0 + $0.0, end: t0 + $0.1) })
    }

    @Test func finishedLockCountsStartToEnd() {
        #expect(record(end: 3600).lockedTime(now: t0 + 9000) == 3600)
    }

    @Test func runningLockCountsUpToNow() {
        #expect(record().lockedTime(now: t0 + 600) == 600)
    }

    @Test func passTimeIsLeftOut() {
        #expect(record(end: 7200, passes: [(3600, 3900)]).lockedTime(now: t0 + 9000) == 6900)
    }

    @Test func aRunningPassCountsOnlyUpToNow() {
        // The pass opened at 50 s and runs to 350 s. At 100 s, 50 s were locked.
        #expect(record(passes: [(50, 350)]).lockedTime(now: t0 + 100) == 50)
    }

    @Test func clipsToAnInterval() {
        let interval = DateInterval(start: t0 + 3600, end: t0 + 7200)
        #expect(record(end: 7200, passes: [(3000, 3900)]).lockedTime(in: interval, now: t0 + 9000) == 3300)
    }

    @Test func outsideTheIntervalIsZero() {
        let interval = DateInterval(start: t0 + 9000, end: t0 + 10_000)
        #expect(record(end: 3600).lockedTime(in: interval, now: t0 + 20_000) == 0)
    }

    @Test func endPassShortensOnlyARunningPass() {
        var lock = record(passes: [(50, 350)])
        lock.endPass(at: t0 + 120)
        #expect(lock.passes == [DateInterval(start: t0 + 50, end: t0 + 120)])
        lock.endPass(at: t0 + 200)
        #expect(lock.passes == [DateInterval(start: t0 + 50, end: t0 + 120)])
    }

    @Test func decodesRecordsSavedBeforePasses() throws {
        let json = #"{"start":0,"end":60,"modeID":"\#(mode.uuidString)"}"#
        let decoded = try JSONDecoder().decode(LockRecord.self, from: Data(json.utf8))
        #expect(decoded.passes.isEmpty)
        #expect(decoded.lockedTime(now: .distantFuture) == 60)
    }

    @Test func passesSurviveSaving() throws {
        let lock = record(end: 7200, passes: [(3600, 3900)])
        let decoded = try JSONDecoder().decode(LockRecord.self, from: JSONEncoder().encode(lock))
        #expect(decoded == lock)
    }
}
