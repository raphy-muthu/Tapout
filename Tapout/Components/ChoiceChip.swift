import SwiftUI

/// A 44pt toggle chip: ink when on, surface-2 when off. Used for days, places and suggestions.
struct ChoiceChip: View {
    let title: String
    let isOn: Bool
    /// Day chips share a row equally; name chips hug their text.
    var fillsWidth = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.glassControls) private var glass

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(fillsWidth ? .tSubhead.weight(.semibold) : .tSubhead.weight(.medium))
                .foregroundStyle(isOn ? Color.bg : Color.inkSecondary)
                .padding(.horizontal, fillsWidth ? 0 : Space.md)
                .padding(.vertical, Space.xxs) // keeps large labels off the edges
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                .background {
                    if glass && !isOn {
                        GlassPane(shape: Capsule(style: .continuous), tint: .surface2)
                    } else {
                        Capsule(style: .continuous).fill(isOn ? Color.ink : Color.surface2)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
