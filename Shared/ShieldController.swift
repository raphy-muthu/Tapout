import FamilyControls
import ManagedSettings

/// Puts the chosen apps behind a shield, or takes it away.
protocol Shielding {
    func apply(_ selection: FamilyActivitySelection)
    func clear()
}

extension ManagedSettingsStore.Name {
    nonisolated(unsafe) static let tapout = Self("tapout")
}

/// Shields through Screen Time. Settings persist across launches and restarts until cleared.
struct ShieldController: Shielding {
    private let store = ManagedSettingsStore(named: .tapout)

    func apply(_ selection: FamilyActivitySelection) {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let sites = selection.webDomainTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = sites.isEmpty ? nil : sites
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    func clear() {
        store.clearAllSettings()
    }
}
