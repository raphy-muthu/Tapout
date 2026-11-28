import Testing
@testable import Tapout

/// What runs after a full-screen cover closes when a Time's up cover takes the turn first.
struct AfterCoverTests {
    @Test(arguments: [AfterCover.scan(unlocking: true), .scan(unlocking: false), .pair])
    func theOwnersChoiceWaitsForTheTimesUp(_ action: AfterCover) {
        #expect(AfterCover.deferring(action, over: nil) == action)
        #expect(AfterCover.deferring(action, over: .scan(unlocking: false)) == action)
    }

    @Test(arguments: [AfterCover.milestone, .timerCheck, nil] as [AfterCover?])
    func otherStepsDontDisplaceAWaitingChoice(_ action: AfterCover?) {
        // Milestones and the timer check come after the Time's up anyway.
        #expect(AfterCover.deferring(action, over: .pair) == .pair)
        #expect(AfterCover.deferring(action, over: nil) == nil)
    }

    /// A lock that started or ended while the cover was up must not turn "Try again" into its opposite.
    @Test func tryAgainOnlyRunsInTheStateItWasChosenIn() {
        #expect(AfterCover.scan(unlocking: true).stillApplies(locked: true))
        #expect(!AfterCover.scan(unlocking: true).stillApplies(locked: false))
        #expect(AfterCover.scan(unlocking: false).stillApplies(locked: false))
        #expect(!AfterCover.scan(unlocking: false).stillApplies(locked: true))
    }

    @Test func pairingNeverOpensDuringALock() {
        #expect(AfterCover.pair.stillApplies(locked: false))
        #expect(!AfterCover.pair.stillApplies(locked: true))
        #expect(AfterCover.milestone.stillApplies(locked: true))
    }
}
