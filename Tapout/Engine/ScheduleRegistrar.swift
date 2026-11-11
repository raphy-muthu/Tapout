import DeviceActivity
import Foundation

/// Keeps DeviceActivity's activities matching the modes' schedules. Returns the lines for the log: each start, each stop, and any problem.
protocol ScheduleRegistering {
    func sync(_ modes: [Mode]) -> [String]
}

/// The part of `DeviceActivityCenter` the registrar uses, so tests can record instead.
protocol ActivityCentering {
    var activities: [DeviceActivityName] { get }
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

struct LiveActivityCenter: ActivityCentering {
    private let center = DeviceActivityCenter()

    var activities: [DeviceActivityName] { center.activities }

    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        try center.startMonitoring(activity, during: schedule)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        center.stopMonitoring(activities)
    }
}

struct ScheduleRegistrar<Center: ActivityCentering>: ScheduleRegistering {
    let center: Center
    let store: SharedStore
    var now: () -> Date = Date.init

    func sync(_ modes: [Mode]) -> [String] {
        let plan = ModeActivity.plan(for: modes)
        let wanted = Set(plan.map(\.name))
        let running = center.activities
        let stale = running.filter { ModeActivity.modeID(of: $0) != nil && !wanted.contains($0) }
        var lines: [String] = []
        if !stale.isEmpty {
            center.stopMonitoring(stale)
            lines += stale.map { "Schedule stopped: \($0.rawValue)" }
        }
        var registered = store.registeredSchedules.filter { wanted.contains(DeviceActivityName($0.key)) }
        let dropped = ModeActivity.runnableCount(in: modes) - plan.count
        if dropped > 0 {
            lines.append("\(dropped) scheduled \(dropped == 1 ? "mode" : "modes") left out: at most \(ModeActivity.limit) can run")
        }
        for entry in plan {
            let key = entry.name.rawValue
            let isRunning = running.contains(entry.name)
            // Unchanged and running: leave it, so its window doesn't start again.
            if isRunning, registered[key] == entry.schedule { continue }
            if isRunning {
                center.stopMonitoring([entry.name])
                lines.append("Schedule stopped: \(key)")
            }
            // A restart can't lock mid-window: the monitor skips a window its schedule was stamped in.
            if let id = ModeActivity.modeID(of: entry.name) {
                var stamps = store.scheduleSavedAt
                stamps[id.uuidString] = now()
                store.scheduleSavedAt = stamps
            }
            do {
                try center.startMonitoring(entry.name, during: ModeActivity.deviceSchedule(for: entry.schedule))
                registered[key] = entry.schedule
                let name = ModeActivity.modeID(of: entry.name).flatMap { id in modes.first { $0.id == id }?.name } ?? key
                lines.append("Schedule started: \(name) \(Self.clock(entry.schedule.start))–\(Self.clock(entry.schedule.end))")
            } catch {
                registered[key] = nil
                lines.append("Schedule \(key) not started: \(error)")
            }
        }
        store.registeredSchedules = registered
        return lines
    }

    private static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}

/// For the simulator, previews and tests: DeviceActivity doesn't run there.
struct NoSchedules: ScheduleRegistering {
    func sync(_ modes: [Mode]) -> [String] { [] }
}

enum ScheduleRegistrars {
    static func live(store: SharedStore) -> any ScheduleRegistering {
        #if targetEnvironment(simulator)
        NoSchedules()
        #else
        ScheduleRegistrar(center: LiveActivityCenter(), store: store)
        #endif
    }
}
