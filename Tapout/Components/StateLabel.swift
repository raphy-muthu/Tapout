import SwiftUI

/// The state word with its line glyph, e.g. "Locked" in ember-ink.
struct StateLabel: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
            Text(text).font(.tHeadline)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}
