import Testing
@testable import Tapout

struct ModeTextTests {
    @Test func countsUseTheRightNoun() {
        #expect(Copy.count(1, "lock", "locks") == "1 lock")
        #expect(Copy.count(0, "lock", "locks") == "0 locks")
    }

    @Test func subtitleNamesTheDaysOrManual() {
        #expect(ModeText.subtitle(Mode(name: "Focus")) == "0 apps · manual")
        let deepWork = Mode(name: "Deep work", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020))
        #expect(ModeText.subtitle(deepWork) == "0 apps · weekdays")
    }

    @Test func unlockSummaryShortensLongLists() {
        #expect(ModeText.unlockSummary([]) == "Any place")
        #expect(ModeText.unlockSummary(["Kitchen"]) == "Kitchen")
        #expect(ModeText.unlockSummary(["Kitchen", "Desk", "Car"]) == "Kitchen +2")
    }
}
