# Phase 3B Onboarding, Emergency Pass, Rejected Tag and Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The rest of Tapout's screens, on mock lock state: five-step onboarding (with a new "When should it lock?" step), the hold-for-10-seconds emergency pass, the rejected-tag screen behind a real scan flow, the Insights tab and milestones, plus the lock-intention flow ("What's it for?" before a lock, "Did you do it?" after it).

**Architecture:** Builds on Phase 3A (must be executed first). Lock state still comes from `MockLockController`, but Home's Scan and the locked orb now read a tag through 3A's `TagScanning` seam, and `AppModel` decides whether that tag may lock or unlock the active mode. The mock flow now writes `LockRecord`s (with the optional intention) to the App Group store, so Insights shows real numbers in the simulator. Insights maths lives in pure, tested types (`Insights`, `Comparison`, `Milestone`, `Gated`) that follow the honest-insights rules. Full-screen moments (rejected tag, emergency pass, milestone) share one `Cover` item on `RootView`.

**Tech Stack:** Swift 6, SwiftUI, Observation, FamilyControls (`FamilyActivityPicker`, `AuthorizationCenter`, `Label(token)`), Swift Testing, XcodeGen, Xcode 27.1, iPhone 17 simulator (iOS 26.5).

**Design source:** `docs/superpowers/specs/2026-10-27-phase3b-design.md` (decisions, the three ideas adopted from Uncoil, honest-insights rules), and `design/screens/{Main,EmergencyPass,Rejected,Insights,Home,LockFrame}.dc.html`.

## Decisions (2026-10-27/28)

- **Lock intention is optional and costs at most one tap.** A "What's it for?" field (40 characters max) and up to three recent intentions as chips sit above Scan. The intention shows under "Locked" on the lock moment and on locked Home. On unlock, a lock with an intention asks "Did you do it?" with two equal buttons, "Not yet" and "Done"; swiping away records nothing. Emergency passes never ask.
- **Onboarding has five steps:** Tap to lock, Allow Screen Time, What should wait?, **When should it lock?** (new), Pair your first tag + interests. Step 4 gives the starter mode ("Focus") a schedule; "Not now" leaves it manual. Steps 4 and 5 have "Not now".
- **Honest insights:** values that need data return `Gated.progress(have:need:)` until they have it. Best time needs 8 locks in 28 days and 3 in the winning block; Goals done needs 3 answered intentions; Longest needs a finished lock. Sums and counts always show. Streaks stay alive until midnight. Nothing counts misses.
- **Unlocking checks the mode's places.** A paired tag outside the active mode's unlock places shows the rejected screen ("Not for Sleep."). Unknown tags show "That's not one of your tags." "Pair as a new place" only appears while unlocked.
- **The mock lock flow writes history.** `AppModel.startLock` / `finishLock` record locks now; Phase 4 moves this into `LockEngine`. An emergency pass doesn't end the record (the lock is still running).
- **Milestones** (first lock, first 10 hours, 7 days in a row, 50 hours, 100 hours) each show once, right after the unlock that reached them (after the "Did you do it?" sheet, if any). Share uses plain text until Phase 5's recap image.
- **`MockData` goes away.** Home's "phone-free today" and the lock moment's place name are real now.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor extension `com.raphymuthu.tapout.monitor`. App Group `group.com.raphymuthu.tapout`.
- Five emergency passes total, ever (`SharedStore.totalPasses`). An emergency pass opens apps for 5 minutes.
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.inkTertiary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.onEmber`, `.slate`, `.slateInk`, `.slateLine`, `.slateGlow`, `.track`, `.danger`). No raw hex.
- Fraunces for titles and numbers of 20pt and up, through the styles in `Typography.swift`; SF Pro for everything else. Fraunces has no tabular digits: anything in Fraunces that ticks uses `FixedDigitText`.
- 44pt minimum touch targets. Continuous corners. No borders on cards; light theme cards carry `cardShadow()`.
- Disabled controls show at 0.45 opacity.
- Copy: very few words, no guilt or shame, no emoji, no exclamation marks. No miss counters anywhere.
- Lock = two rigid taps 90 ms apart; unlock = one soft tap; mismatch = warning; Reduce Motion swaps springs for crossfades, haptics still play (unless turned off in Settings).
- `Shared/` stays free of SwiftUI (it compiles into the extension).
- Every new screen has `#Preview`s in dark and light.
- Never commit. The user commits manually; each task ends with a suggested commit message.

## File map

| File | Responsibility |
| --- | --- |
| `Shared/Interest.swift` | Onboarding interests |
| `Shared/SharedStore.swift` | + `currentIntention`, `interests`, `seenMilestones` |
| `Tapout/Model/AppModel.swift` | + lock recording, tag checks, onboarding save, insights accessors |
| `Tapout/Model/Insights.swift` | `Gated`, `TimeBlock`, week maths, best time, goals, streak |
| `Tapout/Model/Comparison.swift` | Interest-based time comparisons |
| `Tapout/Model/Milestone.swift` | Milestones and their subtitles |
| `Tapout/Model/OnboardingDraft.swift` | `FocusWindow`, onboarding answers |
| `Tapout/Model/AppSettings.swift` | + `onboardedKey` |
| `Tapout/Model/DemoData.swift` | + intentions, interests, launch arguments |
| `Tapout/Model/MockData.swift` | Deleted |
| `Tapout/Engine/TagScanning.swift` | `MockTagScanner` can return a known tag |
| `Tapout/Engine/ScreenTimeAccess.swift` | Screen Time authorization request |
| `Tapout/Components/{DayChips,StepDots}.swift` | Shared day toggles, onboarding dots |
| `Tapout/Features/Lock/{IntentionField,IntentionCheckSheet,RejectedView}.swift` | Lock intention and rejected tag |
| `Tapout/Features/EmergencyPass/{HoldCountdown,EmergencyPassView}.swift` | The hold-to-use screen |
| `Tapout/Features/Onboarding/{OnboardingView,OnboardingSteps}.swift` | Onboarding |
| `Tapout/Features/Insights/{InsightsView,InsightsParts,MilestoneView}.swift` | Insights tab and milestone |
| `Tapout/Features/Home/{HomeView,LockMomentView,LockMomentLink}.swift` | Intention, scan stand-in, pass link, real phone-free time |
| `Tapout/Features/Modes/ModeEditor.swift` | Uses `DayChips` |
| `Tapout/App/RootView.swift` | Scan flow, covers, sheets, onboarding, Insights tab |
| `TapoutTests/{AppModelLock,Insights,Comparison,Milestone,RejectedTag,HoldCountdown,OnboardingDraft}Tests.swift`, `TestDates.swift`, `SharedStoreTests.swift`, `DemoDataTests.swift` | Unit tests |

Build/test command used throughout (run from `~/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)"
```

Device compile check, for tasks that touch FamilyControls UI or Core NFC (builds unsigned until signing is set up):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build -quiet
```

The suite has 102 tests after Phase 3A and the Fraunces switch.

---

### Task 1: Lock records, tag checks and onboarding data

**Files:**
- Create: `Shared/Interest.swift`, `TapoutTests/AppModelLockTests.swift`
- Modify: `Shared/SharedStore.swift`, `Tapout/Model/AppModel.swift`, `TapoutTests/SharedStoreTests.swift`

**Interfaces:**
- Consumes (3A): `AppModel(store:now:)`, `AppModel.activeMode`, `.places`, `.pair(_:name:)`, `.save(_:)`, private `store`, `now`, `cleaned(_:fallback:)`; `LockRecord(start:end:placeUID:modeID:intention:intentionDone:)`; `Mode.unlockPlaces`; `SharedStore` private `read(_:absent:corrupt:)` / `write(_:_:)` and `Key`; `SharedStore.makeTest(suite:)`.
- Produces:
  - `Interest` (`sports | movies | reading | music | travel | fitness`), `.title`.
  - `SharedStore.currentIntention: String?`, `.interests: [Interest]`, `.seenMilestones: [String]`.
  - `AppModel.currentIntention`, `.interests`, `.seenMilestones: Set<String>` (observable, read-only).
  - `AppModel.TagCheck` (`.accepted(PairedTag) | .unknown | .wrongPlace(PairedTag)`), `check(_:unlocking:)`, `unlockPlacesForActiveMode: [PairedTag]`.
  - `AppModel.intentionLimit` (40), `startLock(placeUID:intention:)`, `finishLock() -> LockRecord?` (discardable), `answerIntention(forLockStartedAt:done:)`, `recentIntentions: [String]`.
  - `AppModel.completeOnboarding(selection:alwaysAllowed:schedule:interests:)`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/AppModelLockTests.swift -->
```swift
import FamilyControls
import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelLockTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let kitchen = TagUID(hex: "04AA01")
    private let desk = TagUID(hex: "04AA02")

    private func makeModel() -> AppModel {
        AppModel(store: store, now: { [clock] in clock.now })
    }

    /// A model with Kitchen and Desk paired.
    private func pairedModel() -> AppModel {
        let model = makeModel()
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        return model
    }

    @Test func startLockRecordsTheActiveModePlaceAndIntention() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "  History essay  ")
        let record = try #require(model.history.last)
        #expect(record.start == clock.now)
        #expect(record.end == nil)
        #expect(record.placeUID == kitchen)
        #expect(record.modeID == model.activeMode.id)
        #expect(record.intention == "History essay")
        #expect(model.currentIntention == "History essay")
    }

    @Test func blankIntentionIsNone() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "   ")
        #expect(model.history.last?.intention == nil)
        #expect(model.currentIntention == nil)
    }

    @Test func longIntentionIsCut() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: String(repeating: "a", count: 50))
        #expect(model.history.last?.intention?.count == AppModel.intentionLimit)
    }

    @Test func finishLockEndsTheRunningLockAndClearsTheIntention() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 1500
        let finished = model.finishLock()
        #expect(finished?.end == clock.now)
        #expect(finished?.intention == "Essay")
        #expect(model.history.last?.end == clock.now)
        #expect(model.currentIntention == nil)
    }

    @Test func finishLockWithNothingRunningReturnsNil() {
        #expect(makeModel().finishLock() == nil)
    }

    @Test func answerIntentionSavesTheAnswer() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        clock.now += 600
        let finished = try #require(model.finishLock())
        model.answerIntention(forLockStartedAt: finished.start, done: true)
        #expect(model.history.last?.intentionDone == true)
    }

    @Test func recentIntentionsAreNewestFirstWithoutRepeats() {
        let model = pairedModel()
        for intention in ["A", "B", "A", "C", "D"] {
            model.startLock(placeUID: kitchen, intention: intention)
            clock.now += 60
            model.finishLock()
            clock.now += 60
        }
        #expect(model.recentIntentions == ["D", "C", "A"])
    }

    @Test func unknownTagIsUnknown() {
        #expect(pairedModel().check(TagUID(hex: "FF"), unlocking: false) == .unknown)
    }

    @Test func anyPairedTagLocks() {
        let model = pairedModel()
        var mode = model.activeMode
        mode.unlockPlaces = [kitchen]
        model.save(mode)
        #expect(model.check(desk, unlocking: false) == .accepted(model.places[1]))
    }

    @Test func unlockNeedsOneOfTheModesPlaces() {
        let model = pairedModel()
        var mode = model.activeMode
        mode.unlockPlaces = [kitchen]
        model.save(mode)
        #expect(model.check(desk, unlocking: true) == .wrongPlace(model.places[1]))
        #expect(model.check(kitchen, unlocking: true) == .accepted(model.places[0]))
        #expect(model.unlockPlacesForActiveMode.map(\.name) == ["Kitchen"])
    }

    @Test func modeWithoutPlacesUnlocksAnywhere() {
        let model = pairedModel()
        #expect(model.check(desk, unlocking: true) == .accepted(model.places[1]))
        #expect(model.unlockPlacesForActiveMode.map(\.name) == ["Kitchen", "Desk"])
    }

    @Test func completeOnboardingFillsTheStarterMode() {
        let model = makeModel()
        let schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)
        model.completeOnboarding(
            selection: FamilyActivitySelection(),
            alwaysAllowed: FamilyActivitySelection(),
            schedule: schedule,
            interests: [.sports, .music]
        )
        #expect(model.modes.count == 1)
        #expect(model.activeMode.name == AppModel.starterModeName)
        #expect(model.activeMode.schedule == schedule)
        #expect(model.interests == [.sports, .music])
        #expect(store.interests == [.sports, .music])
    }
}
```

Add to `TapoutTests/SharedStoreTests.swift`, inside `SharedStoreTests`:

```swift
    @Test func phase3bKeysDefaultAndRoundTrip() {
        let store = SharedStore.makeTest()
        #expect(store.currentIntention == nil)
        #expect(store.interests.isEmpty)
        #expect(store.seenMilestones.isEmpty)
        store.currentIntention = "Essay"
        store.interests = [.reading]
        store.seenMilestones = ["firstLock"]
        #expect(store.currentIntention == "Essay")
        #expect(store.interests == [.reading])
        #expect(store.seenMilestones == ["firstLock"])
    }
