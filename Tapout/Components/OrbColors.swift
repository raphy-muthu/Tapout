import simd

/// The orb's gradient stops as RGB (0...1), the single source for `OrbView` and the shader.
/// Ported from Orb.dc.html; these are not design tokens, nothing else uses them.
struct OrbColors: Equatable {
    var hi, mid, deep, edge, glow, ripple: SIMD3<Float>
    var glowAlpha: Float

    private static func rgb(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(Float((hex >> 16) & 0xFF), Float((hex >> 8) & 0xFF), Float(hex & 0xFF)) / 255
    }

    static func ember(light: Bool) -> OrbColors {
        OrbColors(hi: rgb(0xFFE3C4), mid: rgb(0xFF9F43), deep: rgb(0xC0600F),
                  edge: rgb(light ? 0x8A3F06 : 0x3D1702), glow: rgb(0xFF9F43), ripple: rgb(0xFF9F43),
                  glowAlpha: light ? 0.42 : 0.5)
    }

    static func slate(light: Bool) -> OrbColors {
        OrbColors(hi: rgb(0xEEF1F6), mid: rgb(0x9AA3B4), deep: rgb(0x555E70),
                  edge: rgb(light ? 0x4A5263 : 0x141820), glow: rgb(0x8A94A6), ripple: rgb(0xC8D2E2),
                  glowAlpha: light ? 0.32 : 0.34)
    }

    /// 0 is slate, 1 is ember.
    static func mixed(tone: Double, light: Bool) -> OrbColors {
        let t = Float(min(1, max(0, tone)))
        let a = slate(light: light), b = ember(light: light)
        // x + (y - x) * 1 is not always exactly y in floating point, so the ends return the tones.
        if t == 0 { return a }
        if t == 1 { return b }
        func mix(_ x: SIMD3<Float>, _ y: SIMD3<Float>) -> SIMD3<Float> { x + (y - x) * t }
        return OrbColors(hi: mix(a.hi, b.hi), mid: mix(a.mid, b.mid), deep: mix(a.deep, b.deep),
                         edge: mix(a.edge, b.edge), glow: mix(a.glow, b.glow), ripple: mix(a.ripple, b.ripple),
                         glowAlpha: a.glowAlpha + (b.glowAlpha - a.glowAlpha) * t)
    }
}
