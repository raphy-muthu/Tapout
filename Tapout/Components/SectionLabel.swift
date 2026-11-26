import SwiftUI

/// The specs' small uppercase label above a group: 12pt medium, tracking 0.4.
struct SectionLabel: View {
    let text: String
    /// nil is the usual tertiary ink, or the stronger secondary ink on glass, where the glow sits behind it.
    var color: Color? = nil

    @Environment(\.glassControls) private var glass

    var body: some View {
        Text(text)
            .font(.tCaption)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(color ?? (glass ? .inkSecondary : .inkTertiary))
            .accessibilityAddTraits(.isHeader)
    }
}