```

- [ ] **Step 2: Run the tests to see them fail** — expect `Interest`, `startLock`, `check`, `completeOnboarding` not found.

- [ ] **Step 3: Implement**

<!-- file: Shared/Interest.swift -->
```swift
import Foundation

/// What the owner enjoys, picked in onboarding. Insights compares locked time with these.
enum Interest: String, Codable, CaseIterable, Sendable {
    case sports, movies, reading, music, travel, fitness

    var title: String { rawValue.capitalized }
}
```

In `Shared/SharedStore.swift`, add after `alwaysAllowed`:

```swift
    /// What the running lock is for, if the owner said. Cleared on unlock.
    var currentIntention: String? {
        get { read(.currentIntention, absent: nil, corrupt: nil) }
        set { write(newValue, .currentIntention) }
    }

    var interests: [Interest] {
        get { read(.interests, absent: [], corrupt: []) }
        set { write(newValue, .interests) }
    }

    /// Milestones already shown, by raw value, so each shows once.
    var seenMilestones: [String] {
        get { read(.seenMilestones, absent: [], corrupt: []) }
        set { write(newValue, .seenMilestones) }
    }
```

and extend the key list:

```swift
    private enum Key: String {
        case session, selection, pairedTags, passesLeft, relockStrategy, log
        case modes, activeModeID, defaultPlace, lockHistory, alwaysAllowed
        case currentIntention, interests, seenMilestones
    }
```

In `Tapout/Model/AppModel.swift`:

1. Add after `private(set) var alwaysAllowed = FamilyActivitySelection()`:

```swift
    private(set) var currentIntention: String?
    private(set) var interests: [Interest] = []
    private(set) var seenMilestones: Set<String> = []
```

2. At the end of `reload()`, after `alwaysAllowed = store.alwaysAllowed`:

```swift
        currentIntention = store.currentIntention
        interests = store.interests
        seenMilestones = Set(store.seenMilestones)
```

3. Add before `private static func cleaned(_:fallback:)`:

```swift
    // MARK: Locks

    enum TagCheck: Equatable {
        /// A paired tag that may lock now, or unlock the active mode.
        case accepted(PairedTag)
        case unknown
        /// Paired, but the active mode only unlocks at other places.
        case wrongPlace(PairedTag)
    }

    /// The longest intention kept: enough for "History essay, first paragraph".
    static let intentionLimit = 40

    /// Whether `uid` may lock (while unlocked) or unlock the active mode (while locked).
    func check(_ uid: TagUID, unlocking: Bool) -> TagCheck {
        guard let place = places.first(where: { $0.uid == uid }) else { return .unknown }
        let allowed = activeMode.unlockPlaces
        if unlocking, !allowed.isEmpty, !allowed.contains(uid) { return .wrongPlace(place) }
        return .accepted(place)
    }

    /// The places that can unlock the active mode, in pairing order. Every place when the mode doesn't say.
    var unlockPlacesForActiveMode: [PairedTag] {
        let allowed = activeMode.unlockPlaces
        return allowed.isEmpty ? places : places.filter { allowed.contains($0.uid) }
    }

    /// Records the start of a lock with the active mode. A blank intention counts as none.
    func startLock(placeUID: TagUID?, intention: String?) {
        let trimmed = intention?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let intention = trimmed.isEmpty ? nil : String(trimmed.prefix(Self.intentionLimit))
        var all = store.lockHistory
        all.append(LockRecord(start: now(), end: nil, placeUID: placeUID, modeID: activeMode.id, intention: intention))
        store.lockHistory = all
        store.currentIntention = intention
        reload()
    }

    /// Ends the running lock and returns it, or nil when none was running.
    @discardableResult
    func finishLock() -> LockRecord? {
        var all = store.lockHistory
        guard let index = all.lastIndex(where: { $0.end == nil }) else { return nil }
        all[index].end = now()
        store.lockHistory = all
        store.currentIntention = nil
        reload()
        return all[index]
    }

    /// Saves the answer to "Did you do it?" for the lock that started at `start`.
    func answerIntention(forLockStartedAt start: Date, done: Bool) {
        store.lockHistory = store.lockHistory.map { record in
            var record = record
            if record.start == start { record.intentionDone = done }
            return record
        }
        reload()
    }

    /// Up to three recent intentions, newest first, without repeats.
    var recentIntentions: [String] {
        var seen = Set<String>()
        return Array(history.reversed().compactMap(\.intention).filter { seen.insert($0).inserted }.prefix(3))
    }

    // MARK: Onboarding

    /// Saves onboarding's answers: the active (starter) mode gets the apps and schedule.
    func completeOnboarding(
        selection: FamilyActivitySelection,
        alwaysAllowed: FamilyActivitySelection,
        schedule: ModeSchedule?,
        interests: [Interest]
    ) {
        var mode = activeMode
        mode.selection = selection
        mode.schedule = schedule
        save(mode)
        store.alwaysAllowed = alwaysAllowed
        store.interests = interests
        reload()
    }
```

- [ ] **Step 4: Run the build/test command** — 102 + 16 = 118 tests pass, no warnings from `Tapout/`, `Shared/`, `TapoutTests/` or `TapoutMonitor/`.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Record locks with intentions and check tags against the active mode`

---

### Task 2: Insights, comparisons and milestones

**Files:**
- Create: `Tapout/Model/Insights.swift`, `Tapout/Model/Comparison.swift`, `Tapout/Model/Milestone.swift`, `TapoutTests/TestDates.swift`, `TapoutTests/InsightsTests.swift`, `TapoutTests/ComparisonTests.swift`, `TapoutTests/MilestoneTests.swift`
- Modify: `Tapout/Model/AppModel.swift`

**Interfaces:**
- Consumes: `LockRecord`, `Interest`, `TimeFormat.short`, Task 1's `AppModel` additions.
- Produces:
  - `Gated<Value: Equatable>` (`.value(Value) | .progress(have: Int, need: Int)`).
  - `TimeBlock` (`mornings | afternoons | evenings | nights`), `.title`, `.of(hour:)`.
  - `Insights.lockedTime(in:history:now:)`, `.totalLocked(history:now:)`, `.week(of:calendar:)`, `Insights.Day(start:letter:lockedTime:isToday:)`, `.days(weekOf:history:now:calendar:)`, `.lockCount(weekOf:history:calendar:)`, `.longest(weekOf:history:calendar:) -> TimeInterval?`, `.bestTime(history:now:calendar:) -> Gated<TimeBlock>`, `Insights.Goals(done:answered:)`, `.goals(history:now:) -> Gated<Goals>`, `.streak(history:now:calendar:) -> Int`; constants `bestTimeNeed` (8), `bestTimeBlockNeed` (3), `goalsNeed` (3).
  - `Comparison(interest:phrase:plural:symbol:length:)`, `Comparison.all`, `.best(for:interests:)`, `asLongAs(_:)`, `worth(_:)`.
  - `Milestone` (`firstLock | tenHours | sevenDayStreak | fiftyHours | hundredHours`), `.title`, `.reached(in:now:calendar:)`, `subtitle(totalLocked:interests:)`.
  - `AppModel.phoneFreeToday(calendar:)`, `.totalLocked`, `.unseenMilestone(calendar:)`, `.markSeen(_:)`.
  - Tests: `TestDates.calendar`, `TestDates.oct(_:_:_:)`, `TestDates.lock(_:minutes:intention:done:)`, `TestDates.modeID`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/TestDates.swift -->
```swift
import Foundation
@testable import Tapout

/// A fixed Gregorian calendar (UTC, Monday first, English symbols) and dates around the week of
/// Monday 26 October 2026, so Insights tests don't depend on the machine's settings.
enum TestDates {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }()

    static let modeID = UUID()

    /// `day` of October 2026 (26 = Monday) at `hour`:`minute` UTC.
    static func oct(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// A finished lock of `minutes`.
    static func lock(_ start: Date, minutes: Double, intention: String? = nil, done: Bool? = nil) -> LockRecord {
        LockRecord(start: start, end: start + minutes * 60, placeUID: nil, modeID: modeID,
                   intention: intention, intentionDone: done)
    }
}
```

