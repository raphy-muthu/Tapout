import UIKit

/// Haptics are the one feedback channel that survives Reduce Motion, so never skip them for that.
/// The owner can still turn them off in Settings.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private static var isEnabled: Bool { AppSettings.hapticsEnabled() }

    /// Call when a tag session starts so the first lock tap lands on time.
    static func prepare() { rigid.prepare() }

    /// Two firm taps, 90 ms apart.
    static func lock() {
        guard isEnabled else { return }
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    /// One soft tap.
    static func unlock() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    static func mismatch() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func select() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
