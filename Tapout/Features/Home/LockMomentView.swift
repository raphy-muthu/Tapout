import SwiftUI

/// The lock storyboard from design/screens/LockFrame.dc.html:
/// 0 ms tag read + first rigid tap · 90 ms second tap and ring sweep ·
/// ~450 ms seal shockwave · 600 ms settled at 0:00.
struct LockMomentView: View {
    let placeName: String
    /// The lock that just started; drives the timer once it settles.
    let session: LockSession
    /// What the lock is for, shown under "Locked".
    var intention: String? = nil
    /// A timer lock counts down, so the overlay matches Home's countdown when it hands over.
    var timer: TimerLock? = nil
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Storyboard frame, 1...4.
    @State private var frame = 1
    @State private var ring = 0.0
    @LivingGlassFlag private var livingGlass

    var body: some View {
        VStack(spacing: 0) {
            placePill
                // Above the glass orb's warmth, which spills past the orb. Only with the switch on, so the
                // classic shockwave still draws over the pill exactly as before.
                .zIndex(livingGlass ? 1 : 0)
            VStack(spacing: Space.lg) {
                orb
                caption
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.bg
                // The locked background arrives with the lock, so Home takes over without a jump.
                if livingGlass {
                    LivingGlassReader { choice in
                        if choice == .glass {
                            LivingBackdrop(tone: frame > 1 ? .ember : .slate)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .task { await play() }
    }

    private var placePill: some View {
        HStack(spacing: 6) {
            PinGlyph(size: 16, lineWidth: 1.8)
            Text(placeName).font(.tSubhead.weight(.semibold))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, Space.xxs)
        .frame(minHeight: 36)
        .controlSurface(.surface1, in: Capsule(style: .continuous))
        .environment(\.glassControls, livingGlass)
        .frame(minHeight: 44)
    }

    private var orb: some View {
        LivingGlassReader { choice in
            switch choice {
            case .classic:
                classicOrb
            case .glass:
                // One orb. The tone change at frame 2 sends the shader ripple that replaces the shockwave,
                // and `warmth` starts slate and settles ember. The seal ring is ember from the first frame
                // of its sweep, as in the classic path (at frame 1 it is 0 and draws nothing).
                ZStack {
                    if frame == 1 {
                        ReadyRings().transition(.opacity)
                    }
                    LivingOrb(tone: frame == 1 ? .slate : .ember, ringTone: .ember, ring: ring, size: 280,
                              warmth: frame > 1, changedFrom: .slate)
                }
                .frame(width: 280, height: 280)
                .background { if frame > 1 { LockBloom() } }
                .lockMomentMatch(.orb, inOverlay: true)
                // This is the lock. Home's orb, appearing ember underneath or after the hand-over, must not
                // swing from slate a second time.
                .onAppear { _ = OrbToneMemory.shared.swap(.ember) }
            }
        }
    }

    private var classicOrb: some View {
        ZStack {
            if frame == 1 {
                ReadyRings().transition(.opacity)
            }
            if frame >= 3 && !reduceMotion {
                Shockwave(from: 280)
            }
            LivingOrb(tone: .slate, size: 280).opacity(frame == 1 ? 1 : 0)
            LivingOrb(tone: .ember, ring: ring, size: 280).opacity(frame == 1 ? 0 : 1)
        }
        .frame(width: 280, height: 280)
        .lockMomentMatch(.orb, inOverlay: true)
    }

    private var caption: some View {
        VStack(spacing: Space.xs) {
            if frame == 4 {
                Group {
                    // Live, so the digits match Home's timer when the overlay hands over.
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        if let timer {
                            TimerText(text: TimeFormat.clock(timer.remaining(at: context.date).rounded(.up)))
                        } else {
                            TimerText(text: TimeFormat.clock(session.elapsed(at: context.date)))
                        }
                    }
                    .lockMomentMatch(.timer, inOverlay: true)
                    StateLabel(text: timer == nil ? "Locked" : "Locked · timer", systemImage: "lock", color: .emberInk)
                        .lockMomentMatch(.stateWord, inOverlay: true)
                    if let intention {
                        Text(intention)
                            .font(.tSubhead)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .lockMomentMatch(.intention, inOverlay: true)
                    }
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
            } else if frame == 1 {
                Text("Hold still")
                    .font(.tTitle)
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(height: 204, alignment: .top)
    }

    private func play() async {
        // Two rigid taps: now and at 90 ms.
        LivingFeedback.lock()
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
    LockMomentView(placeName: "Kitchen", session: .locked(since: .now), intention: "Essay outline") {}
}
