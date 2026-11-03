import SwiftUI

/// One pip per emergency pass: ember for each left, surface-2 for each used.
struct PassPips: View {
    let left: Int
    var total = SharedStore.totalPasses
    var width: CGFloat = 24
    var height: CGFloat = 8

    var body: some View {
        HStack(spacing: height > 8 ? 10 : 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < left ? Color.ember : Color.surface2)
                    .frame(width: width, height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(left) of \(total) passes left")
    }
}
