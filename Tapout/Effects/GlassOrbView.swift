import SwiftUI

/// The shader-drawn orb. Same layout contract as `OrbView` (a `size` square, the glow spills outside it),
/// with live tilt, ripples and a slate-to-ember mix that animates under `withAnimation`.
struct GlassOrbView: View, Animatable {
    /// 0 is slate, 1 is ember.
    var tone: Double
    var ringTone: OrbTone?
    var ring: Double
    var size: CGFloat
    /// Read inside the timeline each frame, so tilt changes never re-render the view on their own clock.
    var tilt: @MainActor () -> SIMD2<Double>
    var ripples: OrbRipples
    /// 0 freezes the sway and ripples (the picture still draws).
    var amplitude: Double

    @Environment(\.colorScheme) private var colorScheme

    init(tone: Double, ringTone: OrbTone? = nil, ring: Double = 0, size: CGFloat = 300,
         tilt: @escaping @MainActor () -> SIMD2<Double> = { .zero }, ripples: OrbRipples = OrbRipples(), amplitude: Double = 1) {
        self.tone = tone
        self.ringTone = ringTone
        self.ring = ring
        self.size = size
        self.tilt = tilt
        self.ripples = ripples
        self.amplitude = amplitude
    }

    /// `nonisolated` because `Animatable` is not main-actor isolated (Swift 6); it only touches two Doubles.
    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(tone, ring) }
        set { tone = newValue.first; ring = newValue.second }
    }

    /// The shader's square: the orb plus room for the glow and ripples.
    private var canvas: CGFloat { size * 1.44 }

    var body: some View {
        let light = colorScheme == .light
        let colors = OrbColors.mixed(tone: tone, light: light)
        ZStack {
            TimelineView(.animation(minimumInterval: MotionBudget.frameInterval)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                let ages = ripples.ages(at: now)
                let tilt = tilt()
                Rectangle()
                    .fill(Color.white)
                    .frame(width: canvas, height: canvas)
                    .allowsHitTesting(false) // the canvas is 1.44x the orb; only the orb takes taps
                    // Argument order matches the Metal signature of `glassOrb` exactly.
                    .colorEffect(ShaderLibrary.glassOrb(
                        .float(canvas), .float(size),
                        .float(tilt.x * amplitude), .float(tilt.y * amplitude),
                        .float(now.truncatingRemainder(dividingBy: 86400)), .float(light ? 1 : 0),
                        .float3(Double(colors.hi.x), Double(colors.hi.y), Double(colors.hi.z)),
                        .float3(Double(colors.mid.x), Double(colors.mid.y), Double(colors.mid.z)),
                        .float3(Double(colors.deep.x), Double(colors.deep.y), Double(colors.deep.z)),
                        .float3(Double(colors.edge.x), Double(colors.edge.y), Double(colors.edge.z)),
                        .float3(Double(colors.glow.x), Double(colors.glow.y), Double(colors.glow.z)),
                        .float(Double(colors.glowAlpha)),
                        .float3(Double(colors.ripple.x), Double(colors.ripple.y), Double(colors.ripple.z)),
                        .float3(Double(ages.x), Double(ages.y), Double(ages.z)),
                        .float(amplitude)))
            }
            OrbSealRing(tone: ringTone ?? (tone >= 0.5 ? .ember : .slate), ring: ring, size: size)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        // Taps land on the orb, so a wrapping Button (locked Home's "Scan to unlock") works.
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone >= 0.5 ? (ring >= 1 ? "Sealed ember orb" : "Ember orb") : "Slate orb")
    }
}

#Preview("Glass orbs") {
    VStack(spacing: 60) {
        HStack(spacing: 40) {
            GlassOrbView(tone: 0, size: 150)
            GlassOrbView(tone: 1, ring: 1, size: 150)
        }
        HStack(spacing: 40) {
            OrbView(tone: .slate, size: 150)
            OrbView(tone: .ember, ring: 1, size: 150)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bg)
    .preferredColorScheme(.dark)
}
