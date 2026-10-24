import UIKit

/// Haptics are the one feedback channel that survives Reduce Motion, so never skip them.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    /// Call when a tag session starts so the first lock tap lands on time.
    static func prepare() { rigid.prepare() }

    /// Two firm taps, 90 ms apart.
    static func lock() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    /// One soft tap.
    static func unlock() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }

    static func mismatch() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}
