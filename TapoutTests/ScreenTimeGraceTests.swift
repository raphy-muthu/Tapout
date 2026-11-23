import Foundation
import Testing
@testable import Tapout

struct ScreenTimeGraceTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func approvedClears() {
        var grace = ScreenTimeGrace()
        #expect(grace.observe(needed: false, now: t0) == .clear)
    }

    @Test func firstMissingReadWaits() {
        var grace = ScreenTimeGrace()
        #expect(grace.observe(needed: true, now: t0) == .wait(until: t0.addingTimeInterval(ScreenTimeGrace.delay)))
    }

    @Test func missingAgainBeforeTheDelayKeepsWaiting() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        let due = t0.addingTimeInterval(ScreenTimeGrace.delay)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(0.4)) == .wait(until: due))
    }

    @Test func missingForTheWholeDelayShowsThePage() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(ScreenTimeGrace.delay)) == .show)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(ScreenTimeGrace.delay + 5)) == .show)
    }

    @Test func approvalInTheMeantimeStartsTheWaitAgain() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        #expect(grace.observe(needed: false, now: t0.addingTimeInterval(1)) == .clear)
        let later = t0.addingTimeInterval(2)
        #expect(grace.observe(needed: true, now: later) == .wait(until: later.addingTimeInterval(ScreenTimeGrace.delay)))
    }

    @Test func theDelayIsLongEnoughForAStaleReadAndShortEnoughToNotice() {
        #expect(ScreenTimeGrace.delay >= 1 && ScreenTimeGrace.delay <= 2)
    }
}
