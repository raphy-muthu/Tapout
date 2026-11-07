import SwiftUI

/// The milestone moment from design/screens/Insights.dc.html: a sealed ember orb in fading rings.
struct MilestoneView: View {
    let milestone: Milestone
    let subtitle: String

    @Environment(\.dismiss) private var dismiss

    private struct Ring: Hashable {
        let size: CGFloat
        let width: CGFloat
        let opacity: Double
    }

    /// The fading outer rings, largest first.
    private let rings = [Ring(size: 504, width: 1, opacity: 0.1), Ring(size: 408, width: 1.5, opacity: 0.2),
                         Ring(size: 320, width: 2, opacity: 0.4)]
    private static let specOrb: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
            Spacer(minLength: 0)
            // Shrinks the orb at the largest text sizes so the words still fit.
            ViewThatFits(in: .vertical) {
                moment(orb: 240)
                moment(orb: 120)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                ShareLink(item: "\(milestone.title), with Tapout.") {
                    Text("Share")
                        .font(.tHeadline)
                        .foregroundStyle(Color.onEmber)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.ember, in: Capsule(style: .continuous))
                }
                Button { dismiss() } label: {
                    Text("Done")
                        .font(.tBody)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.md)
        .background(Color.bg.ignoresSafeArea())
    }

    private func moment(orb: CGFloat) -> some View {
        VStack(spacing: 40) {
            ZStack {
                ForEach(rings, id: \.self) { ring in
                    Circle()
                        .strokeBorder(Color.emberLine, lineWidth: ring.width)
                        .opacity(ring.opacity)
                        .frame(width: ring.size * orb / Self.specOrb, height: ring.size * orb / Self.specOrb)
                }
                OrbView(tone: .ember, ring: 1, size: orb)
            }
            .frame(width: orb, height: orb)
            .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                SectionLabel(text: "Milestone", color: .emberInk)
                Text(milestone.title).font(.tLargeTitle).foregroundStyle(Color.ink)
                Text(subtitle).font(.tBody).foregroundStyle(Color.inkSecondary)
            }
            .multilineTextAlignment(.center)
        }
    }
}

#Preview("Milestone · dark") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.dark)
}

#Preview("Milestone · light") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.light)
}
