# Phase 3A Settings, Places and Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real, persisted modes, places and settings with their screens: Settings (pushed from Home's gear, read-only while locked), the Places tab with pairing and place sheets, the Modes tab with the mode editor, and a mode picker on Home. All of it runs in the simulator on mock lock state.

**Architecture:** New models (`Mode`, `ModeSchedule`, `LockRecord`) live in `Shared/` and persist in the App Group `SharedStore`, because the monitor extension will run mode schedules in Phase 4. A `@MainActor @Observable AppModel` wraps the store for the app (modes, places, history, always-allowed apps) the way `LockEngine` wraps it for locking. Lock state still comes from `MockLockController`; `RootView` publishes it as an `isLocked` environment value that every editable screen respects. Hardware is behind small seams: a `TagScanning` protocol (real `TagReader` on device, `MockTagScanner` in the simulator) and `FamilyActivityPicker` for apps. `RootView` becomes a `NavigationStack` so Settings is a push that covers the tab bar.

**Tech Stack:** Swift 6, SwiftUI, Observation, FamilyControls (`FamilyActivitySelection`, `FamilyActivityPicker`, `Label(token)`), Core NFC (through `TagReader`), Swift Testing, XcodeGen, Xcode 27.1, iPhone 17 simulator (iOS 26.5).

## Decisions (2026-10-27)

- **Schedules auto-lock and auto-unlock.** At a schedule's start the mode locks by itself; at its end it unlocks. Phase 3A only stores and shows schedules; Phase 4 runs them with DeviceActivity.
- **Unlock places.** A mode can only be unlocked by its chosen places; no places chosen means any paired place. 3A stores and shows this; Phase 4 enforces it in `LockEngine.handleTag`.
- **Everything editable is read-only while locked** (an emergency pass counts as locked). That includes pairing new places, so an unknown sticker can never be paired to escape a lock.
- **Emergency pass link stays on locked Home** and will open the hold screen in 3B. 3A leaves Home's emergency behaviour as it is.
- **Phase 3 is split.** 3A (this plan): data models, Settings, Places, Modes, Home mode picker. 3B: Onboarding, Emergency pass hold, Rejected tag, Insights and milestone.
- **Real data, mocked hardware.** Modes, places, history and preferences are real and persisted now. Tag reads use `MockTagScanner` where NFC isn't available; the app picker is the real `FamilyActivityPicker` (it shows nothing useful in the simulator, which is expected).
- **A fresh install starts with one mode, "Focus"**, with no schedule and no apps. 3B's onboarding fills it in.
- **Preferences** (haptics, Live Activity, appearance) are app-only, so they live in standard `UserDefaults` via `@AppStorage`. Live Activity is stored only; Phase 5 reads it.
- **The Lab moves.** In DEBUG, a "Developer Lab" row at the bottom of Settings opens `LabView`; the gear no longer opens it directly.
- **`-demoData`** (DEBUG launch argument) replaces the App Group's modes, places and history with spec-like sample data for screenshots.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor extension `com.raphymuthu.tapout.monitor`. App Group `group.com.raphymuthu.tapout`.
- Five emergency passes total, ever (`SharedStore.totalPasses`).
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.inkTertiary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.slate`, `.slateInk`, `.slateLine`, `.danger`, …). No raw hex.
- SF Pro for words, SF Pro Rounded for numbers; `.monospacedDigit()` on anything that ticks.
- 44pt minimum touch targets. Continuous corners. No borders on cards; light theme cards carry `cardShadow()`.
- Disabled controls show at 0.45 opacity.
- Copy: very few words, no guilt or shame, no emoji, no exclamation marks.
- `Shared/` stays free of SwiftUI (it compiles into the extension).
- Every new screen has `#Preview`s in dark and light.
- Never commit. The user commits manually; each task ends with a suggested commit message.

## File map

| File | Responsibility |
| --- | --- |
| `Shared/Mode.swift` | `ModeSchedule`, `Mode` |
| `Shared/LockRecord.swift` | One past or running lock |
| `Shared/SharedStore.swift` | + `modes`, `activeModeID`, `defaultPlace`, `lockHistory`, `alwaysAllowed` |
| `Tapout/Model/ScheduleFormat.swift` | Schedule wording; `ClockMinutes` (minutes ↔ `Date`) |
| `Tapout/Model/LockStats.swift` | Lock counts per place, locked time per mode per week |
| `Tapout/Model/ModeText.swift` | `Copy.count`, mode card wording |
| `Tapout/Model/AppModel.swift` | Observable modes, places, history, always-allowed |
| `Tapout/Model/AppSettings.swift` | `Appearance`, preference keys |
| `Tapout/Model/DemoData.swift` | Sample data, preview model, `-demoData` |
| `Tapout/Model/MockData.swift` | Drop `modeName` (now real) |
| `Tapout/DesignSystem/Haptics.swift` | Respect the haptics preference |
| `Tapout/DesignSystem/Typography.swift` | + `tTitle1` (28/34 semibold) |
| `Tapout/App/LockEnvironment.swift` | `\.isLocked` |
| `Tapout/Components/{SectionLabel,Card,CircleIconButton,ScreenHeader,ChoiceChip,DashedTile,LockedBanner,PassPips,FlowLayout}.swift` | Shared pieces used by 3A and 3B |
| `Tapout/App/RootView.swift` | NavigationStack, routes, tabs, appearance, `isLocked` |
| `Tapout/App/TapoutApp.swift` | Creates the `AppModel` |
| `Tapout/Features/Settings/SettingsView.swift` | Settings |
| `Tapout/Engine/TagScanning.swift` | `TagScanning`, `TagScanners`, `MockTagScanner` |
| `Tapout/Features/Places/{PlacesView,PlaceCards,PairPlaceSheet,PlaceSheet}.swift` | Places tab and sheets |
| `Tapout/Features/Modes/{ModesView,ModeCards,ModeEditor}.swift` | Modes tab and editor |
| `Tapout/Features/Home/{HomeView,HomeHeader}.swift` | Real mode name; mode picker |
| `TapoutTests/{ScheduleFormat,LockStats,ModeText,AppModel,AppSettings,DemoData}Tests.swift`, `SharedStoreTests.swift` | Unit tests |

