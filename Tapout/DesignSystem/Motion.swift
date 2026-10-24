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
}
