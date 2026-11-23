import Foundation

/// Stand-ins for the simulator and previews, where Screen Time shields and DeviceActivity don't run.
/// The app's own clock still relocks an expired pass and ends a timer, through `LockEngine.tick()`.
struct NoShields: Shielding {
    func apply(_ plan: ShieldPlan) {}
    func clear() {}
}

/// Stands in for both the emergency relock and the timer's end schedule.
struct NoRelock: RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {}
    func cancel() {}
    func scheduledSummary() -> String { "none (simulator)" }
}
