import SwiftUI

/// Shown over everything when Screen Time access was turned off after onboarding: onboarding's
/// step 2 without the dots. Locks can't shield anything until access is back.
struct ScreenTimeAgainView: View {
    let onGranted: () -> Void

    @State private var outcome: ScreenTimeAccess.Outcome?
    @State private var requesting = false

    var body: some View {
        VStack(spacing: Space.lg) {
            ScrollsWhenTall { ScreenTimeStep() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: Space.md) {
                if let message = outcome?.message {
                    Text(message)
                        .font(.tFootnote)
                        .foregroundStyle(Color.danger)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "Allow") { Task { await allow() } }
                if outcome?.offersSettings == true {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.tBody)
                            .foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
    }

    private func allow() async {
        guard !requesting else { return }
        requesting = true
        defer { requesting = false }
        let result = await ScreenTimeAccess.request()
        outcome = result
        if result == .granted { onGranted() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Screen Time again · dark") {
    ScreenTimeAgainView {}.preferredColorScheme(.dark)
}

#Preview("Screen Time again · light") {
    ScreenTimeAgainView {}.preferredColorScheme(.light)
}
