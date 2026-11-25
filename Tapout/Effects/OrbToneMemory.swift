/// The tone the glass orb last showed, app-wide. Home is rebuilt on every tab return, the glass branch is
/// inserted afresh after the background, and the keyboard swaps the unlocked orb's size, so an orb appearing
/// is not by itself a change of state. The memory tells a real lock or unlock from a fresh copy of the same orb.
@MainActor
final class OrbToneMemory {
    static let shared = OrbToneMemory()

    private var last: OrbTone?

    /// Records `tone` as shown and returns the tone shown before it (nil the first time).
    func swap(_ tone: OrbTone) -> OrbTone? {
        defer { last = tone }
        return last
    }
}

/// What a glass orb does as it appears.
struct OrbEntrance: Equatable {
    /// Where the warmth starts; nil means it is already settled in the orb's own tone.
    var warmFrom: OrbTone?
    /// Whether the orb sends a ripple.
    var ripples: Bool

    /// Swing (warm or cool, and ripple) only when the tone changed since an orb was last shown.
    static func decide(previous: OrbTone?, tone: OrbTone) -> OrbEntrance {
        if let previous, previous != tone {
            OrbEntrance(warmFrom: previous, ripples: true)
        } else {
            OrbEntrance(warmFrom: nil, ripples: false)
        }
    }

    /// With a change the caller knows (`known`), that wins over the memory. The warmth keeps the known start
    /// even when the orb appears before its tone changes (the lock moment appears slate and warms at frame 2).
    static func decide(known: OrbTone?, remembered: OrbTone?, tone: OrbTone) -> OrbEntrance {
        let swing = decide(previous: known ?? remembered, tone: tone)
        return OrbEntrance(warmFrom: known ?? swing.warmFrom, ripples: swing.ripples)
    }
}