<!-- file: TapoutTests/InsightsTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct InsightsTests {
    private let calendar = TestDates.calendar
    private func oct(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { TestDates.oct(day, hour, minute) }
    private func lock(_ start: Date, _ minutes: Double, _ intention: String? = nil, _ done: Bool? = nil) -> LockRecord {
        TestDates.lock(start, minutes: minutes, intention: intention, done: done)
    }

    @Test func lockedTimeClipsToTheIntervalAndCountsARunningLock() {
        let overnight = lock(oct(25, 23), 120) // Sunday 23:00 to Monday 01:00
        let running = LockRecord(start: oct(26, 10), end: nil, placeUID: nil, modeID: TestDates.modeID)
        let monday = calendar.dateInterval(of: .day, for: oct(26, 12))!
        let time = Insights.lockedTime(in: monday, history: [overnight, running], now: oct(26, 10, 30))
        #expect(time == 90 * 60)
    }

    @Test func daysRunMondayToSundayAndMarkToday() {
        let history = [lock(oct(26, 9), 60), lock(oct(28, 9), 30)]
        let days = Insights.days(weekOf: oct(28, 12), history: history, now: oct(28, 12), calendar: calendar)
        #expect(days.map(\.letter) == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(days[0].lockedTime == 3600)
        #expect(days[2].lockedTime == 1800)
        #expect(days[2].isToday)
        #expect(days.filter(\.isToday).count == 1)
    }

    @Test func countAndLongestUseThisWeeksFinishedLocks() {
        let history = [
            lock(oct(25, 9), 200), // last week
            lock(oct(26, 9), 40),
            lock(oct(27, 9), 90),
            LockRecord(start: oct(28, 9), end: nil, placeUID: nil, modeID: TestDates.modeID),
        ]
        #expect(Insights.lockCount(weekOf: oct(28, 10), history: history, calendar: calendar) == 2)
        #expect(Insights.longest(weekOf: oct(28, 10), history: history, calendar: calendar) == TimeInterval(90 * 60))
    }

    @Test func longestIsNilBeforeTheFirstLock() {
        #expect(Insights.longest(weekOf: oct(28, 10), history: [], calendar: calendar) == nil)
        #expect(Insights.lockCount(weekOf: oct(28, 10), history: [], calendar: calendar) == 0)
    }

    @Test func bestTimeWaitsForEightLocks() {
        let history = (20...26).map { lock(oct($0, 14), 30) }
        #expect(Insights.bestTime(history: history, now: oct(28, 12), calendar: calendar) == .progress(have: 7, need: 8))
    }

    @Test func bestTimePicksTheBusiestBlock() {
        let afternoons = (20...24).map { lock(oct($0, 14), 30) }
        let mornings = (25...27).map { lock(oct($0, 9), 30) }
        #expect(Insights.bestTime(history: afternoons + mornings, now: oct(28, 12), calendar: calendar) == .value(.afternoons))
    }

    @Test func goalsWaitForThreeAnswers() {
        let history = [
            lock(oct(26, 9), 30, "Essay", true),
            lock(oct(27, 9), 30, "Notes", false),
            lock(oct(27, 15), 30, "Reading", nil),
        ]
        #expect(Insights.goals(history: history, now: oct(28, 12)) == .progress(have: 2, need: 3))
    }

    @Test func goalsCountTheDoneOnes() {
        let history = [
            lock(oct(25, 9), 30, "Essay", true),
            lock(oct(26, 9), 30, "Essay", true),
            lock(oct(27, 9), 30, "Notes", false),
            lock(oct(27, 15), 30),
        ]
        #expect(Insights.goals(history: history, now: oct(28, 12)) == .value(Insights.Goals(done: 2, answered: 3)))
    }

    @Test func streakStaysAliveUntilMidnight() {
        let history = [lock(oct(26, 9), 30), lock(oct(27, 9), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 2)
    }

    @Test func streakCountsToday() {
        let history = [lock(oct(26, 9), 30), lock(oct(27, 9), 30), lock(oct(28, 7), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 3)
    }

    @Test func streakBreaksOnAGap() {
        let history = [lock(oct(24, 9), 30), lock(oct(26, 9), 30), lock(oct(27, 9), 30)]
        #expect(Insights.streak(history: history, now: oct(28, 8), calendar: calendar) == 2)
    }
}
```

<!-- file: TapoutTests/ComparisonTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct ComparisonTests {
    private let movie = Comparison.all.first { $0.interest == .movies }!

    @Test func picksTheBiggestComparisonThatFits() {
        #expect(Comparison.best(for: 3 * 3600 + 20 * 60, interests: [.sports, .movies])?.interest == .sports)
        #expect(Comparison.best(for: 50 * 60, interests: [.music, .movies])?.interest == .music)
    }

    @Test func nothingFitsAShortTotal() {
        #expect(Comparison.best(for: 30 * 60, interests: [.movies]) == nil)
    }

    @Test func noInterestsMeansMovies() {
        #expect(Comparison.best(for: 2 * 3600 + 5 * 60, interests: [])?.interest == .movies)
    }

    @Test func wording() {
        #expect(movie.asLongAs(2.5 * 3600) == "As long as a feature film")
        #expect(movie.asLongAs(5 * 3600) == "As long as 2 movies")
        #expect(movie.worth(10 * 3600) == "About 5 movies' worth of time, back.")
        #expect(movie.worth(2 * 3600) == "About a feature film's worth of time, back.")
    }
}
```

<!-- file: TapoutTests/MilestoneTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct MilestoneTests {
    private let calendar = TestDates.calendar

    @Test func firstLockComesFirst() {
        let history = [TestDates.lock(TestDates.oct(26, 9), minutes: 30)]
        #expect(Milestone.reached(in: history, now: TestDates.oct(28, 12), calendar: calendar) == [.firstLock])
    }

    @Test func tenHoursAndSevenDays() {
        let week = (21...27).map { TestDates.lock(TestDates.oct($0, 9), minutes: 90) } // 10h 30m over 7 days
        let reached = Milestone.reached(in: week, now: TestDates.oct(28, 8), calendar: calendar)
        #expect(reached == [.firstLock, .tenHours, .sevenDayStreak])
    }

    @Test func subtitles() {
        #expect(Milestone.firstLock.subtitle(totalLocked: 1800, interests: []) == "The first of many.")
        #expect(Milestone.tenHours.subtitle(totalLocked: 10 * 3600, interests: [.movies]) == "About 5 movies' worth of time, back.")
        #expect(Milestone.sevenDayStreak.subtitle(totalLocked: 3600, interests: []) == "A week of locks in a row.")
    }

    @Test func eachMilestoneShowsOnce() {
        var now = TestDates.oct(28, 9)
        let model = AppModel(store: SharedStore.makeTest(), now: { now })
        #expect(model.unseenMilestone(calendar: calendar) == nil)
        model.startLock(placeUID: nil, intention: nil)
        now += 45 * 60
        model.finishLock()
        #expect(model.unseenMilestone(calendar: calendar) == .firstLock)
        model.markSeen(.firstLock)
        #expect(model.unseenMilestone(calendar: calendar) == nil)
        #expect(model.phoneFreeToday(calendar: calendar) == 45 * 60)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `Insights`, `Comparison`, `Milestone` not found.

- [ ] **Step 3: Implement**

<!-- file: Tapout/Model/Insights.swift -->
```swift
import Foundation

/// A derived value that needs enough data first. Below the minimum, screens show progress instead
/// ("3 of 8"), so a tile never shows a number built from a handful of locks.
enum Gated<Value: Equatable>: Equatable {
    case value(Value)
    case progress(have: Int, need: Int)
}

/// When a lock started, in four broad blocks.
enum TimeBlock: String, CaseIterable, Equatable {
    case mornings, afternoons, evenings, nights

    var title: String { rawValue.capitalized }

    /// Mornings 5–12, afternoons 12–17, evenings 17–22, nights 22–5.
    static func of(hour: Int) -> TimeBlock {
        switch hour {
        case 5..<12: .mornings
        case 12..<17: .afternoons
        case 17..<22: .evenings
        default: .nights
        }
    }
}

/// The numbers behind Insights, Home and milestones. Follows the honest-insights rules in
/// docs/superpowers/specs/2026-10-27-phase3b-design.md: minimum samples, streaks alive until midnight,
/// and nothing that counts misses.
enum Insights {
    static let bestTimeNeed = 8
    static let bestTimeBlockNeed = 3
    static let goalsNeed = 3
    /// Best time and goals look back four weeks.
    static let lookback: TimeInterval = 28 * 86_400

    struct Day: Equatable {
        let start: Date
        /// "M", "T", …
        let letter: String
        let lockedTime: TimeInterval
        let isToday: Bool
    }

    struct Goals: Equatable {
        let done: Int
        let answered: Int
    }

    /// Locked time inside `interval`. A running lock counts up to `now`.
    static func lockedTime(in interval: DateInterval, history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { total, record in
            let end = min(record.end ?? now, now)
            guard end > record.start,
                  let overlap = DateInterval(start: record.start, end: end).intersection(with: interval) else { return total }
            return total + overlap.duration
        }
    }

    /// All locked time so far.
    static func totalLocked(history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { $0 + max(0, min($1.end ?? now, now).timeIntervalSince($1.start)) }
    }

    static func week(of date: Date, calendar: Calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    /// One entry per day of `date`'s week, in the calendar's order.
    static func days(weekOf date: Date, history: [LockRecord], now: Date, calendar: Calendar) -> [Day] {
        let week = week(of: date, calendar: calendar)
        return (0..<7).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: week.start),
                  let day = calendar.dateInterval(of: .day, for: start) else { return nil }
            let weekday = calendar.component(.weekday, from: start)
            return Day(
                start: start,
                letter: calendar.veryShortWeekdaySymbols[weekday - 1],
                lockedTime: lockedTime(in: day, history: history, now: now),
                isToday: calendar.isDate(start, inSameDayAs: now)
            )
        }
    }

    static func lockCount(weekOf date: Date, history: [LockRecord], calendar: Calendar) -> Int {
        finished(in: week(of: date, calendar: calendar), history: history).count
    }

    /// The longest finished lock this week; nil before the first one.
    static func longest(weekOf date: Date, history: [LockRecord], calendar: Calendar) -> TimeInterval? {
        finished(in: week(of: date, calendar: calendar), history: history)
            .compactMap { record in record.end.map { $0.timeIntervalSince(record.start) } }
            .max()
    }

    /// When the owner locks most, over the last four weeks. Needs 8 locks, and the winning block
    /// needs 3 of them. Ties go to the block with more locked time.
    static func bestTime(history: [LockRecord], now: Date, calendar: Calendar) -> Gated<TimeBlock> {
        let recent = finished(in: DateInterval(start: now - lookback, end: now), history: history)
        guard recent.count >= bestTimeNeed else { return .progress(have: recent.count, need: bestTimeNeed) }
        let blocks = Dictionary(grouping: recent) { TimeBlock.of(hour: calendar.component(.hour, from: $0.start)) }
        let ranked = blocks.map { block, locks in
            (block: block, count: locks.count, time: totalLocked(history: locks, now: now))
        }
        .sorted { ($0.count, $0.time) > ($1.count, $1.time) }
        guard let top = ranked.first, top.count >= bestTimeBlockNeed else {
            return .progress(have: ranked.first?.count ?? 0, need: bestTimeBlockNeed)
        }
        return .value(top.block)
    }

    /// How many answered intentions were done, over the last four weeks. Needs 3 answers.
    static func goals(history: [LockRecord], now: Date) -> Gated<Goals> {
        let answered = history.filter { $0.start >= now - lookback && $0.intentionDone != nil }
        guard answered.count >= goalsNeed else { return .progress(have: answered.count, need: goalsNeed) }
        return .value(Goals(done: answered.filter { $0.intentionDone == true }.count, answered: answered.count))
    }

    /// Days in a row with a finished lock. Until today has one, the streak runs to yesterday,
    /// so it never reads zero first thing in the morning.
    static func streak(history: [LockRecord], now: Date, calendar: Calendar) -> Int {
        let days = Set(history.filter { $0.end != nil }.map { calendar.startOfDay(for: $0.start) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Finished locks that started inside `interval`.
    private static func finished(in interval: DateInterval, history: [LockRecord]) -> [LockRecord] {
        history.filter { $0.end != nil && interval.contains($0.start) }
    }
}
```

<!-- file: Tapout/Model/Comparison.swift -->
```swift
import Foundation

/// An everyday length of time to compare locked time with, keyed by interest. Approximate on purpose.
struct Comparison: Equatable {
    let interest: Interest
    /// "an entire NFL game"
    let phrase: String
    /// "NFL games"
    let plural: String
    /// SF Symbol for the Insights card.
    let symbol: String
    let length: TimeInterval

    static let all: [Comparison] = [
        Comparison(interest: .sports, phrase: "an entire NFL game", plural: "NFL games", symbol: "football", length: 3 * 3600 + 12 * 60),
        Comparison(interest: .movies, phrase: "a feature film", plural: "movies", symbol: "film", length: 2 * 3600),
        Comparison(interest: .reading, phrase: "a 300-page novel", plural: "novels", symbol: "book", length: 6 * 3600),
        Comparison(interest: .music, phrase: "a full album", plural: "albums", symbol: "music.note", length: 45 * 60),
        Comparison(interest: .travel, phrase: "a flight across the US", plural: "cross-country flights", symbol: "airplane", length: 5 * 3600 + 30 * 60),
        Comparison(interest: .fitness, phrase: "a marathon", plural: "marathons", symbol: "figure.run", length: 4 * 3600 + 30 * 60),
    ]

    /// The longest comparison that `time` covers, from the owner's interests (Movies when none were picked).
    /// nil when even the shortest is longer than `time`; screens then hide the comparison.
    static func best(for time: TimeInterval, interests: [Interest]) -> Comparison? {
        let picked = interests.isEmpty ? [.movies] : interests
        return all.filter { picked.contains($0.interest) && $0.length <= time }.max { $0.length < $1.length }
    }

    /// Insights card: "As long as an entire NFL game", "As long as 2 NFL games".
    func asLongAs(_ time: TimeInterval) -> String {
        let count = Int(time / length)
        return count >= 2 ? "As long as \(count) \(plural)" : "As long as \(phrase)"
    }

    /// Milestone line: "About 5 movies' worth of time, back."
    func worth(_ time: TimeInterval) -> String {
        let count = Int(time / length)
        return count >= 2 ? "About \(count) \(plural)' worth of time, back." : "About \(phrase)'s worth of time, back."
    }
}
```

<!-- file: Tapout/Model/Milestone.swift -->
```swift
import Foundation

/// Moments worth one full-screen celebration each. Shown once, right after the unlock that reached them.
enum Milestone: String, CaseIterable, Identifiable {
    case firstLock, tenHours, sevenDayStreak, fiftyHours, hundredHours

    var id: Self { self }

    var title: String {
        switch self {
        case .firstLock: "First lock"
        case .tenHours: "First 10 hours"
        case .sevenDayStreak: "7 days in a row"
        case .fiftyHours: "50 hours"
        case .hundredHours: "100 hours"
        }
    }

    /// Every milestone reached so far, in order. Only finished locks count.
    static func reached(in history: [LockRecord], now: Date, calendar: Calendar) -> [Milestone] {
        let finished = history.filter { $0.end != nil }
        let total = Insights.totalLocked(history: finished, now: now)
        let streak = Insights.streak(history: finished, now: now, calendar: calendar)
        return allCases.filter { milestone in
            switch milestone {
            case .firstLock: !finished.isEmpty
            case .tenHours: total >= 10 * 3600
            case .sevenDayStreak: streak >= 7
            case .fiftyHours: total >= 50 * 3600
            case .hundredHours: total >= 100 * 3600
            }
        }
    }

    /// The line under the title. Time milestones compare the total with something from the owner's interests.
    func subtitle(totalLocked: TimeInterval, interests: [Interest]) -> String {
        switch self {
        case .firstLock:
            "The first of many."
        case .sevenDayStreak:
            "A week of locks in a row."
        case .tenHours, .fiftyHours, .hundredHours:
            Comparison.best(for: totalLocked, interests: interests)?.worth(totalLocked)
                ?? "\(TimeFormat.short(totalLocked)) phone-free."
        }
    }
}
```

In `Tapout/Model/AppModel.swift`, add before `private static func cleaned(_:fallback:)`:

```swift
    // MARK: Insights

    /// Locked time since midnight, for Home's "phone-free today".
    func phoneFreeToday(calendar: Calendar = .current) -> TimeInterval {
        guard let today = calendar.dateInterval(of: .day, for: now()) else { return 0 }
        return Insights.lockedTime(in: today, history: history, now: now())
    }

    var totalLocked: TimeInterval {
        Insights.totalLocked(history: history, now: now())
    }

    /// The first milestone reached that hasn't been shown yet.
    func unseenMilestone(calendar: Calendar = .current) -> Milestone? {
        Milestone.reached(in: history, now: now(), calendar: calendar).first { !seenMilestones.contains($0.rawValue) }
    }

    func markSeen(_ milestone: Milestone) {
        store.seenMilestones = seenMilestones.union([milestone.rawValue]).sorted()
        reload()
    }
```

- [ ] **Step 4: Run the build/test command** — 118 + 19 = 137 tests pass, no warnings.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Add honest insights maths, comparisons and milestones`

---

### Task 3: Scan flow, rejected tag and lock intention

**Files:**
- Create: `Tapout/Features/Lock/IntentionField.swift`, `Tapout/Features/Lock/IntentionCheckSheet.swift`, `Tapout/Features/Lock/RejectedView.swift`, `TapoutTests/RejectedTagTests.swift`
- Modify: `Tapout/Engine/TagScanning.swift`, `Tapout/Features/Home/HomeView.swift` (rewrite), `Tapout/Features/Home/LockMomentView.swift`, `Tapout/Features/Home/LockMomentLink.swift`, `Tapout/App/RootView.swift` (rewrite)
- Delete: `Tapout/Model/MockData.swift`

**Interfaces:**
- Consumes: Task 1–2 `AppModel` API; 3A `TagScanning`, `TagScanners`, `TagScanPrompt.pair`, `PairPlaceSheet(model:)`, `HomeHeader(modes:activeMode:showsLockGlyph:onSelectMode:onOpenSettings:)`, `SettingsView(model:passesLeft:onOpenTab:)`, `PlacesView(model:)`, `ModesView(model:)`, `Route`, `ChoiceChip`, `CircleIconButton`, `Font.tTitle1`; Phase 1 `OrbView`, `PrimaryButton`, `StateLabel`, `TimerText`, `LockMomentView`, `lockMomentMatch`.
- Produces:
  - `TagScanners.live(known:)`; DEBUG `MockTagScanner(known:)` (`-mockUnknownTag` forces an unknown tag).
  - `RejectedTag(title:hint:canPair:)`, `.unknown(tryPlaces:locked:)`, `.wrongPlace(mode:tryPlaces:)`; `RejectedView(rejected:onTryAgain:onPair:)`.
  - `IntentionField(text:recent:)`; `IntentionCheck(id:intention:)`; `IntentionCheckSheet(check:onAnswer:)`.
  - `HomeView(controller:model:intentionDraft:onScan:onEmergencyPass:onOpenSettings:)`.
  - `LockMomentView(placeName:session:intention:onFinished:)`; `LockMomentPart.intention`.
  - `Cover` (`.rejected(RejectedTag)` for now; Tasks 4 and 6 add cases); `RootView` scan flow.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/RejectedTagTests.swift -->
```swift
import Testing
@testable import Tapout

struct RejectedTagTests {
    @Test func unknownTagWhileUnlockedOffersPairing() {
        let rejected = RejectedTag.unknown(tryPlaces: ["Kitchen", "Desk", "Car"], locked: false)
        #expect(rejected.title == "That's not one of your tags.")
        #expect(rejected.hint == "Try Kitchen or Desk.")
        #expect(rejected.canPair)
    }

    @Test func unknownTagWhileLockedNeverOffersPairing() {
        #expect(!RejectedTag.unknown(tryPlaces: ["Kitchen"], locked: true).canPair)
        #expect(RejectedTag.unknown(tryPlaces: ["Kitchen"], locked: true).hint == "Try Kitchen.")
    }

    @Test func noPlacesPointsToPlacesWhileUnlocked() {
        #expect(RejectedTag.unknown(tryPlaces: [], locked: false).hint == "Pair one in Places.")
        #expect(RejectedTag.unknown(tryPlaces: [], locked: true).hint == nil)
    }

    @Test func wrongPlaceNamesTheMode() {
        let rejected = RejectedTag.wrongPlace(mode: "Sleep", tryPlaces: ["Bedroom"])
        #expect(rejected.title == "Not for Sleep.")
        #expect(rejected.hint == "Try Bedroom.")
        #expect(!rejected.canPair)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `RejectedTag` not found.

- [ ] **Step 3: Let the simulator scanner find a known tag.** Replace `Tapout/Engine/TagScanning.swift`:

<!-- file: Tapout/Engine/TagScanning.swift -->
```swift
import Foundation

/// Reads one tag's UID. The real reader needs NFC hardware; the simulator gets a stand-in.
protocol TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID
}

enum TagScanPrompt {
    static let pair = "Hold your tag near the top of your iPhone."
}

extension TagReader: TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await readUID(prompt: prompt)
    }
}

enum TagScanners {
    /// The NFC reader, or in DEBUG builds without NFC (the simulator) a stand-in that finds `known`,
    /// or a new tag when `known` is nil.
    @MainActor static func live(known: TagUID? = nil) -> any TagScanning {
        #if DEBUG
        if !TagReader.isAvailable { return MockTagScanner(known: known) }
        #endif
        return TagReader()
    }
}

#if DEBUG
/// Simulator stand-in. Finds `known` after a second, or a new random tag when `known` is nil
/// or the app was launched with `-mockUnknownTag`.
struct MockTagScanner: TagScanning {
    var known: TagUID?

    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await Task.sleep(for: .seconds(1))
        if let known, !ProcessInfo.processInfo.arguments.contains("-mockUnknownTag") { return known }
        return TagUID(data: Data((0..<7).map { _ in UInt8.random(in: .min ... .max) }))
    }
}
#endif
```

- [ ] **Step 4: Write the lock pieces**

<!-- file: Tapout/Features/Lock/RejectedView.swift -->
```swift
import SwiftUI

/// What the rejected screen says about a tag that can't do what was asked.
struct RejectedTag: Equatable {
    let title: String
    let hint: String?
    /// Only while unlocked, so a new sticker can never be paired to escape a lock.
    let canPair: Bool

    static func unknown(tryPlaces: [String], locked: Bool) -> RejectedTag {
        RejectedTag(title: "That's not one of your tags.", hint: hint(tryPlaces, locked: locked), canPair: !locked)
    }

    /// A paired tag that the active mode doesn't unlock at.
    static func wrongPlace(mode: String, tryPlaces: [String]) -> RejectedTag {
        RejectedTag(title: "Not for \(mode).", hint: hint(tryPlaces, locked: true), canPair: false)
    }

    /// "Try Kitchen or Desk." from the first two places. With none, point to Places, which only helps while unlocked.
    private static func hint(_ places: [String], locked: Bool) -> String? {
        switch places.count {
        case 0: locked ? nil : "Pair one in Places."
        case 1: "Try \(places[0])."
        default: "Try \(places[0]) or \(places[1])."
        }
    }
}

/// The unknown-tag screen from design/screens/Rejected.dc.html.
struct RejectedView: View {
    let rejected: RejectedTag
    let onTryAgain: () -> Void
    let onPair: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .stroke(Color.danger, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [46, 32]))
                        .opacity(0.9)
                        .frame(width: 248, height: 248)
                    OrbView(tone: .slate, size: 220)
                }
                .frame(width: 260, height: 260)
                .accessibilityHidden(true)
                VStack(spacing: Space.xs) {
                    Text(rejected.title)
                        .font(.tTitle1)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: 300)
                    if let hint = rejected.hint {
                        Text(hint).font(.tBody).foregroundStyle(Color.inkSecondary)
                    }
                }
                .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                PrimaryButton(title: "Try again") {
                    onTryAgain()
                    dismiss()
                }
                if rejected.canPair {
                    Button("Pair as a new place") {
                        onPair()
                        dismiss()
                    }
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.md)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
    }
}

#Preview("Rejected · dark") {
    RejectedView(rejected: .unknown(tryPlaces: ["Kitchen", "Desk"], locked: false), onTryAgain: {}, onPair: {})
        .preferredColorScheme(.dark)
}

#Preview("Rejected · light") {
    RejectedView(rejected: .unknown(tryPlaces: ["Kitchen", "Desk"], locked: false), onTryAgain: {}, onPair: {})
        .preferredColorScheme(.light)
}
```

<!-- file: Tapout/Features/Lock/IntentionField.swift -->
```swift
import SwiftUI

/// The optional "What's it for?" field above Scan, with recent intentions as one-tap chips.
struct IntentionField: View {
    @Binding var text: String
    let recent: [String]

    var body: some View {
        VStack(spacing: Space.xs) {
            TextField(text: $text, prompt: Text("What's it for?").foregroundStyle(Color.inkTertiary)) {
                Text("What's it for?")
            }
            .font(.tBody)
            .foregroundStyle(Color.ink)
            .submitLabel(.done)
            .padding(.horizontal, Space.md)
            .frame(height: 44)
            .background(Color.surface1, in: Capsule(style: .continuous))
            .cardShadow()
            .accessibilityHint("Optional")
            .onChange(of: text) { _, new in
                if new.count > AppModel.intentionLimit { text = String(new.prefix(AppModel.intentionLimit)) }
            }
            if !recent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.xs) {
                        ForEach(recent, id: \.self) { item in
                            ChoiceChip(title: item, isOn: text == item) { text = text == item ? "" : item }
                        }
                    }
                }
            }
        }
    }
}
```

<!-- file: Tapout/Features/Lock/IntentionCheckSheet.swift -->
```swift
import SwiftUI

/// A finished lock that had an intention.
struct IntentionCheck: Identifiable, Equatable {
    /// The lock's start, which identifies it in the history.
    let id: Date
    let intention: String
}

/// "Did you do it?" after unlocking. Two equal answers, no score; swiping away records nothing.
struct IntentionCheckSheet: View {
    let check: IntentionCheck
    let onAnswer: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.lg) {
            VStack(spacing: Space.xs) {
                Text("Did you do it?").font(.tTitle).foregroundStyle(Color.ink)
                Text(check.intention)
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            HStack(spacing: Space.sm) {
                answer("Not yet", done: false)
                answer("Done", done: true)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
    }

    private func answer(_ title: String, done: Bool) -> some View {
        Button {
            Haptics.select()
            onAnswer(done)
            dismiss()
        } label: {
            Text(title)
                .font(.tHeadline)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Color.surface2, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}

#Preview("Check · dark") {
    Color.bg.sheet(isPresented: .constant(true)) {
        IntentionCheckSheet(check: IntentionCheck(id: .now, intention: "History essay, first paragraph")) { _ in }
    }
    .preferredColorScheme(.dark)
}

#Preview("Check · light") {
    Color.bg.sheet(isPresented: .constant(true)) {
        IntentionCheckSheet(check: IntentionCheck(id: .now, intention: "History essay, first paragraph")) { _ in }
    }
    .preferredColorScheme(.light)
}
```

- [ ] **Step 5: Show the intention through the lock moment.** In `Tapout/Features/Home/LockMomentLink.swift`, add the case:

```swift
enum LockMomentPart: Hashable {
    case orb, timer, stateWord, intention
}
```

In `Tapout/Features/Home/LockMomentView.swift`:
- add a property after `session`: `var intention: String? = nil` with the doc comment `/// What the lock is for, shown under "Locked".`
- in `caption`, inside the `frame == 4` group after the `StateLabel(...)…lockMomentMatch(.stateWord, inOverlay: true)` line, add:

```swift
                    if let intention {
                        Text(intention)
                            .font(.tSubhead)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .lockMomentMatch(.intention, inOverlay: true)
                    }
```

- change `.frame(height: 176, alignment: .top)` on `caption` to `.frame(height: 204, alignment: .top)`.
- change the preview to `LockMomentView(placeName: "Kitchen", session: .locked(since: .now), intention: "Essay outline") {}`.

- [ ] **Step 6: Rewrite Home**

<!-- file: Tapout/Features/Home/HomeView.swift -->
```swift
import SwiftUI

/// Home in its three states, matching design/screens/Home.dc.html, plus the optional lock intention.
struct HomeView: View {
    let controller: MockLockController
    let model: AppModel
    @Binding var intentionDraft: String
    /// Reads a tag to lock or unlock. The locked orb uses it too: tap the orb, then the tag.
    let onScan: () -> Void
    let onEmergencyPass: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(
                modes: model.modes,
                activeMode: model.activeMode,
                showsLockGlyph: isLocked,
                onSelectMode: { model.setActiveMode($0) },
                onOpenSettings: onOpenSettings
            )
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                switch controller.session {
                case .unlocked: unlocked
                case .locked: locked(at: context.date)
                case .emergency: emergency(at: context.date)
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
    }

    private var isLocked: Bool {
        if case .locked = controller.session { true } else { false }
    }

    private var unlocked: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Shrinks the orb when the keyboard is up for the intention field.
            ViewThatFits(in: .vertical) {
                orbAndState(size: 300)
                orbAndState(size: 200)
                orbAndState(size: 120)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.sm) {
                IntentionField(text: $intentionDraft, recent: model.recentIntentions)
                PrimaryButton(title: "Scan", systemImage: "wave.3.right", action: onScan)
            }
        }
    }

    private func orbAndState(size: CGFloat) -> some View {
        VStack(spacing: Space.xl) {
            OrbView(tone: .slate, size: size)
            VStack(spacing: Space.xxs) {
                StateLabel(text: "Unlocked", systemImage: "lock.open", color: .slateInk)
                Text("\(TimeFormat.short(model.phoneFreeToday())) phone-free today")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private func locked(at date: Date) -> some View {
        let elapsed = controller.session.elapsed(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                Button(action: onScan) {
                    OrbView(tone: .ember, ring: 1, size: 244)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Scan to unlock")
                .accessibilityHint("Then hold your tag near the top of your iPhone")
                .lockMomentMatch(.orb)

                VStack(spacing: Space.xs) {
                    TimerText(text: TimeFormat.clock(elapsed))
                        .accessibilityLabel("Locked for \(TimeFormat.spoken(elapsed))")
                        .lockMomentMatch(.timer)
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                        .lockMomentMatch(.stateWord)
                    if let intention = model.currentIntention {
                        Text(intention)
                            .font(.tSubhead)
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(1)
                            .lockMomentMatch(.intention)
                    }
                }
            }
            Spacer(minLength: 0)
            if controller.passesLeft > 0 {
                Button(action: onEmergencyPass) {
                    Text("Emergency pass · \(controller.passesLeft) left")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func emergency(at date: Date) -> some View {
        let remaining = controller.session.remaining(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                OrbView(tone: .slate, ringTone: .ember,
                        ring: controller.session.remainingFraction(at: date), size: 244)
                VStack(spacing: Space.xxs) {
                    Text("Relocks in")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                    TimerText(text: TimeFormat.clock(remaining.rounded(.up)))
                        .accessibilityLabel("Relocks in \(TimeFormat.spoken(remaining))")
                    Text("Emergency pass · \(controller.passesLeft) of \(MockLockController.totalPasses) left")
                        .font(.tFootnote.weight(.medium))
                        .foregroundStyle(Color.emberInk)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Relock now", action: relockNow)
        }
    }

    private func relockNow() {
        Haptics.lock()
        withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { controller.relockNow() }
    }
}

#Preview("Unlocked · dark") {
    RootView(model: DemoData.previewModel()).preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))), model: DemoData.previewModel())
        .preferredColorScheme(.dark)
}

#Preview("Emergency · dark") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2),
             model: DemoData.previewModel())
        .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    RootView(model: DemoData.previewModel()).preferredColorScheme(.light)
}

#Preview("Locked · light") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))), model: DemoData.previewModel())
        .preferredColorScheme(.light)
}

#Preview("Emergency · light") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2),
             model: DemoData.previewModel())
        .preferredColorScheme(.light)
}
```

- [ ] **Step 7: Rewrite RootView with the scan flow**

<!-- file: Tapout/App/RootView.swift -->
```swift
import SwiftUI

/// Screens pushed over the tabs. The tab bar belongs to the root, so pushed screens cover it.
enum Route: Hashable {
    case settings
}

/// Full-screen moments over everything.
enum Cover: Identifiable {
    case rejected(RejectedTag)

    var id: String {
        switch self {
        case .rejected: "rejected"
        }
    }
}

/// What to do once a cover has gone, so a scan or sheet never starts while it is still leaving.
private enum AfterCover {
    case scan, pair
}

/// Tabs, the floating tab bar, navigation, tag scans, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var model: AppModel
    @State private var tab = AppTab.home
    @State private var path: [Route] = []
    @State private var showingLockMoment = false
    @State private var lockPlaceName = ""
    @State private var intentionDraft = ""
    @State private var intentionCheck: IntentionCheck?
    @State private var cover: Cover?
    @State private var afterCover: AfterCover?
    @State private var pairing = false
    @State private var scanning = false
    @State private var keyboardUp = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight

    init(controller: MockLockController = MockLockController(), model: AppModel) {
        _controller = State(initialValue: controller)
        _model = State(initialValue: model)
    }

    var body: some View {
        let accent = Accent.for(controller.session.lockState)
        NavigationStack(path: $path) {
            ZStack {
                screen
                    .safeAreaInset(edge: .bottom, spacing: Space.md) {
                        // Tucked away while typing, so the intention field and Scan fit above the keyboard on small iPhones.
                        if !keyboardUp { FloatingTabBar(active: $tab) }
                    }
                if showingLockMoment {
                    LockMomentView(placeName: lockPlaceName, session: controller.session, intention: model.currentIntention) {
                        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { showingLockMoment = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .background(Color.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .settings:
                    SettingsView(model: model, passesLeft: controller.passesLeft, onOpenTab: open)
                }
            }
        }
        // Fraunces styles are read once per render, so rebuild the screens when Bold Text changes.
        // The id sits on the stack, not on RootView, so controller, model and tab survive; it comes
        // before the presentations so an open cover or sheet isn't dismissed by the change.
        .id(legibilityWeight)
        // Presentations sit inside the environment modifiers below, so covers and sheets get the accent,
        // the lock state and the appearance too.
        .fullScreenCover(item: $cover, onDismiss: runAfterCover) { cover in
            switch cover {
            case .rejected(let rejected):
                RejectedView(rejected: rejected, onTryAgain: { afterCover = .scan }, onPair: { afterCover = .pair })
            }
        }
        .sheet(item: $intentionCheck) { check in
            IntentionCheckSheet(check: check) { done in
                model.answerIntention(forLockStartedAt: check.id, done: done)
            }
        }
        .sheet(isPresented: $pairing) {
            PairPlaceSheet(model: model)
        }
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .environment(\.isLocked, controller.session.lockState == .locked)
        .environment(\.accent, accent)
        .tint(accent.line)
        .preferredColorScheme(appearance.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { keyboardUp = false }
        }
        .task {
            // Lock state isn't persisted yet, so a lock left open by a crash can't still be running.
            if controller.session == .unlocked { model.discardInterruptedLocks() }
            await runClock()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(
                controller: controller,
                model: model,
                intentionDraft: $intentionDraft,
                onScan: { Task { await scan() } },
                onEmergencyPass: useEmergencyPass,
                onOpenSettings: openSettings
            )
        case .modes:
            ModesView(model: model)
        case .places:
            PlacesView(model: model)
        case .insights:
            PlaceholderView(title: "Insights")
        }
    }

    /// A quick double tap on the gear would otherwise push Settings twice.
    private func openSettings() {
        guard path.isEmpty else { return }
        path.append(.settings)
    }

    /// Settings links jump to a tab: pop back to the root, then switch.
    private func open(_ destination: AppTab) {
        path.removeAll()
        tab = destination
    }

    /// Reads a tag, then locks, unlocks, or shows why it can't.
    private func scan() async {
        guard !scanning else { return }
        scanning = true
        defer { scanning = false }
        Haptics.prepare()
        let unlocking = controller.session.lockState == .locked
        // The simulator stand-in finds a place that works, unless launched with -mockUnknownTag.
        let known = unlocking ? model.unlockPlacesForActiveMode.first?.uid : model.defaultPlace?.uid
        let uid: TagUID
        do {
            uid = try await TagScanners.live(known: known).scan(prompt: TagScanPrompt.pair)
        } catch {
            return // cancelled, or no tag: the system NFC sheet already said so
        }
        let tryPlaces = model.unlockPlacesForActiveMode.map(\.name)
        switch model.check(uid, unlocking: unlocking) {
        case .accepted(let place):
            if unlocking { unlock() } else { lock(at: place) }
        case .unknown:
            Haptics.mismatch()
            cover = .rejected(.unknown(tryPlaces: tryPlaces, locked: unlocking))
        case .wrongPlace:
            Haptics.mismatch()
            cover = .rejected(.wrongPlace(mode: model.activeMode.name, tryPlaces: tryPlaces))
        }
    }

    private func lock(at place: PairedTag) {
        controller.simulateTagRead()
        model.startLock(placeUID: place.uid, intention: intentionDraft)
        intentionDraft = ""
        lockPlaceName = place.name
        showingLockMoment = true // the lock moment plays the lock haptic
    }

    private func unlock() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { controller.simulateTagRead() }
        if let record = model.finishLock(), let intention = record.intention {
            intentionCheck = IntentionCheck(id: record.start, intention: intention)
        }
    }

    private func useEmergencyPass() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) { controller.useEmergencyPass() }
    }

    private func runAfterCover() {
        let action = afterCover
        afterCover = nil
        switch action {
        case .scan: Task { await scan() }
        case .pair: pairing = true
        case nil: break
        }
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let before = controller.session
            withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { controller.tick() }
            if controller.session != before { Haptics.lock() }
        }
    }
}
```

- [ ] **Step 8: Delete `Tapout/Model/MockData.swift`.** Then `grep -rn "MockData" Tapout TapoutTests` must print nothing.

- [ ] **Step 9: Run the build/test command and the device compile check** — both clean, 137 + 4 = 141 tests pass.

- [ ] **Step 10: Leave uncommitted.** Suggested message: `Scan tags to lock and unlock, reject unknown tags, add lock intention`

---

### Task 4: Emergency pass hold

**Files:**
- Create: `Tapout/Features/EmergencyPass/HoldCountdown.swift`, `Tapout/Features/EmergencyPass/EmergencyPassView.swift`, `TapoutTests/HoldCountdownTests.swift`
- Modify: `Tapout/App/RootView.swift`

**Interfaces:**
- Consumes: `PassPips(left:total:width:height:)`, `CircleIconButton`, `SharedStore.totalPasses`, `MockLockController.emergencyDuration`, `FixedDigitText(text:face:size:)`, Task 3's `Cover`.
- Produces: `HoldCountdown` (`duration` 10, `progress`, `isDone`, `secondsLeft`, `label`, `title`, `progress(held:)`); `EmergencyPassView(passesLeft:onUse:)`; `Cover.emergencyPass`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/HoldCountdownTests.swift -->
```swift
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
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `HoldCountdown` not found.

- [ ] **Step 3: Implement**

<!-- file: Tapout/Features/EmergencyPass/HoldCountdown.swift -->
```swift
import Foundation

/// The 10-second hold that spends an emergency pass. Kept apart from the view so the timing is testable.
struct HoldCountdown: Equatable {
    static let duration: TimeInterval = 10

    /// 0 … 1 of the hold.
    var progress: Double = 0

    var isDone: Bool { progress >= 1 }

    var secondsLeft: Int {
        isDone ? 0 : Int((Self.duration * (1 - progress)).rounded(.up))
    }

    var label: String {
        if isDone { return "Pass used" }
        return progress > 0 ? "Keep holding" : "Hold"
    }

    var title: String { isDone ? "Apps open" : "Hold for 10 seconds" }

    static func progress(held: TimeInterval) -> Double {
        min(1, max(0, held / duration))
    }
}
```

<!-- file: Tapout/Features/EmergencyPass/EmergencyPassView.swift -->
```swift
import SwiftUI

/// Hold for 10 seconds to spend one of five lifetime passes, per design/screens/EmergencyPass.dc.html.
/// Letting go resets the hold.
struct EmergencyPassView: View {
    let passesLeft: Int
    let onUse: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var countdown = HoldCountdown()
    @State private var holdTask: Task<Void, Never>?
    @State private var confirmingAccessibleUse = false

    var body: some View {
        VStack(spacing: 0) {
            header
            pips.padding(.top, 40)
            Spacer(minLength: 0)
            VStack(spacing: 28) {
                holdButton
                VStack(spacing: Space.xxs) {
                    Text(passesLeft > 0 ? countdown.title : "No passes left.")
                        .font(.tTitle)
                        .foregroundStyle(Color.ink)
                    Text("Apps open for \(Int(MockLockController.emergencyDuration / 60)) min, then relock.")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.lg)
        .background(Color.bg.ignoresSafeArea())
        .onDisappear { holdTask?.cancel() }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("Emergency pass").font(.tHeadline).foregroundStyle(Color.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var pips: some View {
        VStack(spacing: Space.sm) {
            PassPips(left: passesLeft, width: 40, height: 12)
            (Text("\(passesLeft)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                + Text(" of \(SharedStore.totalPasses) left. Passes never refill.").foregroundStyle(Color.inkSecondary))
                .font(.tSubhead)
        }
    }

    private var holdButton: some View {
        ZStack {
            Circle()
                .fill(Color.ember)
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .opacity(0.08 + countdown.progress * 0.35)
            Circle()
                .stroke(Color.track, lineWidth: 8)
                .frame(width: 236, height: 236)
            Circle()
                .trim(from: 0, to: countdown.progress)
                .stroke(Color.emberLine, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 236, height: 236)
            VStack(spacing: Space.xxs) {
                FixedDigitText(text: "\(countdown.secondsLeft)", size: 72)
                    .foregroundStyle(Color.ink)
                Text(countdown.label)
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(width: 204, height: 204)
            .background(Color.surface1, in: Circle())
            .cardShadow()
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in startHolding() }
                    .onEnded { _ in stopHolding() }
            )
        }
        .frame(width: 248, height: 248)
        .opacity(passesLeft > 0 ? 1 : 0.45)
        .allowsHitTesting(passesLeft > 0 && !countdown.isDone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold for 10 seconds to use a pass")
        .accessibilityValue(countdown.isDone ? "Pass used" : "\(countdown.secondsLeft) seconds")
        // A 10-second hold is hard with assistive tech, so VoiceOver gets an action with a confirmation instead.
        .accessibilityAction(named: "Use a pass") { confirmingAccessibleUse = true }
        .confirmationDialog("Use an emergency pass?", isPresented: $confirmingAccessibleUse, titleVisibility: .visible) {
            Button("Use a pass") { complete() }
        }
    }

    private func startHolding() {
        guard holdTask == nil, passesLeft > 0, !countdown.isDone else { return }
        let start = Date.now
        holdTask = Task { @MainActor in
            while !Task.isCancelled {
                let before = countdown.secondsLeft
                countdown.progress = HoldCountdown.progress(held: Date.now.timeIntervalSince(start))
                if countdown.isDone {
                    complete()
                    return
                }
                if countdown.secondsLeft != before { Haptics.select() }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopHolding() {
        holdTask?.cancel()
        holdTask = nil
        guard !countdown.isDone else { return }
        withAnimation(Motion.ui) { countdown.progress = 0 }
    }

    private func complete() {
        guard passesLeft > 0 else { return }
        countdown.progress = 1
        Haptics.unlock()
        onUse()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        }
    }
}

#Preview("Emergency pass · dark") {
    EmergencyPassView(passesLeft: 3) {}.preferredColorScheme(.dark)
}

#Preview("Emergency pass · light") {
    EmergencyPassView(passesLeft: 3) {}.preferredColorScheme(.light)
}
```

- [ ] **Step 4: Open it from Home's pass link.** In `Tapout/App/RootView.swift`:
  - Add the case to `Cover` and its id:

```swift
enum Cover: Identifiable {
    case rejected(RejectedTag)
    case emergencyPass

    var id: String {
        switch self {
        case .rejected: "rejected"
        case .emergencyPass: "emergencyPass"
        }
    }
}
```

  - In the `fullScreenCover` switch, add:

```swift
            case .emergencyPass:
                EmergencyPassView(passesLeft: controller.passesLeft) {
                    withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) { controller.useEmergencyPass() }
                }
```

  - In `screen`, change `onEmergencyPass: useEmergencyPass,` to `onEmergencyPass: { cover = .emergencyPass },`.
  - Delete the `useEmergencyPass()` method (the hold screen plays the unlock haptic itself).

- [ ] **Step 5: Run the build/test command** — 141 + 6 = 147 tests pass, no warnings.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add the hold-for-10-seconds emergency pass`

---

> **Task 4 as built differs from the code above** after review: the hold uses `@GestureState` and stops when the app leaves `.active`, progress accumulates through `HoldCountdown.advance(by:)` with a capped step, `onUse` returns whether a pass was spent, and the screen snapshots the pass count when it opens. The source files are the truth.

---

### Task 5: Onboarding with focus time

**Files:**
- Create: `Tapout/Model/OnboardingDraft.swift`, `Tapout/Engine/ScreenTimeAccess.swift`, `Tapout/Components/DayChips.swift`, `Tapout/Components/StepDots.swift`, `Tapout/Features/Onboarding/OnboardingView.swift`, `Tapout/Features/Onboarding/OnboardingSteps.swift`, `TapoutTests/OnboardingDraftTests.swift`
- Modify: `Tapout/Model/AppSettings.swift`, `Tapout/Model/DemoData.swift` (DEBUG launch arguments), `Tapout/Features/Modes/ModeEditor.swift` (use `DayChips`), `Tapout/App/RootView.swift`

**Interfaces:**
- Consumes: `AppModel.completeOnboarding(selection:alwaysAllowed:schedule:interests:)`, `AppModel.places`, `PairPlaceSheet(model:)`, `ModeSchedule`, `ScheduleFormat.range(_:locale:)`, `Interest`, `ChoiceChip`, `SectionLabel`, `View.card(radius:padding:)`, `FlowLayout`, `OrbView`, `PrimaryButton`, FamilyControls `familyActivityPicker`, `Label(_ token:)`, `AuthorizationCenter`.
- Produces: `FocusWindow` (`mornings | afternoons | evenings`, `title`, `start`, `end`); `OnboardingDraft` (`stepCount` 5, `step`, `selection`, `alwaysAllowed`, `window`, `days`, `interests`, `schedule`, `cta`, `advance()`); `ScreenTimeAccess.request() async -> Bool`; `DayChips(days:)`; `StepDots(step:count:)`; `OnboardingView(model:onFinish:)`; `AppSettings.onboardedKey`; DEBUG launch arguments `-skipOnboarding`, `-resetOnboarding`, `-resetMilestones` (and `-demoData` now also skips onboarding).

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/OnboardingDraftTests.swift -->
```swift
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
        #expect(titles == ["Get started", "Allow", "Continue", "Continue", "Scan tag", "Scan tag"])
        #expect(draft.step == OnboardingDraft.stepCount)
    }
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `OnboardingDraft`, `FocusWindow` not found.

- [ ] **Step 3: Implement the model and the access request**

<!-- file: Tapout/Model/OnboardingDraft.swift -->
```swift
import FamilyControls
import Foundation

/// The "When should it lock?" choices.
enum FocusWindow: String, CaseIterable, Identifiable {
    case mornings, afternoons, evenings

    var id: Self { self }
    var title: String { rawValue.capitalized }

    /// Minutes after midnight.
    var start: Int {
        switch self {
        case .mornings: 9 * 60
        case .afternoons: 13 * 60
        case .evenings: 18 * 60
        }
    }

    var end: Int {
        switch self {
        case .mornings: 12 * 60
        case .afternoons: 17 * 60
        case .evenings: 21 * 60
        }
    }
}

/// Onboarding's answers, saved together on the last step.
struct OnboardingDraft {
    static let stepCount = 5

    var step = 1
    var selection = FamilyActivitySelection()
    var alwaysAllowed = FamilyActivitySelection()
    var window: FocusWindow?
    var days: Set<Int> = ModeSchedule.weekdays
    var interests: Set<Interest> = []

    /// nil without a window or days; the starter mode then stays manual.
    var schedule: ModeSchedule? {
        guard let window, !days.isEmpty else { return nil }
        return ModeSchedule(days: days, start: window.start, end: window.end)
    }

    var cta: String {
        switch step {
        case 1: "Get started"
        case 2: "Allow"
        case 3, 4: "Continue"
        default: "Scan tag"
        }
    }

    mutating func advance() {
        step = min(step + 1, Self.stepCount)
    }
}
```

<!-- file: Tapout/Engine/ScreenTimeAccess.swift -->
```swift
import FamilyControls

/// Asks for Screen Time access for this iPhone's own user.
enum ScreenTimeAccess {
    /// True when Tapout may block apps. The simulator can't grant access, so there it always continues.
    @MainActor static func request() async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return true
        } catch {
            return false
        }
        #endif
    }
}
```

In `Tapout/Model/AppSettings.swift`, add to `AppSettings`:

```swift
    /// Set once onboarding is finished or skipped.
    static let onboardedKey = "settings.onboarded"
```

In `Tapout/Model/DemoData.swift`, replace the DEBUG extension at the bottom:

```swift
#if DEBUG
extension AppModel {
    /// Launch arguments for screenshots and testing:
    /// `-demoData` replaces the App Group's modes, places and history with `DemoData` and skips onboarding;
    /// `-skipOnboarding` skips it without sample data; `-resetOnboarding` shows it again;
    /// `-resetMilestones` lets milestones show again.
    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        let store = SharedStore.appGroup()
        if arguments.contains("-demoData") { DemoData.seed(store) }
        if arguments.contains("-demoData") || arguments.contains("-skipOnboarding") {
            UserDefaults.standard.set(true, forKey: AppSettings.onboardedKey)
        }
        if arguments.contains("-resetOnboarding") { UserDefaults.standard.set(false, forKey: AppSettings.onboardedKey) }
        if arguments.contains("-resetMilestones") { store.seenMilestones = [] }
        return AppModel(store: store)
    }
}
#endif
```

- [ ] **Step 4: Write the shared pieces**

<!-- file: Tapout/Components/DayChips.swift -->
```swift
import SwiftUI

/// Monday-first day toggles sharing one row, for the Modes editor and onboarding.
struct DayChips: View {
    @Binding var days: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ModeSchedule.displayOrder, id: \.self) { day in
                ChoiceChip(title: Calendar.current.veryShortWeekdaySymbols[day - 1], isOn: days.contains(day), fillsWidth: true) {
                    if days.contains(day) { days.remove(day) } else { days.insert(day) }
                }
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
            }
        }
    }
}
```

In `Tapout/Features/Modes/ModeEditor.swift`, replace the day row (the `HStack(spacing: 6) { ForEach(ModeSchedule.displayOrder, id: \.self) { day in ChoiceChip(…) … } }` block in the When card) with `DayChips(days: $days)`, where `days` is the editor's existing day state.

<!-- file: Tapout/Components/StepDots.swift -->
```swift
import SwiftUI

/// Onboarding's progress dots: the current step is a 24pt capsule.
struct StepDots: View {
    let step: Int
    let count: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(1...count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == step ? Color.ink : Color.inkTertiary)
                    .frame(width: index == step ? 24 : 8, height: 8)
            }
        }
        .animation(Motion.ui, value: step)
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of \(count)")
    }
}
```

- [ ] **Step 5: Write the steps**

<!-- file: Tapout/Features/Onboarding/OnboardingSteps.swift -->
```swift
import FamilyControls
import SwiftUI

/// Step 1, from design/screens/Main.dc.html.
struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: Space.xxl) {
            OrbView(tone: .slate, size: 300)
            VStack(spacing: Space.xs) {
                Text("Tap to lock.").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("Tap again to get your phone back.").font(.tBody).foregroundStyle(Color.inkSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Step 2.
struct ScreenTimeStep: View {
    /// The owner declined in the system prompt.
    let denied: Bool

    var body: some View {
        VStack(spacing: Space.xxl) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "hourglass")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundStyle(Color.ink)
                    .frame(width: 200, height: 200)
                    .background(Color.surface1, in: RoundedRectangle(cornerRadius: 56, style: .continuous))
                    .cardShadow()
                Image(systemName: "lock")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.onEmber)
                    .frame(width: 64, height: 64)
                    .background(Color.ember, in: Circle())
                    .background(Circle().fill(Color.bg).padding(-6))
                    .offset(x: 10, y: 10)
            }
            .accessibilityHidden(true)
            VStack(spacing: Space.xs) {
                Text("Allow Screen Time").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("Tapout uses it to block apps on this iPhone.")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: 300)
                if denied {
                    Text("Screen Time is off. Tap Allow to try again.")
                        .font(.tFootnote)
                        .foregroundStyle(Color.danger)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Step 3: what to block, and what always stays open.
struct AppsStep: View {
    let selection: FamilyActivitySelection
    let alwaysAllowed: FamilyActivitySelection
    let onPickApps: () -> Void
    let onPickAllowed: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                Text("What should wait?").font(.tLargeTitle).foregroundStyle(Color.ink)
                blockCard
                allowedCard
            }
        }
        .scrollIndicators(.hidden)
    }

    private var blockCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(text: "Block", color: .emberInk)
                Spacer()
                Text("\(selection.applicationTokens.count + selection.categoryTokens.count)")
                    .font(.numberMedium)
                    .foregroundStyle(Color.ink)
                    + Text(" apps").font(.tSubhead).foregroundStyle(Color.inkSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.sm), count: 4), spacing: Space.sm) {
                ForEach(Array(selection.applicationTokens.prefix(7)), id: \.self) { token in
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                }
                Button(action: onPickApps) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                .strokeBorder(Color.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                        .contentShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Choose apps")
            }
        }
        .card()
    }

    private var allowedCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionLabel(text: "Always allowed", color: .slateInk)
            FlowLayout {
                // iOS never blocks the Phone app, so it is always listed.
                chip(Text("Phone"))
                ForEach(Array(alwaysAllowed.applicationTokens), id: \.self) { token in
                    chip(Label(token))
                }
                Button("+ Add", action: onPickAllowed)
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, Space.md)
                    .frame(minHeight: 44)
            }
        }
        .card()
    }

    private func chip(_ content: some View) -> some View {
        content
            .font(.tSubhead)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, Space.md)
            .frame(minHeight: 44)
            .background(Color.surface2, in: Capsule(style: .continuous))
    }
}

