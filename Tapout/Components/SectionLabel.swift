import SwiftUI

/// The specs' small uppercase label above a group: 12pt medium, tracking 0.4.
struct SectionLabel: View {
    let text: String
    var color: Color = .inkTertiary

    var body: some View {
        Text(text)
            .font(.tCaption)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}
