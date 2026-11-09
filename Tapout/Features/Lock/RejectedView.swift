import SwiftUI

/// What the rejected screen says about a tag that can't do what was asked.
struct RejectedTag: Equatable {
    let title: String
    let hint: String?
    /// Only while unlocked, so a new sticker can never be paired to escape a lock.
    let canPair: Bool

    static func unknown(tryPlaces: [String], locked: Bool) -> RejectedTag {
        RejectedTag(title: "That's not one of your tags.", hint: hint(tryPlaces, locked: locked), canPair: !locked)
    }

    /// A paired tag that the active mode doesn't unlock at.
    static func wrongPlace(mode: String, tryPlaces: [String]) -> RejectedTag {
        RejectedTag(title: "Not for \(mode).", hint: hint(tryPlaces, locked: true), canPair: false)
    }

    /// "Try Kitchen or Desk." from the first two places. With none, point to Places, which only helps while unlocked.
    private static func hint(_ places: [String], locked: Bool) -> String? {
        switch places.count {
        case 0: locked ? nil : "Pair one in Places."
        case 1: "Try \(places[0])."
        default: "Try \(places[0]) or \(places[1])."
        }
    }
}

/// The unknown-tag screen from design/screens/Rejected.dc.html.
struct RejectedView: View {
    let rejected: RejectedTag
    let onTryAgain: () -> Void
    let onPair: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
                Spacer()
            }
            Spacer(minLength: 0)
            if typeSize.isAccessibilitySize {
                // A smaller orb at accessibility sizes so the words fit whole; scrolls if even that is too tall.
                ViewThatFits(in: .vertical) {
                    moment(scale: 0.5)
                    ScrollView { moment(scale: 0.5) }.scrollIndicators(.hidden)
                }
            } else {
                moment(scale: 1)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                PrimaryButton(title: "Try again") {
                    onTryAgain()
                    dismiss()
                }
                if rejected.canPair {
                    Button {
                        onPair()
                        dismiss()
                    } label: {
                        Text("Pair as a new place")
                            .font(.tBody)
                            .foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.md)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
    }

    private func moment(scale: CGFloat) -> some View {
        VStack(spacing: 40 * scale) {
            ZStack {
                Circle()
                    .stroke(Color.danger, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [46 * scale, 32 * scale]))
                    .opacity(0.9)
                    .frame(width: 248 * scale, height: 248 * scale)
                OrbView(tone: .slate, size: 220 * scale)
            }
            .frame(width: 260 * scale, height: 260 * scale)
            .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text(rejected.title)
                    .font(.tTitle1)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: typeSize.isAccessibilitySize ? nil : 300)
                if let hint = rejected.hint {
                    Text(hint).font(.tBody).foregroundStyle(Color.inkSecondary)
                }
            }
            .multilineTextAlignment(.center)
        }
    }
}

#Preview("Rejected · dark") {
    RejectedView(rejected: .unknown(tryPlaces: ["Kitchen", "Desk"], locked: false), onTryAgain: {}, onPair: {})
        .preferredColorScheme(.dark)
}

#Preview("Rejected · light") {
    RejectedView(rejected: .unknown(tryPlaces: ["Kitchen", "Desk"], locked: false), onTryAgain: {}, onPair: {})
        .preferredColorScheme(.light)
}
