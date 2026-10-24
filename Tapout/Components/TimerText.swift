import SwiftUI

/// Hero numerals. Scales with Dynamic Type but caps at 1.3× because it already fills the width.
struct TimerText: View {
    let text: String

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 112

    var body: some View {
        Text(text)
            .font(.system(size: min(size, 112 * 1.3), weight: .ultraLight, design: .rounded).monospacedDigit())
            .kerning(-3)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
