import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Owner preferences. App-only, so they live in standard defaults; views bind with `@AppStorage`.
enum AppSettings {
    static let hapticsKey = "settings.haptics"
    /// The Live Activity for a running lock. On unless the owner turned it off.
    static let liveActivityKey = "settings.liveActivity"
    static let appearanceKey = "settings.appearance"
    /// Set once onboarding is finished or skipped.
    static let onboardedKey = "settings.onboarded"

    /// On unless the owner turned it off.
    static func hapticsEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: hapticsKey) as? Bool ?? true
    }
}
