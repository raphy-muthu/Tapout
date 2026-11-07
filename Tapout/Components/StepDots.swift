import SwiftUI

/// Onboarding's progress dots: the current step is a 24pt capsule.
struct StepDots: View {
    let step: Int
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(1...count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == step ? Color.ink : Color.inkTertiary)
                    .frame(width: index == step ? 24 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? Motion.reveal : Motion.ui, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of \(count)")
    }
}
