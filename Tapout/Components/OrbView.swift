import SwiftUI

enum OrbTone {
    case ember, slate
}

/// The glass orb hero, ported from `renderVals()` in design/screens/Orb.dc.html:
/// a glow, a glass body, a specular gloss and an optional seal ring.
struct OrbView: View {
    var tone: OrbTone
    /// Colour of the seal ring; defaults to the orb's own tone.
    var ringTone: OrbTone? = nil
    /// How much of the seal ring is drawn, 0...1.
    var ring: Double = 0
    var size: CGFloat = 300

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = OrbPalette(tone: tone, light: colorScheme == .light)
        let sphere = size * (1 - 2 * 0.13)
        ZStack {
            glow(palette)
            glassBody(palette, sphere: sphere)
            gloss(sphere: sphere)
            OrbSealRing(tone: ringTone ?? tone, ring: ring, size: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// Radial halo, 1.44× the orb, centred behind it.
    private func glow(_ palette: OrbPalette) -> some View {
        let side = size * 1.44
        return Circle()
            .fill(RadialGradient(stops: [
                .init(color: palette.glow.opacity(palette.glowAlpha), location: 0),
                .init(color: palette.glow.opacity(palette.glowAlpha * 0.35), location: 0.38),
                .init(color: palette.glow.opacity(0), location: 0.68),
            ], center: .center, startRadius: 0, endRadius: side / 2 * 1.4142)) // CSS farthest-corner
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }

    private func glassBody(_ palette: OrbPalette, sphere: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(stops: [
                    .init(color: palette.hi, location: 0),
                    .init(color: palette.mid, location: 0.34),
                    .init(color: palette.deep, location: 0.72),
                    .init(color: palette.edge, location: 1),
                ], center: UnitPoint(x: 0.5, y: 0.58), startRadius: 0, endRadius: sphere * 0.766)
                .shadow(.inner(color: .white.opacity(0.14), radius: sphere * 0.05, y: -sphere * 0.05))
                .shadow(.inner(color: .black.opacity(0.28), radius: sphere * 0.06, y: sphere * 0.06))
            )
            .overlay {
                // Light pooling at the bottom of the glass
                EllipseHighlight(rx: 0.7, ry: 0.34, cx: 0.5, cy: 0.92, side: sphere, stops: [
                    .init(color: .white.opacity(0.32), location: 0),
                    .init(color: .white.opacity(0), location: 0.7),
                ])
                .clipShape(Circle())
            }
            .overlay { Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
            .frame(width: sphere, height: sphere)
            .shadow(color: palette.dropShadow, radius: sphere * 0.09, y: sphere * 0.08)
    }

    private func gloss(sphere: CGFloat) -> some View {
        ZStack {
            EllipseHighlight(rx: 0.30, ry: 0.20, cx: 0.35, cy: 0.24, side: sphere, stops: [
                .init(color: .white.opacity(0.92), location: 0),
                .init(color: .white.opacity(0.35), location: 0.45),
                .init(color: .white.opacity(0), location: 1),
            ])
            EllipseHighlight(rx: 0.12, ry: 0.07, cx: 0.66, cy: 0.78, side: sphere, stops: [
                .init(color: .white.opacity(0.4), location: 0),
                .init(color: .white.opacity(0), location: 1),
            ])
        }
        .frame(width: sphere, height: sphere)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    private var label: String {
        switch tone {
        case .ember: ring >= 1 ? "Sealed ember orb" : "Ember orb"
        case .slate: "Slate orb"
        }
    }
}

/// The seal ring drawn around an orb. Always in the tree (an empty trim draws nothing)
/// so the ring can sweep in when animated.
struct OrbSealRing: View {
    var tone: OrbTone
    /// How much of the ring is drawn, 0...1.
    var ring: Double
    var size: CGFloat

    init(tone: OrbTone, ring: Double, size: CGFloat) {
        self.tone = tone
        self.ring = ring
        self.size = size
    }

    var body: some View {
        let progress = min(max(ring, 0), 1)
        let stroke = max(2.5, size * 0.016)
        let ember = tone == .ember
        ZStack {
            Circle()
                .stroke(Color.track, lineWidth: stroke)
                .opacity(progress > 0 && progress < 1 ? 1 : 0)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ember ? Color.emberLine : Color.slateLine,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size - stroke * 3, height: size - stroke * 3)
        .shadow(color: (ember ? Color.ember : Color.slate).opacity(0.7), radius: size * 0.025)
        .allowsHitTesting(false)
    }
}

/// CSS `radial-gradient(ellipse rx% ry% at cx% cy%, …)` drawn in a `side` × `side` box.
private struct EllipseHighlight: View {
    let rx: CGFloat, ry: CGFloat, cx: CGFloat, cy: CGFloat
    let side: CGFloat
    let stops: [Gradient.Stop]

    var body: some View {
        let radius = side * rx
        Circle()
            .fill(RadialGradient(stops: stops, center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(x: 1, y: ry / rx)
            .position(x: side * cx, y: side * cy)
            .frame(width: side, height: side)
    }
}

/// The orb's gradient stops as SwiftUI colours, built from the shared `OrbColors` table.
private struct OrbPalette {
    let hi, mid, deep, edge, glow, dropShadow: Color
    let glowAlpha: Double

    init(tone: OrbTone, light: Bool) {
        let colors = tone == .ember ? OrbColors.ember(light: light) : OrbColors.slate(light: light)
        hi = Color(colors.hi)
        mid = Color(colors.mid)
        deep = Color(colors.deep)
        edge = Color(colors.edge)
        glow = Color(colors.glow)
        glowAlpha = Double(colors.glowAlpha)
        dropShadow = light
            ? Color(.sRGB, red: 0x15 / 255, green: 0x17 / 255, blue: 0x1B / 255).opacity(0.18)
            : .black.opacity(0.5)
    }
}

private extension Color {
    init(_ rgb: SIMD3<Float>) {
        self.init(.sRGB, red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
    }
}

#Preview("Orbs") {
    VStack(spacing: 60) {
        OrbView(tone: .slate, size: 200)
        OrbView(tone: .ember, ring: 1, size: 200)
        OrbView(tone: .slate, ringTone: .ember, ring: 0.6, size: 200)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bg)
}
