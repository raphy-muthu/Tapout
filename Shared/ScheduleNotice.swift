import Foundation
import UserNotifications

/// The few words a schedule says through a notification.
enum ScheduleNotice {
    static func locked(_ mode: Mode) -> (title: String, body: String) {
        (mode.name, "Locked until you tap a tag.")
    }

    static func skipped(_ mode: Mode, _ reason: ScheduledLock.Reason) -> (title: String, body: String) {
        switch reason {
        case .noApps: (mode.name, "Didn't lock: no apps chosen.")
        case .noAccess: (mode.name, "Didn't lock: Screen Time is off.")
        case .noTag: (mode.name, "Didn't lock: no tag paired.")
        }
    }

    /// A timer lock ended by itself.
    static func timerFinished(duration: TimeInterval) -> (title: String, body: String) {
        ("Time's up", "\(length(duration)) locked. Your apps are open.")
    }

    /// A timer lock ended inside `mode`'s scheduled window, so the mode's scheduled lock took over.
    static func timerHandedOver(_ mode: Mode) -> (title: String, body: String) {
        (mode.name, "Timer done. Locked until you tap a tag.")
    }

    /// "45 min", "1 h" or "1 h 30 min". `TimeFormat` lives in the app target, not `Shared`.
    private static func length(_ duration: TimeInterval) -> String {
        let minutes = max(0, Int((duration / 60).rounded()))
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(rest) min"
        }
    }
}

/// Posts a notification. A protocol, so tests can record instead.
protocol LockNotifying {
    func post(title: String, body: String)
}

/// A local notification, shown at once. Silently nothing when the owner said no to notifications.
struct LocalNotifier: LockNotifying {
    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        // Wait for the hand-off, so the extension isn't suspended before the request is queued.
        let queued = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { _ in queued.signal() }
        _ = queued.wait(timeout: .now() + 1)
    }
}
