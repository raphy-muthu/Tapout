import SwiftUI

/// Hero numerals. Scales with Dynamic Type but caps at 1.3× because it already fills the width,
/// and steps down if a long time still wouldn't fit.
struct TimerText: View {
    let text: String

    @ScaledMetric(relativeTo: .largeTitle) private var scaledSize: CGFloat = 112

    var body: some View {
        let size = min(scaledSize, 112 * 1.3)
        ViewThatFits(in: .horizontal) {
            FixedDigitText(text: text, size: size)
            FixedDigitText(text: text, size: size * 0.85)
            FixedDigitText(text: text, size: size * 0.7)
        }
        .foregroundStyle(Color.ink)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
