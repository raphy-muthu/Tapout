import Foundation

/// Which haptics a lock or unlock plays.
enum HapticRoute: Equatable {
    case classic, engine

    static func choose(livingGlass: Bool) -> HapticRoute { livingGlass ? .engine : .classic }
}

/// Lock and unlock haptics for the whole app: the Core Haptics patterns with the Living glass switch on,
/// today's `Haptics` with it off (the switch is Debug-only, so Release always plays today's).
@MainActor
enum LivingFeedback {
    static func lock() {
        switch HapticRoute.choose(livingGlass: AppSettings.livingGlassEnabled()) {
        case .engine: HapticEngine.shared.play(.lock)
        case .classic: Haptics.lock()
        }
    }

    static func unlock() {
        switch HapticRoute.choose(livingGlass: AppSettings.livingGlassEnabled()) {
        case .engine: HapticEngine.shared.play(.unlock)
        case .classic: Haptics.unlock()
        }
    }
}
