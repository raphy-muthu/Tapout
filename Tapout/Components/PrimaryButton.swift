import SwiftUI

/// The one primary pill per screen, filled in the current state's accent.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
                }
                Text(title).font(.tHeadline)
            }
            .foregroundStyle(accent.onFill)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(accent.fill, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
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
