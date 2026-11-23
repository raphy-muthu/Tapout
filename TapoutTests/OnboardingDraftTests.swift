import Testing
@testable import Tapout

struct OnboardingDraftTests {
    @Test func noWindowMeansNoSchedule() {
        #expect(OnboardingDraft().schedule == nil)
    }

    @Test func windowAndDaysMakeASchedule() {
        var draft = OnboardingDraft()
        draft.window = .afternoons
        #expect(draft.schedule == ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))
    }

    @Test func noDaysMeansNoSchedule() {
        var draft = OnboardingDraft()
        draft.window = .mornings
        draft.days = []
        #expect(draft.schedule == nil)
    }

    @Test func windows() {
        #expect(FocusWindow.allCases.map(\.title) == ["Mornings", "Afternoons", "Evenings"])
        #expect(FocusWindow.mornings.start == 9 * 60 && FocusWindow.mornings.end == 12 * 60)
        #expect(FocusWindow.evenings.start == 18 * 60 && FocusWindow.evenings.end == 21 * 60)
    }

    @Test func buttonTitlesAndStepping() {
        var draft = OnboardingDraft()
        var titles: [String] = []
        for _ in 0..<6 {
            titles.append(draft.cta)
            draft.advance()
        }
        #expect(titles == ["Get started", "Allow", "Continue", "Continue", "Continue", "Scan tag"])
        #expect(draft.step == OnboardingDraft.stepCount)
    }

    @Test func interestsComeBeforePairingAndFinishOnPairing() {
        var draft = OnboardingDraft()
        while draft.step < 5 { draft.advance() }
        #expect(draft.cta == "Continue")      // the interests step
        draft.advance()
        #expect(draft.step == OnboardingDraft.stepCount)
        #expect(draft.cta == "Scan tag")      // pairing is last
        draft.advance()
        #expect(draft.step == OnboardingDraft.stepCount)
    }
}
