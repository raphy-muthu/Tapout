import DeviceActivity
import FamilyControls
import Foundation
import os
import WidgetKit

/// Runs in its own process, woken by DeviceActivity. Starts scheduled locks when a mode's window
/// begins (schedules never unlock), relocks an emergency pass at its relock time, and logs every
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
                                     accessReadout: readout)
        log(line, store, now)
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        relock(activity, callback: "intervalWillEndWarning")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if ModeActivity.modeID(of: activity) != nil {
            // Schedules never unlock: the end of a window changes nothing.
            log("Schedule window ended: \(activity.rawValue)", SharedStore.appGroup(), Date())
            return
        }
        relock(activity, callback: "intervalDidEnd")
    }

    /// What this process sees of Screen Time access; the rule in `ScheduledLock.accessApproved` decides.
    private static var liveAccess: ScheduledLock.LiveAccess {
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved { return .approved }
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return .approved }
        return status == .denied ? .denied : .notDetermined
    }

    private func log(_ line: String, _ store: SharedStore, _ now: Date) {
        Self.logger.info("\(line, privacy: .public) at \(now.formatted(date: .omitted, time: .standard), privacy: .public)")
        store.appendLog(line, source: .monitor, at: now)
    }

    private func relock(_ activity: DeviceActivityName, callback: String) {
        guard activity == RelockPlan.activity else { return }
        let store = SharedStore.appGroup()
        let now = Date()
        if let late = EmergencyRelock.perform(store: store, shields: ShieldController(), now: now) {
            log("\(callback): relocked, \(Int(late))s after relock time", store, now)
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            let reason = if case .emergency = store.session { "not due yet" } else { "nothing to relock" }
            log("\(callback): \(reason)", store, now)
        }
    }
}
