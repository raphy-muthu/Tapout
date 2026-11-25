import Foundation

/// The timer dial's maths: 6° per minute, 60 minutes per lap, two laps (5 min to 2 h), 5-minute steps.
/// Angles are clockwise from 12 o'clock, in degrees, with y pointing down (screen coordinates).
enum DialMath {
    static let step = 5
    static let minimum = 5
    static let maximum = 120

    struct Ticks: Equatable { var outer: Int; var inner: Int }
    /// Where the handle sits: `angle` in 0...360 (360 means a full lap), `lap` 0 (outer) or 1 (inner).
    struct Handle: Equatable { var angle: Double; var lap: Int }

    static func angle(dx: Double, dy: Double) -> Double {
        var a = atan2(dx, -dy) * 180 / .pi
        if a < 0 { a += 360 }
        return a
    }

    /// The shortest signed turn from `a` to `b`, in -180..<180.
    static func delta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d >= 180 { d -= 360 } else if d < -180 { d += 360 }
        return d
    }

    /// Unsnapped minutes after the finger moved from angle `a` to `b`. Relative, so a touch never jumps the value.
    static func dragged(minutes: Double, from a: Double, to b: Double) -> Double {
        min(Double(maximum), max(Double(minimum), minutes + delta(from: a, to: b) / 6))
    }

    static func snapped(_ minutes: Double) -> Int {
        min(maximum, max(minimum, Int((minutes / Double(step)).rounded()) * step))
    }

    /// How far past a step boundary the finger must go before the value changes.
    static let deadBand = 0.75

    /// `snapped`, with hysteresis: while `raw` stays within half a step plus `deadBand` of `current`,
    /// the value holds, so a finger resting on a boundary doesn't flip between two steps (and buzz).
    static func snapped(_ raw: Double, holding current: Int) -> Int {
        abs(raw - Double(current)) < Double(step) / 2 + deadBand ? current : snapped(raw)
    }

    static func litTicks(minutes: Int) -> Ticks {
        Ticks(outer: min(60, max(0, minutes)), inner: min(60, max(0, minutes - 60)))
    }

    static func handle(minutes: Int) -> Handle {
        let lap = minutes > 60 ? 1 : 0
        let inLap = minutes - lap * 60
        return Handle(angle: Double(inLap) * 6, lap: lap)
    }
}
