import Foundation
import Testing
@testable import Tapout

@MainActor
struct MilestoneTests {
    private let calendar = TestDates.calendar

    @Test func firstLockComesFirst() {
        let history = [TestDates.lock(TestDates.oct(26, 9), minutes: 30)]
        #expect(Milestone.reached(in: history, now: TestDates.oct(28, 12), calendar: calendar) == [.firstLock])
    }

    @Test func tenHoursAndSevenDays() {
        let week = (21...27).map { TestDates.lock(TestDates.oct($0, 9), minutes: 90) } // 10h 30m over 7 days
        let reached = Milestone.reached(in: week, now: TestDates.oct(28, 8), calendar: calendar)
        #expect(reached == [.firstLock, .tenHours, .sevenDayStreak])
    }

    @Test func aRunningLockDoesNotCount() {
        let running = LockRecord(start: TestDates.oct(1, 9), end: nil, placeUID: nil, modeID: TestDates.modeID)
        #expect(Milestone.reached(in: [running], now: TestDates.oct(28, 12), calendar: calendar).isEmpty)
    }

    @Test func fiftyAndHundredHours() {
        func reached(hours: Double) -> [Milestone] {
            let history = [TestDates.lock(TestDates.oct(1, 9), minutes: hours * 60)]
            return Milestone.reached(in: history, now: TestDates.oct(28, 12), calendar: calendar)
        }
        #expect(reached(hours: 49.9) == [.firstLock, .tenHours])
        #expect(reached(hours: 50) == [.firstLock, .tenHours, .fiftyHours])
        #expect(reached(hours: 99.9) == [.firstLock, .tenHours, .fiftyHours])
        #expect(reached(hours: 100) == [.firstLock, .tenHours, .fiftyHours, .hundredHours])
    }

    @Test func subtitles() {
        #expect(Milestone.firstLock.subtitle(totalLocked: 1800, interests: []) == "The first of many.")
        #expect(Milestone.tenHours.subtitle(totalLocked: 10 * 3600, interests: [.movies]) == "About 5 movies' worth of time, back.")
        #expect(Milestone.sevenDayStreak.subtitle(totalLocked: 3600, interests: []) == "A week of locks in a row.")
    }

    @Test func eachMilestoneShowsOnce() {
        var now = TestDates.oct(28, 9)
        let model = AppModel(store: SharedStore.makeTest(), now: { now })
        #expect(model.unseenMilestone(calendar: calendar) == nil)
        model.startLock(placeUID: nil, intention: nil)
        now += 45 * 60
        model.finishLock()
        #expect(model.unseenMilestone(calendar: calendar) == .firstLock)
        model.markSeen(.firstLock)
        #expect(model.unseenMilestone(calendar: calendar) == nil)
        #expect(model.phoneFreeToday(calendar: calendar) == 45 * 60)
    }

    @Test func aFreshModelStillKnowsWhatWasSeen() {
        var now = TestDates.oct(28, 9)
        let store = SharedStore.makeTest()
        let model = AppModel(store: store, now: { now })
        model.startLock(placeUID: nil, intention: nil)
        now += 45 * 60
        model.finishLock()
        model.markSeen(.firstLock)

        let fresh = AppModel(store: store, now: { now })
        #expect(fresh.seenMilestones == [Milestone.firstLock.rawValue])
        #expect(fresh.unseenMilestone(calendar: calendar) == nil)
    }
}
