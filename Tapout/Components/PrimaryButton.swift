import SwiftUI

/// The one primary pill per screen, filled in the current state's accent.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.accent) private var accent
    @Environment(\.glassControls) private var glass

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
                }
                Text(title).font(.tHeadline).multilineTextAlignment(.center)
            }
            .foregroundStyle(accent.onFill)
            // Room around a large label; the pill grows rather than letting the words touch its edges.
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                Capsule(style: .continuous).fill(accent.fill)
                if glass { Gloss() }
            }
            .shadow(color: glass ? accent.fill.opacity(0.55) : .clear, radius: 16, y: 6)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// A wet highlight over the primary fill: bright along the top, a little shade below, a rim.
private struct Gloss: View {
    var body: some View {
        let shape = Capsule(style: .continuous)
        ZStack {
            shape.fill(LinearGradient(stops: [.init(color: .white.opacity(0.42), location: 0),
                                              .init(color: .white.opacity(0.08), location: 0.48),
                                              .init(color: .black.opacity(0), location: 0.52),
                                              .init(color: .black.opacity(0.14), location: 1)],
                                      startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.12)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
    }
}

/// Press feedback from the design system: scale 0.97, no colour change.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
