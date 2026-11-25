import Foundation

/// Turns raw gravity samples into a small, smooth tilt vector.
/// The "rest pose" slowly follows the phone, so the light settles when the phone is held still
/// and only reacts to movement. Positive x: the right edge dips. Positive y: the top edge tips away.
struct TiltFilter {
    var smoothing: Double
    var restRate: Double
    var gain: Double
    private var smoothed: SIMD2<Double>?
    private var rest: SIMD2<Double>?
    private(set) var value: SIMD2<Double> = .zero

    init(smoothing: Double = 0.2, restRate: Double = 0.01, gain: Double = 2.4) {
        self.smoothing = smoothing
        self.restRate = restRate
        self.gain = gain
    }

    @discardableResult
    mutating func update(gravityX: Double, gravityY: Double) -> SIMD2<Double> {
        let sample = SIMD2(gravityX, gravityY)
        let s = smoothed.map { $0 + (sample - $0) * smoothing } ?? sample
        let r = rest.map { $0 + (s - $0) * restRate } ?? s
        smoothed = s
        rest = r
        let raw = (s - r) * gain
        value = SIMD2(min(1, max(-1, raw.x)), min(1, max(-1, raw.y)))
        return value
    }

    mutating func reset() {
        smoothed = nil
        rest = nil
        value = .zero
    }
}