Build/test command used throughout (run from `~/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)"
```

Device compile check, for tasks that touch FamilyControls UI or Core NFC (signing isn't set up yet, so it builds unsigned):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build -quiet
```

The suite has 54 tests before this plan.

---

### Task 1: Models, store keys and wording helpers

**Files:**
- Create: `Shared/Mode.swift`, `Shared/LockRecord.swift`, `Tapout/Model/ScheduleFormat.swift`, `Tapout/Model/LockStats.swift`, `Tapout/Model/ModeText.swift`
- Modify: `Shared/SharedStore.swift`
- Test: `TapoutTests/ScheduleFormatTests.swift`, `TapoutTests/LockStatsTests.swift`, `TapoutTests/ModeTextTests.swift`, `TapoutTests/SharedStoreTests.swift`

**Interfaces:**
- Consumes: `SharedStore` (private `read(_:absent:corrupt:)` / `write(_:_:)`), `TagUID`, `PairedTag`, `TimeFormat` (Phase 1–2).
- Produces:
  - `ModeSchedule(days: Set<Int>, start: Int, end: Int)`; statics `weekdays`, `weekend`, `everyDay`, `displayOrder` (`[2,3,4,5,6,7,1]`).
  - `Mode(id:name:selection:schedule:unlockPlaces:)` (all but `name` defaulted), `Identifiable`, `Equatable`, `Codable`; `blockedCount`.
  - `LockRecord(start:end:placeUID:modeID:intention:intentionDone:)` (last two optional, default nil).
  - `SharedStore.modes`, `.activeModeID`, `.defaultPlace`, `.lockHistory`, `.alwaysAllowed`.
  - `ScheduleFormat.short(_:)`, `.range(_:locale:)`, `.days(_:calendar:)`; `ClockMinutes.date(_:on:calendar:)`, `.minutes(of:calendar:)`.
  - `LockStats.lockCount(at:in:)`, `.lockedTime(modeID:weekOf:in:calendar:)`.
  - `Copy.count(_:_:_:)`; `ModeText.apps(_:)`, `.subtitle(_:)`, `.unlockSummary(_:)`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/ScheduleFormatTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct ScheduleFormatTests {
    private let posix: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    @Test(arguments: [
        (ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020), "9–5"),
        (ModeSchedule(days: ModeSchedule.weekdays, start: 570, end: 1020), "9:30–5"),
        (ModeSchedule(days: ModeSchedule.everyDay, start: 1350, end: 420), "10:30–7"),
        (ModeSchedule(days: ModeSchedule.everyDay, start: 0, end: 720), "12–12"),
    ])
    func shortFormFitsATile(_ schedule: ModeSchedule, _ expected: String) {
        #expect(ScheduleFormat.short(schedule) == expected)
    }

    @Test func rangeFollowsTheLocale() {
        let schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020)
        #expect(ScheduleFormat.range(schedule, locale: Locale(identifier: "de_DE")) == "09:00 – 17:00")
    }

    @Test func namedDayGroups() {
        #expect(ScheduleFormat.days(ModeSchedule.weekdays, calendar: posix) == "weekdays")
        #expect(ScheduleFormat.days(ModeSchedule.weekend, calendar: posix) == "weekends")
        #expect(ScheduleFormat.days(ModeSchedule.everyDay, calendar: posix) == "every day")
    }

    @Test func otherDaysListMondayFirst() {
        #expect(ScheduleFormat.days([1, 4, 2], calendar: posix) == "Mon, Wed, Sun")
    }

    @Test func clockMinutesRoundTrip() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = ClockMinutes.date(570, on: Date(timeIntervalSinceReferenceDate: 800_000_000), calendar: calendar)
        #expect(calendar.component(.hour, from: date) == 9)
        #expect(ClockMinutes.minutes(of: date, calendar: calendar) == 570)
    }
}
```

<!-- file: TapoutTests/LockStatsTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct LockStatsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        return calendar
    }()
    private let mode = UUID()
    private let kitchen = TagUID(hex: "04A1")

    /// Wednesday 28 October 2026, 12:00 UTC.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))! }

    @Test func countsLocksAtOnePlace() {
        let history = [
            LockRecord(start: now - 5 * 3600, end: now - 4 * 3600, placeUID: kitchen, modeID: mode),
            LockRecord(start: now - 3 * 3600, end: now - 2 * 3600, placeUID: TagUID(hex: "04B2"), modeID: mode),
            LockRecord(start: now - 3600, end: now - 1800, placeUID: kitchen, modeID: mode),
        ]
        #expect(LockStats.lockCount(at: kitchen, in: history) == 2)
    }

    @Test func weekTotalClipsAtTheWeekStartAndCountsTheRunningLock() {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let history = [
            LockRecord(start: weekStart - 3600, end: weekStart + 3600, placeUID: nil, modeID: mode), // 1h inside
            LockRecord(start: now - 7200, end: now - 3600, placeUID: nil, modeID: mode), // 1h
            LockRecord(start: now - 1800, end: nil, placeUID: nil, modeID: mode), // running, 30m so far
            LockRecord(start: now - 7200, end: now, placeUID: nil, modeID: UUID()), // another mode
            LockRecord(start: weekStart - 86_400, end: weekStart - 82_800, placeUID: nil, modeID: mode), // last week
        ]
        #expect(LockStats.lockedTime(modeID: mode, weekOf: now, in: history, calendar: calendar) == 9000)
    }
}
```

<!-- file: TapoutTests/ModeTextTests.swift -->
```swift
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
```

Append to `TapoutTests/SharedStoreTests.swift`, inside `struct SharedStoreTests`:

```swift
    @Test func newKeysStartEmpty() {
        let store = SharedStore.makeTest()
        #expect(store.modes.isEmpty)
        #expect(store.activeModeID == nil)
        #expect(store.defaultPlace == nil)
        #expect(store.lockHistory.isEmpty)
    }

    @Test func modesPlacesAndHistoryRoundTrip() {
        let store = SharedStore.makeTest()
        let kitchen = TagUID(hex: "04A1")
        let mode = Mode(
            name: "Deep work",
            schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020),
            unlockPlaces: [kitchen]
        )
        store.modes = [mode]
        store.activeModeID = mode.id
        store.defaultPlace = kitchen
        store.lockHistory = [LockRecord(start: Self.start, end: Self.start + 60, placeUID: kitchen, modeID: mode.id)]

        #expect(store.modes == [mode])
        #expect(store.activeModeID == mode.id)
        #expect(store.defaultPlace == kitchen)
        #expect(store.lockHistory == [LockRecord(start: Self.start, end: Self.start + 60, placeUID: kitchen, modeID: mode.id)])
    }

    @Test func lockIntentionRoundTripsAndIsNilWhenAbsent() throws {
        let store = SharedStore.makeTest()
        let modeID = UUID()
        let withIntention = LockRecord(start: Self.start, end: Self.start + 60, placeUID: nil, modeID: modeID,
                                       intention: "History essay, first paragraph", intentionDone: true)
        let without = LockRecord(start: Self.start, end: nil, placeUID: nil, modeID: modeID)
        store.lockHistory = [withIntention, without]
        #expect(store.lockHistory == [withIntention, without])
        #expect(store.lockHistory[1].intention == nil)
        #expect(store.lockHistory[1].intentionDone == nil)

        // History saved before these fields existed has no keys for them.
        let json = Data(#"{"start":0,"modeID":"\#(modeID.uuidString)"}"#.utf8)
        let old = try JSONDecoder().decode(LockRecord.self, from: json)
        #expect(old.intention == nil)
        #expect(old.intentionDone == nil)
    }
```

- [ ] **Step 2: Run the tests to see them fail** — expect build errors: `ModeSchedule`, `Mode`, `LockRecord`, `ScheduleFormat`, `LockStats`, `Copy`, `ModeText` not found.

- [ ] **Step 3: Implement**

<!-- file: Shared/Mode.swift -->
```swift
import FamilyControls
import Foundation

/// When a mode locks by itself. It locks at `start` and unlocks at `end` on each of `days`.
struct ModeSchedule: Codable, Equatable, Sendable {
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    var days: Set<Int>
    /// Minutes after midnight. An `end` before `start` runs past midnight.
    var start: Int
    var end: Int

    static let weekdays: Set<Int> = [2, 3, 4, 5, 6]
    static let weekend: Set<Int> = [1, 7]
    static let everyDay: Set<Int> = Set(1...7)
    /// Monday first, for day chips and lists.
    static let displayOrder = [2, 3, 4, 5, 6, 7, 1]
}

/// A named set of apps to block, an optional schedule, and the places that can end it.
struct Mode: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var schedule: ModeSchedule?
    /// Places that can unlock this mode. Empty means any paired place.
    var unlockPlaces: Set<TagUID>

    init(
        id: UUID = UUID(),
        name: String,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        schedule: ModeSchedule? = nil,
        unlockPlaces: Set<TagUID> = []
    ) {
        self.id = id
        self.name = name
        self.selection = selection
        self.schedule = schedule
        self.unlockPlaces = unlockPlaces
    }

    /// Apps plus categories, for "6 apps" labels.
    var blockedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
}
```

<!-- file: Shared/LockRecord.swift -->
```swift
import Foundation

/// One lock, for counts and totals in Places, Modes and Insights. `end` is nil while it runs.
struct LockRecord: Codable, Equatable, Sendable {
    let start: Date
    var end: Date?
    let placeUID: TagUID?
    let modeID: UUID
    /// What the lock was for ("History essay, first paragraph"). Optional; Phase 3B sets it.
    var intention: String? = nil
    /// The answer to "Did you do it?" on unlock. nil = no intention, not asked, or skipped.
    var intentionDone: Bool? = nil
}
```

In `Shared/SharedStore.swift`, add these properties after `relockStrategy`:

```swift
    /// Every mode the owner has made. `AppModel` keeps at least one.
    var modes: [Mode] {
        get { read(.modes, absent: [], corrupt: []) }
        set { write(newValue, .modes) }
    }

    var activeModeID: UUID? {
        get { read(.activeModeID, absent: nil, corrupt: nil) }
        set { write(newValue, .activeModeID) }
    }

    /// The place Places shows first.
    var defaultPlace: TagUID? {
        get { read(.defaultPlace, absent: nil, corrupt: nil) }
        set { write(newValue, .defaultPlace) }
    }

    var lockHistory: [LockRecord] {
        get { read(.lockHistory, absent: [], corrupt: []) }
        set { write(newValue, .lockHistory) }
    }

    /// Apps that stay open in every mode.
    var alwaysAllowed: FamilyActivitySelection {
        get { read(.alwaysAllowed, absent: FamilyActivitySelection(), corrupt: FamilyActivitySelection()) }
        set { write(newValue, .alwaysAllowed) }
    }
```

and extend the key list:

```swift
    private enum Key: String {
        case session, selection, pairedTags, passesLeft, relockStrategy, log
        case modes, activeModeID, defaultPlace, lockHistory, alwaysAllowed
    }
```

<!-- file: Tapout/Model/ScheduleFormat.swift -->
```swift
import Foundation

/// Wording for mode schedules.
enum ScheduleFormat {
    /// Tile form: "9–5", "9:30–5". Twelve-hour without am/pm; the tile has no room for more.
    static func short(_ schedule: ModeSchedule) -> String {
        "\(compact(schedule.start))–\(compact(schedule.end))"
    }

    /// Editor form in the owner's locale: "09:00 – 17:00", "9:00 AM – 5:00 PM".
    static func range(_ schedule: ModeSchedule, locale: Locale = .current) -> String {
        "\(time(schedule.start, locale: locale)) – \(time(schedule.end, locale: locale))"
    }

    /// "weekdays", "weekends", "every day", or short day names Monday first: "Mon, Wed".
    static func days(_ days: Set<Int>, calendar: Calendar = .current) -> String {
        switch days {
        case ModeSchedule.everyDay: return "every day"
        case ModeSchedule.weekdays: return "weekdays"
        case ModeSchedule.weekend: return "weekends"
        default:
            return ModeSchedule.displayOrder
                .filter(days.contains)
                .map { calendar.shortWeekdaySymbols[$0 - 1] }
                .joined(separator: ", ")
        }
    }

    private static func compact(_ minutes: Int) -> String {
        let hour = minutes / 60 % 12 == 0 ? 12 : minutes / 60 % 12
        let minute = minutes % 60
        return minute == 0 ? "\(hour)" : "\(hour):" + String(format: "%02d", minute)
    }

    private static func time(_ minutes: Int, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: Date(timeIntervalSinceReferenceDate: TimeInterval(minutes * 60)))
    }
}

