import Foundation
import Testing
@testable import Tapout

struct ModeScheduleTests {
    private func schedule(_ start: Int, _ end: Int) -> ModeSchedule {
        ModeSchedule(days: ModeSchedule.weekdays, start: start, end: end)
    }

    @Test func durationWithinADay() {
        #expect(schedule(540, 1020).duration == 480)
    }

    @Test func durationRunsPastMidnight() {
        #expect(schedule(1350, 420).duration == 510)
    }

    @Test func equalStartAndEndIsZeroAndNotRunnable() {
        let same = schedule(540, 540)
        #expect(same.duration == 0)
        #expect(!same.isRunnable)
    }

    @Test func fourteenMinutesIsNotRunnable() {
        #expect(!schedule(540, 554).isRunnable)
    }

    @Test func fifteenMinutesIsRunnable() {
        #expect(schedule(540, 555).isRunnable)
    }

    @Test func makeNeedsAtLeastOneDay() {
        #expect(ModeSchedule.make(days: [], start: 540, end: 1020) == nil)
        #expect(ModeSchedule.make(days: [2], start: 540, end: 1020) == ModeSchedule(days: [2], start: 540, end: 1020))
    }
}
