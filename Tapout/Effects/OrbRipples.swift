import Foundation
import simd

/// The start times of the orb's last few ripples. Pure bookkeeping; the shader draws them.
struct OrbRipples: Equatable {
    static let lifetime: TimeInterval = 1.5
    static let capacity = 3
    private var starts: [TimeInterval] = []

    mutating func add(at time: TimeInterval) {
        starts.append(time)
        if starts.count > Self.capacity { starts.removeFirst(starts.count - Self.capacity) }
    }

    /// Ages in seconds, newest first. -1 marks an empty or finished slot.
    func ages(at time: TimeInterval) -> SIMD3<Float> {
        var out = SIMD3<Float>(repeating: -1)
        for (slot, start) in starts.reversed().enumerated() where slot < Self.capacity {
            let age = time - start
            if age >= 0 && age < Self.lifetime { out[slot] = Float(age) }
        }
        return out
    }
}