/// Converts between a schedule's minutes after midnight and the `Date` a `DatePicker` edits.
enum ClockMinutes {
    static func date(_ minutes: Int, on day: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
```

<!-- file: Tapout/Model/LockStats.swift -->
```swift
import Foundation

/// Totals over the lock history.
enum LockStats {
    static func lockCount(at place: TagUID, in history: [LockRecord]) -> Int {
        history.filter { $0.placeUID == place }.count
    }

    /// Time locked in `modeID` during the week that contains `now`. A lock still running counts up to `now`.
    static func lockedTime(modeID: UUID, weekOf now: Date, in history: [LockRecord], calendar: Calendar = .current) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return history.filter { $0.modeID == modeID }.reduce(0) { total, record in
            let start = max(record.start, week.start)
            let end = min(record.end ?? now, week.end)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
```

<!-- file: Tapout/Model/ModeText.swift -->
```swift
import Foundation

enum Copy {
    /// "1 lock", "3 locks".
    static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }
}

/// Wording on mode cards and tiles.
enum ModeText {
    static func apps(_ mode: Mode) -> String {
        Copy.count(mode.blockedCount, "app", "apps")
    }

    /// "6 apps · weekdays", "2 apps · manual".
    static func subtitle(_ mode: Mode) -> String {
        "\(apps(mode)) · \(mode.schedule.map { ScheduleFormat.days($0.days) } ?? "manual")"
    }

    /// Unlock place names in pairing order, shortened for a tile.
    static func unlockSummary(_ names: [String]) -> String {
        switch names.count {
        case 0: "Any place"
        case 1: names[0]
        default: "\(names[0]) +\(names.count - 1)"
        }
    }
}
```

- [ ] **Step 4: Run the build/test command** — all tests pass (54 existing + 13 new = 67), no warnings from `Tapout/`, `Shared/` or `TapoutTests/`. Then run the device compile check (the extension now compiles `Mode.swift`). `Mode`'s synthesized `Equatable` relies on `FamilyActivitySelection` being `Equatable`; if this SDK says it isn't, stop and report it rather than hand-writing `==`.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Add mode, schedule and lock history models with wording helpers`

---

### Task 2: AppModel, preferences, haptics toggle and demo data

**Files:**
- Create: `Tapout/Model/AppModel.swift`, `Tapout/Model/AppSettings.swift`, `Tapout/Model/DemoData.swift`
- Modify: `Tapout/DesignSystem/Haptics.swift`
- Test: `TapoutTests/AppModelTests.swift`, `TapoutTests/AppSettingsTests.swift`, `TapoutTests/DemoDataTests.swift`

**Interfaces:**
- Consumes: Task 1 types and store keys; `SharedStore.makeTest(suite:)` (tests).
- Produces:
  - `AppModel(store:now:)`, `AppModel.live()`, DEBUG `AppModel.fromLaunchArguments()`, `AppModel.starterModeName` ("Focus").
  - Observable read-only `modes`, `activeModeID`, `places`, `defaultPlaceID`, `history`, `alwaysAllowed`.
  - `activeMode`, `otherModes`, `newMode()`, `isSaved(_:)`, `save(_:)`, `deleteMode(id:) -> Bool`, `setActiveMode(_:)`, `unlockPlaceNames(for:)`, `lockedThisWeek(_:calendar:)`.
  - `defaultPlace`, `otherPlaces`, `pair(_:name:) -> PairResult` (`.paired | .alreadyPaired(name:)`), `renamePlace(_:to:)`, `removePlace(_:)`, `makeDefault(_:)`, `lockCount(at:)`, `updateAlwaysAllowed(_:)`.
  - `Appearance` (`system | light | dark`, `title`, `colorScheme`), `AppSettings.hapticsKey`, `.liveActivityKey`, `.appearanceKey`, `.hapticsEnabled(in:)`.
  - `DemoData.seed(_:now:calendar:)`, `DemoData.previewModel()`, place UIDs `DemoData.kitchen`, `.desk`, `.car`, `.bedroom`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/AppModelTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelTests {
    private let store = SharedStore.makeTest()
    private let kitchen = TagUID(hex: "04A1")
    private let desk = TagUID(hex: "04B2")

    @Test func freshInstallStartsWithOneActiveMode() {
        let model = AppModel(store: store)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName])
        #expect(model.activeMode.id == model.modes[0].id)
    }

    @Test func existingModesAreNotReseeded() {
        store.modes = [Mode(name: "Deep work")]
        #expect(AppModel(store: store).modes.map(\.name) == ["Deep work"])
    }

    @Test func activeModeFallsBackToTheFirst() {
        store.modes = [Mode(name: "A"), Mode(name: "B")]
        store.activeModeID = UUID()
        #expect(AppModel(store: store).activeMode.name == "A")
    }

    @Test func saveAddsANewModeAndReplacesAnExistingOne() {
        let model = AppModel(store: store)
        var mode = model.newMode()
        #expect(!model.isSaved(mode))
        mode.name = "  Evenings  "
        model.save(mode)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName, "Evenings"])
        mode.name = "Nights"
        model.save(mode)
        #expect(model.modes.map(\.name) == [AppModel.starterModeName, "Nights"])
    }

    @Test func activeModeSurvivesANewModel() {
        let model = AppModel(store: store)
        let evenings = Mode(name: "Evenings")
        model.save(evenings)
        model.setActiveMode(evenings.id)
        #expect(AppModel(store: store).activeMode.id == evenings.id)
    }

    @Test func theLastModeCantBeDeleted() {
        let model = AppModel(store: store)
        #expect(!model.deleteMode(id: model.modes[0].id))
        #expect(model.modes.count == 1)
    }

    @Test func deletingTheActiveModeActivatesTheFirst() {
        let model = AppModel(store: store)
        let evenings = Mode(name: "Evenings")
        model.save(evenings)
        model.setActiveMode(evenings.id)
        #expect(model.deleteMode(id: evenings.id))
        #expect(model.activeMode.name == AppModel.starterModeName)
    }

    @Test func firstPairedPlaceBecomesDefault() {
        let model = AppModel(store: store)
        #expect(model.pair(kitchen, name: "Kitchen") == .paired)
        #expect(model.pair(desk, name: "Desk") == .paired)
        #expect(model.defaultPlace?.uid == kitchen)
        #expect(model.otherPlaces.map(\.name) == ["Desk"])
    }

    @Test func pairingATagTwiceIsRefused() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        #expect(model.pair(kitchen, name: "Desk") == .alreadyPaired(name: "Kitchen"))
        #expect(model.places.count == 1)
    }

    @Test func blankNamesGetANumberedPlace() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "   ")
        #expect(model.places.first?.name == "Place 1")
    }

    @Test func renamingTrimsAndIgnoresBlanks() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.renamePlace(kitchen, to: "  Pantry ")
        #expect(model.places.first?.name == "Pantry")
        model.renamePlace(kitchen, to: " ")
        #expect(model.places.first?.name == "Pantry")
    }

    @Test func removingAPlaceForgetsItEverywhere() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        model.save(Mode(name: "Deep work", unlockPlaces: [kitchen, desk]))
        model.removePlace(kitchen)
        #expect(model.places.map(\.name) == ["Desk"])
        #expect(model.defaultPlace?.uid == desk)
        #expect(model.modes.last?.unlockPlaces == [desk])
    }

    @Test func makeDefaultMovesTheHero() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        model.makeDefault(desk)
        #expect(model.defaultPlace?.uid == desk)
        #expect(model.otherPlaces.map(\.name) == ["Kitchen"])
    }

    @Test func unlockPlaceNamesFollowPairingOrderAndSkipUnknownTags() {
        let model = AppModel(store: store)
        model.pair(kitchen, name: "Kitchen")
        model.pair(desk, name: "Desk")
        let mode = Mode(name: "Deep work", unlockPlaces: [desk, kitchen, TagUID(hex: "FFFF")])
        #expect(model.unlockPlaceNames(for: mode) == ["Kitchen", "Desk"])
    }
}
```

<!-- file: TapoutTests/AppSettingsTests.swift -->
```swift
import Foundation
import SwiftUI
import Testing
@testable import Tapout

struct AppSettingsTests {
    @Test func hapticsAreOnUntilTurnedOff() {
        let defaults = UserDefaults(suiteName: "tapout.tests.\(UUID().uuidString)")!
        #expect(AppSettings.hapticsEnabled(in: defaults))
        defaults.set(false, forKey: AppSettings.hapticsKey)
        #expect(!AppSettings.hapticsEnabled(in: defaults))
    }

    @Test func appearanceMapsToAColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }
}
```

<!-- file: TapoutTests/DemoDataTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct DemoDataTests {
    @Test func seedsTheSpecsSampleData() {
        let store = SharedStore.makeTest()
        DemoData.seed(store)
        let model = AppModel(store: store)

        #expect(model.modes.map(\.name) == ["Deep work", "Evenings", "Weekend", "Sleep"])
        #expect(model.activeMode.name == "Deep work")
        #expect(model.activeMode.schedule == ModeSchedule(days: ModeSchedule.weekdays, start: 540, end: 1020))
        #expect(model.unlockPlaceNames(for: model.activeMode) == ["Kitchen"])
        #expect(model.places.map(\.name) == ["Kitchen", "Desk", "Car", "Bedroom"])
        #expect(model.defaultPlace?.name == "Kitchen")
        let modeIDs = Set(model.modes.map(\.id))
        #expect(!model.history.isEmpty)
        #expect(model.history.allSatisfy { modeIDs.contains($0.modeID) })
    }
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `AppModel`, `AppSettings`, `Appearance`, `DemoData` not found.

- [ ] **Step 3: Implement**

<!-- file: Tapout/Model/AppModel.swift -->
```swift
import FamilyControls
import Foundation
import Observation

/// Modes, places, lock history and always-allowed apps, kept in the App Group store so the
/// monitor extension can run schedules in Phase 4. Lock state stays with the lock controller.
@MainActor
@Observable
final class AppModel {
    enum PairResult: Equatable {
        case paired
        case alreadyPaired(name: String)
    }

    /// The one mode a fresh install starts with.
    static let starterModeName = "Focus"

    private(set) var modes: [Mode] = []
    private(set) var activeModeID: UUID?
    private(set) var places: [PairedTag] = []
    private(set) var defaultPlaceID: TagUID?
    private(set) var history: [LockRecord] = []
    private(set) var alwaysAllowed = FamilyActivitySelection()

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let now: () -> Date

    init(store: SharedStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
        reload()
    }

    static func live() -> AppModel {
        AppModel(store: .appGroup())
    }

    /// Re-reads the store. Seeds the starter mode when there are none, so `activeMode` always exists.
    func reload() {
        if store.modes.isEmpty {
            let starter = Mode(name: Self.starterModeName)
            store.modes = [starter]
            store.activeModeID = starter.id
        }
        modes = store.modes
        activeModeID = store.activeModeID
        places = store.pairedTags
        defaultPlaceID = store.defaultPlace
        history = store.lockHistory
        alwaysAllowed = store.alwaysAllowed
    }

    // MARK: Modes

    /// The chosen mode, or the first one if the chosen one is gone.
    var activeMode: Mode {
        modes.first { $0.id == activeModeID } ?? modes[0]
    }

    var otherModes: [Mode] {
        modes.filter { $0.id != activeMode.id }
    }

    /// A blank mode for the editor. It isn't stored until `save`.
    func newMode() -> Mode {
        Mode(name: "")
    }

    func isSaved(_ mode: Mode) -> Bool {
        modes.contains { $0.id == mode.id }
    }

