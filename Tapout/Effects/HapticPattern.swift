import Foundation

/// One beat of a haptic pattern. A transient is a tap; a continuous event is a swell.
struct HapticEvent: Equatable {
    enum Kind { case transient, continuous }
    var kind: Kind
    var time: TimeInterval
    var duration: TimeInterval = 0
    var intensity: Float
    var sharpness: Float
}

/// What to use where Core Haptics is not available.
enum HapticFallback: Equatable { case lock, unlock, select }

/// The app's haptic vocabulary. Pure data, so the timing is testable.
enum HapticPattern: CaseIterable {
    /// Two rigid taps 90 ms apart (the spec rule), then a soft swell under the bloom.
    case lock
    /// One soft tap and a fading echo.
    case unlock
    /// A step settling on a dial.
    case detent
    /// A tick as a finger crosses a chart column.
    case scrub
    /// The lock pair at lower intensity, for a tag that just paired.
    case paired

    var events: [HapticEvent] {
        switch self {
        case .lock:
            [HapticEvent(kind: .transient, time: 0, intensity: 1, sharpness: 0.9),
             HapticEvent(kind: .transient, time: 0.09, intensity: 1, sharpness: 0.9),
             HapticEvent(kind: .continuous, time: 0.16, duration: 0.45, intensity: 0.35, sharpness: 0.1)]
        case .unlock:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.6, sharpness: 0.2),
             HapticEvent(kind: .transient, time: 0.18, intensity: 0.25, sharpness: 0.1)]
        case .detent:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.5, sharpness: 0.6)]
        case .scrub:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.3, sharpness: 0.8)]
        case .paired:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.7, sharpness: 0.8),
             HapticEvent(kind: .transient, time: 0.09, intensity: 0.7, sharpness: 0.8)]
        }
    }

    var fallback: HapticFallback {
        switch self {
        case .lock, .paired: .lock
        case .unlock: .unlock
        case .detent, .scrub: .select
        }
    }
}
