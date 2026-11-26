import SwiftUI

/// Pure numbers for the glow that fills Home.
enum BackdropPlan {
    /// One soft pool of light, in screen fractions. `radius` is a fraction of the screen width.
    struct Pool: Equatable {
        var x: Double
        var y: Double
        var radius: Double
        var strength: Double
    }

    /// Frames per second for the drift. The pools are large and slow, so this stays low.
    static let framesPerSecond = 20.0

    /// How much of the glow shows behind a screen made mostly of text and numbers.
    static let readingStrength = 0.75

    /// The strongest the color gets at a pool's centre. Light mode is softer so text keeps its contrast.
    static func peak(tone: OrbTone, dark: Bool) -> Double {
        switch tone {
        case .ember: dark ? 0.46 : 0.34
        case .slate: dark ? 0.34 : 0.28
        }
    }

    /// The pools at `time`: one breathing behind the orb, two drifting low and high.
    static func pools(at time: Double) -> [Pool] {
        let breath = sin(time * 0.9)
        return [
            Pool(x: 0.5 + 0.03 * sin(time * 0.31), y: 0.36 + 0.012 * cos(time * 0.43),
                 radius: 1.02 + 0.09 * breath, strength: 0.88 + 0.12 * breath),
            Pool(x: 0.14 + 0.22 * sin(time * 0.23), y: 0.82 + 0.07 * cos(time * 0.29),
                 radius: 0.78 + 0.08 * sin(time * 0.37), strength: 0.62),
            Pool(x: 0.90 - 0.20 * cos(time * 0.19), y: 0.10 + 0.07 * sin(time * 0.27),
                 radius: 0.66 + 0.07 * cos(time * 0.41), strength: 0.5),
        ]
    }
}

/// A slow, breathing glow of the state's color behind the tabs, their sheets and onboarding. Decorative only; state is always also in words.
struct LivingBackdrop: View {
    let tone: OrbTone
    /// False holds the pools still (motion limited).
    var animates = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / BackdropPlan.framesPerSecond, paused: !animates)) { context in
            let time = animates ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400) : 0
            let pools = BackdropPlan.pools(at: time)
            ZStack {
                layer(.slate, pools: pools).opacity(tone == .slate ? 1 : 0)
                layer(.ember, pools: pools).opacity(tone == .ember ? 1 : 0)
            }
        }
        .animation(Motion.bloom, value: tone)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layer(_ tone: OrbTone, pools: [BackdropPlan.Pool]) -> some View {
        Pools(color: tone == .ember ? .ember : .slate, pools: pools, tone: tone)
    }

    private struct Pools: View {
        let color: Color
        let pools: [BackdropPlan.Pool]
        let tone: OrbTone
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let peak = BackdropPlan.peak(tone: tone, dark: colorScheme == .dark)
            GeometryReader { proxy in
                ForEach(pools.indices, id: \.self) { index in
                    let pool = pools[index]
                    let radius = proxy.size.width * pool.radius
                    let alpha = peak * pool.strength
                    Circle()
                        .fill(RadialGradient(stops: [
                            .init(color: color.opacity(alpha), location: 0),
                            .init(color: color.opacity(alpha * 0.55), location: 0.36),
                            .init(color: color.opacity(alpha * 0.16), location: 0.68),
                            .init(color: color.opacity(0), location: 1),
                        ], center: .center, startRadius: 0, endRadius: radius))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: proxy.size.width * pool.x, y: proxy.size.height * pool.y)
                }
            }
        }
    }
}

/// The lock moment's bloom: ember light bursting from the orb across the screen, then fading into the backdrop.
/// Place it as the orb's background; it overflows without taking layout space.
struct LockBloom: View {
    private struct Frame {
        var scale = 0.16
        var opacity = 0.0
    }

    @State private var fired = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strength = colorScheme == .dark ? 1.0 : 0.75
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: .ember.opacity(0.85 * strength), location: 0),
                .init(color: .ember.opacity(0.62 * strength), location: 0.42),
                .init(color: .ember.opacity(0.30 * strength), location: 0.74),
                .init(color: .ember.opacity(0), location: 1),
            ], center: .center, startRadius: 0, endRadius: 800))
            .frame(width: 1600, height: 1600)
            .keyframeAnimator(initialValue: Frame(), trigger: fired) { view, frame in
                view.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.0, duration: 0.62)
                    CubicKeyframe(1.15, duration: 0.7)
                }
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(1.0, duration: 0.16)
                    CubicKeyframe(0.75, duration: 0.42)
                    CubicKeyframe(0.0, duration: 0.7)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { fired = true }
    }
}