    /// Adds the mode, or replaces the stored one with the same id.
    func save(_ mode: Mode) {
        var mode = mode
        mode.name = Self.cleaned(mode.name, fallback: "Mode")
        var all = store.modes
        if let index = all.firstIndex(where: { $0.id == mode.id }) {
            all[index] = mode
        } else {
            all.append(mode)
        }
        store.modes = all
        reload()
    }

    /// Refuses to delete the last mode. Deleting the active mode makes the first remaining one active.
    @discardableResult
    func deleteMode(id: UUID) -> Bool {
        var all = store.modes
        guard all.count > 1, all.contains(where: { $0.id == id }) else { return false }
        all.removeAll { $0.id == id }
        store.modes = all
        if store.activeModeID == id { store.activeModeID = all[0].id }
        reload()
        return true
    }

    func setActiveMode(_ id: UUID) {
        guard modes.contains(where: { $0.id == id }) else { return }
        store.activeModeID = id
        reload()
    }

    /// Names of the places that unlock `mode`, in pairing order. Empty means any place.
    func unlockPlaceNames(for mode: Mode) -> [String] {
        places.filter { mode.unlockPlaces.contains($0.uid) }.map(\.name)
    }

    func lockedThisWeek(_ mode: Mode, calendar: Calendar = .current) -> TimeInterval {
        LockStats.lockedTime(modeID: mode.id, weekOf: now(), in: history, calendar: calendar)
    }

    // MARK: Places

    /// The chosen default, or the first place if that one was removed.
    var defaultPlace: PairedTag? {
        places.first { $0.uid == defaultPlaceID } ?? places.first
    }

    var otherPlaces: [PairedTag] {
        places.filter { $0.uid != defaultPlace?.uid }
    }

    /// Only call while unlocked; the screens enforce that. The first place becomes the default.
    @discardableResult
    func pair(_ uid: TagUID, name: String) -> PairResult {
        if let existing = store.pairedTags.first(where: { $0.uid == uid }) {
            return .alreadyPaired(name: existing.name)
        }
        let fallback = "Place \(store.pairedTags.count + 1)"
        store.pairedTags.append(PairedTag(uid: uid, name: Self.cleaned(name, fallback: fallback), pairedAt: now()))
        if store.defaultPlace == nil { store.defaultPlace = uid }
        reload()
        return .paired
    }

    func renamePlace(_ uid: TagUID, to name: String) {
        let name = Self.cleaned(name, fallback: "")
        guard !name.isEmpty else { return }
        store.pairedTags = store.pairedTags.map { tag in
            var tag = tag
            if tag.uid == uid { tag.name = name }
            return tag
        }
        reload()
    }

    /// Forgets the place everywhere. Modes that unlocked only there unlock at any place.
    func removePlace(_ uid: TagUID) {
        store.pairedTags.removeAll { $0.uid == uid }
        store.modes = store.modes.map { mode in
            var mode = mode
            mode.unlockPlaces.remove(uid)
            return mode
        }
        if store.defaultPlace == uid { store.defaultPlace = store.pairedTags.first?.uid }
        reload()
    }

    func makeDefault(_ uid: TagUID) {
        guard places.contains(where: { $0.uid == uid }) else { return }
        store.defaultPlace = uid
        reload()
    }

    func lockCount(at uid: TagUID) -> Int {
        LockStats.lockCount(at: uid, in: history)
    }

    // MARK: Always allowed

    func updateAlwaysAllowed(_ selection: FamilyActivitySelection) {
        store.alwaysAllowed = selection
        reload()
    }

    private static func cleaned(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
```

<!-- file: Tapout/Model/AppSettings.swift -->
```swift
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// nil follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Owner preferences. App-only, so they live in standard defaults; views bind with `@AppStorage`.
enum AppSettings {
    static let hapticsKey = "settings.haptics"
    /// Stored only; the Live Activity arrives in Phase 5.
    static let liveActivityKey = "settings.liveActivity"
    static let appearanceKey = "settings.appearance"

    /// On unless the owner turned it off.
    static func hapticsEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: hapticsKey) as? Bool ?? true
    }
}
```

<!-- file: Tapout/Model/DemoData.swift -->
```swift
import Foundation

/// Spec-like sample data: four modes, four places and a week of locks. Used by previews and,
/// in DEBUG, by the `-demoData` launch argument for screenshots. Never runs in normal use.
enum DemoData {
    static let kitchen = TagUID(hex: "04A1B2C3D4E501")
    static let desk = TagUID(hex: "04A1B2C3D4E502")
    static let car = TagUID(hex: "04A1B2C3D4E503")
    static let bedroom = TagUID(hex: "04A1B2C3D4E504")

    /// Replaces modes, places, the default place and the lock history. Leaves lock state alone.
    static func seed(_ store: SharedStore, now: Date = .now, calendar: Calendar = .current) {
        let pairedAt = now.addingTimeInterval(-30 * 86_400)
        store.pairedTags = [
            PairedTag(uid: kitchen, name: "Kitchen", pairedAt: pairedAt),
            PairedTag(uid: desk, name: "Desk", pairedAt: pairedAt),
            PairedTag(uid: car, name: "Car", pairedAt: pairedAt),
            PairedTag(uid: bedroom, name: "Bedroom", pairedAt: pairedAt),
        ]
        store.defaultPlace = kitchen

        let deepWork = Mode(
            name: "Deep work",
            schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 9 * 60, end: 17 * 60),
            unlockPlaces: [kitchen]
        )
        let evenings = Mode(
            name: "Evenings",
            schedule: ModeSchedule(days: ModeSchedule.everyDay, start: 19 * 60, end: 22 * 60),
            unlockPlaces: [kitchen, desk]
        )
        let weekend = Mode(name: "Weekend", schedule: ModeSchedule(days: ModeSchedule.weekend, start: 10 * 60, end: 18 * 60))
        let sleep = Mode(
            name: "Sleep",
            schedule: ModeSchedule(days: ModeSchedule.everyDay, start: 22 * 60 + 30, end: 7 * 60),
            unlockPlaces: [bedroom]
        )
        store.modes = [deepWork, evenings, weekend, sleep]
        store.activeModeID = deepWork.id
        store.lockHistory = history(deepWork: deepWork.id, evenings: evenings.id, now: now, calendar: calendar)
    }

    /// A model over a scratch store, seeded, for `#Preview`s.
    @MainActor
    static func previewModel() -> AppModel {
        let store = SharedStore(defaults: UserDefaults(suiteName: "tapout.preview")!)
        seed(store)
        return AppModel(store: store)
    }

    /// Two locks a day for the past week; nothing in the future.
    private static func history(deepWork: UUID, evenings: UUID, now: Date, calendar: Calendar) -> [LockRecord] {
        let places = [kitchen, desk, car, bedroom]
        var records: [LockRecord] = []
        for day in 0..<7 {
            guard let midnight = calendar.date(byAdding: .day, value: -day, to: calendar.startOfDay(for: now)) else { continue }
            let morning = midnight.addingTimeInterval(9.5 * 3600)
            records.append(LockRecord(start: morning, end: morning + Double(60 + day * 10) * 60,
                                      placeUID: places[day % places.count], modeID: deepWork))
            let evening = midnight.addingTimeInterval(19.5 * 3600)
            records.append(LockRecord(start: evening, end: evening + 45 * 60, placeUID: kitchen, modeID: evenings))
        }
        return records.filter { ($0.end ?? now) <= now }
    }
}

#if DEBUG
extension AppModel {
    /// `-demoData` replaces the App Group's modes, places and history with `DemoData`, for screenshots.
    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> AppModel {
        let store = SharedStore.appGroup()
        if arguments.contains("-demoData") { DemoData.seed(store) }
        return AppModel(store: store)
    }
}
#endif
```

In `Tapout/DesignSystem/Haptics.swift`, respect the preference. Replace the doc comment and add a guard to each feedback method:

```swift
/// Haptics are the one feedback channel that survives Reduce Motion, so never skip them for that.
/// The owner can still turn them off in Settings.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    private static var isEnabled: Bool { AppSettings.hapticsEnabled() }

    /// Call when a tag session starts so the first lock tap lands on time.
    static func prepare() { rigid.prepare() }

    /// Two firm taps, 90 ms apart.
    static func lock() {
        guard isEnabled else { return }
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    /// One soft tap.
    static func unlock() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
    }

    static func mismatch() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func select() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
```

- [ ] **Step 4: Run the build/test command** — all tests pass (67 + 17 new = 84), no warnings.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Add AppModel for modes and places, preferences and demo data`

---

### Task 3: Shared components and the locked environment

**Files:**
- Create: `Tapout/App/LockEnvironment.swift`, `Tapout/Components/SectionLabel.swift`, `Tapout/Components/Card.swift`, `Tapout/Components/CircleIconButton.swift`, `Tapout/Components/ScreenHeader.swift`, `Tapout/Components/ChoiceChip.swift`, `Tapout/Components/DashedTile.swift`, `Tapout/Components/LockedBanner.swift`, `Tapout/Components/PassPips.swift`, `Tapout/Components/FlowLayout.swift`
- Modify: `Tapout/DesignSystem/Typography.swift`

**Interfaces:**
- Consumes: tokens, `PressScaleStyle`, `Haptics`, `SharedStore.totalPasses`.
- Produces: `EnvironmentValues.isLocked`; `Font.tTitle1`; `SectionLabel(text:color:)`; `View.card(radius:padding:)`; `CircleIconButton(systemImage:label:tint:action:)`; `ScreenHeader(title:addLabel:onAdd:)`; `ChoiceChip(title:isOn:fillsWidth:action:)`; `DashedTile(title:vertical:action:)`; `LockedBanner()`; `PassPips(left:total:width:height:)`; `FlowLayout(spacing:)`.

These are views; they're checked in the screens that use them (Tasks 4–7). This task ends with a clean build.

- [ ] **Step 1: Add the environment value and the 28pt title style**

<!-- file: Tapout/App/LockEnvironment.swift -->
```swift
import SwiftUI

extension EnvironmentValues {
    /// True while a lock (or an emergency pass within it) is running. Everything editable is read-only then.
    @Entry var isLocked = false
}
```

