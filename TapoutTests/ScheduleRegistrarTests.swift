import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct ScheduleRegistrarTests {
    private let store = SharedStore.makeTest()
    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)

    @Test func startsEachRunnableSchedule() {
        let center = FakeActivityCenter()
        let focus = Mode(name: "Focus", schedule: afternoons)
        #expect(ScheduleRegistrar(center: center, store: store).sync([focus, Mode(name: "Manual")]) == ["Schedule started: Focus 13:00–17:00"])
        #expect(center.started == [ModeActivity.name(for: focus.id)])
        #expect(store.registeredSchedules == [ModeActivity.name(for: focus.id).rawValue: afternoons])
    }

    @Test func leavesAnUnchangedRunningActivityAlone() {
        let focus = Mode(name: "Focus", schedule: afternoons)
        let name = ModeActivity.name(for: focus.id)
        store.registeredSchedules = [name.rawValue: afternoons]
        let center = FakeActivityCenter(running: [name])
        _ = ScheduleRegistrar(center: center, store: store).sync([focus])
        #expect(center.started.isEmpty)
    }

    @Test func aStartStampsTheModeAndAnUnchangedOneIsNotStampedAgain() {
        let focus = Mode(name: "Focus", schedule: afternoons)
        let first = Date(timeIntervalSince1970: 1_000)
        _ = ScheduleRegistrar(center: FakeActivityCenter(), store: store, now: { first }).sync([focus])
        #expect(store.scheduleSavedAt[focus.id.uuidString] == first)
        let center = FakeActivityCenter(running: [ModeActivity.name(for: focus.id)])
        _ = ScheduleRegistrar(center: center, store: store, now: { first + 500 }).sync([focus])
        #expect(center.started.isEmpty)
        #expect(store.scheduleSavedAt[focus.id.uuidString] == first)
    }

    @Test func saysHowManyModesWereLeftOut() {
        let modes = (0..<(ModeActivity.limit + 2)).map { Mode(name: "M\($0)", schedule: afternoons) }
        let center = FakeActivityCenter()
        let problems = ScheduleRegistrar(center: center, store: store).sync(modes)
        #expect(center.started.count == ModeActivity.limit)
        #expect(problems.filter { $0.contains("left out") }.count == 1)
        #expect(problems.contains { $0.contains("2 scheduled modes left out") })
        #expect(!ScheduleRegistrar(center: FakeActivityCenter(), store: SharedStore.makeTest()).sync(Array(modes.prefix(3))).contains { $0.contains("left out") })
    }

    @Test func restartsAChangedSchedule() {
        var focus = Mode(name: "Focus", schedule: afternoons)
        let name = ModeActivity.name(for: focus.id)
        store.registeredSchedules = [name.rawValue: afternoons]
        let center = FakeActivityCenter(running: [name])
        focus.schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 9 * 60, end: 12 * 60)
        _ = ScheduleRegistrar(center: center, store: store).sync([focus])
        #expect(center.stopped == [name])
        #expect(center.started == [name])
    }

    @Test func stopsModeActivitiesThatAreNoLongerWantedButNotTheRelock() {
        let gone = ModeActivity.name(for: UUID())
        let center = FakeActivityCenter(running: [gone, RelockPlan.activity])
        _ = ScheduleRegistrar(center: center, store: store).sync([])
        #expect(center.stopped == [gone])
        #expect(center.activities == [RelockPlan.activity])
    }

    @Test func reportsAStartThatFailed() {
        let center = FakeActivityCenter()
        center.failure = FakeError()
        let problems = ScheduleRegistrar(center: center, store: store).sync([Mode(name: "Focus", schedule: afternoons)])
        #expect(problems.count == 1)
        #expect(store.registeredSchedules.isEmpty)
    }
}