/// Step 4 (new): when the first mode locks by itself.
struct FocusTimeStep: View {
    @Binding var window: FocusWindow?
    @Binding var days: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("When should it lock?").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("It locks on its own. Tap a tag to open early.")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(FocusWindow.allCases) { option in
                    row(option)
                    if option != FocusWindow.allCases.last {
                        Rectangle().fill(Color.surface2).frame(height: 1)
                    }
                }
            }
            .card(padding: Space.md)
            DayChips(days: $days)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func row(_ option: FocusWindow) -> some View {
        Button {
            Haptics.select()
            window = option
        } label: {
            HStack(spacing: Space.sm) {
                Text(option.title).font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                Text(ScheduleFormat.range(ModeSchedule(days: [], start: option.start, end: option.end)))
                    .font(.numberSmall)
                    .foregroundStyle(Color.inkSecondary)
                Image(systemName: window == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(window == option ? Color.slateInk : Color.inkTertiary)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(window == option ? .isSelected : [])
    }
}

/// Step 5: the first tag, and interests for Insights' comparisons.
struct PairStep: View {
    @Binding var interests: Set<Interest>

    var body: some View {
        VStack(spacing: Space.xl) {
            VStack(spacing: 20) {
                ZStack {
                    Circle().strokeBorder(Color.slateLine, lineWidth: 2).opacity(0.6).frame(width: 216, height: 216)
                    Circle().fill(Color.slateGlow).frame(width: 164, height: 164).blur(radius: 20)
                    Circle().fill(Color.surface2).frame(width: 168, height: 168)
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Color.ink)
                }
                .frame(width: 220, height: 220)
                .accessibilityHidden(true)
                VStack(spacing: Space.xxs) {
                    Text("Pair your first tag").font(.tTitle1).foregroundStyle(Color.ink)
                    Text("Hold the top of your phone to it.").font(.tSubhead).foregroundStyle(Color.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionLabel(text: "Your interests")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 3), spacing: Space.xs) {
                    ForEach(Interest.allCases, id: \.self) { interest in
                        ChoiceChip(title: interest.title, isOn: interests.contains(interest), fillsWidth: true) {
                            if interests.contains(interest) { interests.remove(interest) } else { interests.insert(interest) }
                        }
                    }
                }
            }
        }
        .padding(.top, Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
```

- [ ] **Step 6: Write the onboarding container**

<!-- file: Tapout/Features/Onboarding/OnboardingView.swift -->
```swift
import FamilyControls
import SwiftUI

/// First-launch onboarding: design/screens/Main.dc.html steps 1–4, plus the new focus-time step.
/// Saves everything at the end; pairing the first tag (or "Not now" on step 5) finishes it.
struct OnboardingView: View {
    let model: AppModel
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = OnboardingDraft()
    @State private var pickingApps = false
    @State private var pickingAllowed = false
    @State private var pairing = false
    @State private var accessDenied = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Group {
                switch draft.step {
                case 1: WelcomeStep()
                case 2: ScreenTimeStep(denied: accessDenied)
                case 3:
                    AppsStep(
                        selection: draft.selection,
                        alwaysAllowed: draft.alwaysAllowed,
                        onPickApps: { pickingApps = true },
                        onPickAllowed: { pickingAllowed = true }
                    )
                case 4: FocusTimeStep(window: $draft.window, days: $draft.days)
                default: PairStep(interests: $draft.interests)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .familyActivityPicker(isPresented: $pickingApps, selection: $draft.selection)
            footer
                .familyActivityPicker(isPresented: $pickingAllowed, selection: $draft.alwaysAllowed)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
        .sheet(isPresented: $pairing, onDismiss: pairingEnded) {
            PairPlaceSheet(model: model)
        }
    }

    private var footer: some View {
        VStack(spacing: Space.md) {
            StepDots(step: draft.step, count: OnboardingDraft.stepCount)
            PrimaryButton(title: draft.cta) { Task { await next() } }
            if draft.step >= 4 {
                Button("Not now", action: skip)
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(minHeight: 44)
            }
        }
    }

    private func next() async {
        switch draft.step {
        case 2:
            accessDenied = !(await ScreenTimeAccess.request())
            if !accessDenied { advance() }
        case OnboardingDraft.stepCount:
            pairing = true
        default:
            advance()
        }
    }

    private func advance() {
        Haptics.select()
        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { draft.advance() }
    }

    /// Step 4 skips the schedule; step 5 finishes without a tag (pair one in Places later).
    private func skip() {
        if draft.step == 4 {
            draft.window = nil
            advance()
        } else {
            finish()
        }
    }

    private func pairingEnded() {
        if !model.places.isEmpty { finish() }
    }

    private func finish() {
        model.completeOnboarding(
            selection: draft.selection,
            alwaysAllowed: draft.alwaysAllowed,
            schedule: draft.schedule,
            interests: Interest.allCases.filter(draft.interests.contains)
        )
        onFinish()
    }
}

#Preview("Onboarding · dark") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.dark)
}

#Preview("Onboarding · light") {
    OnboardingView(model: DemoData.previewModel()) {}.preferredColorScheme(.light)
}
```

- [ ] **Step 7: Show onboarding on first launch.** In `Tapout/App/RootView.swift`:
  - Add after the appearance `@AppStorage`: `@AppStorage(AppSettings.onboardedKey) private var hasOnboarded = false`
  - Add to the `ZStack` inside the `NavigationStack`, after `.background(Color.bg.ignoresSafeArea())` (inside the stack, so it never competes with the root's `Cover`). Being inside the stack, it rebuilds if Bold Text is toggled mid-onboarding and restarts at step 1, which is acceptable:

```swift
            .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
                OnboardingView(model: model) { hasOnboarded = true }
            }
```

- [ ] **Step 8: Run the build/test command and the device compile check** — both clean, 147 + 5 = 152 tests pass.

- [ ] **Step 9: Leave uncommitted.** Suggested message: `Add onboarding with the focus-time step`

---

> **Task 5 as built differs from the code below:** after a Screen Time denial, step 2 also shows "Open Settings" (the copy reads "Screen Time is off. Turn it on in Settings, then tap Allow."); Allow ignores taps during the request; the app tiles are `Color.clear.aspectRatio(1, contentMode: .fit)` with the content in an overlay, because the "+" tile collapsed otherwise; the count says "1 app". `-mockScreenTimeDenied` shows the denial in the simulator.

### Task 6: Insights tab and milestones

**Files:**
- Create: `Tapout/Features/Insights/InsightsView.swift`, `Tapout/Features/Insights/InsightsParts.swift`, `Tapout/Features/Insights/MilestoneView.swift`
- Modify: `Tapout/Model/DemoData.swift` (intentions and interests), `TapoutTests/DemoDataTests.swift`, `Tapout/App/RootView.swift`

**Interfaces:**
- Consumes: Task 2 (`Insights`, `Gated`, `Comparison`, `Milestone`, `AppModel.unseenMilestone`, `.markSeen`, `.totalLocked`, `.history`, `.interests`), Task 3 (`Cover`, `IntentionCheck`, `unlock()`), `TimeFormat`, `OrbView`, `SectionLabel`, `CircleIconButton`, `View.card(radius:padding:)`.
- Produces: `InsightsView(model:)`; `ComparisonCard(comparison:total:)`, `WeekBars(days:)`, `InsightTile(value:caption:pending:)`; `MilestoneView(milestone:subtitle:)`; `Cover.milestone(Milestone)`.

- [ ] **Step 1: Give the demo data intentions and interests (test first).** Add to `TapoutTests/DemoDataTests.swift`, inside `DemoDataTests`:

```swift
    @Test func seedsIntentionsAndInterests() {
        let store = SharedStore.makeTest()
        DemoData.seed(store)
        let model = AppModel(store: store)
        #expect(model.interests == [.sports, .movies])
        #expect(model.history.contains { $0.intention != nil && $0.intentionDone != nil })
    }
```

Run it and see it fail, then in `Tapout/Model/DemoData.swift`:
  - in `seed`, after `store.lockHistory = …`, add `store.interests = [.sports, .movies]`.
  - in `history(deepWork:evenings:now:calendar:)`, replace the morning `records.append(…)` with:

```swift
            // Today's goal is unanswered, so Goals done reads "2 of 3" whatever the time of day.
            let goals: [(String, Bool?)] = [("Reading", nil), ("Essay outline", true), ("Chapter 4 notes", true), ("Problem set", false)]
            let goal = day < goals.count ? goals[day] : nil
            records.append(LockRecord(start: morning, end: morning + Double(60 + day * 10) * 60,
                                      placeUID: places[day % places.count], modeID: deepWork,
                                      intention: goal?.0, intentionDone: goal?.1 ?? nil))
```

- [ ] **Step 2: Write the Insights pieces**

<!-- file: Tapout/Features/Insights/InsightsParts.swift -->
```swift
import SwiftUI

/// "As long as an entire NFL game", with the interest's symbol on an ember-glow disc.
struct ComparisonCard: View {
    let comparison: Comparison
    let total: TimeInterval

    var body: some View {
        HStack(spacing: Space.md) {
            Image(systemName: comparison.symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(Color.emberInk)
                .frame(width: 56, height: 56)
                .background(Color.emberGlow, in: Circle())
                .accessibilityHidden(true)
            Text(comparison.asLongAs(total))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
        .card(padding: 20)
    }
}

/// Phone-free time per day this week. Today's bar is ember and labelled; the others stay quiet.
struct WeekBars: View {
    let days: [Insights.Day]

    var body: some View {
        let peak = max(days.map(\.lockedTime).max() ?? 0, 1)
        VStack(spacing: Space.sm) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.start) { day in
                    VStack(spacing: 6) {
                        Text(TimeFormat.short(day.lockedTime))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkTertiary)
                            .opacity(day.isToday ? 1 : 0)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(day.isToday ? Color.ember : Color.surface2)
                            .frame(height: 20 + 120 * day.lockedTime / peak)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 168)
            HStack(spacing: 10) {
                ForEach(days, id: \.start) { day in
                    Text(day.letter)
                        .font(.tCaption)
                        .foregroundStyle(day.isToday ? Color.ink : Color.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phone-free time per day this week")
        .accessibilityValue(days.map { "\($0.start.formatted(.dateTime.weekday(.wide))), \(TimeFormat.spoken($0.lockedTime))" }
            .joined(separator: "; "))
    }
}

/// A value over a caption. `pending` values are progress toward an insight ("3 of 8"), shown quieter.
/// Word values like "Mornings" stay in `numberMedium` on purpose; don't "fix" them to SF Pro.
struct InsightTile: View {
    let value: String
    let caption: String
    var pending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.numberMedium)
                .foregroundStyle(pending ? Color.inkTertiary : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface1, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
    }
}
```

<!-- file: Tapout/Features/Insights/InsightsView.swift -->
```swift
import SwiftUI

/// The Insights tab's week view, per design/screens/Insights.dc.html, with the honest-insights rules:
/// gated tiles show progress until there is enough data, and nothing counts misses.
struct InsightsView: View {
    let model: AppModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(now: context.date, calendar: .current)
        }
    }

    @ViewBuilder
    private func content(now: Date, calendar: Calendar) -> some View {
        let history = model.history
        let total = Insights.lockedTime(in: Insights.week(of: now, calendar: calendar), history: history, now: now)
        let comparison = Comparison.best(for: total, interests: model.interests)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(total: total)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(TimeFormat.short(total))
                        .font(.numberHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.ink)
                    Text("phone-free this week").font(.tBody).foregroundStyle(Color.inkSecondary)
                }
                .padding(.top, Space.xl)
                .accessibilityElement(children: .combine)
                if let comparison {
                    ComparisonCard(comparison: comparison, total: total).padding(.top, 20)
                }
                WeekBars(days: Insights.days(weekOf: now, history: history, now: now, calendar: calendar))
                    .padding(.top, Space.xl)
                tiles(now: now, calendar: calendar).padding(.top, Space.lg)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func header(total: TimeInterval) -> some View {
        HStack {
            Text("This week").font(.tHeadline).foregroundStyle(Color.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            ShareLink(item: "\(TimeFormat.short(total)) phone-free this week, with Tapout.") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.surface1, in: Circle())
                    .cardShadow()
            }
            .accessibilityLabel("Share")
        }
        .frame(height: 44)
    }

    private func tiles(now: Date, calendar: Calendar) -> some View {
        let history = model.history
        let longest = Insights.longest(weekOf: now, history: history, calendar: calendar)
        return VStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                InsightTile(value: "\(Insights.lockCount(weekOf: now, history: history, calendar: calendar))", caption: "locks")
                InsightTile(value: longest.map(TimeFormat.short) ?? "0m", caption: "longest", pending: longest == nil)
            }
            HStack(spacing: Space.sm) {
                gatedTile(Insights.bestTime(history: history, now: now, calendar: calendar),
                          caption: "best time", waiting: "locks to best time") { $0.title }
                gatedTile(Insights.goals(history: history, now: now),
                          caption: "goals done", waiting: "answers to goals") { "\($0.done) of \($0.answered)" }
            }
        }
    }

    @ViewBuilder
    private func gatedTile<Value: Equatable>(_ gated: Gated<Value>, caption: String, waiting: String,
                                  text: (Value) -> String) -> some View {
        switch gated {
        case .value(let value):
            InsightTile(value: text(value), caption: caption)
        case .progress(let have, let need):
            InsightTile(value: "\(have) of \(need)", caption: waiting, pending: true)
        }
    }
}