In `Tapout/DesignSystem/Typography.swift`, add after `tLargeTitle`:

```swift
    static let tTitle1 = Font.title.weight(.semibold) // 28/34: card heroes in the screen specs
```

- [ ] **Step 2: Write the components**

<!-- file: Tapout/Components/SectionLabel.swift -->
```swift
import SwiftUI

/// The specs' small uppercase label above a group: 12pt medium, tracking 0.4.
struct SectionLabel: View {
    let text: String
    var color: Color = .inkTertiary

    var body: some View {
        Text(text)
            .font(.tCaption)
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}
```

<!-- file: Tapout/Components/Card.swift -->
```swift
import SwiftUI

extension View {
    /// A surface-1 card: continuous corners, no border, the light-theme soft shadow.
    func card(radius: CGFloat = Radius.card, padding: CGFloat = Space.lg) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .cardShadow()
    }
}
```

<!-- file: Tapout/Components/CircleIconButton.swift -->
```swift
import SwiftUI

/// The specs' 44pt round buttons: back, close and add.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var tint: Color = .inkSecondary
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Color.surface1, in: Circle())
                .cardShadow()
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }
}
```

<!-- file: Tapout/Components/ScreenHeader.swift -->
```swift
import SwiftUI

/// A tab's large title with its add button. Adding is off while locked.
struct ScreenHeader: View {
    let title: String
    let addLabel: String
    let onAdd: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        HStack {
            Text(title)
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleIconButton(systemImage: "plus", label: addLabel, tint: .ink, action: onAdd)
                .disabled(isLocked)
        }
    }
}
```

<!-- file: Tapout/Components/ChoiceChip.swift -->
```swift
import SwiftUI

/// A 44pt toggle chip: ink when on, surface-2 when off. Used for days, places and suggestions.
struct ChoiceChip: View {
    let title: String
    let isOn: Bool
    /// Day chips share a row equally; name chips hug their text.
    var fillsWidth = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(fillsWidth ? .tSubhead.weight(.semibold) : .tSubhead.weight(.medium))
                .foregroundStyle(isOn ? Color.bg : Color.inkSecondary)
                .padding(.horizontal, fillsWidth ? 0 : Space.md)
                .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
                .background(isOn ? Color.ink : Color.surface2, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
```

<!-- file: Tapout/Components/DashedTile.swift -->
```swift
import SwiftUI

/// The dashed "add" tile at the end of a grid.
struct DashedTile: View {
    let title: String
    /// Modes stacks the icon above the title; Places puts them side by side.
    var vertical = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Group {
                if vertical {
                    VStack(spacing: Space.xs) { icon; Text(title) }
                } else {
                    HStack(spacing: Space.xs) { icon; Text(title) }
                }
            }
            .font(.tSubhead.weight(.medium))
            .foregroundStyle(Color.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 84)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var icon: some View {
        Image(systemName: "plus").font(.system(size: 20, weight: .medium))
    }
}
```

<!-- file: Tapout/Components/LockedBanner.swift -->
```swift
import SwiftUI

/// Shown on editable screens while locked.
struct LockedBanner: View {
    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "lock").font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text("View only while locked").font(.tHeadline)
                Text("Tap a tag to make changes.").font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.emberInk)
        .padding(.vertical, Space.md)
        .padding(.horizontal, 20)
        .background(Color.emberGlow, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
```

<!-- file: Tapout/Components/PassPips.swift -->
```swift
import SwiftUI

/// One pip per emergency pass: ember for each left, surface-2 for each used.
struct PassPips: View {
    let left: Int
    var total = SharedStore.totalPasses
    var width: CGFloat = 24
    var height: CGFloat = 8

    var body: some View {
        HStack(spacing: height > 8 ? 10 : 6) {
            ForEach(0..<total, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < left ? Color.ember : Color.surface2)
                    .frame(width: width, height: height)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(left) of \(total) passes left")
    }
}
```

<!-- file: Tapout/Components/FlowLayout.swift -->
```swift
import SwiftUI

/// Lays chips out left to right and wraps them onto new rows, like the specs' flex-wrap rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = Space.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthWithItem = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if widthWithItem > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
```

- [ ] **Step 3: Run the build/test command** — builds clean, 95 tests still pass, no warnings.

- [ ] **Step 4: Leave uncommitted.** Suggested message: `Add shared chips, cards, headers and the locked environment`

---

### Task 4: Settings and navigation

**Files:**
- Create: `Tapout/Features/Settings/SettingsView.swift`
- Modify: `Tapout/App/RootView.swift`, `Tapout/App/TapoutApp.swift`, `Tapout/Features/Home/HomeView.swift` (previews only)

**Interfaces:**
- Consumes: `AppModel`, `AppSettings`, `Appearance`, `DemoData.previewModel()`, Task 3 components, `MockLockController.passesLeft`, `LabView` (DEBUG).
- Produces: `Route` (`.settings`); `RootView(controller:model:)`; `SettingsView(model:passesLeft:onOpenTab:)`. `RootView` injects `\.isLocked` and `preferredColorScheme`.

- [ ] **Step 1: Write Settings**

<!-- file: Tapout/Features/Settings/SettingsView.swift -->
```swift
import FamilyControls
import SwiftUI

/// Settings, pushed from Home's gear. Read-only while locked, per design/screens/Settings.dc.html.
struct SettingsView: View {
    let model: AppModel
    let passesLeft: Int
    let onOpenTab: (AppTab) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @AppStorage(AppSettings.hapticsKey) private var haptics = true
    @AppStorage(AppSettings.liveActivityKey) private var liveActivity = true
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @State private var pickingAllowed = false
    #if DEBUG
    @State private var showingLab = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: Space.md) {
                header
                if isLocked { LockedBanner() }
                passesCard
                linksCard
                preferencesCard
                footer
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .familyActivityPicker(
            isPresented: $pickingAllowed,
            selection: Binding(get: { model.alwaysAllowed }, set: { model.updateAlwaysAllowed($0) })
        )
        #if DEBUG
        .sheet(isPresented: $showingLab) { LabView() }
        #endif
    }

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.tHeadline)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                Spacer()
            }
        }
        .frame(height: 44)
    }

    private var passesCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Emergency passes").font(.tHeadline).foregroundStyle(Color.ink)
                PassPips(left: passesLeft)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(passesLeft)").font(.numberMedium).foregroundStyle(Color.ink)
                Text("/\(SharedStore.totalPasses)")
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(Color.inkTertiary)
            }
            .accessibilityHidden(true)
        }
        .card(padding: 20)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "Places", value: "\(model.places.count)") { onOpenTab(.places) }
            SettingsRow(title: "Modes", value: "\(model.modes.count)") { onOpenTab(.modes) }
            SettingsRow(title: "Always allowed", value: Copy.count(allowedCount, "app", "apps")) { pickingAllowed = true }
        }
        .disabled(isLocked)
        .padding(.horizontal, 20)
        .padding(.vertical, Space.xxs)
        .card(padding: 0)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            toggleRow("Haptics", isOn: $haptics)
            toggleRow("Live Activity", isOn: $liveActivity)
            HStack {
                Text("Appearance").font(.tBody).foregroundStyle(Color.ink)
                Spacer()
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.inkSecondary)
                .opacity(isLocked ? 0.45 : 1)
            }
            .frame(minHeight: 56)
        }
        .disabled(isLocked)
        .padding(.horizontal, 20)
        .padding(.vertical, Space.xxs)
        .card(padding: 0)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.tBody).foregroundStyle(Color.ink)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Color.slate)
                .opacity(isLocked ? 0.45 : 1)
        }
        .frame(minHeight: 56)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Text("Tapout \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
            #if DEBUG
            Button("Developer Lab") { showingLab = true }
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
                .frame(minHeight: 44)
            #endif
        }
        .padding(.top, Space.lg)
    }

    private var allowedCount: Int {
        model.alwaysAllowed.applicationTokens.count + model.alwaysAllowed.categoryTokens.count
    }
}

/// A 56pt row: title, value, then a chevron, or a lock glyph while locked.
private struct SettingsRow: View {
    let title: String
    let value: String
    let action: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.tBody).foregroundStyle(Color.ink)
                Spacer()
                Text(value).font(.tBody).foregroundStyle(Color.inkSecondary)
                Image(systemName: isLocked ? "lock" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityLabel("Locked")
                    .accessibilityHidden(!isLocked)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Unlocked · dark") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .environment(\.isLocked, true)
    .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .preferredColorScheme(.light)
}

#Preview("Locked · light") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .environment(\.isLocked, true)
    .preferredColorScheme(.light)
}
```

- [ ] **Step 2: Make RootView a navigation stack**

<!-- file: Tapout/App/RootView.swift -->
```swift
import SwiftUI

/// Screens pushed over the tabs. The tab bar belongs to the root, so pushed screens cover it.
enum Route: Hashable {
    case settings
}

/// Tabs, the floating tab bar, navigation, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var model: AppModel
    @State private var tab = AppTab.home
    @State private var path: [Route] = []
    @State private var showingLockMoment = false
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system

    @Namespace private var lockMomentNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                        FloatingTabBar(active: $tab)
                    }
                if showingLockMoment {
                    LockMomentView(placeName: model.defaultPlace?.name ?? MockData.placeName, session: controller.session) {
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
        .environment(\.lockMomentLink, reduceMotion ? nil
            : LockMomentLink(namespace: lockMomentNamespace, overlayShowing: showingLockMoment))
        .environment(\.isLocked, controller.session.lockState == .locked)
        .environment(\.accent, accent)
        .tint(accent.line)
        .preferredColorScheme(appearance.colorScheme)
        .task { await runClock() }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(controller: controller, onScan: scan, onOpenSettings: { path.append(.settings) })
        case .modes:
            PlaceholderView(title: "Modes")
        case .places:
            PlaceholderView(title: "Places")
        case .insights:
            PlaceholderView(title: "Insights")
        }
    }

    /// Settings links jump to a tab: pop back to the root, then switch.
    private func open(_ destination: AppTab) {
        path.removeAll()
        tab = destination
    }

    /// Phase 1 stand-in for a successful tag read. The overlay appears instantly,
    /// the way it will right after iOS's NFC sheet closes.
    private func scan() {
        Haptics.prepare()
        controller.simulateTagRead()
        showingLockMoment = true
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

- [ ] **Step 3: Create the model at launch**

<!-- file: Tapout/App/TapoutApp.swift -->
```swift
import SwiftUI

