import SwiftUI

/// Home in its three states, matching design/screens/Home.dc.html.
struct HomeView: View {
    let controller: MockLockController
    let onScan: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(modeName: MockData.modeName, isLocked: isLocked, onOpenSettings: onOpenSettings)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                switch controller.session {
                case .unlocked: unlocked
                case .locked: locked(at: context.date)
                case .emergency: emergency(at: context.date)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
    }

    private var isLocked: Bool {
        if case .locked = controller.session { true } else { false }
    }

    private var unlocked: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: Space.xl) {
                OrbView(tone: .slate, size: 300)
                VStack(spacing: Space.xxs) {
                    StateLabel(text: "Unlocked", systemImage: "lock.open", color: .slateInk)
                    Text("\(TimeFormat.short(MockData.phoneFreeToday)) phone-free today")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Scan", systemImage: "wave.3.right", action: onScan)
        }
    }

    private func locked(at date: Date) -> some View {
        let elapsed = controller.session.elapsed(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                // Stand-in for tapping a tag until Core NFC arrives in Phase 4.
                Button(action: unlock) {
                    OrbView(tone: .ember, ring: 1, size: 244)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock")
                .accessibilityHint("Stands in for tapping your tag")
                .lockMomentMatch(.orb)

                VStack(spacing: Space.xs) {
                    TimerText(text: TimeFormat.clock(elapsed))
                        .accessibilityLabel("Locked for \(TimeFormat.spoken(elapsed))")
                        .lockMomentMatch(.timer)
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                        .lockMomentMatch(.stateWord)
                }
            }
            Spacer(minLength: 0)
            if controller.passesLeft > 0 {
                Button(action: useEmergencyPass) {
                    Text("Emergency pass · \(controller.passesLeft) left")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emergency(at date: Date) -> some View {
        let remaining = controller.session.remaining(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                OrbView(tone: .slate, ringTone: .ember,
                        ring: controller.session.remainingFraction(at: date), size: 244)
                VStack(spacing: Space.xxs) {
                    Text("Relocks in")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                    TimerText(text: TimeFormat.clock(remaining.rounded(.up)))
                        .accessibilityLabel("Relocks in \(TimeFormat.spoken(remaining))")
                    Text("Emergency pass · \(controller.passesLeft) of \(MockLockController.totalPasses) left")
                        .font(.tFootnote.weight(.medium))
                        .foregroundStyle(Color.emberInk)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Relock now", action: relockNow)
        }
    }

    private func unlock() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { controller.simulateTagRead() }
    }

    private func useEmergencyPass() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) { controller.useEmergencyPass() }
    }

    private func relockNow() {
        Haptics.lock()
        withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { controller.relockNow() }
    }
}

#Preview("Unlocked · dark") {
    RootView().preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))))
        .preferredColorScheme(.dark)
}

#Preview("Emergency · dark") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2))
        .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Locked · light") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))))
        .preferredColorScheme(.light)
}

#Preview("Emergency · light") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2))
        .preferredColorScheme(.light)
}
