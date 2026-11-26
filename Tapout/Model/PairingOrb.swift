import Foundation

/// The orb on the pairing sheet, with the Living glass switch on: ripples while it waits, then seals in ember.
enum PairingOrb {
    struct Look: Equatable {
        var tone: OrbTone
        var ring: Double
        /// Seconds between ripples; nil for none.
        var rippleEvery: TimeInterval?
    }

    static func look(_ phase: PairPlaceSheet.Phase) -> Look {
        switch phase {
        case .scanning: Look(tone: .slate, ring: 0, rippleEvery: 1.1)
        case .found: Look(tone: .ember, ring: 1, rippleEvery: nil)
        case .failed: Look(tone: .slate, ring: 0, rippleEvery: nil)
        }
    }
}
