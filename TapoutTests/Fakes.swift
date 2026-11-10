import FamilyControls
import Foundation
@testable import Tapout

struct FakeError: Error {}

extension SharedStore {
    /// A store on a throwaway defaults suite, so tests never touch the App Group.
    /// Pass the same `suite` twice to get two stores over the same data.
    static func makeTest(suite: String = "tapout.tests.\(UUID().uuidString)") -> SharedStore {
        SharedStore(defaults: UserDefaults(suiteName: suite)!)
    }
}

/// Records shield calls instead of touching Screen Time.
final class FakeShields: Shielding {
    private(set) var plans: [ShieldPlan] = []
    private(set) var cleared = 0
    /// Called at the start of `apply` / `clear`, before the call is recorded, so a test can see what
    /// the store held at that moment. Tests run on the main actor.
    var onApply: (@MainActor () -> Void)?
    var onClear: (@MainActor () -> Void)?

    var applied: Int { plans.count }

    func apply(_ plan: ShieldPlan) {
        if let onApply { MainActor.assumeIsolated { onApply() } }
        plans.append(plan)
    }

    func clear() {
        if let onClear { MainActor.assumeIsolated { onClear() } }
        cleared += 1
    }
}

/// Records relock schedules instead of calling DeviceActivity.
final class FakeRelock: RelockScheduling {
    struct Call: Equatable {
        let relockAt: Date
        let now: Date
        let strategy: RelockStrategy
    }

    var failure: (any Error)?
    /// Called at the start of `cancel`; see `FakeShields.onApply`.
    var onCancel: (@MainActor () -> Void)?
    private(set) var scheduled: [Call] = []
    private(set) var cancelled = 0

    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        if let failure { throw failure }
        scheduled.append(Call(relockAt: relockAt, now: now, strategy: strategy))
    }

    func cancel() {
        if let onCancel { MainActor.assumeIsolated { onCancel() } }
        cancelled += 1
    }

    func scheduledSummary() -> String { "fake schedule" }
}
