import Foundation
import Testing
@testable import Tapout

struct ScheduleRunTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let notifier = FakeNotifier()
    private let mode = Mode(name: "Focus", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))
    /// Monday 2026-11-09, 1 PM.
    private var monday1PM: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 13))! }

    private func run(access: Bool = true, apps: Bool = true, tag: Bool = true, at now: Date? = nil) -> String {
        store.modes = [mode]
        return ScheduledLock.run(modeID: mode.id, store: store, shields: shields, notifier: notifier,
                                 now: now ?? monday1PM, accessApproved: access, hasApps: { _ in apps }, hasTag: tag, calendar: calendar)
    }

    @Test func aWindowStartLocksAndSaysSo() {
        let line = run()
        #expect(store.session == .locked(since: monday1PM))
        #expect(shields.applied == 1)
        #expect(notifier.posted == ["Focus|Locked until you tap a tag."])
        #expect(line == "Scheduled lock: Focus")
    }

    @Test func aWindowItCantLockIsSkippedWithAReason() {
        _ = run(apps: false)
        #expect(store.session == .unlocked)
        #expect(shields.applied == 0)
        #expect(notifier.posted == ["Focus|Didn't lock: no apps chosen."])
        _ = run(access: false)
        #expect(notifier.posted.last == "Focus|Didn't lock: Screen Time is off.")
        _ = run(tag: false)
        #expect(notifier.posted.last == "Focus|Didn't lock: no tag paired.")
    }

    @Test func aQuietSkipPostsNothing() {
        store.session = .locked(since: monday1PM - 600)
        let line = run()
        #expect(notifier.posted.isEmpty)
        #expect(line == "Schedule skipped: already locked")
    }

    @Test func anUnknownModeIsSkippedQuietly() {
        let line = ScheduledLock.run(modeID: UUID(), store: store, shields: shields, notifier: notifier,
                                     now: monday1PM, accessApproved: true, calendar: calendar)
        #expect(notifier.posted.isEmpty)
        #expect(line == "Schedule skipped: mode not found")
    }
}
