import SwiftUI
import UIKit

/// Fraunces has no tabular figures, so `.monospacedDigit()` does nothing and a `1` is far narrower
/// than a `0`. Anything that ticks gives each digit a slot as wide as the widest digit.
enum DigitSlots {
    static func digitWidth(face: FrauncesFace, size: CGFloat) -> CGFloat {
        let font = UIFont(name: face.rawValue, size: size) ?? .systemFont(ofSize: size)
        return "0123456789".map { String($0).size(withAttributes: [.font: font]).width }.max() ?? size
    }

    /// nil leaves anything else, such as the colon, at its natural width.
    static func width(of character: Character, digitWidth: CGFloat) -> CGFloat? {
        character.isNumber ? digitWidth : nil
    }
}

/// Numbers in Fraunces that don't shift as they change.
struct FixedDigitText: View {
    let text: String
    var face = FrauncesFace.display
    let size: CGFloat

    var body: some View {
        // Resolve once so the slots are measured in the face that is drawn.
        let face = face.resolved()
        let digitWidth = DigitSlots.digitWidth(face: face, size: size)
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.custom(face.rawValue, fixedSize: size))
                    .fixedSize()
                    .frame(width: DigitSlots.width(of: character, digitWidth: digitWidth))
            }
        }
        // Digits and colons are placed left to right; right-to-left would show the time reversed.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
