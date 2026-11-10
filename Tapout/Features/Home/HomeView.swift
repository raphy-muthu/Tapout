import SwiftUI

/// Home in its three states, matching design/screens/Home.dc.html, plus the optional lock intention.
struct HomeView: View {
    let engine: LockEngine
    let model: AppModel
    @Binding var intentionDraft: String
    /// Reads a tag to lock or unlock. The locked orb uses it too: tap the orb, then the tag.
    let onScan: () -> Void
    let onEmergencyPass: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(
                modes: model.modes,
                activeMode: model.activeMode,
                showsLockGlyph: isLocked,
                onSelectMode: { model.setActiveMode($0) },
                onOpenSettings: onOpenSettings
            )
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                switch engine.session {
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
        if case .locked = engine.session { true } else { false }
    }

    private var unlocked: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Shrinks the orb when the keyboard is up for the intention field.
            ViewThatFits(in: .vertical) {
                orbAndState(size: 300)
                orbAndState(size: 200)
                orbAndState(size: 120)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.sm) {
                IntentionField(text: $intentionDraft, recent: model.recentIntentions)
                PrimaryButton(title: "Scan", systemImage: "wave.3.right", action: onScan)
            }
        }
    }

    private func orbAndState(size: CGFloat) -> some View {
        VStack(spacing: Space.xl) {
            OrbView(tone: .slate, size: size)
            VStack(spacing: Space.xxs) {
                StateLabel(text: "Unlocked", systemImage: "lock.open", color: .slateInk)
                Text("\(TimeFormat.short(model.phoneFreeToday())) phone-free today")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private func locked(at date: Date) -> some View {
        // Without pass time. The record can be a moment behind the lock state at launch, and previews have none.
        let elapsed = model.runningLockTime(at: date) ?? engine.session.elapsed(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                Button(action: onScan) {
                    // Smaller at accessibility sizes, so the intention and the pass link fit without truncating.
                    OrbView(tone: .ember, ring: 1, size: typeSize.isAccessibilitySize ? 120 : 244)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan to unlock")
                .accessibilityHint("Then hold your tag near the top of your iPhone")
                .lockMomentMatch(.orb)

                VStack(spacing: Space.xs) {
                    TimerText(text: TimeFormat.clock(elapsed))
                        .accessibilityLabel("Locked for \(TimeFormat.spoken(elapsed))")
                        .lockMomentMatch(.timer)
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                        .lockMomentMatch(.stateWord)
                    if let intention = model.currentIntention {
                        Text(intention)
                            .font(.tSubhead)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                            .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
                            .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                            .lockMomentMatch(.intention)
                    }
                }
            }
            Spacer(minLength: 0)
            if engine.passesLeft > 0 {
                Button(action: onEmergencyPass) {
                    Text("Emergency pass · \(engine.passesLeft) left")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emergency(at date: Date) -> some View {
        let remaining = engine.session.remaining(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                OrbView(tone: .slate, ringTone: .ember,
                        ring: engine.session.remainingFraction(at: date), size: typeSize.isAccessibilitySize ? 140 : 244)
                VStack(spacing: Space.xxs) {
                    Text("Relocks in")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                    TimerText(text: TimeFormat.clock(remaining.rounded(.up)))
                        .accessibilityLabel("Relocks in \(TimeFormat.spoken(remaining))")
                    Text("Emergency pass · \(engine.passesLeft) of \(SharedStore.totalPasses) left")
                        .font(.tFootnote.weight(.medium))
                        .foregroundStyle(Color.emberInk)
                        .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Relock now", action: relockNow)
        }
    }

    private func relockNow() {
        Haptics.lock()
        withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { engine.relockNow() }
        model.endPass()
    }
}

private extension RootView {
    /// Previews show Home, not onboarding: the flag sits in a scratch suite.
    func onboardedForPreview() -> some View {
        let defaults = UserDefaults(suiteName: "tapout.preview")!
        defaults.set(true, forKey: AppSettings.onboardedKey)
        return defaultAppStorage(defaults)
    }
}

// The previews use DEBUG-only LockEngine.preview.
#if DEBUG
#Preview("Unlocked · dark") {
    RootView(engine: .preview(), model: DemoData.previewModel()).onboardedForPreview().preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    RootView(engine: .preview(session: .locked(since: .now - (47 * 60 + 12)), passesLeft: 3), model: DemoData.previewModel())
        .onboardedForPreview()
        .preferredColorScheme(.dark)
}

#Preview("Emergency · dark") {
    RootView(engine: .preview(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2),
             model: DemoData.previewModel())
        .onboardedForPreview()
        .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    RootView(engine: .preview(), model: DemoData.previewModel()).onboardedForPreview().preferredColorScheme(.light)
}

#Preview("Locked · light") {
    RootView(engine: .preview(session: .locked(since: .now - (47 * 60 + 12)), passesLeft: 3), model: DemoData.previewModel())
        .onboardedForPreview()
        .preferredColorScheme(.light)
}

#Preview("Emergency · light") {
    RootView(engine: .preview(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2),
             model: DemoData.previewModel())
        .onboardedForPreview()
        .preferredColorScheme(.light)
}
#endif
