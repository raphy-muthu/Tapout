import DeviceActivity
import Foundation
import ManagedSettings
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

    /// `pinZone` stamps each moment with the calendar's time zone, so a later change of time zone in Settings
    /// doesn't move it.
    static func schedule(
        relockAt: Date,
        now: Date,
        strategy: RelockStrategy,
        calendar: Calendar = .current,
        pinZone: Bool = false
    ) -> DeviceActivitySchedule {
        func moment(_ date: Date) -> DateComponents {
            var parts = calendar.dateComponents(components, from: date)
            if pinZone { parts.timeZone = calendar.timeZone }
            return parts
        }
        switch strategy {
        case .warning:
            let end = max(relockAt, now + minimumInterval)
            let lead = Int(end.timeIntervalSince(relockAt).rounded())
            return DeviceActivitySchedule(
                intervalStart: moment(now),
                intervalEnd: moment(end),
                repeats: false,
                warningTime: DateComponents(minute: lead / 60, second: lead % 60)
            )
        case .pastStart:
            return DeviceActivitySchedule(
                intervalStart: moment(relockAt - minimumInterval),
                intervalEnd: moment(relockAt),
                repeats: false
            )
        }
    }

    /// The usage event that wakes the monitor once the shielded apps have been used for a pass's length, whatever
    /// the clock says. Real use of that length means the pass is over, so the monitor relocks.
    nonisolated(unsafe) static let usageEvent = DeviceActivityEvent.Name("tapout.emergency.used")

    static func usageEvents(for plan: ShieldPlan, length: TimeInterval) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        guard !plan.isEmpty else { return [:] }
        let seconds = Int(length.rounded())
        return [usageEvent: DeviceActivityEvent(applications: plan.applications, categories: plan.categories,
                                                webDomains: plan.webDomains,
                                                threshold: DateComponents(minute: seconds / 60, second: seconds % 60))]
    }
}

/// When the wall clock and the monotonic clock disagree, a wall-clock DeviceActivity callback comes at the wrong
/// real moment. This is the wall-clock date the callback should be moved to, or nil when they agree (to a minute).
enum ClockRearm {
    static let slack: TimeInterval = 60

    static func target(wallEnd: Date, realRemaining: TimeInterval?, now: Date) -> Date? {
        guard let realRemaining else { return nil }
        let target = now + realRemaining
        return abs(target.timeIntervalSince(wallEnd)) > slack ? target : nil
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
    /// For the emergency relock: the shield whose use wakes the monitor (`RelockPlan.usageEvents`).
    let usage: (@Sendable () -> ShieldPlan)?

    init(activity: DeviceActivityName = RelockPlan.activity, usage: (@Sendable () -> ShieldPlan)? = nil) {
        self.activity = activity
        self.usage = usage
    }

    /// Tries the strictest form first (time zone pinned, usage event), then plainer ones, so an extra that
    /// DeviceActivity refuses never stops a pass or timer from being scheduled at all.
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([activity])
        let events = usage.map { RelockPlan.usageEvents(for: $0(), length: max(60, relockAt.timeIntervalSince(now))) } ?? [:]
        let attempts: [(pinZone: Bool, events: [DeviceActivityEvent.Name: DeviceActivityEvent])] =
            [(true, events), (false, events), (false, [:])]
        var lastError: (any Error)?
        for attempt in attempts {
            do {
                try center.startMonitoring(
                    activity,
                    during: RelockPlan.schedule(relockAt: relockAt, now: now, strategy: strategy, pinZone: attempt.pinZone),
                    events: attempt.events
                )
                Self.logger.info("Scheduled \(activity.rawValue, privacy: .public): \(scheduledSummary(), privacy: .public)")
                return
            } catch {
                lastError = error
                Self.logger.error("Schedule attempt failed for \(activity.rawValue, privacy: .public): \(error)")
            }
        }
        throw lastError ?? CocoaError(.featureUnsupported)
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
