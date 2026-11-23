/// What to do once a full-screen cover has gone, so a scan or sheet never starts while it is still leaving.
enum AfterCover: Equatable {
    case scan, pair, milestone
    /// The Time's up cover closed: "Did you do it?" if the timer had an intention, else milestones.
    case timerCheck

    /// A Time's up cover takes the turn when a cover closes. The owner's own choice ("Try again", "Pair")
    /// waits for it and runs after the Time's up and its "Did you do it?". Milestones and the timer check
    /// follow a Time's up anyway, so they never displace a waiting choice. Returns the action to keep waiting.
    static func deferring(_ action: AfterCover?, over waiting: AfterCover?) -> AfterCover? {
        switch action {
        case .scan, .pair: action
        case .milestone, .timerCheck, nil: waiting
        }
    }
}
