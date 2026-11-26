#if DEBUG
import Foundation

/// The Lab's replay of onboarding. Replaying the real one on a set-up phone would overwrite the active mode's
/// apps and schedule, so this runs over a scratch store with a stand-in tag reader.
enum OnboardingPreview {
    static let suite = "tapout.onboarding-preview"

    /// A model like a fresh install's, forgetting any earlier preview.
    @MainActor static func freshModel() -> AppModel {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return AppModel(store: SharedStore(defaults: UserDefaults(suiteName: suite)!))
    }

    /// One preview. Made when the button is pressed, so a redraw can't reset it midway.
    @MainActor struct Run: Identifiable {
        let id = UUID()
        let model = OnboardingPreview.freshModel()
    }

    /// "Reads" a new tag after a few seconds, long enough to watch the orb ripple.
    struct Scanner: TagScanning {
        @MainActor func scan(prompt: String) async throws -> TagUID {
            try await Task.sleep(for: .seconds(3))
            return TagUID(data: Data((0..<7).map { _ in UInt8.random(in: .min ... .max) }))
        }
    }
}
#endif
