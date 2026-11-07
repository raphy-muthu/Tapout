import Foundation

/// The 10-second hold that spends an emergency pass. Kept apart from the view so the timing is testable.
struct HoldCountdown: Equatable {
    static let duration: TimeInterval = 10
    /// The most hold time one tick can add, so a suspension or stall can't jump the hold to done.
    static let maxStep: TimeInterval = 0.25

    /// 0 … 1 of the hold.
    var progress: Double = 0

    var isDone: Bool { progress >= 1 }

    var secondsLeft: Int {
        isDone ? 0 : Int((Self.duration * (1 - progress)).rounded(.up))
    }

    var label: String {
        if isDone { return "Pass used" }
        return progress > 0 ? "Keep holding" : "Hold"
    }

    var title: String { isDone ? "Apps open" : "Hold for 10 seconds" }

    /// Adds one tick of hold time, capped at `maxStep`.
    mutating func advance(by elapsed: TimeInterval) {
        let step = min(max(0, elapsed), Self.maxStep)
        progress = Self.progress(held: progress * Self.duration + step)
    }

    static func progress(held: TimeInterval) -> Double {
        min(1, max(0, held / duration))
    }
}
