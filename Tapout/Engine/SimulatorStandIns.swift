import Foundation

/// Stand-ins for the simulator and previews, where Screen Time shields and DeviceActivity don't run.
/// The app's own clock still relocks an expired pass.
struct NoShields: Shielding {
    func apply(_ plan: ShieldPlan) {}
    func clear() {}
}

struct NoRelock: RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {}
    func cancel() {}
    func scheduledSummary() -> String { "none (simulator)" }
}
