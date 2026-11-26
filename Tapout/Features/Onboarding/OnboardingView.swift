import FamilyControls
import SwiftUI

/// First-launch onboarding: design/screens/Main.dc.html six steps: welcome, Screen Time, apps, focus time, interests, first tag.
/// Saves everything at the end; pairing the first tag (or "Not now" on the last step) finishes it.
/// With the Living glass switch on, one glass orb stays above the steps (see `OnboardingOrb`).
struct OnboardingView: View {
    let model: AppModel
    /// The Lab's preview: asks iOS for nothing and offers a close button. Its caller passes a scratch model.
    var isPreview = false
    /// A stand-in for the tag reader; nil uses the real one.
    var scanner: (any TagScanning)? = nil
    let onFinish: () -> Void

    @Environment(\.glassControls) private var glass
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var draft = OnboardingDraft()
    @State private var pickingApps = false
    @State private var pickingAllowed = false
    @State private var pairing = false
    @State private var accessOutcome: ScreenTimeAccess.Outcome?
    @State private var requestingAccess = false
    /// The first tag paired, with the glass orb up: it seals before onboarding closes.
    @State private var paired = false

    var body: some View {
        VStack(spacing: Space.lg) {
            if glass { orbStage }
            Group {
                switch draft.step {
                case 1: ScrollsWhenTall { WelcomeStep() }
                case 2: ScrollsWhenTall { ScreenTimeStep() }
                case 3:
                    AppsStep(
                        selection: draft.selection,
                        alwaysAllowed: draft.alwaysAllowed,
                        onPickApps: { pickingApps = true },
                        onPickAllowed: { pickingAllowed = true }
                    )
                case 4: ScrollsWhenTall { FocusTimeStep(window: $draft.window, days: $draft.days) }
                case 5: ScrollsWhenTall { InterestsStep(interests: $draft.interests) }
                default: ScrollsWhenTall { PairStep(pairedName: paired ? model.defaultPlace?.name : nil) }
                }
            }
            // Fraunces styles are read once per render. The steps hold no state, so this resets nothing.
            .id(legibilityWeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .familyActivityPicker(isPresented: $pickingApps, selection: $draft.selection)
            footer
                .familyActivityPicker(isPresented: $pickingAllowed, selection: $draft.alwaysAllowed)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .background {
            GlassPageBackground(tone: paired ? .ember : .slate, isOn: glass,
                                strength: isHeroStep ? 1 : BackdropPlan.readingStrength)
                .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) {
            // Gone once paired: onboarding is about to close by itself.
            if isPreview && !paired {
                CircleIconButton(systemImage: "xmark", label: "Close preview", action: onFinish)
                    .padding(.horizontal, Space.lg)
            }
        }
        .environment(\.accent, .for(.unlocked))
        .sheet(isPresented: $pairing, onDismiss: pairingEnded) {
            PairPlaceSheet(model: model, scanner: scanner ?? TagScanners.live())
                .environment(\.glassControls, glass)
        }
    }

    /// Welcome, Screen Time and pairing are about the orb; the steps between are about their lists.
    private var isHeroStep: Bool {
        draft.step <= 2 || draft.step == OnboardingDraft.stepCount
    }

    /// One orb for the whole of onboarding, so it moves and changes instead of being replaced.
    private var orbStage: some View {
        let look = OnboardingOrb.look(step: draft.step, paired: paired, largeText: typeSize.isAccessibilitySize)
        return LivingOrb(tone: look.tone, ring: look.ring, size: OnboardingOrb.fullSize, rippleEvery: look.rippleEvery)
            .overlay {
                if let symbol = look.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 76, weight: .light))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            // Drawn once at full size and scaled, so a change of size animates.
            .scaleEffect(max(look.size, 1) / OnboardingOrb.fullSize)
            .frame(width: look.size, height: look.size)
            .opacity(look.size > 0 ? 1 : 0)
            .padding(.top, isHeroStep && !typeSize.isAccessibilitySize ? Space.xl : 0)
            .animation(Motion.travel(Motion.lock, reduceMotion: reduceMotion), value: look)
            // The steps crossfade around it; the orb itself must not slide or resize with Reduce Motion.
            .transaction { if reduceMotion { $0.animation = nil } }
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: Space.md) {
            // In the footer, so it stays on screen even when the step scrolls at large text sizes.
            if draft.step == 2, let message = accessOutcome?.message {
                Text(message)
                    .font(.tFootnote)
                    .foregroundStyle(Color.danger)
                    .multilineTextAlignment(.center)
            }
            StepDots(step: draft.step, count: OnboardingDraft.stepCount)
            PrimaryButton(title: draft.cta) { Task { await next() } }
                // The first tag just paired: nothing left to press while the orb seals.
                .opacity(paired ? 0 : 1)
                .disabled(paired)
            if draft.step == 4 || draft.step == OnboardingDraft.stepCount {
                textButton("Not now", action: skip)
                    .opacity(paired ? 0 : 1)
                    .disabled(paired)
            } else if draft.step == 2 && accessOutcome?.offersSettings == true {
                // iOS may not ask again after a decline, and Tapout can't block anything without
                // Screen Time, so the way forward is Settings rather than a skip.
                textButton("Open Settings", action: openSettings)
            }
        }
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tBody)
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    private func next() async {
        switch draft.step {
        case 2 where isPreview:
            advance()
        case 2:
            // A second tap during the request would advance twice and skip step 3.
            guard !requestingAccess else { return }
            requestingAccess = true
            defer { requestingAccess = false }
            let outcome = await ScreenTimeAccess.request()
            accessOutcome = outcome
            if outcome == .granted { advance() }
        case OnboardingDraft.stepCount:
            pairing = true
        default:
            advance()
        }
    }

