import SwiftUI

/// Pure numbers for the warmth behind the glass orb.
enum OrbWarmthPlan {
    /// The color drawn: `from` until it settles, then its own. No `from` is settled at once.
    static func shown(tone: OrbTone, from: OrbTone?, settled: Bool) -> OrbTone {
        settled ? tone : from ?? tone
    }
    /// 2.6× the orb, past the orb's own 1.44× glow.
    static func side(orb: CGFloat) -> CGFloat { orb * 2.6 }
    /// As the milestone wash: full in dark, 55% in light.
    static func strength(dark: Bool) -> Double { dark ? 1 : 0.55 }
}

/// A soft circle of `ember-glow` or `slate-glow` behind the glass orb (the tokens' rule: a blurred circle,
/// never a full-screen wash). Given `from`, it appears in that color and settles into its own over `Motion.bloom`;
/// without it, it appears settled.
struct OrbWarmth: View {
    let tone: OrbTone
    /// The state the orb just left, or nil when nothing changed.
    let from: OrbTone?
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        let side = OrbWarmthPlan.side(orb: size)
        let strength = OrbWarmthPlan.strength(dark: colorScheme == .dark)
        let shown = OrbWarmthPlan.shown(tone: tone, from: from, settled: settled)
        ZStack {
            disc(Color.slateGlow, side: side, strength: strength).opacity(shown == .slate ? 1 : 0)
            disc(Color.emberGlow, side: side, strength: strength).opacity(shown == .ember ? 1 : 0)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard from != nil else { settled = true; return }
            withAnimation(Motion.resolved(Motion.bloom, reduceMotion: reduceMotion)) { settled = true }
        }
    }

    private func disc(_ color: Color, side: CGFloat, strength: Double) -> some View {
        Circle().fill(RadialGradient(stops: [
            .init(color: color.opacity(strength), location: 0),
            .init(color: color.opacity(strength * 0.6), location: 0.35),
            .init(color: color.opacity(strength * 0.18), location: 0.7),
            .init(color: color.opacity(0), location: 1),
        ], center: .center, startRadius: 0, endRadius: side / 2))
    }
}
