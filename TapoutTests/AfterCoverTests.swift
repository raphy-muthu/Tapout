import Testing
@testable import Tapout

/// What runs after a full-screen cover closes when a Time's up cover takes the turn first.
struct AfterCoverTests {
    @Test(arguments: [AfterCover.scan, .pair])
    func theOwnersChoiceWaitsForTheTimesUp(_ action: AfterCover) {
        #expect(AfterCover.deferring(action, over: nil) == action)
        #expect(AfterCover.deferring(action, over: .scan) == action)
    }

    @Test(arguments: [AfterCover.milestone, .timerCheck, nil] as [AfterCover?])
    func otherStepsDontDisplaceAWaitingChoice(_ action: AfterCover?) {
        // Milestones and the timer check come after the Time's up anyway.
        #expect(AfterCover.deferring(action, over: .pair) == .pair)
        #expect(AfterCover.deferring(action, over: nil) == nil)
    }
}