    private func advance() {
        Haptics.select()
        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { draft.advance() }
    }

    /// Step 4 skips the schedule; the last step finishes without a tag (pair one in Places later).
    private func skip() {
        if draft.step == 4 {
            draft.window = nil
            advance()
        } else {
            finish()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Cancelling the sheet with no place stays on the last step. With a place, onboarding is done.
    private func pairingEnded() {
        guard !model.places.isEmpty, !paired else { return }
        guard glass else { return finish() }
        // Saved first, so nothing is lost if Tapout closes while the orb seals.
        save()
        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { paired = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            close()
        }
    }

    private func finish() {
        save()
        close()
    }

    private func save() {
        model.completeOnboarding(
            selection: draft.selection,
            alwaysAllowed: draft.alwaysAllowed,
            schedule: draft.schedule,
            interests: Interest.allCases.filter(draft.interests.contains)
        )
    }

    private func close() {
        if draft.schedule != nil && !isPreview { Task { await NoticePermission.request() } }
        onFinish()
    }
}

/// A step keeps its own layout while it fits. At the largest text sizes it scrolls, so the CTA stays on screen.
/// Scrolls only when the content is taller than the space, as at the largest text sizes.
struct ScrollsWhenTall<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.glassControls) private var glass

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content.padding(.horizontal, ShadowRoom.width(glass)) }
                .padding(.horizontal, -ShadowRoom.width(glass))
                .scrollIndicators(.hidden)
        }
    }
}

/// A scroll view clips at its edges, which cuts a glass card's shadow off square. With the switch on, a step's
/// scroll view runs to the screen's edges and its content keeps the page margin.
enum ShadowRoom {
    static func width(_ glass: Bool) -> CGFloat { glass ? Space.lg : 0 }
}

#Preview("Onboarding · dark") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.dark)
}

#Preview("Onboarding · glass") {
    OnboardingView(model: DemoData.previewModel()) {}
        .environment(\.glassControls, true).preferredColorScheme(.dark)
}

#Preview("Onboarding · light") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.light)
}
