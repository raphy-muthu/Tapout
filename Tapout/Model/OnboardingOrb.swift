import CoreGraphics
import Foundation

/// The one orb that stays on screen through onboarding, with the Living glass switch on.
enum OnboardingOrb {
    struct Look: Equatable {
        /// 0 hides the orb: the busy steps need the room at large text sizes.
        var size: CGFloat
        /// A sixth of the ring per step; the last sixth closes when the first tag pairs.
        var ring: Double
        var tone: OrbTone
        /// Seconds between ripples; nil for none.
        var rippleEvery: TimeInterval?
        /// An SF Symbol drawn on the orb.
        var symbol: String?
    }

    /// The largest size, which the orb is drawn at and then scaled from.
    static let fullSize: CGFloat = 260

    static func look(step: Int, paired: Bool, largeText: Bool) -> Look {
        let count = OnboardingDraft.stepCount
        let size: CGFloat = switch step {
        case 1: largeText ? 180 : fullSize
        case 2: largeText ? 120 : 190
        case count: largeText ? 150 : 230
        default: largeText ? 0 : 96
        }
        let filled = paired ? count : min(step, count - 1)
        return Look(
            size: size,
            ring: Double(filled) / Double(count),
            tone: paired ? .ember : .slate,
            rippleEvery: step == count && !paired ? 1.1 : nil,
            symbol: step == 2 ? "hourglass" : nil
        )
    }
}
