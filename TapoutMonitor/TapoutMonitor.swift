import DeviceActivity
import FamilyControls
import Foundation
import os
import WidgetKit

/// Runs in its own process, woken by DeviceActivity. Starts scheduled locks when a mode's window
/// begins (schedules never unlock), relocks an emergency pass at its relock time, ends a timer lock, and logs every
/// callback so the Lab shows when it fired.
final class TapoutMonitor: DeviceActivityMonitor {
    /// A second timing record, independent of the shared log (read it in Console.app).
    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let store = SharedStore.appGroup()
        let now = Date()
        guard let modeID = ModeActivity.modeID(of: activity) else {
            log("intervalDidStart \(activity.rawValue)", store, now)
            return
        }
        let live = Self.liveAccess
        let mirrored = store.screenTimeApproved
        let readout = "live \(live), app \(mirrored.map(String.init(describing:)) ?? "nil")"
        let line = ScheduledLock.run(modeID: modeID, store: store, shields: ShieldController(),
                                     notifier: LocalNotifier(), now: now,
                                     accessApproved: ScheduledLock.accessApproved(live: live, mirrored: mirrored),
                                     accessReadout: readout, clock: ClockAnchor.current())
        log(line, store, now)
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        if activity == TimerPlan.activity { return endTimer(callback: "intervalWillEndWarning") }
        relock(activity, callback: "intervalWillEndWarning")
    }

    /// The shielded apps were used for a pass's length: whatever the clock says, the pass is over.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == RelockPlan.usageEvent else { return }
        relock(activity, callback: "eventDidReachThreshold")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if ModeActivity.modeID(of: activity) != nil {
            // Schedules never unlock: the end of a window changes nothing.
            log("Schedule window ended: \(activity.rawValue)", SharedStore.appGroup(), Date())
            return
        }
        if activity == TimerPlan.activity { return endTimer(callback: "intervalDidEnd") }
        relock(activity, callback: "intervalDidEnd")
    }

    /// What this process sees of Screen Time access; the rule in `ScheduledLock.accessApproved` decides.
    private static var liveAccess: ScheduledLock.LiveAccess {
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved { return .approved }
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return .approved }
        return status == .denied ? .denied : .notDetermined
    }

    /// The access rule a schedule start uses, for a timer handing over to a schedule.
    private static func accessApproved(_ store: SharedStore) -> Bool {
        ScheduledLock.accessApproved(live: liveAccess, mirrored: store.screenTimeApproved)
    }

    /// Lines can hold a mode's name, so they stay private in the system log.
    private func log(_ line: String, _ store: SharedStore, _ now: Date) {
        Self.logger.info("\(line, privacy: .private) at \(now.formatted(date: .omitted, time: .standard), privacy: .public)")
        store.appendLog(line, source: .monitor, at: now)
    }

    /// The pass relock. A due timer is finished first (`TimerLock.runMonitorRelock`), so the relock never
    /// re-locks a timer that is over.
    private func relock(_ activity: DeviceActivityName, callback: String) {
        guard activity == RelockPlan.activity else { return }
        let store = SharedStore.appGroup()
        let now = Date()
        let clock = ClockAnchor.current()
        let run = TimerLock.runMonitorRelock(store: store, shields: ShieldController(), notifier: LocalNotifier(), now: now,
                                             accessApproved: Self.accessApproved(store), clock: clock)
        for line in run.lines { log("\(callback): \(line)", store, now) }
        rearmIfClockMoved(store, now: now, clock: clock)
        if run.changed { WidgetCenter.shared.reloadAllTimelines() }
    }

    /// A callback booked in wall-clock time came early or late because the date, time or time zone moved:
    /// books the end again at the real end, so a timer or pass still ends on time.
    private func rearmIfClockMoved(_ store: SharedStore, now: Date, clock: ClockAnchor?) {
        if let timer = store.timerLock,
           let target = ClockRearm.target(wallEnd: timer.endsAt, realRemaining: timer.realRemaining(clock: clock), now: now) {
            rearm(RelockScheduler(activity: TimerPlan.activity), "timer", target: target, store: store, now: now)
        }
        if case .emergency(let relockAt, _) = store.session,
           let target = ClockRearm.target(wallEnd: relockAt,
                                          realRemaining: EmergencyRelock.realRemaining(store: store, clock: clock), now: now) {
            rearm(RelockScheduler(usage: { SharedStore.appGroup().activeShieldPlan }), "pass", target: target,
                  store: store, now: now)
        }
    }

    private func rearm(_ scheduler: RelockScheduler, _ what: String, target: Date, store: SharedStore, now: Date) {
        do {
            try scheduler.schedule(relockAt: target, now: now, strategy: store.relockStrategy)
            log("Clock changed: \(what) end moved to \(target.formatted(date: .omitted, time: .standard))", store, now)
        } catch {
            log("Clock changed: could not move the \(what) end: \(error)", store, now)
        }
    }

    private func endTimer(callback: String) {
        let store = SharedStore.appGroup()
        let now = Date()
        let clock = ClockAnchor.current()
        let line = TimerLock.runMonitorEnd(store: store, shields: ShieldController(), notifier: LocalNotifier(), now: now,
                                           accessApproved: Self.accessApproved(store), clock: clock)
        log("\(callback): \(line)", store, now)
        rearmIfClockMoved(store, now: now, clock: clock)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