@main
struct TapoutApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootView(controller: .fromLaunchArguments(), model: .fromLaunchArguments())
            #else
            RootView(model: .live())
            #endif
        }
    }
}
```

- [ ] **Step 4: Fix Home's previews.** In `Tapout/Features/Home/HomeView.swift`, replace the six `#Preview`s with:

```swift
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

- [ ] **Step 5: Run the build/test command and the device compile check** — both clean, 95 tests pass.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add Settings, pushed from Home, read-only while locked`

---

### Task 5: Places tab, pairing and place sheets

**Files:**
- Create: `Tapout/Engine/TagScanning.swift`, `Tapout/Features/Places/PlacesView.swift`, `Tapout/Features/Places/PlaceCards.swift`, `Tapout/Features/Places/PairPlaceSheet.swift`, `Tapout/Features/Places/PlaceSheet.swift`
- Modify: `Tapout/App/RootView.swift` (Places tab)

**Interfaces:**
- Consumes: `AppModel` places API, `TagReader.readUID(prompt:)`, `TagReader.ReadError`, `TagReader.isAvailable`, Task 3 components, `PrimaryButton`, `Motion.readyPulse`.
- Produces: `protocol TagScanning { @MainActor func scan(prompt:) async throws -> TagUID }`; `TagScanPrompt.pair`; `TagScanners.live()`; DEBUG `MockTagScanner`; `PlacesView(model:)`; `PlacePuck(size:)`, `DefaultPlaceCard(name:locks:)`, `PlaceTile(name:locks:)`; `PairPlaceSheet(model:)`; `PlaceSheet(model:place:)`.

- [ ] **Step 1: Write the scanner seam**

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
    /// The NFC reader, or in DEBUG builds without NFC (the simulator) a stand-in.
    @MainActor static func live() -> any TagScanning {
        #if DEBUG
        if !TagReader.isAvailable { return MockTagScanner() }
        #endif
        return TagReader()
    }
}

#if DEBUG
/// Simulator stand-in: finds a new random tag after a second.
struct MockTagScanner: TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await Task.sleep(for: .seconds(1))
        return TagUID(data: Data((0..<7).map { _ in UInt8.random(in: .min ... .max) }))
    }
}
#endif
```

- [ ] **Step 2: Write the cards**

<!-- file: Tapout/Features/Places/PlaceCards.swift -->
```swift
import SwiftUI

/// The tag "puck" from Places.dc.html: a recessed disc, a slate ring and a glowing ember dot.
struct PlacePuck: View {
    var size: CGFloat = 148

    var body: some View {
        Circle()
            .fill(Color.surface2
                .shadow(.inner(color: .black.opacity(0.2), radius: 7, y: -6))
                .shadow(.inner(color: .white.opacity(0.07), radius: 5, y: 4)))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.slateLine, lineWidth: 2)
                    .frame(width: size * 0.65, height: size * 0.65)
                    .opacity(0.8)
            }
            .overlay {
                Circle().fill(Color.ember).frame(width: 14, height: 14).shadow(color: .ember, radius: 8)
            }
            .accessibilityHidden(true)
    }
}

/// The hero card for the default place.
struct DefaultPlaceCard: View {
    let name: String
    let locks: Int

    var body: some View {
        VStack(spacing: 20) {
            PlacePuck()
            VStack(spacing: Space.xxs) {
                Text(name).font(.tTitle1).foregroundStyle(Color.ink)
                Text("Default · \(Copy.count(locks, "lock", "locks"))")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .card(radius: Radius.sheet)
        .accessibilityElement(children: .combine)
    }
}

/// A grid tile for every other place.
struct PlaceTile: View {
    let name: String
    let locks: Int

    var body: some View {
        HStack(spacing: Space.sm) {
            Circle()
                .fill(Color.surface2)
                .frame(width: 44, height: 44)
                .overlay { Circle().fill(Color.slateLine).frame(width: 8, height: 8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.tHeadline).foregroundStyle(Color.ink).lineLimit(1)
                Text(Copy.count(locks, "lock", "locks")).font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 3: Write the Places tab**

<!-- file: Tapout/Features/Places/PlacesView.swift -->
```swift
import SwiftUI

/// The Places tab, per the list view in design/screens/Places.dc.html.
struct PlacesView: View {
    let model: AppModel

    @Environment(\.isLocked) private var isLocked
    @State private var pairing = false
    @State private var selected: PairedTag?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Places", addLabel: "Pair a place") { pairing = true }
                Group {
                    if let place = model.defaultPlace {
                        Button { selected = place } label: {
                            DefaultPlaceCard(name: place.name, locks: model.lockCount(at: place.uid))
                        }
                        .buttonStyle(PressScaleStyle())
                    } else {
                        emptyCard
                    }
                }
                .padding(.top, Space.lg)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible())], spacing: Space.sm) {
                    ForEach(model.otherPlaces) { place in
                        Button { selected = place } label: {
                            PlaceTile(name: place.name, locks: model.lockCount(at: place.uid))
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                    DashedTile(title: "Pair") { pairing = true }
                        .disabled(isLocked)
                }
                .padding(.top, Space.sm)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $pairing) { PairPlaceSheet(model: model) }
        .sheet(item: $selected) { PlaceSheet(model: model, place: $0) }
    }

    private var emptyCard: some View {
        VStack(spacing: Space.xs) {
            Text("No places yet").font(.tTitle).foregroundStyle(Color.ink)
            Text("Pair a tag to make your first place.").font(.tSubhead).foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .card(radius: Radius.sheet)
    }
}

#Preview("Places · dark") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Places · light") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}

#Preview("Places · locked") {
    PlacesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.isLocked, true).preferredColorScheme(.dark)
}
```

- [ ] **Step 4: Write the pairing sheet**

<!-- file: Tapout/Features/Places/PairPlaceSheet.swift -->
```swift
import SwiftUI

/// Pairs a tag as a named place: scan, then name it. Matches the pair sheet in Places.dc.html.
/// Only reachable while unlocked.
struct PairPlaceSheet: View {
    let model: AppModel

    enum Phase: Equatable {
        case scanning
        case found(TagUID)
        case failed(String)
    }

    static let suggestions = ["Kitchen", "Desk", "Bedroom", "Front door"]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanner: any TagScanning = TagScanners.live()
    @State private var phase = Phase.scanning
    @State private var name = ""
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: Space.lg) {
            status
            if case .found = phase {
                nameField
                FlowLayout {
                    ForEach(Self.suggestions, id: \.self) { suggestion in
                        ChoiceChip(title: suggestion, isOn: name == suggestion) { name = suggestion }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .presentationDetents([.height(664)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
        .task { await scan() }
    }

    private var status: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .strokeBorder(Color.slateLine, lineWidth: 2)
                    .frame(width: 156, height: 156)
                    .opacity(phase == .scanning && pulsing ? 0.35 : 1)
                Circle().fill(Color.surface2).frame(width: 124, height: 124)
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.slateInk)
            }
            .frame(width: 160, height: 160)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.readyPulse) { pulsing = true }
            }
            Text(statusText)
                .font(.tHeadline)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel(text: "Name this place")
            TextField("Name", text: $name)
                .font(.tTitle)
                .foregroundStyle(Color.ink)
                .submitLabel(.done)
                .padding(.horizontal, Space.md)
                .frame(height: 56)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .scanning:
            Button("Cancel") { dismiss() }
                .font(.tBody)
                .foregroundStyle(Color.inkSecondary)
                .frame(minHeight: 44)
        case .found(let uid):
            PrimaryButton(title: "Save place") { save(uid) }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.45 : 1)
        case .failed:
            PrimaryButton(title: "Try again") { Task { await scan() } }
        }
    }

    private var symbol: String {
        switch phase {
        case .scanning: "wave.3.right"
        case .found: "checkmark"
        case .failed: "exclamationmark"
        }
    }

    private var statusText: String {
        switch phase {
        case .scanning: "Ready to scan"
        case .found: "Tag found"
        case .failed(let message): message
        }
    }

    private var statusColor: Color {
        if case .failed = phase { .inkSecondary } else { .slateInk }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scan() async {
        phase = .scanning
        do {
            let uid = try await scanner.scan(prompt: TagScanPrompt.pair)
            if let existing = model.places.first(where: { $0.uid == uid }) {
                Haptics.mismatch()
                phase = .failed("Already paired as \(existing.name).")
            } else {
                Haptics.select()
                name = Self.suggestions.first { suggestion in !model.places.contains { $0.name == suggestion } } ?? ""
                phase = .found(uid)
            }
        } catch TagReader.ReadError.cancelled {
            dismiss()
        } catch TagReader.ReadError.timedOut {
            phase = .failed("No tag found.")
        } catch {
            phase = .failed("Couldn't read that tag.")
        }
    }

    private func save(_ uid: TagUID) {
        if case .alreadyPaired(let existing) = model.pair(uid, name: trimmedName) {
            phase = .failed("Already paired as \(existing).")
            return
        }
        Haptics.select()
        dismiss()
    }
}
```

- [ ] **Step 5: Write the place sheet**

<!-- file: Tapout/Features/Places/PlaceSheet.swift -->
```swift
import SwiftUI

/// Rename a place, make it the default or remove it. Read-only while locked.
struct PlaceSheet: View {
    let model: AppModel
    let place: PairedTag

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @State private var name: String
    @State private var confirmingRemove = false

    init(model: AppModel, place: PairedTag) {
        self.model = model
        self.place = place
        _name = State(initialValue: place.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                if !isLocked {
                    Button("Save") {
                        model.renamePlace(place.uid, to: name)
                        dismiss()
                    }
                    .font(.tHeadline)
                    .foregroundStyle(Color.ink)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.45 : 1)
                }
            }
            .frame(minHeight: 44)

            if isLocked { LockedBanner() }

            VStack(alignment: .leading, spacing: Space.xxs) {
                SectionLabel(text: "Name")
                TextField("Name", text: $name)
                    .font(.tLargeTitle)
                    .foregroundStyle(Color.ink)
                    .submitLabel(.done)
                    .disabled(isLocked)
                Text("\(Copy.count(model.lockCount(at: place.uid), "lock", "locks")) · paired \(place.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkSecondary)
            }

            if !isDefault && !isLocked {
                Button {
                    model.makeDefault(place.uid)
                    Haptics.select()
                    dismiss()
                } label: {
                    Text("Make default")
                        .font(.tBody)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .padding(.horizontal, 20)
                        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
            }

            Spacer(minLength: 0)

            if !isLocked {
                Button("Remove place", role: .destructive) { confirmingRemove = true }
                    .font(.tBody)
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .presentationDetents([.medium])
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
        .confirmationDialog("Remove \(place.name)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.removePlace(place.uid)
                dismiss()
            }
        } message: {
            Text("Modes that unlock only here will unlock at any place.")
        }
    }

    private var isDefault: Bool {
        model.defaultPlace?.uid == place.uid
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 6: Show Places in its tab.** In `RootView.screen`, replace `PlaceholderView(title: "Places")` with `PlacesView(model: model)`.

- [ ] **Step 7: Run the build/test command and the device compile check** — both clean, 95 tests pass.

- [ ] **Step 8: Leave uncommitted.** Suggested message: `Add Places tab with pairing and place sheets`

---

### Task 6: Modes tab, mode editor and Home's mode picker

**Files:**
- Create: `Tapout/Features/Modes/ModesView.swift`, `Tapout/Features/Modes/ModeCards.swift`, `Tapout/Features/Modes/ModeEditor.swift`
- Modify: `Tapout/Features/Home/HomeHeader.swift`, `Tapout/Features/Home/HomeView.swift`, `Tapout/App/RootView.swift` (Modes tab, Home's model), `Tapout/Model/MockData.swift` (drop `modeName`)

**Interfaces:**
- Consumes: `AppModel` modes API, `ScheduleFormat`, `ClockMinutes`, `ModeText`, `TimeFormat.short`, `OrbView(tone:ring:size:)`, Task 3 components, FamilyControls `Label(_ token: ApplicationToken)`.
- Produces: `ModesView(model:)`, `ActiveModeCard(mode:unlockNames:lockedThisWeek:)`, `StatTile(value:caption:rounded:)`, `ModeTile(mode:)`, `ModeEditor(model:mode:)`; `HomeHeader(modes:activeMode:showsLockGlyph:onSelectMode:onOpenSettings:)`; `HomeView(controller:model:onScan:onOpenSettings:)`.

- [ ] **Step 1: Write the cards**

<!-- file: Tapout/Features/Modes/ModeCards.swift -->
```swift
import SwiftUI

/// The active mode's hero card, per the list view in design/screens/Modes.dc.html.
struct ActiveModeCard: View {
    let mode: Mode
    let unlockNames: [String]
    let lockedThisWeek: TimeInterval

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xxs) {
                        if isLocked { Image(systemName: "lock").font(.system(size: 12, weight: .bold)) }
                        Text(isLocked ? "Active now" : "Selected")
                    }
                    .font(.tCaption)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(isLocked ? Color.emberInk : Color.slateInk)
                    Text(mode.name).font(.tTitle1).foregroundStyle(Color.ink)
                    Text(ModeText.subtitle(mode)).font(.tSubhead).foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: Space.sm)
                OrbView(tone: isLocked ? .ember : .slate, ring: isLocked ? 1 : 0, size: 104)
            }
            HStack(spacing: Space.xs) {
                StatTile(value: mode.schedule.map(ScheduleFormat.short) ?? "Manual", caption: "Schedule", rounded: mode.schedule != nil)
                StatTile(value: ModeText.unlockSummary(unlockNames), caption: "Unlocks at", rounded: false)
                StatTile(value: TimeFormat.short(lockedThisWeek), caption: "This week", rounded: true)
            }
        }
        .card(radius: Radius.sheet)
    }
}

/// A small value-over-caption tile inside a card.
struct StatTile: View {
    let value: String
    let caption: String
    /// Numbers use SF Pro Rounded; words use SF Pro.
    let rounded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(rounded ? .system(size: 20, design: .rounded) : .tHeadline)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption).font(.caption).foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.sm)
        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A grid tile for every mode that isn't active.
