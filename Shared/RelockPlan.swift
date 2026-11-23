import DeviceActivity
import Foundation
import os

/// How the emergency relock is scheduled. DeviceActivity refuses intervals under 15 minutes,
/// so both strategies stretch the interval and aim a callback at the 5-minute mark.
enum RelockStrategy: String, Codable, CaseIterable, Sendable {
    /// Interval starts now and lasts 15 min; `intervalWillEndWarning` fires 10 min before the end.
    case warning
    /// Interval started 10 min ago and ends at the relock time; `intervalDidEnd` fires.
    case pastStart
}

/// Builds the DeviceActivity schedule that ends an emergency pass.
enum RelockPlan {
    nonisolated(unsafe) static let activity = DeviceActivityName("tapout.emergency")
    /// DeviceActivity's shortest allowed interval.
    static let minimumInterval: TimeInterval = 15 * 60
    /// Full dates, so an interval that crosses midnight is not read as tomorrow's.
    static let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

    static func schedule(
        relockAt: Date,
        now: Date,
        strategy: RelockStrategy,
        calendar: Calendar = .current
    ) -> DeviceActivitySchedule {
        switch strategy {
        case .warning:
            let end = max(relockAt, now + minimumInterval)
            let lead = Int(end.timeIntervalSince(relockAt).rounded())
            return DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(components, from: now),
                intervalEnd: calendar.dateComponents(components, from: end),
                repeats: false,
                warningTime: DateComponents(minute: lead / 60, second: lead % 60)
            )
        case .pastStart:
            return DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(components, from: relockAt - minimumInterval),
                intervalEnd: calendar.dateComponents(components, from: relockAt),
                repeats: false
            )
        }
    }
}

/// The DeviceActivity name that ends a timer lock. Scheduled with the same `RelockPlan.schedule` strategies.
enum TimerPlan {
    nonisolated(unsafe) static let activity = DeviceActivityName("tapout.timer")
}

/// Starts and stops a one-off end schedule: the emergency relock, or a timer lock's end.
protocol RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws
    func cancel()
    /// What DeviceActivity actually stored for the activity, for the log.
    func scheduledSummary() -> String
}

struct RelockScheduler: RelockScheduling {
    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "relock")

    /// `RelockPlan.activity` for the emergency relock, `TimerPlan.activity` for a timer's end.
    let activity: DeviceActivityName

    init(activity: DeviceActivityName = RelockPlan.activity) {
        self.activity = activity
    }

    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])
        try center.startMonitoring(
            activity,
            during: RelockPlan.schedule(relockAt: relockAt, now: now, strategy: strategy)
        )
        Self.logger.info("Scheduled \(activity.rawValue, privacy: .public): \(scheduledSummary(), privacy: .public)")
    }

    func cancel() {
        DeviceActivityCenter().stopMonitoring([activity])
    }

    func scheduledSummary() -> String {
        let center = DeviceActivityCenter()
        let interval = center.schedule(for: activity)?.nextInterval
            .map { "\($0.start.formatted(date: .omitted, time: .standard))-\($0.end.formatted(date: .omitted, time: .standard))" }
        return "\(interval ?? "none"), \(center.activities.count) activities"
    }
}
