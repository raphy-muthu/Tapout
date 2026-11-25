import SwiftUI

/// Two springs carry the brand; everything else stays out of the way.
enum Motion {
    static var lock: Animation { .spring(response: 0.6, dampingFraction: 0.72) }
    static var unlock: Animation { .spring(response: 0.8, dampingFraction: 0.9) }
    static var ui: Animation { .spring(response: 0.4, dampingFraction: 0.85) }
    static var press: Animation { .easeOut(duration: 0.15) }
    static var reveal: Animation { .easeInOut(duration: 0.4) }
    // Reduce Motion: crossfade in place, no scale or travel
    static var lockReduced: Animation { .easeInOut(duration: 0.25) }
    static var unlockReduced: Animation { .easeInOut(duration: 0.35) }
    static var readyPulse: Animation { .easeInOut(duration: 1.6).repeatForever(autoreverses: true) }

    /// The orb's slate-to-ember change.
    static var tone: Animation { .easeInOut(duration: 0.9) }
    /// Background warmth after a lock.
    static var bloom: Animation { .easeOut(duration: 1.2) }
    /// A chart or dial following a finger.
    static var scrub: Animation { .spring(response: 0.25, dampingFraction: 0.9) }
    /// A step settling into place.
    static var detent: Animation { .spring(response: 0.18, dampingFraction: 0.8) }

    /// The animation to use: `animation`, or a short crossfade when Reduce Motion is on.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : animation
    }
}
