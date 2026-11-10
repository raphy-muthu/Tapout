import FamilyControls
import ManagedSettings

/// What one lock shields: the mode's apps, categories and sites, minus the always-allowed ones.
/// A category can't drop single apps from its token, so allowed apps become category exceptions.
struct ShieldPlan: Equatable {
    var applications: Set<ApplicationToken>
    var categories: Set<ActivityCategoryToken>
    var webDomains: Set<WebDomainToken>
    var allowedApplications: Set<ApplicationToken>
    var allowedWebDomains: Set<WebDomainToken>

    init(blocking blocked: FamilyActivitySelection, allowing allowed: FamilyActivitySelection) {
        applications = blocked.applicationTokens.subtracting(allowed.applicationTokens)
        // An always-allowed category stops that category's block; apps blocked by name still stay blocked.
        categories = blocked.categoryTokens.subtracting(allowed.categoryTokens)
        webDomains = blocked.webDomainTokens.subtracting(allowed.webDomainTokens)
        allowedApplications = allowed.applicationTokens
        allowedWebDomains = allowed.webDomainTokens
    }

    /// Nothing to shield, because the mode has no apps yet.
    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }
}

extension SharedStore {
    /// The active mode's shield. Every lock, relock and pass end uses it, in the app and in the
    /// monitor, so they always agree. Modes are read-only while locked, so it can't change mid-lock.
    var activeShieldPlan: ShieldPlan {
        let modes = self.modes
        let mode = modes.first { $0.id == activeModeID } ?? modes.first
        return ShieldPlan(blocking: mode?.selection ?? FamilyActivitySelection(), allowing: alwaysAllowed)
    }
}