struct ModeTile: View {
    let mode: Mode

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            OrbView(tone: .slate, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.name).font(.tHeadline).foregroundStyle(Color.ink).lineLimit(1)
                Text(ModeText.apps(mode)).font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
        }
        .card(padding: 20)
        .accessibilityElement(children: .combine)
    }
}
```

- [ ] **Step 2: Write the Modes tab**

<!-- file: Tapout/Features/Modes/ModesView.swift -->
```swift
import SwiftUI

/// The Modes tab: the active mode, then every other mode.
struct ModesView: View {
    let model: AppModel

    @Environment(\.isLocked) private var isLocked
    @State private var editing: Mode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Modes", addLabel: "New mode") { editing = model.newMode() }
                Button { editing = model.activeMode } label: {
                    ActiveModeCard(
                        mode: model.activeMode,
                        unlockNames: model.unlockPlaceNames(for: model.activeMode),
                        lockedThisWeek: model.lockedThisWeek(model.activeMode)
                    )
                }
                .buttonStyle(PressScaleStyle())
                .padding(.top, Space.lg)
                SectionLabel(text: "Ready")
                    .padding(.top, Space.xl)
                    .padding(.bottom, Space.sm)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible())], spacing: Space.sm) {
                    ForEach(model.otherModes) { mode in
                        Button { editing = mode } label: { ModeTile(mode: mode) }
                            .buttonStyle(PressScaleStyle())
                    }
                    DashedTile(title: "New mode", vertical: true) { editing = model.newMode() }
                        .disabled(isLocked)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editing) { ModeEditor(model: model, mode: $0) }
    }
}

#Preview("Modes · dark") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.dark)
}

#Preview("Modes · light") {
    ModesView(model: DemoData.previewModel()).background(Color.bg).preferredColorScheme(.light)
}

#Preview("Modes · locked") {
    ModesView(model: DemoData.previewModel()).background(Color.bg)
        .environment(\.isLocked, true).preferredColorScheme(.dark)
}
```

- [ ] **Step 3: Write the editor**

<!-- file: Tapout/Features/Modes/ModeEditor.swift -->
```swift
import FamilyControls
import SwiftUI

/// Create or edit a mode, per the edit view in design/screens/Modes.dc.html. Read-only while locked.
struct ModeEditor: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @State private var draft: Mode
    @State private var days: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var picking = false
    @State private var confirmingDelete = false

    init(model: AppModel, mode: Mode) {
        self.model = model
        _draft = State(initialValue: mode)
        _days = State(initialValue: mode.schedule?.days ?? [])
        _start = State(initialValue: ClockMinutes.date(mode.schedule?.start ?? 9 * 60))
        _end = State(initialValue: ClockMinutes.date(mode.schedule?.end ?? 17 * 60))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.sm) {
                header
                if isLocked { LockedBanner() }
                nameField.padding(.vertical, Space.md)
                Group {
                    blockCard
                    whenCard
                    unlockCard
                }
                .disabled(isLocked)
                if model.isSaved(draft) && !isLocked { deleteButton }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bg.ignoresSafeArea())
        .familyActivityPicker(isPresented: $picking, selection: $draft.selection)
        .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                model.deleteMode(id: draft.id)
                dismiss()
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.sheet)
    }

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.tBody)
                .foregroundStyle(Color.inkSecondary)
                .frame(minHeight: 44)
            Spacer()
            OrbView(tone: .slate, size: 44)
            Spacer()
            Button("Save", action: save)
                .font(.tHeadline)
                .foregroundStyle(Color.ink)
                .frame(minHeight: 44)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            SectionLabel(text: "Name")
            TextField("Name", text: $draft.name, prompt: Text("Mode name").foregroundStyle(Color.inkTertiary))
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
                .submitLabel(.done)
                .disabled(isLocked)
        }
    }

    private var blockCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("Block").font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                Button { picking = true } label: {
                    Text("\(ModeText.apps(draft)) ›")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            let icons = Array(draft.selection.applicationTokens.prefix(6))
            if !icons.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 6), spacing: Space.xs) {
                    ForEach(icons, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("When").font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                if days.isEmpty {
                    Text("Manual").font(.numberSmall).foregroundStyle(Color.inkSecondary)
                } else {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                    Text("–").foregroundStyle(Color.inkSecondary)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
            .frame(minHeight: 44)
            HStack(spacing: 6) {
                ForEach(ModeSchedule.displayOrder, id: \.self) { day in
                    ChoiceChip(title: Calendar.current.veryShortWeekdaySymbols[day - 1], isOn: days.contains(day), fillsWidth: true) {
                        if days.contains(day) { days.remove(day) } else { days.insert(day) }
                    }
                    .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                }
            }
            Text(days.isEmpty ? "Pick days to lock on a schedule." : "Locks at the start, unlocks at the end.")
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Unlock at").font(.tHeadline).foregroundStyle(Color.ink)
            if model.places.isEmpty {
                Text("Pair a place to choose where this mode unlocks.")
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkTertiary)
            } else {
                FlowLayout {
                    ForEach(model.places) { place in
                        ChoiceChip(title: place.name, isOn: draft.unlockPlaces.contains(place.uid)) {
                            if draft.unlockPlaces.contains(place.uid) {
                                draft.unlockPlaces.remove(place.uid)
                            } else {
                                draft.unlockPlaces.insert(place.uid)
                            }
                        }
                    }
                }
                Text(draft.unlockPlaces.isEmpty ? "Any of your places unlocks this mode." : "Only these places unlock this mode.")
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var deleteButton: some View {
        Button("Delete mode", role: .destructive) { confirmingDelete = true }
            .font(.tBody)
            .foregroundStyle(Color.danger)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(model.modes.count <= 1)
            .opacity(model.modes.count <= 1 ? 0.45 : 1)
            .padding(.top, Space.md)
    }

    private var canSave: Bool {
        let named = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let validTimes = days.isEmpty || ClockMinutes.minutes(of: start) != ClockMinutes.minutes(of: end)
        return !isLocked && named && validTimes
    }

    private func save() {
        var mode = draft
        mode.schedule = days.isEmpty ? nil : ModeSchedule(
            days: days,
            start: ClockMinutes.minutes(of: start),
            end: ClockMinutes.minutes(of: end)
        )
        model.save(mode)
        Haptics.select()
        dismiss()
    }
}

#Preview("Editor · dark") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.activeMode).preferredColorScheme(.dark)
}

#Preview("Editor · light") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.activeMode).preferredColorScheme(.light)
}
```

- [ ] **Step 4: Turn Home's mode pill into a picker**

<!-- file: Tapout/Features/Home/HomeHeader.swift -->
```swift
import SwiftUI

