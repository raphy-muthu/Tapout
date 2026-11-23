import Foundation
import Testing
@testable import Tapout

struct LiveActivityPlanTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func shot(_ state: LockSnapshot.State) -> LockSnapshot { .sample(state) }

    @Test func nothingToDoWhileUnlockedWithoutOne() {
        #expect(LiveActivityPlan.decide(snapshot: shot(.unlocked), enabled: true, current: nil) == .none)
    }

    @Test func unlockingEndsIt() {
        let running = LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))
        #expect(LiveActivityPlan.decide(snapshot: shot(.unlocked), enabled: true, current: running) == .end)
    }

    @Test func turningItOffEndsIt() {
        let locked = shot(.locked(countingFrom: now))
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: false, current: LiveActivityPlan.content(for: locked)) == .end)
    }

    @Test func aLockStartsOne() throws {
        let state = try #require(LiveActivityPlan.content(for: shot(.locked(countingFrom: now))))
        #expect(state.lockedFrom == now)
        #expect(state.openUntil == nil)
        #expect(state.modeName == "Deep work")
        #expect(LiveActivityPlan.decide(snapshot: shot(.locked(countingFrom: now)), enabled: true, current: nil) == .start(state))
    }

    @Test func theSameStateChangesNothing() {
        let locked = shot(.locked(countingFrom: now))
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: true, current: LiveActivityPlan.content(for: locked)) == .none)
    }

    @Test func aPassUpdatesItWithTheRelockTime() throws {
        let running = LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))
        let open = shot(.open(relockAt: now + 300, resumesFrom: now + 60))
        let state = try #require(LiveActivityPlan.content(for: open))
        #expect(state.openUntil == now + 300)
        #expect(state.lockedFrom == now + 60)
        #expect(LiveActivityPlan.decide(snapshot: open, enabled: true, current: running) == .update(state))
    }

    @Test func timesAreWholeSecondsSoTinyDriftDoesntUpdate() {
        let a = LiveActivityPlan.content(for: shot(.locked(countingFrom: now + 0.0004)))
        let b = LiveActivityPlan.content(for: shot(.locked(countingFrom: now - 0.0004)))
        #expect(a == b)
    }

    @Test func afterTheRelockItUpdatesBackToLocked() throws {
        let open = LiveActivityPlan.content(for: shot(.open(relockAt: now + 300, resumesFrom: now + 60)))
        let locked = shot(.locked(countingFrom: now))
        let wanted = try #require(LiveActivityPlan.content(for: locked))
        #expect(wanted.openUntil == nil)
        #expect(LiveActivityPlan.decide(snapshot: locked, enabled: true, current: open) == .update(wanted))
    }

    @Test func turnedOffWithNoActivityDoesNothing() {
        #expect(LiveActivityPlan.decide(snapshot: shot(.locked(countingFrom: now)), enabled: false, current: nil) == .none)
    }

    @Test func onlyRunningActivitiesCountAsCurrent() {
        #expect(LiveActivityPlan.countsAsCurrent(.active))
        #expect(LiveActivityPlan.countsAsCurrent(.stale))
        #expect(!LiveActivityPlan.countsAsCurrent(.over))
    }

    // MARK: Timer lock

    @Test func aTimerLockCarriesItsEndInWholeSeconds() throws {
        let timed = LockSnapshot.sample(.locked(countingFrom: now), timerEndsAt: now + 1800.0004)
        let state = try #require(LiveActivityPlan.content(for: timed))
        #expect(state.timerEndsAt == now + 1800)
        #expect(LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))?.timerEndsAt == nil)
    }

    @Test func aPassKeepsTheTimersEnd() throws {
        let open = LockSnapshot.sample(.open(relockAt: now + 300, resumesFrom: now), timerEndsAt: now + 1800)
        #expect(try #require(LiveActivityPlan.content(for: open)).timerEndsAt == now + 1800)
    }

    @Test func aChangedEndDateAloneUpdatesIt() throws {
        let before = LockSnapshot.sample(.locked(countingFrom: now), timerEndsAt: now + 1800)
        let after = LockSnapshot.sample(.locked(countingFrom: now), timerEndsAt: now + 2400)
        let running = LiveActivityPlan.content(for: before)
        let wanted = try #require(LiveActivityPlan.content(for: after))
        #expect(LiveActivityPlan.decide(snapshot: after, enabled: true, current: running) == .update(wanted))
        #expect(LiveActivityPlan.decide(snapshot: before, enabled: true, current: running) == .none)
    }

    @Test func startingATimerOnARunningLockUpdatesIt() throws {
        let plain = LiveActivityPlan.content(for: shot(.locked(countingFrom: now)))
        let timed = LockSnapshot.sample(.locked(countingFrom: now), timerEndsAt: now + 1800)
        let wanted = try #require(LiveActivityPlan.content(for: timed))
        #expect(LiveActivityPlan.decide(snapshot: timed, enabled: true, current: plain) == .update(wanted))
    }

    @Test func theContentStateRoundTripsWithAndWithoutAnEndDate() throws {
        let timed = LockActivityAttributes.ContentState(lockedFrom: now, openUntil: nil, modeName: "Deep work",
                                                        placeName: nil, timerEndsAt: now + 1800)
        let plain = LockActivityAttributes.ContentState(lockedFrom: now, openUntil: nil, modeName: "Deep work", placeName: nil)
        #expect(plain.timerEndsAt == nil)
        for state in [timed, plain] {
            let data = try JSONEncoder().encode(state)
            #expect(try JSONDecoder().decode(LockActivityAttributes.ContentState.self, from: data) == state)
        }
    }

    @Test func aContentStateWrittenBeforeTimersStillDecodes() throws {
        let old = #"{"lockedFrom":800000000,"modeName":"Deep work"}"#
        let state = try JSONDecoder().decode(LockActivityAttributes.ContentState.self, from: Data(old.utf8))
        #expect(state.lockedFrom == now)
        #expect(state.timerEndsAt == nil)
        #expect(state.openUntil == nil)
    }
    // MARK: Stale date and the done look

    private func state(openUntil: Date? = nil, timerEndsAt: Date? = nil) -> LockActivityAttributes.ContentState {
        .init(lockedFrom: now - 600, openUntil: openUntil, modeName: "Deep work", placeName: nil, timerEndsAt: timerEndsAt)
    }

    @Test func aPlainLockHasNoStaleDate() {
        #expect(LiveActivityPlan.staleDate(for: state()) == nil)
    }

    @Test func aPassGoesStaleAtItsRelock() {
        #expect(LiveActivityPlan.staleDate(for: state(openUntil: now + 300)) == now + 300)
    }

    @Test func aTimerGoesStaleAtItsEnd() {
        #expect(LiveActivityPlan.staleDate(for: state(timerEndsAt: now + 900)) == now + 900)
    }

    @Test func aPassDuringATimerGoesStaleAtTheEarlierOfTheTwo() {
        #expect(LiveActivityPlan.staleDate(for: state(openUntil: now + 300, timerEndsAt: now + 900)) == now + 300)
        #expect(LiveActivityPlan.staleDate(for: state(openUntil: now + 300, timerEndsAt: now + 120)) == now + 120)
    }

    @Test func aStaleTimerReadsAsDone() {
        #expect(state(timerEndsAt: now).timerIsOver(isStale: true))
        #expect(state(openUntil: now + 300, timerEndsAt: now + 120).timerIsOver(isStale: true))
    }

    @Test func aRunningTimerOrAStalePassBeforeTheTimersEndIsNotDone() {
        #expect(!state(timerEndsAt: now).timerIsOver(isStale: false))
        #expect(!state(openUntil: now + 300, timerEndsAt: now + 900).timerIsOver(isStale: true))
        #expect(!state(openUntil: now + 300).timerIsOver(isStale: true))
        #expect(!state().timerIsOver(isStale: true))
    }
}
