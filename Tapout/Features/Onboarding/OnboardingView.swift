import FamilyControls
import SwiftUI

/// First-launch onboarding: design/screens/Main.dc.html steps 1–4, plus the new focus-time step.
/// Saves everything at the end; pairing the first tag (or "Not now" on step 5) finishes it.
struct OnboardingView: View {
    let model: AppModel
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var draft = OnboardingDraft()
    @State private var pickingApps = false
    @State private var pickingAllowed = false
    @State private var pairing = false
    @State private var accessOutcome: ScreenTimeAccess.Outcome?
    @State private var requestingAccess = false

    var body: some View {
        VStack(spacing: Space.lg) {
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
                default: ScrollsWhenTall { PairStep(interests: $draft.interests) }
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
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
        .sheet(isPresented: $pairing, onDismiss: pairingEnded) {
            PairPlaceSheet(model: model)
        }
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
            if draft.step >= 4 {
                textButton("Not now", action: skip)
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

    /// Step 4 skips the schedule; step 5 finishes without a tag (pair one in Places later).
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

    /// Cancelling the sheet with no place stays on step 5. With a place, onboarding is done.
    private func pairingEnded() {
        if !model.places.isEmpty { finish() }
    }

    private func finish() {
        model.completeOnboarding(
            selection: draft.selection,
            alwaysAllowed: draft.alwaysAllowed,
            schedule: draft.schedule,
            interests: Interest.allCases.filter(draft.interests.contains)
        )
        onFinish()
    }
}

/// A step keeps its own layout while it fits. At the largest text sizes it scrolls, so the CTA stays on screen.
private struct ScrollsWhenTall<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollIndicators(.hidden)
        }
    }
}

#Preview("Onboarding · dark") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.dark)
}

#Preview("Onboarding · light") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.light)
}