#Preview("Insights · dark") {
    InsightsView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Insights · light") {
    InsightsView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}
```

<!-- file: Tapout/Features/Insights/MilestoneView.swift -->
```swift
import SwiftUI

/// The milestone moment from design/screens/Insights.dc.html: a sealed ember orb in fading rings.
struct MilestoneView: View {
    let milestone: Milestone
    let subtitle: String

    @Environment(\.dismiss) private var dismiss

    private struct Ring: Hashable {
        let size: CGFloat
        let width: CGFloat
        let opacity: Double
    }

    /// The fading outer rings, largest first.
    private let rings = [Ring(size: 504, width: 1, opacity: 0.1), Ring(size: 408, width: 1.5, opacity: 0.2),
                         Ring(size: 320, width: 2, opacity: 0.4)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            }
            Spacer(minLength: 0)
            VStack(spacing: 40) {
                ZStack {
                    ForEach(rings, id: \.self) { ring in
                        Circle()
                            .strokeBorder(Color.emberLine, lineWidth: ring.width)
                            .opacity(ring.opacity)
                            .frame(width: ring.size, height: ring.size)
                    }
                    OrbView(tone: .ember, ring: 1, size: 240)
                }
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)
                VStack(spacing: Space.xs) {
                    SectionLabel(text: "Milestone", color: .emberInk)
                    Text(milestone.title).font(.tLargeTitle).foregroundStyle(Color.ink)
                    Text(subtitle).font(.tBody).foregroundStyle(Color.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                ShareLink(item: "\(milestone.title), with Tapout.") {
                    Text("Share")
                        .font(.tHeadline)
                        .foregroundStyle(Color.onEmber)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.ember, in: Capsule(style: .continuous))
                }
                Button("Done") { dismiss() }
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.md)
        .background(Color.bg.ignoresSafeArea())
    }
}

