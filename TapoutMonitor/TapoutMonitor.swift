import DeviceActivity
import Foundation
import os

/// Runs in its own process, woken by DeviceActivity. Relocks an emergency pass when its
/// interval reaches the relock time, and logs every callback so the Lab shows when it fired.
final class TapoutMonitor: DeviceActivityMonitor {
    /// A second timing record, independent of the shared log (read it in Console.app).
    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Self.logger.info("intervalDidStart \(activity.rawValue, privacy: .public) at \(Date().formatted(date: .omitted, time: .standard), privacy: .public)")
        SharedStore.appGroup().appendLog("intervalDidStart \(activity.rawValue)", source: .monitor)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        relock(activity, callback: "intervalWillEndWarning")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        relock(activity, callback: "intervalDidEnd")
    }

    private func relock(_ activity: DeviceActivityName, callback: String) {
        guard activity == RelockPlan.activity else { return }
        let store = SharedStore.appGroup()
        let now = Date()
        let time = now.formatted(date: .omitted, time: .standard)
        if let late = EmergencyRelock.perform(store: store, shields: ShieldController(), now: now) {
            Self.logger.info("\(callback, privacy: .public) \(activity.rawValue, privacy: .public) at \(time, privacy: .public): relocked, \(Int(late), privacy: .public)s late")
            store.appendLog("\(callback): relocked, \(Int(late))s after relock time", source: .monitor, at: now)
        } else {
            Self.logger.info("\(callback, privacy: .public) \(activity.rawValue, privacy: .public) at \(time, privacy: .public): nothing to relock")
            store.appendLog("\(callback): nothing to relock", source: .monitor, at: now)
        }
    }
}
