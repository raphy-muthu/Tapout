import SwiftUI

extension EnvironmentValues {
    /// Frosted-glass controls (the tabs, their sheets and onboarding with the Living glass switch on). Off by
    /// default, so every other screen keeps its solid surfaces.
    @Entry var glassControls: Bool = false
}

/// A control's background: today's solid surface, or frosted glass with a light rim.
private struct ControlSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let fill: Color
    let shadowed: Bool

    @Environment(\.glassControls) private var glass
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if glass {
            content
                .background { GlassPane(shape: shape, tint: fill) }
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.12), radius: 14, y: 8)
        } else if shadowed {
            content.background(fill, in: shape).cardShadow()
        } else {
            content.background(fill, in: shape)
        }
    }
}

/// The pane itself: blur, a little of the surface color, a sheen from the top and a rim that catches the light.
struct GlassPane<S: InsettableShape>: View {
    let shape: S
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(tint.opacity(dark ? 0.28 : 0.35))
            shape.fill(LinearGradient(colors: [.white.opacity(dark ? 0.13 : 0.55), .white.opacity(0)],
                                      startPoint: .top, endPoint: .center))
            shape.strokeBorder(LinearGradient(
                stops: [.init(color: .white.opacity(dark ? 0.42 : 0.95), location: 0),
                        .init(color: .white.opacity(dark ? 0.06 : 0.35), location: 0.5),
                        .init(color: .white.opacity(dark ? 0.18 : 0.6), location: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }
}

extension View {
    /// `fill` is the solid surface used without glass, and the glass's tint.
    func controlSurface(_ fill: Color, in shape: some InsettableShape, shadowed: Bool = true) -> some View {
        modifier(ControlSurface(shape: shape, fill: fill, shadowed: shadowed))
    }
}