/// The mode pill and the settings button. While unlocked the pill opens a mode picker.
struct HomeHeader: View {
    let modes: [Mode]
    let activeMode: Mode
    /// The lock glyph shows only in the locked state, not during an emergency pass.
    let showsLockGlyph: Bool
    let onSelectMode: (UUID) -> Void
    let onOpenSettings: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        HStack {
            if isLocked {
                pill
            } else {
                Menu {
                    Picker("Mode", selection: Binding(get: { activeMode.id }, set: { id in
                        Haptics.select()
                        onSelectMode(id)
                    })) {
                        ForEach(modes) { mode in Text(mode.name).tag(mode.id) }
                    }
                } label: {
                    pill
                }
                .accessibilityHint("Choose a mode")
            }

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.surface1, in: Circle())
                    .cardShadow()
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Settings")
        }
        .frame(height: 44)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            if showsLockGlyph {
                Image(systemName: "lock").font(.system(size: 14, weight: .semibold))
            }
            Text(activeMode.name).font(.tSubhead.weight(.semibold))
            if !isLocked {
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(showsLockGlyph ? Color.emberInk : Color.ink)
        .padding(.leading, 14)
        .padding(.trailing, Space.md)
        .frame(height: 44)
        .background(Color.surface1, in: Capsule(style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode: \(activeMode.name)")
    }
}
```

In `Tapout/Features/Home/HomeView.swift`:

```swift
struct HomeView: View {
    let controller: MockLockController
    let model: AppModel
    let onScan: () -> Void
    let onOpenSettings: () -> Void
```

and replace the header line in `body` with:

```swift
            HomeHeader(
                modes: model.modes,
                activeMode: model.activeMode,
                showsLockGlyph: isLocked,
                onSelectMode: { model.setActiveMode($0) },
                onOpenSettings: onOpenSettings
            )
```

In `Tapout/Model/MockData.swift`, delete `static let modeName = "Deep work"` (the mode name is real now).

- [ ] **Step 5: Wire the Modes tab and Home's model.** In `RootView.screen`:

```swift
        case .home:
            HomeView(controller: controller, model: model, onScan: scan, onOpenSettings: { path.append(.settings) })
        case .modes:
            ModesView(model: model)
```

- [ ] **Step 6: Run the build/test command and the device compile check** — both clean, 95 tests pass.

- [ ] **Step 7: Leave uncommitted.** Suggested message: `Add Modes tab, mode editor and Home mode picker`

---

### Task 7: Verify in the simulator

Simulator: iPhone 17, iOS 26.5, id `33A5EBE9-5D77-488C-85C0-FDBC419C7ECE`. Points are 402 × 874. Useful tap points: tab bar Home (73, 807), Modes (158, 807), Places (243, 807), Insights (329, 807); Home's gear (356, 92); Home's mode pill (80, 92).

- [ ] **Step 1:** Run the build/test command and the device compile check: 95 tests pass, no warnings from `Tapout/`, `Shared/`, `TapoutTests/` or `TapoutMonitor/`.
- [ ] **Step 2:** Install `build/dd/Build/Products/Debug-iphonesimulator/Tapout.app`. Launch with `-demoData`, in dark (`xcrun simctl ui <id> appearance dark`), then light. For each theme screenshot: Home (pill says "Deep work"), the mode menu open, Settings, Places, Modes, a mode editor (tap "Deep work"), a place sheet (tap a place tile), and the pair sheet (tap "Pair" and wait for "Tag found").
- [ ] **Step 3:** Launch with `-demoData -mockState locked`. Screenshot Settings (banner, lock glyphs, dimmed toggles), Places (add and Pair disabled), Modes ("Active now" with an ember orb; add and New mode disabled), the editor (banner, controls disabled, Save dimmed, no Delete) and Home (pill not a menu).
- [ ] **Step 4:** Compare against `Settings.dc.html`, `Places.dc.html` and `Modes.dc.html`: titles and sizes, card radii (24 / 32), chip states, section labels, spacing, dark/light colours, and the 0.45 opacity on disabled controls.
- [ ] **Step 5:** Flows, unlocked:
  - Pair: "Pair" → "Tag found" → pick "Front door" → "Save place". A new tile appears.
  - Place sheet: rename, make default (the hero changes), remove (confirm; the tile disappears).
  - New mode: "+" → name "Reading", pick Mon and Wed, set 20:00 – 21:00, pick a place → Save. The tile shows "0 apps"; its editor shows the saved values.
  - Delete that mode. Deleting is refused (button dimmed) when only one mode is left.
  - Home: pick "Evenings" from the pill; Modes shows Evenings as Selected.
  - Settings: Places and Modes rows jump to their tabs; Appearance → Light switches the app; Haptics off then Scan on Home gives no haptic (check on device later); Developer Lab opens.
- [ ] **Step 6:** Report with screenshots, saved as contact sheets in `docs/superpowers/verification/phase3a-*.png`. Note anything that can't be checked in the simulator (haptics, the real app picker, real NFC). Leave all changes uncommitted with the suggested message `Phase 3A verification results`.

---

## Phase 4 notes (from this plan)

- Locking uses `activeMode.selection`, with `alwaysAllowed` exempted, instead of `SharedStore.selection`.
- `LockEngine.handleTag` refuses to unlock with a place outside `activeMode.unlockPlaces` (when non-empty).
- Phase 4 writes `LockRecord`s (with intention) when `LockEngine` locks and unlocks: append on lock, set `end` (and `intentionDone` once answered) on unlock.
- Mode schedules become DeviceActivity schedules that lock at the start and unlock at the end; the monitor extension reads `modes` from the store.
- `\.isLocked` and Settings' pass count come from `LockEngine` instead of `MockLockController`.
- **Which mode is locked.** A schedule can lock a mode that isn't the active one, and `LockSession.locked(since:)` has no mode. Either add the mode's id to the lock session, or have the extension set `activeModeID` when a schedule fires. Locking and the unlock-place check must use the locked mode, not whichever mode is selected.
- **DeviceActivity's activity limit** (reportedly about 20 per app). One activity per weekday per mode doesn't fit (the demo data alone would need 21). Use one repeating daily activity per mode, with the extension checking `days` in `intervalDidStart`; an overnight run belongs to its start day. Schedules are already guaranteed to be at least 15 minutes (`ModeSchedule.isRunnable`).
- **Stale cache.** `AppModel` reloads only after its own changes. Reload when the scene becomes active, so locks and history the extension wrote show up. Read-modify-write of `lockHistory` from two processes isn't atomic.
- **Model-level guard.** `AppModel` should refuse changes while `store.session` is locked, as a second line behind the screens' guards.
- **Product call before enforcing unlock places:** removing a place currently makes a mode that unlocked only there unlock at any place. Decide whether to refuse that removal or ask for a replacement place.

## Extending this plan

New screens or features slot in as tasks after Task 6, before verification. Data they need goes through `AppModel` and, if the extension must see it, a new `SharedStore` key with the same absent/corrupt fallbacks.

**New fields on stored types must be Optional** (or have custom decoding). Synthesized `Decodable` ignores default values, so a new non-Optional field on `Mode` or `LockRecord` makes every saved array fail to decode; the store then reads it as empty and only the `<key>.unreadable` backup survives.

Phase 3B (`docs/superpowers/specs/2026-10-27-phase3b-design.md`) builds on this plan: it reuses `AppModel`, `ChoiceChip` day chips, `SectionLabel` and `LockedBanner`, and builds the lock-intention UI on the `LockRecord.intention` / `intentionDone` fields added here.

## Verification results (2026-11-02)

- 95 tests pass; simulator, unsigned device and Release builds are clean, with no warnings from `Tapout/`, `Shared/`, `TapoutTests/` or `TapoutMonitor/`.
- iPhone 17 simulator, iOS 26.5, `-demoData`: Settings, Places, the pair sheet (mock scan → "Tag found" → Save adds a tile), Modes, the mode editor (toggling a day + Save updates the card) and Home's mode menu (picking Evenings updates the pill) all match the specs, in dark and light (`docs/superpowers/verification/phase3a-dark.png`, `phase3a-light.png`).
- With `-mockState locked`: Home's pill shows the lock without a menu; Settings shows the banner, lock glyphs and dimmed controls; Places and Modes disable their add buttons and dashed tiles; Modes shows "Active now" with the sealed ember orb; the editor is read-only with no Delete (`phase3a-locked.png`).
- Found and fixed during verification: a quick double tap on the gear pushed Settings twice (RootView `openSettings` now pushes only from the root), and hiding the navigation bar had disabled the edge swipe back (`Tapout/App/SwipeBack.swift`). Both re-checked in the simulator.
- Review-driven changes beyond the plan: unreadable stored values are backed up to `<key>.unreadable`; the pair sheet's scanner is injectable and its scan is tied to the sheet's lifetime; every sheet and the always-allowed picker close or refuse changes if a lock starts while open; schedules must be at least 15 minutes; day summaries compress to "Mon–Sat"; `TapoutApp` builds the model once.
- Not verified: switching Appearance from Light or Dark back to System at runtime (simulator taps on the menu were unreliable; check on a device), haptics, the real app picker, real NFC.
