import UserNotifications

/// Scheduled locks happen while Tapout is closed, so a notification says when one starts or can't.
enum NoticePermission {
    /// Asks once; later calls return the first answer without asking again.
    static func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
