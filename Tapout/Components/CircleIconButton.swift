import SwiftUI

/// The specs' 44pt round buttons: back, close and add.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = .inkSecondary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Color.surface1, in: Circle())
                .cardShadow()
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }
}
