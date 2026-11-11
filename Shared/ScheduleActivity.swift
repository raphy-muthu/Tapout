import DeviceActivity
import Foundation

extension ModeSchedule {
    /// The window around `date`: it starts at `start` on one of `days` and lasts `duration` minutes,
    /// into the next day when `end` is before `start`. Times are wall-clock, so a 23- or 25-hour day keeps them.
    /// nil outside every window, or when the schedule is too short to run.
    func window(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard isRunnable else { return nil }
        let today = calendar.startOfDay(for: date)
        // A window that crosses midnight may have started yesterday.
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  days.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(bySettingHour: self.start / 60, minute: self.start % 60, second: 0, of: day,
                                            matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
                  let endDay = calendar.date(byAdding: .day, value: self.end > self.start ? 0 : 1, to: day),
                  let end = calendar.date(bySettingHour: self.end / 60, minute: self.end % 60, second: 0, of: endDay,
                                          matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
                  end > start else { continue }
            let window = DateInterval(start: start, end: end)
            if date >= window.start && date < window.end { return window }
        }
        return nil
    }
}

/// The DeviceActivity side of mode schedules: one daily activity per scheduled mode. The monitor
/// checks the weekday itself, because one activity per weekday would soon pass DeviceActivity's limit.
enum ModeActivity {
    static let prefix = "tapout.mode."
    /// DeviceActivity throws `excessiveActivities` past its limit; one slot stays free for the emergency relock.
    static let limit = 19

    static func name(for modeID: UUID) -> DeviceActivityName {
        DeviceActivityName(prefix + modeID.uuidString)
    }

    /// The mode behind an activity, or nil for anything else (the emergency relock).
    static func modeID(of activity: DeviceActivityName) -> UUID? {
        guard activity.rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(activity.rawValue.dropFirst(prefix.count)))
    }

    /// Repeats every day from the mode's start to its end, past midnight when the end is earlier.
    static func deviceSchedule(for schedule: ModeSchedule) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.start / 60, minute: schedule.start % 60),
            intervalEnd: DateComponents(hour: schedule.end / 60, minute: schedule.end % 60),
            repeats: true
        )
    }

    private static func wanted(_ modes: [Mode]) -> [(name: DeviceActivityName, schedule: ModeSchedule)] {
        modes.compactMap { mode in
            guard let schedule = mode.schedule, schedule.isRunnable, !schedule.days.isEmpty else { return nil }
            return (name(for: mode.id), schedule)
        }
    }

    /// How many modes have a schedule that could run, before the `limit` cut.
    static func runnableCount(in modes: [Mode]) -> Int { wanted(modes).count }

    /// The activities the modes need: runnable schedules only, in mode order, at most `limit`.
    static func plan(for modes: [Mode]) -> [(name: DeviceActivityName, schedule: ModeSchedule)] {
        Array(wanted(modes).prefix(limit))
    }
}
