import SwiftUI

/// The milestone moment from design/screens/Insights.dc.html: a sealed ember orb in fading rings.
/// On appear it seals like the lock moment: the rings settle in from the outside, the seal ring
/// sweeps closed with one detent tick, and the words fade up.
struct MilestoneView: View {
    let milestone: Milestone
    let subtitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The outer rings and orb are in.
    @State private var ringsIn = false
    /// The orb's seal ring, 0...1.
    @State private var seal = 0.0
    /// The glow wash behind the orb.
    @State private var washIn = false
    /// The label, title and subtitle.
    @State private var wordsIn = false
    /// One ripple off the orb when the seal closes.
    @State private var ripple = false
    /// The hero block's opacity. Reduce Motion crossfades it in; otherwise it is simply set, so turning
    /// Reduce Motion on while the cover is open can't hide the hero.
    @State private var blockIn = false
    /// True while the sequence is live; the seal's completion checks it so a dismissed cover stays silent.
    @State private var isPlaying = false

    private struct Ring: Hashable {
        let size: CGFloat
        let width: CGFloat
        let opacity: Double
    }

    /// The fading outer rings, largest first (which is also the order they arrive in).
    private let rings = [Ring(size: 504, width: 1, opacity: 0.1), Ring(size: 408, width: 1.5, opacity: 0.2),
                         Ring(size: 320, width: 2, opacity: 0.4)]
    private static let specOrb: CGFloat = 240

    // Sequence timing, in seconds.
    private static let ringStagger = 0.12
    private static let ringFade = 0.5
    private static let sealStart = 0.15
    private static let sealDuration = 0.9
    private static let wordsDelay = 0.2 // after the seal starts

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
            .zIndex(1) // Close always draws above the decoration
            Spacer(minLength: Space.lg)
            // Shrinks the orb at the largest text sizes so the words still fit.
            ViewThatFits(in: .vertical) {
                moment(orb: 240)
                moment(orb: 120)
                // A long subtitle at the largest sizes scrolls rather than pushing Share off screen.
                // Soft top and bottom edges, so the rings and wash don't end on a hard line and the cut-off
                // subtitle reads as scrollable.
                ScrollView { moment(orb: 120).padding(.vertical, Space.lg) }
                    .scrollIndicators(.hidden)
                    .mask {
                        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                               .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
            }
            .opacity(blockIn ? 1 : 0)
            Spacer(minLength: Space.lg)
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
        .task { await play() }
        .onDisappear { isPlaying = false }
    }

    private func moment(orb: CGFloat) -> some View {
        let scale = orb / Self.specOrb
        return VStack(spacing: 40 * scale + Space.xs) {
            ZStack {
                ZStack {
                    ForEach(Array(rings.enumerated()), id: \.element) { index, ring in
                        Circle()
                            .strokeBorder(Color.emberLine, lineWidth: ring.width)
                            .frame(width: ring.size * scale, height: ring.size * scale)
                            .scaleEffect(ringsIn || reduceMotion ? 1 : 0.9)
                            .opacity(ringsIn ? ring.opacity : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: Self.ringFade)
                                .delay(Double(index) * Self.ringStagger), value: ringsIn)
                    }
                }
                .frame(width: rings[0].size * scale, height: rings[0].size * scale)
                .allowsHitTesting(false)
                // The rings dissolve below the orb so the words sit on a clear field.
                .mask {
                    LinearGradient(stops: [.init(color: .black, location: 0.74),
                                           .init(color: .clear, location: 0.9)],
                                   startPoint: .top, endPoint: .bottom)
                }
                if ripple {
                    RippleRing(from: orb)
                        .allowsHitTesting(false)
                }
                LivingOrb(tone: .ember, ring: seal, size: orb)
                    .opacity(ringsIn ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: ringsIn)
            }
            .frame(width: orb, height: orb)
            .background { wash(orb: orb) }
            .accessibilityHidden(true)
            words
        }
    }

    /// A soft ember wash centred behind the orb, reaching just past the outermost ring, so the page isn't flat.
    private func wash(orb: CGFloat) -> some View {
        let side = orb * 2.5
        let strength = colorScheme == .dark ? 1.0 : 0.55
        return Circle()
            .fill(RadialGradient(stops: [
                .init(color: Color.emberGlow.opacity(strength), location: 0),
                .init(color: Color.emberGlow.opacity(strength * 0.6), location: 0.35),
                .init(color: Color.emberGlow.opacity(strength * 0.18), location: 0.7),
                .init(color: Color.emberGlow.opacity(0), location: 1),
            ], center: .center, startRadius: 0, endRadius: side / 2))
            .frame(width: side, height: side)
            .opacity(washIn ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var words: some View {
        VStack(spacing: Space.sm) {
            VStack(spacing: Space.xs) {
                SectionLabel(text: "Milestone", color: .emberInk)
                Text(milestone.title)
                    .font(.milestoneTitle)
                    .foregroundStyle(Color.ink)
            }
            Text(subtitle)
                .font(.tBody)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 300)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(wordsIn ? 1 : 0)
        .offset(y: wordsIn || reduceMotion ? 0 : 10)
    }

    private func play() async {
        isPlaying = true
        if reduceMotion {
            // Everything simply there, crossfaded in as one block.
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                ringsIn = true
                seal = 1
                washIn = true
                wordsIn = true
            }
            withAnimation(Motion.reveal) { blockIn = true }
            Haptics.select()
            return
        }
        // The hero is visible from the start; each part animates itself in.
        var show = Transaction()
        show.disablesAnimations = true
        withTransaction(show) { blockIn = true }
        ringsIn = true // each ring animates itself, staggered outside-in
        do {
            try await Task.sleep(for: .seconds(Self.sealStart))
            // The haptic and ripple land when the seal sweep finishes, never on a dismissed cover.
            withAnimation(.easeInOut(duration: Self.sealDuration), completionCriteria: .logicallyComplete) {
                seal = 1
                washIn = true
            } completion: {
                guard isPlaying else { return }
                Haptics.select()
                ripple = true
            }
            try await Task.sleep(for: .seconds(Self.wordsDelay))
        } catch { return }
        withAnimation(.easeOut(duration: 0.5)) { wordsIn = true }
    }
}

/// One faint ember ring that leaves the orb as the seal closes, the quiet echo of the lock's shockwave.
private struct RippleRing: View {
    let from: CGFloat
    @State private var expanded = false

    var body: some View {
        Circle()
            .strokeBorder(Color.emberLine, lineWidth: 1.5)
            .frame(width: from, height: from)
            .scaleEffect(expanded ? 1.6 : 1)
            .opacity(expanded ? 0 : 0.4)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { expanded = true }
            }
    }
}

#Preview("Milestone · dark") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.dark)
}

#Preview("Milestone · light") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.light)
}

#Preview("Milestone · streak") {
    MilestoneView(milestone: .sevenDayStreak, subtitle: "A week of locks in a row.").preferredColorScheme(.dark)
}
