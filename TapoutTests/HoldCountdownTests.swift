import Testing
@testable import Tapout

struct HoldCountdownTests {
    @Test func startsAtTenSeconds() {
        let countdown = HoldCountdown()
        #expect(countdown.secondsLeft == 10)
        #expect(countdown.label == "Hold")
        #expect(countdown.title == "Hold for 10 seconds")
        #expect(!countdown.isDone)
    }

    @Test func countsDownWhileHeld() {
        let countdown = HoldCountdown(progress: HoldCountdown.progress(held: 2.5))
        #expect(countdown.progress == 0.25)
        #expect(countdown.secondsLeft == 8)
        #expect(countdown.label == "Keep holding")
    }

    @Test func tenSecondsUsesThePass() {
        let countdown = HoldCountdown(progress: HoldCountdown.progress(held: 10))
        #expect(countdown.isDone)
        #expect(countdown.secondsLeft == 0)
        #expect(countdown.label == "Pass used")
        #expect(countdown.title == "Apps open")
    }

    @Test func progressStaysInRange() {
        #expect(HoldCountdown.progress(held: 12) == 1)
        #expect(HoldCountdown.progress(held: -1) == 0)
    }

    @Test func aLongPauseCannotCompleteTheHold() {
        var c = HoldCountdown()
        c.advance(by: 100)
        #expect(c.progress <= HoldCountdown.maxStep / HoldCountdown.duration)
        #expect(!c.isDone)
    }

    @Test func steadyTicksCompleteInTenSeconds() {
        var c = HoldCountdown()
        for _ in 0..<39 { c.advance(by: 0.25) }
        #expect(!c.isDone)
        c.advance(by: 0.25)
        #expect(c.isDone)
    }
}
