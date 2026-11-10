import FamilyControls
import ManagedSettings

/// Puts the planned apps behind a shield, or takes it away.
protocol Shielding {
    func apply(_ plan: ShieldPlan)
    func clear()
}

extension ManagedSettingsStore.Name {
    nonisolated(unsafe) static let tapout = Self("tapout")
}

/// Shields through Screen Time. Settings persist across launches and restarts until cleared.
struct ShieldController: Shielding {
    private let store = ManagedSettingsStore(named: .tapout)

    func apply(_ plan: ShieldPlan) {
        let categories = plan.categories
        store.shield.applications = plan.applications.isEmpty ? nil : plan.applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: plan.allowedApplications)
        store.shield.webDomains = plan.webDomains.isEmpty ? nil : plan.webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: plan.allowedWebDomains)
    }

    func clear() {
        store.clearAllSettings()
    }
}
