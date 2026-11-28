/// What to do once a full-screen cover has gone, so a scan or sheet never starts while it is still leaving.
enum AfterCover: Equatable {
    /// "Try again" on the rejected screen: unlock when it was shown during a lock, else lock.
    case scan(unlocking: Bool)
    case pair, milestone
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

    /// Whether the owner's choice still means what it did when they made it. A lock can start or end while the
    /// cover is up (a schedule, a timer's end), and then "Try again" would do the opposite, or "Pair" would
    /// open pairing during a lock.
    func stillApplies(locked: Bool) -> Bool {
        switch self {
        case .scan(let unlocking): unlocking == locked
        case .pair: !locked
        case .milestone, .timerCheck: true
        }
    }
}
