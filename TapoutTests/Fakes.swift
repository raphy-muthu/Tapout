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

/// Counts shield calls instead of touching Screen Time.
final class FakeShields: Shielding {
    private(set) var applied = 0
    private(set) var cleared = 0

    func apply(_ selection: FamilyActivitySelection) { applied += 1 }
    func clear() { cleared += 1 }
}

/// Records relock schedules instead of calling DeviceActivity.
final class FakeRelock: RelockScheduling {
    struct Call: Equatable {
        let relockAt: Date
        let now: Date
        let strategy: RelockStrategy
    }

    var failure: (any Error)?
    private(set) var scheduled: [Call] = []
    private(set) var cancelled = 0

    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        if let failure { throw failure }
        scheduled.append(Call(relockAt: relockAt, now: now, strategy: strategy))
    }

    func cancel() { cancelled += 1 }

    func scheduledSummary() -> String { "fake schedule" }
}
