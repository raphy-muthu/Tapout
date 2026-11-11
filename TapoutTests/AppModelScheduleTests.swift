import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelScheduleTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let schedules = FakeSchedules()
    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)

    private func makeModel() -> AppModel {
        AppModel(store: store, schedules: schedules, now: { [clock] in clock.now })
    }

    @Test func savingAScheduleStampsItAndRegisters() {
        let model = makeModel()
        var mode = model.activeMode
        mode.schedule = afternoons
        model.save(mode)
        #expect(store.scheduleSavedAt[mode.id.uuidString] == clock.now)
        #expect(schedules.synced.last?.first?.schedule == afternoons)
    }

    @Test func savingWithoutChangingTheScheduleDoesNotStamp() {
        let model = makeModel()
        var mode = model.activeMode
        mode.schedule = afternoons
        model.save(mode)
        let stamped = clock.now
        clock.now += 3600
        mode.name = "Deep work"
        model.save(mode)
        #expect(store.scheduleSavedAt[mode.id.uuidString] == stamped)
    }

    @Test func deletingAModeDropsItsStampAndRegisters() {
        let model = makeModel()
        let extra = Mode(name: "Evenings", schedule: afternoons)
        model.save(extra)
        #expect(model.deleteMode(id: extra.id))
        #expect(store.scheduleSavedAt[extra.id.uuidString] == nil)
        #expect(schedules.synced.last?.contains { $0.id == extra.id } == false)
    }
}
