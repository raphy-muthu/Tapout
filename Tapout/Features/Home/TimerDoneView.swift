import SwiftUI

/// "Time's up": the calm moment after a timer lock ends, in the app or while Tapout was closed.
/// A small cousin of the milestone cover: a slate orb in a full ember ring, the length, and Done.
/// When a mode's scheduled lock took over at the end (`handedOverTo`), the orb stays ember and sealed and the
/// line says the mode is locked: the apps did not open.
struct TimerDoneView: View {
    let duration: TimeInterval
    var handedOverTo: String? = nil
    let onDone: () -> Void

    /// "45 min locked. Your apps are open.", or "45 min done. Evenings is locked until you tap a tag." on a hand-over.
    static func line(duration: TimeInterval, handedOverTo mode: String?) -> String {
        line(TimeFormat.length(duration), mode)
    }

    /// `line` for VoiceOver, with the length spelled out.
    static func spokenLine(duration: TimeInterval, handedOverTo mode: String?) -> String {
        line(TimeFormat.spokenLength(duration), mode)
    }

    private static func line(_ length: String, _ mode: String?) -> String {
        guard let mode else { return "\(length) locked. Your apps are open." }
        return "\(length) done. \(mode) is locked until you tap a tag."
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Space.lg)
            ViewThatFits(in: .vertical) {
                moment(orb: 200)
                moment(orb: 120)
                ScrollView { moment(orb: 120).padding(.vertical, Space.lg) }
                    .scrollIndicators(.hidden)
            }
            Spacer(minLength: Space.lg)
            PrimaryButton(title: "Done") {
                onDone()
                dismiss()
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.md)
        .background(Color.bg.ignoresSafeArea())
        .onAppear {
            withAnimation(reduceMotion ? Motion.reveal : .easeOut(duration: 0.6)) { shown = true }
        }
    }

    private func moment(orb: CGFloat) -> some View {
        VStack(spacing: Space.xl) {
            OrbView(tone: handedOverTo == nil ? .slate : .ember, ringTone: .ember, ring: 1, size: orb)
                .scaleEffect(shown || reduceMotion ? 1 : 0.94)
                .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text("Time's up")
                    .font(.tLargeTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(Self.line(duration: duration, handedOverTo: handedOverTo))
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 300)
                    .accessibilityLabel(Self.spokenLine(duration: duration, handedOverTo: handedOverTo))
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .offset(y: shown || reduceMotion ? 0 : 8)
        }
        .opacity(shown ? 1 : 0)
    }
}

#Preview("Time's up · dark") {
    TimerDoneView(duration: 45 * 60) {}.preferredColorScheme(.dark)
}

#Preview("Time's up · light") {
    TimerDoneView(duration: 90 * 60) {}.preferredColorScheme(.light)
}

#Preview("Time's up · handed over") {
    TimerDoneView(duration: 45 * 60, handedOverTo: "Evenings") {}.preferredColorScheme(.dark)
}