#Preview("Milestone · dark") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.dark)
}

#Preview("Milestone · light") {
    MilestoneView(milestone: .tenHours, subtitle: "About 5 movies' worth of time, back.").preferredColorScheme(.light)
}
```

- [ ] **Step 3: Wire them into RootView.** In `Tapout/App/RootView.swift`:
  - Add the case to `Cover` and its id:

```swift
enum Cover: Identifiable {
    case rejected(RejectedTag)
    case emergencyPass
    case milestone(Milestone)

    var id: String {
        switch self {
        case .rejected: "rejected"
        case .emergencyPass: "emergencyPass"
        case .milestone(let milestone): "milestone-\(milestone.rawValue)"
        }
    }
}
```

  - In the `fullScreenCover` switch, add:

```swift
            case .milestone(let milestone):
                MilestoneView(milestone: milestone,
                              subtitle: milestone.subtitle(totalLocked: model.totalLocked, interests: model.interests))
```

  - Change `.sheet(item: $intentionCheck) { check in` to `.sheet(item: $intentionCheck, onDismiss: showMilestone) { check in`.
  - In `unlock()`, after the `if let record = model.finishLock() …` block, add `if intentionCheck == nil { showMilestone() }`.
  - Add the method:

```swift
    /// After an unlock (and its "Did you do it?" sheet), celebrate the first milestone not shown yet.
    private func showMilestone() {
        guard let milestone = model.unseenMilestone() else { return }
        model.markSeen(milestone)
        cover = .milestone(milestone)
    }
```

  - In `screen`, replace `PlaceholderView(title: "Insights")` with `InsightsView(model: model)`.

- [ ] **Step 4: Check `PlaceholderView` is unused.** `grep -rn "PlaceholderView(" Tapout` should only show its own file; if so, delete `Tapout/Features/Placeholder/PlaceholderView.swift`.

- [ ] **Step 5: Run the build/test command and the device compile check** — both clean, 152 + 1 = 153 tests pass.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add Insights and milestones`

---

> **Task 6 as built differs from the code above:** Longest with no finished lock shows "0 of 1" / "lock to longest"; the comparison line uses `tTitle`; today's bar label stays on one line; `showMilestone()` also guards on no cover and unlocked, the sheet's `onDismiss` skips it mid-scan, and `AfterCover.milestone` shows milestones reached together one after another; Share hides at zero; VoiceOver speaks durations and skips empty days. The hero stays plain `Text` in `numberHero`: it moves at most once a minute, and `FixedDigitText`'s slots split "13h" into "1 3h".

> **As built, after the final review:**
> - Passes start at `SharedStore.totalPasses` and never refill. The app's controller reads `store.passesLeft` and writes back each pass spent; with no store (previews, tests) they last as long as the object. `DemoData.seed` sets 3, and the app now builds the model before the controller so the controller sees that value. `-mockState locked` reads the store; `-mockState emergency` always shows 2 and leaves the store alone. So step 4 below reads 5, then 4, on a fresh install, and 3, then 2, with `-demoData`.
> - `ScreenTimeAccess.request()` returns `.granted`, `.declined`, `.noConnection` or `.unavailable`, each with its own line; only `.declined` shows Open Settings. `-mockScreenTimeDenied` maps to `.declined`. Step 2 still has no skip (the owner's decision).
> - The emergency pass button does nothing during a scan. While unlocked, the rejected hint names the first two of all places; while locked, the first two of the mode's unlock places.
> - The onboarding cover moved below `.id(legibilityWeight)`, on its own `Color.clear` host, so Bold Text can't reset the draft. Its Fraunces titles may keep the old cut until the next step, like the other covers; not checked on screen.
> - The singular milestone line is now "About as long as a feature film." The plural form is unchanged.
> - Text buttons keep their 44pt frame and `contentShape` inside the label: Not now, Open Settings, Pair as a new place, + Add, the editor's Cancel, Save, app count and Delete mode, and Developer Lab.
> - `StepDots` uses `Motion.reveal` under Reduce Motion. Onboarding steps 1, 2, 4 and 5 scroll once they don't fit (`ScrollsWhenTall`), and the intention sheet has a `.large` detent. The NFC sheet says "Tag read." instead of "Done.", since a rejected tag shows it too.
> - Home's previews use a scratch `defaultAppStorage` with the onboarded flag set, and every onboarding step has dark and light previews.
> - Tests: 170 (17 new), including the pass, store and Screen Time mappings, the record across a pass and relock, the 50 and 100 hour milestones, Best time's 2/2/2/2 gate and 28-day window, and `TimeBlock` boundaries.

### Task 7: Verify in the simulator

Simulator: iPhone 17, iOS 26.5, id `33A5EBE9-5D77-488C-85C0-FDBC419C7ECE`. Points are 402 × 874. Tap points: tab bar Home (73, 807), Modes (158, 807), Places (243, 807), Insights (329, 807); Home's gear (356, 92); Home's mode pill (80, 92); Scan (201, 723); locked orb (201, 319). Hold the pass with a long `tap` (`duration` 11).

- [ ] **Step 1:** Run the build/test command and the device compile check: 170 tests pass, no warnings from `Tapout/`, `Shared/`, `TapoutTests/` or `TapoutMonitor/`.
- [ ] **Step 2: Onboarding, fresh install.** `xcrun simctl uninstall <id> com.raphymuthu.tapout`, install `build/dd/Build/Products/Debug-iphonesimulator/Tapout.app`, launch with no arguments, dark. Screenshot all five steps. On step 4 pick Afternoons (weekdays stay on); on step 5 pick Sports and Movies, tap "Scan tag", wait for "Tag found", save. Expected: Home, unlocked; Modes shows Focus with schedule "1–5". Repeat with `-resetOnboarding` in light and screenshot steps 1–5.
- [ ] **Step 3: Lock intention.** On Home type "Essay outline", tap Scan. Expected: the lock moment shows "Essay outline" under "Locked"; locked Home keeps it. Tap the orb: unlock, then "Did you do it?" with the intention. Tap Done. Expected next: the "First lock" milestone (ember orb, rings, "The first of many."). Done. Back on unlocked Home, "Essay outline" is a recent chip; tapping it fills the field.
- [ ] **Step 4: Emergency pass.** Lock, tap "Emergency pass · 3 left". Screenshot the hold screen (3 ember pips). Long-press 3 s and release: the ring resets to 10. Long-press 11 s: "Pass used", "Apps open", then Home in the emergency state with 2 left. Relock now.
- [ ] **Step 5: Rejected tag.** Launch with `-demoData -mockUnknownTag`, tap Scan: "That's not one of your tags.", "Try Kitchen or Desk.", "Try again" and "Pair as a new place". Close. Launch with `-demoData -mockUnknownTag -mockState locked`, tap the orb: the same title without "Pair as a new place". Screenshot both, dark and light.
- [ ] **Step 6: Insights.** Launch with `-demoData -resetMilestones`, open Insights, dark then light. Expected: hero total, an NFL comparison card, today's bar ember and labelled, tiles for locks, longest, Best time "Mornings" and Goals done "2 of 3". Launch with `-skipOnboarding` after `xcrun simctl uninstall` (empty history): tiles show "0 of 8" and "0 of 3" in ink-tertiary and the comparison card is hidden.
- [ ] **Step 7:** Compare against `Main.dc.html`, `EmergencyPass.dc.html`, `Rejected.dc.html`, `Insights.dc.html` and the spec `docs/superpowers/specs/2026-10-27-phase3b-design.md`: sizes, radii, copy, dark/light colours, disabled opacity, and that no screen counts misses. Fonts follow `Typography.swift`, not the font families in the spec files.
- [ ] **Step 8:** Report with screenshots saved as contact sheets in `docs/superpowers/verification/phase3b-*.png`. Note what the simulator can't show (haptics, the real app picker, real NFC, Screen Time authorization). Leave all changes uncommitted with the suggested message `Phase 3B verification results`.

---

## Phase 4 notes (from this plan)

- `RootView` calls `AppModel.discardInterruptedLocks()` at launch only because mock lock state isn't persisted. Once `LockEngine` persists the session, an open record can be a real running lock, so remove that call.
- `LockEngine` takes over lock recording: `startLock` / `finishLock` move into `handleTag`, the intention draft passes through, and scheduled unlocks also finish the record and ask "Did you do it?" the next time Tapout opens.
- `RootView.scan()` keeps its shape; `MockLockController.simulateTagRead()` becomes `LockEngine.handleTag(_:)`, which enforces unlock places itself.
- `currentIntention` is ready for the Phase 5 Live Activity.
- An emergency pass doesn't end the lock record today, so Insights counts pass time as locked. Phase 4 can record pass windows and subtract them if that matters.
- Onboarding's Screen Time step calls the real authorization on device; Phase 4 should re-check it on launch and show the Screen Time step again if access was revoked.
- Every shield path must apply the active mode's selection and honour `alwaysAllowed`. Today they all read `store.selection`, which `AppModel` never writes: `LockEngine.handleTag` (`LockEngine.swift:95`), `LockEngine.relockNow` (`:134`), and `EmergencyRelock.perform` (`Shared/EmergencyRelock.swift:10`), which `LockEngine.tick` and the monitor extension both use. Fixing `handleTag` alone leaves the phone open after a pass relocks. The monitor has no `AppModel`, so the resolved selection must be readable from `SharedStore`. `alwaysAllowed` also needs `ShieldController.apply` to change: `Shared/ShieldController.swift:23,25` uses `.specific(categories)` with no `except:`.
- Home's timer restarts after a pass while the record keeps the full span; decide this together with pass windows.
- One `TagReader`, owned by the engine. Give the verdict before invalidating the NFC session. Scan-flow tests belong on `handleTag`.
- Device checks: the lock moment and haptics against the NFC sheet; the milestone cover against the unlock spring; `wrongPlace`; whether iOS asks for Screen Time again after a decline; Open Settings; both real pickers; which Screen Time errors actually fire.
- The controller's stored passes move to `LockEngine`.
