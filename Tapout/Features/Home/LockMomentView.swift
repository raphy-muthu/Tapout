import SwiftUI

/// The lock storyboard from design/screens/LockFrame.dc.html:
/// 0 ms tag read + first rigid tap · 90 ms second tap and ring sweep ·
/// ~450 ms seal shockwave · 600 ms settled at 0:00.
struct LockMomentView: View {
    let placeName: String
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Storyboard frame, 1...4.
    @State private var frame = 1
    @State private var ring = 0.0

    var body: some View {
        VStack(spacing: 0) {
            placePill
            VStack(spacing: Space.lg) {
                orb
                caption
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .task { await play() }
    }

    private var placePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin").font(.system(size: 14, weight: .semibold))
            Text(placeName).font(.tSubhead.weight(.semibold))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color.surface1, in: Capsule(style: .continuous))
        .cardShadow()
        .frame(height: 44)
    }

    private var orb: some View {
        ZStack {
            if frame == 1 {
                ReadyRings().transition(.opacity)
            }
            if frame >= 3 && !reduceMotion {
                Shockwave(from: 280)
            }
            OrbView(tone: .slate, size: 280).opacity(frame == 1 ? 1 : 0)
            OrbView(tone: .ember, ring: ring, size: 280).opacity(frame == 1 ? 0 : 1)
        }
        .frame(width: 280, height: 280)
    }

    private var caption: some View {
        VStack(spacing: Space.xs) {
            if frame == 4 {
                Group {
                    TimerText(text: "0:00")
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
            } else if frame == 1 {
                Text("Hold still")
                    .font(.tTitle)
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(height: 150, alignment: .top)
    }

    private func play() async {
        Haptics.lock() // two rigid taps: now and at 90 ms
        if reduceMotion {
            withAnimation(Motion.lockReduced) {
                frame = 4
                ring = 1
            }
        } else {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(Motion.lock) {
                frame = 2
                ring = 1
            }
            try? await Task.sleep(for: .milliseconds(360))
            frame = 3
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(Motion.ui) { frame = 4 }
        }
        try? await Task.sleep(for: .milliseconds(700))
        onFinished()
    }
}

/// Frame 1: the tag-ready outline around the orb.
private struct ReadyRings: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.slateLine, lineWidth: 2)
                .frame(width: 312, height: 312)
                .opacity(0.7)
            Circle().strokeBorder(Color.slateLine, lineWidth: 1.5)
                .frame(width: 364, height: 364)
                .opacity(0.3)
        }
    }
}

/// Frame 3: one ripple of three ember rings expanding out from the orb and fading.
private struct Shockwave: View {
    let from: CGFloat
    @State private var expanded = false

    var body: some View {
        ZStack {
            ring(size: 380, width: 3, opacity: 0.55)
            ring(size: 540, width: 2, opacity: 0.3)
            ring(size: 740, width: 1.5, opacity: 0.14)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
    }

    private func ring(size: CGFloat, width: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(Color.emberLine, lineWidth: width)
            .frame(width: size, height: size)
            .scaleEffect(expanded ? 1 : from / size)
            .opacity(expanded ? 0 : opacity)
    }
}

#Preview {
    LockMomentView(placeName: MockData.placeName) {}
}
