# Phase 2 Device Spike Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the risky platform parts on a real iPhone: Screen Time access, picking apps and shielding/unshielding them, reading a tag's hardware UID and rejecting unknown tags, and relocking 5 minutes after an emergency pass while Tapout is closed.

**Architecture:** The real services Phase 4 will use go in now. They are backed by an App Group store that both the app and a new `TapoutMonitor` DeviceActivityMonitor extension read. A `@MainActor @Observable` `LockEngine` mirrors `MockLockController`'s API (tag read, emergency pass, relock now, tick) but drives ManagedSettings shields and DeviceActivity relock schedules. A DEBUG-only Lab screen, opened from the settings button, exercises everything and shows a log shared with the extension. Home stays on `MockLockController` until Phase 4.

**Tech Stack:** Swift 6, SwiftUI, Observation, FamilyControls, ManagedSettings, DeviceActivity, Core NFC, Swift Testing, XcodeGen, Xcode 27.1. Unit tests run on the iPhone 17 simulator (iOS 26.5); the spike itself runs on the physical iPhone 16.

## Decisions (2026-10-24)

- **Tags are recognised by hardware UID.** Nothing is written to the tag; any NTAG213/215/216 sticker works. (PLAN.md decision 4.)
- **Spike code is kept.** Services are production-shaped and tested; only the Lab screen is throwaway.
- **Two relock strategies are tested on the device**, because DeviceActivity refuses intervals under 15 minutes:
  - `warning`: interval runs now → now + 15 min with `warningTime` 10 min, so `intervalWillEndWarning` fires at the 5-minute mark.
  - `pastStart`: interval runs (relock − 15 min) → relock time, so `intervalDidEnd` fires at the 5-minute mark.
  The Lab switches between them; the device run (Task 6) records which one fires on time, and Phase 4 keeps the winner.
- **Pass count lives in the App Group store for now.** Moving it to the Keychain (PLAN.md decision 5) is Phase 4.
- **No ShieldConfiguration / ShieldAction extensions yet.** Shielded apps show iOS's default block screen; the "Sealed" look is Phase 4.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor extension `com.raphymuthu.tapout.monitor`. App Group `group.com.raphymuthu.tapout`. Team `HM34P4HC4F`, automatic signing.
- Five emergency passes total, ever. An emergency pass opens apps for 5 minutes (300 s).
- Colours only through asset-catalog tokens. The Lab is DEBUG-only and uses plain system list styling; it is not a designed screen.
- Copy: very few words, no guilt, no emoji, no exclamation marks.
- Keep the extension lean (DeviceActivityMonitor extensions have a ~6 MB memory limit): it compiles only `Shared/` and `TapoutMonitor/`, with no SwiftUI.
- Never commit. The user commits manually; each task ends with a suggested commit message.

## File map

| File | Responsibility |
| --- | --- |
| `project.yml` | Adds `Shared/` sources, signing, entitlements, NFC Info.plist keys, `TapoutMonitor` target |
| `Shared/LockSession.swift` | Moved from `Tapout/Model/`; now `Codable, Sendable` |
| `Shared/Tags.swift` | `TagUID`, `PairedTag` |
| `Shared/SharedStore.swift` | App Group store: session, selection, tags, passes, strategy, log; `LogEntry` |
| `Shared/ShieldController.swift` | `Shielding` protocol + ManagedSettings implementation |
| `Shared/RelockPlan.swift` | `RelockStrategy`, schedule builder, `RelockScheduling` + DeviceActivity implementation |
| `Shared/EmergencyRelock.swift` | The one relock step shared by app and extension |
| `Tapout/Engine/LockEngine.swift` | Real lock state machine for the app |
| `Tapout/Engine/TagReader.swift` | Core NFC UID reader |
| `Tapout/Features/Lab/LabView.swift` | DEBUG test bench |
| `Tapout/App/RootView.swift` | DEBUG: settings button opens the Lab |
| `TapoutMonitor/TapoutMonitor.swift` | DeviceActivityMonitor subclass |
| `TapoutTests/Fakes.swift` | Fake shields, fake relock scheduler, throwaway store |
| `TapoutTests/{SharedStore,TagUID,RelockPlan,EmergencyRelock,LockEngine}Tests.swift` | Unit tests |

Build/test command used throughout (run from `~/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

Disk space was down to ~4.4 GB at the end of Phase 1. A device build adds a second DerivedData tree, so check `df -h /System/Volumes/Data` before Task 4 and free space if under 3 GB.

---

### Task 1: Shared store and models

**Files:**
- Move: `Tapout/Model/LockSession.swift` → `Shared/LockSession.swift` (`git mv`)
- Create: `Shared/Tags.swift`, `Shared/SharedStore.swift`, `TapoutTests/Fakes.swift`, `TapoutTests/SharedStoreTests.swift`, `TapoutTests/TagUIDTests.swift`
- Modify: `project.yml` (add `Shared` to the `Tapout` target's sources)

**Interfaces:**
- Consumes: `LockSession` from Phase 1.
- Produces:
  - `LockSession: Equatable, Codable, Sendable` (cases unchanged).
  - `TagUID(hex:)`, `TagUID(data:)`, `.hex`, `.display` ("04:A2:0F").
  - `PairedTag(uid:name:pairedAt:)`, `id == uid`.
  - `LogEntry(date:source:message:)`, `LogEntry.Source` = `.app | .monitor`.
  - `SharedStore(defaults:)`, `SharedStore.appGroup()`, `SharedStore.appGroupID`, `SharedStore.totalPasses` (5), `SharedStore.logLimit` (200); read/write `session`, `selection`, `pairedTags`, `passesLeft`, `relockStrategy`; read-only `log`; `appendLog(_:source:at:)`, `clearLog()`.
  - Test helper `SharedStore.makeTest(suite:)`.
  - `RelockStrategy` is referenced here and defined in Task 2. To keep Task 1 compiling, define it in `Shared/RelockPlan.swift` now (Step 3) and Task 2 adds the rest of that file.

- [ ] **Step 1: Move `LockSession` and make it codable**

```bash
mkdir -p Shared && git mv Tapout/Model/LockSession.swift Shared/LockSession.swift
```

In `Shared/LockSession.swift` change the two declarations:

```swift
/// The two accent states from the design system: ember owns locked, slate owns unlocked.
enum LockState: Sendable {
    case locked, unlocked
}

/// What the phone is doing right now. Stored in the App Group, so the monitor extension can relock.
enum LockSession: Equatable, Codable, Sendable {
```

Add `Shared` to the app target in `project.yml`:

```yaml
  Tapout:
    type: application
    platform: iOS
    sources:
      - path: Tapout
      - path: Shared
```

- [ ] **Step 2: Write the failing tests**

<!-- file: TapoutTests/Fakes.swift (Task 2 adds the fake shields and relock scheduler) -->
```swift
import FamilyControls
import Foundation
@testable import Tapout

struct FakeError: Error {}

extension SharedStore {
    /// A store on a throwaway defaults suite, so tests never touch the App Group.
    /// Pass the same `suite` twice to get two stores over the same data.
    static func makeTest(suite: String = "tapout.tests.\(UUID().uuidString)") -> SharedStore {
        SharedStore(defaults: UserDefaults(suiteName: suite)!)
    }
}
```

<!-- file: TapoutTests/TagUIDTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct TagUIDTests {
    @Test func bytesBecomeUppercaseHex() {
        #expect(TagUID(data: Data([0x04, 0xA2, 0x0F, 0x1B])).hex == "04A20F1B")
    }

    @Test func hexIsNormalisedToUppercase() {
        #expect(TagUID(hex: "04a20f") == TagUID(hex: "04A20F"))
    }

    @Test func displayGroupsBytesWithColons() {
        #expect(TagUID(hex: "04A20F1B").display == "04:A2:0F:1B")
    }
}
```

<!-- file: TapoutTests/SharedStoreTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct SharedStoreTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func freshInstallDefaults() {
        let store = SharedStore.makeTest()
        #expect(store.session == .unlocked)
        #expect(store.passesLeft == 5)
        #expect(store.pairedTags.isEmpty)
        #expect(store.relockStrategy == .warning)
        #expect(store.log.isEmpty)
    }

    @Test(arguments: [
        LockSession.unlocked,
        .locked(since: SharedStoreTests.start),
        .emergency(relockAt: SharedStoreTests.start + 300, duration: 300),
    ])
    func sessionRoundTrips(_ session: LockSession) {
        let store = SharedStore.makeTest()
        store.session = session
        #expect(store.session == session)
    }

    @Test func aSecondStoreOnTheSameSuiteSeesTheSameValues() {
        let suite = "tapout.tests.\(UUID().uuidString)"
        let first = SharedStore.makeTest(suite: suite)
        first.passesLeft = 2
        first.pairedTags = [PairedTag(uid: TagUID(hex: "04A2"), name: "Desk", pairedAt: Self.start)]
        first.relockStrategy = .pastStart

        let second = SharedStore.makeTest(suite: suite)
        #expect(second.passesLeft == 2)
        #expect(second.pairedTags.map(\.name) == ["Desk"])
        #expect(second.relockStrategy == .pastStart)
    }

    @Test func logKeepsTheNewestEntries() {
        let store = SharedStore.makeTest()
        for index in 0..<(SharedStore.logLimit + 5) {
            store.appendLog("entry \(index)", source: .app, at: Self.start)
        }
        #expect(store.log.count == SharedStore.logLimit)
        #expect(store.log.first?.message == "entry 5")
        #expect(store.log.last?.message == "entry \(SharedStore.logLimit + 4)")
    }

    @Test func clearLogEmptiesIt() {
        let store = SharedStore.makeTest()
        store.appendLog("x", source: .monitor, at: Self.start)
        store.clearLog()
        #expect(store.log.isEmpty)
    }
}
```

- [ ] **Step 3: Run the tests to see them fail** — expect build errors: `TagUID`, `SharedStore`, `RelockStrategy` not found.

- [ ] **Step 4: Implement**

<!-- file: Shared/Tags.swift -->
```swift
import Foundation

/// A tag's hardware serial number, as uppercase hex. Tapout recognises tags by this alone.
struct TagUID: Codable, Hashable, Sendable {
    let hex: String

    init(hex: String) {
        self.hex = hex.uppercased()
    }

    init(data: Data) {
        self.hex = data.map { String(format: "%02X", $0) }.joined()
    }

    /// "04:A2:0F", for the Lab and the log.
    var display: String {
        var pairs: [Substring] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            pairs.append(hex[index..<next])
            index = next
        }
        return pairs.joined(separator: ":")
    }
}

/// A tag the owner has paired. Only paired tags lock and unlock.
struct PairedTag: Codable, Hashable, Identifiable, Sendable {
    let uid: TagUID
    var name: String
    let pairedAt: Date

    var id: TagUID { uid }
}
```

<!-- file: Shared/RelockPlan.swift (Task 1 part; Task 2 adds the rest) -->
```swift
import Foundation

/// How the emergency relock is scheduled. DeviceActivity refuses intervals under 15 minutes,
/// so both strategies stretch the interval and aim a callback at the 5-minute mark.
enum RelockStrategy: String, Codable, CaseIterable, Sendable {
    /// Interval starts now and lasts 15 min; `intervalWillEndWarning` fires 10 min before the end.
    case warning
    /// Interval started 10 min ago and ends at the relock time; `intervalDidEnd` fires.
    case pastStart
}
```

<!-- file: Shared/SharedStore.swift -->
```swift
import FamilyControls
import Foundation

/// One line in the Lab log. The monitor extension writes here too, so the Lab can show
/// when DeviceActivity callbacks really fired.
struct LogEntry: Codable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case app, monitor
    }

    var id = UUID()
    let date: Date
    let source: Source
    let message: String
}

/// Lock state shared by the app and its extensions through the App Group container.
/// Every read goes to UserDefaults, so a value the extension wrote is seen on the next read.
final class SharedStore {
    static let appGroupID = "group.com.raphymuthu.tapout"
    /// Five passes total, ever. They never refill.
    static let totalPasses = 5
    static let logLimit = 200

    static func appGroup() -> SharedStore {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            preconditionFailure("App Group \(appGroupID) is missing from the entitlements")
        }
        return SharedStore(defaults: defaults)
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var session: LockSession {
        get { read(.session) ?? .unlocked }
        set { write(newValue, .session) }
    }

    /// The apps, categories and sites to shield. Opaque tokens; never leaves the device.
    var selection: FamilyActivitySelection {
        get { read(.selection) ?? FamilyActivitySelection() }
        set { write(newValue, .selection) }
    }

    var pairedTags: [PairedTag] {
        get { read(.pairedTags) ?? [] }
        set { write(newValue, .pairedTags) }
    }

    var passesLeft: Int {
        get { read(.passesLeft) ?? Self.totalPasses }
        set { write(newValue, .passesLeft) }
    }

    var relockStrategy: RelockStrategy {
        get { read(.relockStrategy) ?? .warning }
        set { write(newValue, .relockStrategy) }
    }

    var log: [LogEntry] {
        read(.log) ?? []
    }

    func appendLog(_ message: String, source: LogEntry.Source, at date: Date = .now) {
        var entries = log
        entries.append(LogEntry(date: date, source: source, message: message))
        write(Array(entries.suffix(Self.logLimit)), .log)
    }

    func clearLog() {
        defaults.removeObject(forKey: Key.log.rawValue)
    }

    private enum Key: String {
        case session, selection, pairedTags, passesLeft, relockStrategy, log
    }

    private func read<Value: Decodable>(_ key: Key) -> Value? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(Value.self, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, _ key: Key) {
        defaults.set(try? encoder.encode(value), forKey: key.rawValue)
    }
}
```

- [ ] **Step 5: Run the build/test command** — all Phase 1 tests plus the new ones pass.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add App Group store, tag UID and codable lock session`

---

### Task 2: Shields, relock schedule and the shared relock step

**Files:**
- Create: `Shared/ShieldController.swift`, `Shared/EmergencyRelock.swift`, `TapoutTests/RelockPlanTests.swift`, `TapoutTests/EmergencyRelockTests.swift`
- Modify: `Shared/RelockPlan.swift` (add the plan and scheduler), `TapoutTests/Fakes.swift` (restore the fakes)

**Interfaces:**
- Consumes: `SharedStore`, `LockSession`, `RelockStrategy` (Task 1).
- Produces:
  - `protocol Shielding { func apply(_ selection: FamilyActivitySelection); func clear() }`, `ShieldController()`, `ManagedSettingsStore.Name.tapout`.
  - `RelockPlan.activity` (`DeviceActivityName("tapout.emergency")`), `RelockPlan.minimumInterval` (900 s), `RelockPlan.schedule(relockAt:now:strategy:calendar:) -> DeviceActivitySchedule`.
  - `protocol RelockScheduling { func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws; func cancel() }`, `RelockScheduler()`.
  - `EmergencyRelock.perform(store:shields:now:) -> TimeInterval?`: relocks an open pass and returns seconds past the relock time (negative = early), or `nil` when there was no open pass.

- [ ] **Step 1: Add the fakes** — append to `TapoutTests/Fakes.swift`:

```swift
/// Counts shield calls instead of touching Screen Time.
final class FakeShields: Shielding {
    private(set) var applied = 0
    private(set) var cleared = 0

    func apply(_ selection: FamilyActivitySelection) { applied += 1 }
    func clear() { cleared += 1 }
}

/// Records relock schedules instead of calling DeviceActivity.
final class FakeRelock: RelockScheduling {
    struct Call: Equatable {
        let relockAt: Date
        let now: Date
        let strategy: RelockStrategy
    }

    var failure: (any Error)?
    private(set) var scheduled: [Call] = []
    private(set) var cancelled = 0

    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        if let failure { throw failure }
        scheduled.append(Call(relockAt: relockAt, now: now, strategy: strategy))
    }

    func cancel() { cancelled += 1 }
}
```

- [ ] **Step 2: Write the failing tests**

<!-- file: TapoutTests/RelockPlanTests.swift -->
```swift
import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct RelockPlanTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func warningRunsFifteenMinutesAndWarnsAtTheRelockTime() {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: .warning, calendar: calendar)
        #expect(calendar.date(from: schedule.intervalStart) == now)
        #expect(calendar.date(from: schedule.intervalEnd) == now + 900)
        #expect(schedule.warningTime == DateComponents(minute: 10, second: 0))
        #expect(schedule.repeats == false)
    }

    @Test func pastStartEndsAtTheRelockTime() {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: .pastStart, calendar: calendar)
        #expect(calendar.date(from: schedule.intervalStart) == now - 600)
        #expect(calendar.date(from: schedule.intervalEnd) == now + 300)
        #expect(schedule.warningTime == nil)
        #expect(schedule.repeats == false)
    }

    @Test(arguments: RelockStrategy.allCases)
    func everyIntervalMeetsTheFifteenMinuteMinimum(_ strategy: RelockStrategy) throws {
        let schedule = RelockPlan.schedule(relockAt: now + 300, now: now, strategy: strategy, calendar: calendar)
        let start = try #require(calendar.date(from: schedule.intervalStart))
        let end = try #require(calendar.date(from: schedule.intervalEnd))
        #expect(end.timeIntervalSince(start) >= RelockPlan.minimumInterval)
    }
}
```

<!-- file: TapoutTests/EmergencyRelockTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct EmergencyRelockTests {
    private static let relockAt = Date(timeIntervalSinceReferenceDate: 800_000_300)

    @Test func relocksAnOpenPassAndReportsHowLate() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = .emergency(relockAt: Self.relockAt, duration: 300)

        let late = EmergencyRelock.perform(store: store, shields: shields, now: Self.relockAt + 12)

        #expect(late == 12)
        #expect(store.session == .locked(since: Self.relockAt))
        #expect(shields.applied == 1)
    }

    @Test func anEarlyCallbackStillRelocks() {
        let store = SharedStore.makeTest()
        store.session = .emergency(relockAt: Self.relockAt, duration: 300)
        #expect(EmergencyRelock.perform(store: store, shields: FakeShields(), now: Self.relockAt - 30) == -30)
        #expect(store.session == .locked(since: Self.relockAt))
    }

    @Test(arguments: [LockSession.unlocked, .locked(since: EmergencyRelockTests.relockAt)])
    func leavesOtherStatesAlone(_ session: LockSession) {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        store.session = session

        #expect(EmergencyRelock.perform(store: store, shields: shields, now: Self.relockAt) == nil)
        #expect(store.session == session)
        #expect(shields.applied == 0)
    }
}
```

- [ ] **Step 3: Run the tests to see them fail** — expect `RelockPlan`, `Shielding`, `EmergencyRelock` not found.

- [ ] **Step 4: Implement**

<!-- file: Shared/ShieldController.swift -->
```swift
import FamilyControls
import ManagedSettings

/// Puts the chosen apps behind a shield, or takes it away.
protocol Shielding {
    func apply(_ selection: FamilyActivitySelection)
    func clear()
}

extension ManagedSettingsStore.Name {
    static let tapout = Self("tapout")
}

/// Shields through Screen Time. Settings persist across launches and restarts until cleared.
struct ShieldController: Shielding {
    private let store = ManagedSettingsStore(named: .tapout)

    func apply(_ selection: FamilyActivitySelection) {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let sites = selection.webDomainTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = sites.isEmpty ? nil : sites
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    func clear() {
        store.clearAllSettings()
    }
}
```

Append to `Shared/RelockPlan.swift` (and add `import DeviceActivity` at the top):

```swift
/// Builds the DeviceActivity schedule that ends an emergency pass.
enum RelockPlan {
    static let activity = DeviceActivityName("tapout.emergency")
    /// DeviceActivity's shortest allowed interval.
    static let minimumInterval: TimeInterval = 15 * 60
    /// Full dates, so an interval that crosses midnight is not read as tomorrow's.
    static let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]

    static func schedule(
        relockAt: Date,
        now: Date,
        strategy: RelockStrategy,
        calendar: Calendar = .current
    ) -> DeviceActivitySchedule {
        switch strategy {
        case .warning:
            let end = max(relockAt, now + minimumInterval)
            let lead = Int(end.timeIntervalSince(relockAt).rounded())
            return DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(components, from: now),
                intervalEnd: calendar.dateComponents(components, from: end),
                repeats: false,
                warningTime: DateComponents(minute: lead / 60, second: lead % 60)
            )
        case .pastStart:
            return DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(components, from: relockAt - minimumInterval),
                intervalEnd: calendar.dateComponents(components, from: relockAt),
                repeats: false
            )
        }
    }
}

/// Starts and stops the emergency relock schedule.
protocol RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws
    func cancel()
}

struct RelockScheduler: RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {
        let center = DeviceActivityCenter()
        center.stopMonitoring([RelockPlan.activity])
        try center.startMonitoring(
            RelockPlan.activity,
            during: RelockPlan.schedule(relockAt: relockAt, now: now, strategy: strategy)
        )
    }

    func cancel() {
        DeviceActivityCenter().stopMonitoring([RelockPlan.activity])
    }
}
```

<!-- file: Shared/EmergencyRelock.swift -->
```swift
import Foundation

/// The relock step itself, shared by the app (when it is open at the relock time)
/// and the monitor extension (when it is not).
enum EmergencyRelock {
    /// Relocks an open emergency pass. Returns seconds past the relock time (negative = early),
    /// or nil when no pass was open. Relocking early is allowed; strict beats late.
    static func perform(store: SharedStore, shields: some Shielding, now: Date) -> TimeInterval? {
        guard case .emergency(let relockAt, _) = store.session else { return nil }
        shields.apply(store.selection)
        store.session = .locked(since: relockAt)
        return now.timeIntervalSince(relockAt)
    }
}
```

- [ ] **Step 5: Run the build/test command** — all pass. If Swift 6 reports that `RelockPlan.activity` or `ManagedSettingsStore.Name.tapout` is not concurrency-safe (the SDK type isn't marked `Sendable`), declare that one `nonisolated(unsafe) static let`; both are immutable values.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add shield controller, relock schedule and shared relock step`

---

### Task 3: LockEngine

**Files:**
- Create: `Tapout/Engine/LockEngine.swift`, `TapoutTests/LockEngineTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces: `LockEngine(store:shields:relock:now:)`, `LockEngine.live()`, `LockEngine.emergencyDuration` (300); observable read-only `session`, `passesLeft`, `pairedTags`, `selection`, `relockStrategy`, `log`; `reload()`, `updateSelection(_:)`, `setRelockStrategy(_:)`, `pair(_:name:) -> Bool`, `unpair(_:)`, `handleTag(_:) -> TagOutcome`, `useEmergencyPass() throws`, `relockNow()`, `tick() -> Bool`; DEBUG `resetPasses()`, `clearLog()`. `TagOutcome` = `.locked | .unlocked | .rejected`. `PassError` = `.notLocked | .noPassesLeft | .couldNotSchedule(String)`.

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/LockEngineTests.swift -->
```swift
import FamilyControls
import Foundation
import Testing
@testable import Tapout

@MainActor
struct LockEngineTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let relock = FakeRelock()
    private let tag = TagUID(hex: "04A20F1B")

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, now: { [clock] in clock.now })
    }

    private func lockedEngine() -> LockEngine {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        _ = engine.handleTag(tag)
        return engine
    }

    @Test func freshEngineIsUnlockedWithFivePasses() {
        let engine = makeEngine()
        #expect(engine.session == .unlocked)
        #expect(engine.passesLeft == 5)
    }

    @Test func pairingTheSameTagTwiceIsRefused() {
        let engine = makeEngine()
        #expect(engine.pair(tag, name: "Desk"))
        #expect(!engine.pair(tag, name: "Desk again"))
        #expect(engine.pairedTags.count == 1)
    }

    @Test func unknownTagIsRejectedAndChangesNothing() {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        #expect(engine.handleTag(TagUID(hex: "FFFF")) == .rejected)
        #expect(engine.session == .unlocked)
        #expect(shields.applied == 0)
    }

    @Test func pairedTagLocksAndShields() {
        let engine = makeEngine()
        engine.pair(tag, name: "Desk")
        #expect(engine.handleTag(tag) == .locked)
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.applied == 1)
    }

    @Test func pairedTagUnlocksAndClearsEverything() {
        let engine = lockedEngine()
        #expect(engine.handleTag(tag) == .unlocked)
        #expect(engine.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(relock.cancelled == 1)
    }

    @Test func emergencyPassSpendsOneOpensAppsAndSchedulesRelock() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(engine.passesLeft == 4)
        #expect(shields.cleared == 1)
        #expect(engine.session == .emergency(relockAt: clock.now + 300, duration: 300))
        #expect(relock.scheduled == [.init(relockAt: clock.now + 300, now: clock.now, strategy: .warning)])
    }

    @Test func passUsesTheChosenStrategy() throws {
        let engine = lockedEngine()
        engine.setRelockStrategy(.pastStart)
        try engine.useEmergencyPass()
        #expect(relock.scheduled.first?.strategy == .pastStart)
    }

    @Test func failedScheduleKeepsThePassAndTheLock() {
        let engine = lockedEngine()
        relock.failure = FakeError()
        #expect(throws: LockEngine.PassError.self) { try engine.useEmergencyPass() }
        #expect(engine.passesLeft == 5)
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.cleared == 0)
    }

    @Test func noPassesLeftIsRefused() {
        store.passesLeft = 0
        let engine = lockedEngine()
        #expect(throws: LockEngine.PassError.noPassesLeft) { try engine.useEmergencyPass() }
    }

    @Test func passNeedsALock() {
        let engine = makeEngine()
        #expect(throws: LockEngine.PassError.notLocked) { try engine.useEmergencyPass() }
    }

    @Test func relockNowEndsThePassEarly() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        clock.now += 60
        engine.relockNow()
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.applied == 2)
        #expect(relock.cancelled == 1)
    }

    @Test func tickRelocksAnExpiredPass() throws {
        let engine = lockedEngine()
        let start = clock.now
        try engine.useEmergencyPass()
        clock.now = start + 299
        #expect(!engine.tick())
        clock.now = start + 300
        #expect(engine.tick())
        #expect(engine.session == .locked(since: start + 300))
        #expect(shields.applied == 2)
    }

    @Test func tickPicksUpARelockMadeByTheMonitor() throws {
        let engine = lockedEngine()
        let relockAt = clock.now + 300
        try engine.useEmergencyPass()
        _ = EmergencyRelock.perform(store: store, shields: FakeShields(), now: relockAt)
        #expect(!engine.tick())
        #expect(engine.session == .locked(since: relockAt))
    }

    @Test func tagDuringAPassUnlocks() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(engine.handleTag(tag) == .unlocked)
        #expect(relock.cancelled == 1)
    }

    @Test func changingAppsWhileLockedReshields() {
        let engine = lockedEngine()
        engine.updateSelection(FamilyActivitySelection())
        #expect(shields.applied == 2)
    }

    @Test func stateSurvivesANewEngine() {
        _ = lockedEngine()
        let second = makeEngine()
        #expect(second.session == .locked(since: clock.now))
        #expect(second.pairedTags.count == 1)
    }

    @Test func actionsAreLogged() {
        let engine = lockedEngine()
        #expect(engine.log.map(\.message) == ["Paired Desk (04:A2:0F:1B)", "Locked with Desk"])
    }
}
```

- [ ] **Step 2: Run the tests to see them fail** — expect `LockEngine` not found.

- [ ] **Step 3: Implement**

<!-- file: Tapout/Engine/LockEngine.swift -->
```swift
import FamilyControls
import Foundation
import Observation

/// The real lock: paired tags, shields, emergency passes and relock. Everything is kept in the
/// App Group store, so the monitor extension can relock while Tapout is closed.
/// Replaces `MockLockController` in Phase 4.
@MainActor
@Observable
final class LockEngine {
    enum TagOutcome: Equatable {
        case locked, unlocked, rejected
    }

    enum PassError: Error, Equatable {
        case notLocked, noPassesLeft
        case couldNotSchedule(String)
    }

    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60

    private(set) var session: LockSession = .unlocked
    private(set) var passesLeft = SharedStore.totalPasses
    private(set) var pairedTags: [PairedTag] = []
    private(set) var selection = FamilyActivitySelection()
    private(set) var relockStrategy = RelockStrategy.warning
    private(set) var log: [LogEntry] = []

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let shields: any Shielding
    @ObservationIgnored private let relock: any RelockScheduling
    @ObservationIgnored private let now: () -> Date

    init(
        store: SharedStore,
        shields: any Shielding,
        relock: any RelockScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.shields = shields
        self.relock = relock
        self.now = now
        reload()
    }

    static func live() -> LockEngine {
        LockEngine(store: .appGroup(), shields: ShieldController(), relock: RelockScheduler())
    }

    /// Re-reads the store. The monitor extension may have relocked while Tapout was in the background.
    func reload() {
        session = store.session
        passesLeft = store.passesLeft
        pairedTags = store.pairedTags
        selection = store.selection
        relockStrategy = store.relockStrategy
        log = store.log
    }

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        store.selection = newSelection
        if case .locked = store.session { shields.apply(newSelection) }
        record("Apps: \(newSelection.applicationTokens.count), categories: \(newSelection.categoryTokens.count)")
    }

    func setRelockStrategy(_ strategy: RelockStrategy) {
        store.relockStrategy = strategy
        reload()
    }

    /// Returns false when the tag is already paired.
    @discardableResult
    func pair(_ uid: TagUID, name: String) -> Bool {
        guard !store.pairedTags.contains(where: { $0.uid == uid }) else { return false }
        store.pairedTags.append(PairedTag(uid: uid, name: name, pairedAt: now()))
        record("Paired \(name) (\(uid.display))")
        return true
    }

    func unpair(_ tag: PairedTag) {
        store.pairedTags.removeAll { $0.uid == tag.uid }
        record("Unpaired \(tag.name)")
    }

    /// A tag was read: an unknown tag changes nothing; a paired one locks, or unlocks everything.
    func handleTag(_ uid: TagUID) -> TagOutcome {
        guard let tag = store.pairedTags.first(where: { $0.uid == uid }) else {
            record("Rejected unknown tag \(uid.display)")
            return .rejected
        }
        switch store.session {
        case .unlocked:
            shields.apply(store.selection)
            store.session = .locked(since: now())
            record("Locked with \(tag.name)")
            return .locked
        case .locked, .emergency:
            relock.cancel()
            shields.clear()
            store.session = .unlocked
            record("Unlocked with \(tag.name)")
            return .unlocked
        }
    }

    /// Spends one pass and opens apps for five minutes. The pass is only spent once the
    /// relock is scheduled, so a scheduling failure never leaves apps open for good.
    func useEmergencyPass() throws {
        guard case .locked = store.session else { throw PassError.notLocked }
        guard store.passesLeft > 0 else { throw PassError.noPassesLeft }
        let start = now()
        let relockAt = start + Self.emergencyDuration
        let strategy = store.relockStrategy
        do {
            try relock.schedule(relockAt: relockAt, now: start, strategy: strategy)
        } catch {
            record("Relock schedule failed: \(error)")
            throw PassError.couldNotSchedule(String(describing: error))
        }
        store.passesLeft -= 1
        shields.clear()
        store.session = .emergency(relockAt: relockAt, duration: Self.emergencyDuration)
        record("Emergency pass, relock at \(relockAt.formatted(date: .omitted, time: .standard)) via \(strategy.rawValue)")
    }

    func relockNow() {
        guard case .emergency = store.session else { return }
        relock.cancel()
        shields.apply(store.selection)
        store.session = .locked(since: now())
        record("Relocked early")
    }

    /// Call every second while Tapout is open. Relocks an expired pass if the monitor has not,
    /// and picks up anything the monitor changed. Returns true when it relocked.
    /// The monitor schedule is left running, so its callback still shows up in the log.
    @discardableResult
    func tick() -> Bool {
        let date = now()
        if case .emergency(let relockAt, _) = store.session, date >= relockAt,
           let late = EmergencyRelock.perform(store: store, shields: shields, now: date) {
            record("Relocked in app, \(Int(late))s after relock time")
            return true
        }
        reload()
        return false
    }

    #if DEBUG
    func resetPasses() {
        store.passesLeft = SharedStore.totalPasses
        record("Passes reset")
    }

    func clearLog() {
        store.clearLog()
        reload()
    }
    #endif

    private func record(_ message: String) {
        store.appendLog(message, source: .app, at: now())
        reload()
    }
}
```

- [ ] **Step 4: Run the build/test command** — all pass.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Add LockEngine for real tags, shields and emergency relock`

---

### Task 4: Signing, entitlements and the monitor extension

**Files:**
- Create: `TapoutMonitor/TapoutMonitor.swift`
- Modify: `project.yml`
- Generated by XcodeGen (commit them): `Tapout/Tapout.entitlements`, `TapoutMonitor/TapoutMonitor.entitlements`, `TapoutMonitor/Info.plist`

**Interfaces:**
- Consumes: `SharedStore`, `RelockPlan.activity`, `EmergencyRelock`, `ShieldController` (Tasks 1–2).
- Produces: `TapoutMonitor` (DeviceActivityMonitor subclass) embedded in the app; app entitlements for Family Controls, App Group and NFC tag reading; Info.plist `NFCReaderUsageDescription`.

- [ ] **Step 1: Write the extension**

<!-- file: TapoutMonitor/TapoutMonitor.swift -->
```swift
import DeviceActivity
import Foundation

/// Runs in its own process, woken by DeviceActivity. Relocks an emergency pass when its
/// interval reaches the relock time, and logs every callback so the Lab shows when it fired.
final class TapoutMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        SharedStore.appGroup().appendLog("intervalDidStart \(activity.rawValue)", source: .monitor)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        relock(activity, callback: "intervalWillEndWarning")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        relock(activity, callback: "intervalDidEnd")
    }

    private func relock(_ activity: DeviceActivityName, callback: String) {
        guard activity == RelockPlan.activity else { return }
        let store = SharedStore.appGroup()
        let now = Date()
        if let late = EmergencyRelock.perform(store: store, shields: ShieldController(), now: now) {
            store.appendLog("\(callback): relocked, \(Int(late))s after relock time", source: .monitor, at: now)
        } else {
            store.appendLog("\(callback): nothing to relock", source: .monitor, at: now)
        }
    }
}
```

- [ ] **Step 2: Update `project.yml`**

Add signing to the project-wide settings:

```yaml
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: NO
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    DEVELOPMENT_TEAM: HM34P4HC4F
    CODE_SIGN_STYLE: Automatic
```

Replace the `Tapout` target with:

```yaml
  Tapout:
    type: application
    platform: iOS
    sources:
      - path: Tapout
      - path: Shared
    dependencies:
      - target: TapoutMonitor
    info:
      path: Tapout/Info.plist
      properties:
        CFBundleDisplayName: Tapout
        UILaunchScreen:
          UIColorName: bg
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
        NFCReaderUsageDescription: Tapout reads your tag to lock and unlock your apps.
        # Core NFC drops ISO 7816 tags without this list. This AID is the standard NDEF
        # application; Tapout only reads the tag's UID.
        com.apple.developer.nfc.readersession.iso7816.select-identifiers:
          - D2760000850101
    entitlements:
      path: Tapout/Tapout.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.raphymuthu.tapout
        com.apple.developer.nfc.readersession.formats:
          - TAG
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: ""
        ASSETCATALOG_COMPILER_APPICON_NAME: "" # app icon arrives with the AppIcon screen
```

Add the extension target after `TapoutTests`:

```yaml
  TapoutMonitor:
    type: app-extension
    platform: iOS
    sources:
      - path: TapoutMonitor
      - path: Shared
    info:
      path: TapoutMonitor/Info.plist
      properties:
        CFBundleDisplayName: Tapout Monitor
        NSExtension:
          NSExtensionPointIdentifier: com.apple.deviceactivity.monitor-extension
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).TapoutMonitor
    entitlements:
      path: TapoutMonitor/TapoutMonitor.entitlements
      properties:
        com.apple.developer.family-controls: true
        com.apple.security.application-groups:
          - group.com.raphymuthu.tapout
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout.monitor
        TARGETED_DEVICE_FAMILY: "1"
```

- [ ] **Step 3: Run the build/test command** — all tests pass on the simulator, and the build log shows `TapoutMonitor.appex` embedded in `Tapout.app/PlugIns/`:

```bash
ls build/dd/Build/Products/Debug-iphonesimulator/Tapout.app/PlugIns
```

(Use `-derivedDataPath build/dd` on the test command for this check.) Expected: `TapoutMonitor.appex`.

- [ ] **Step 4: Register capabilities.** Open `Tapout.xcodeproj` in Xcode. For both the **Tapout** and **TapoutMonitor** targets, open **Signing & Capabilities** and confirm: team "Puneet Dang", automatic signing, and no red errors next to Family Controls, App Groups (`group.com.raphymuthu.tapout` ticked) and, on Tapout, Near Field Communication Tag Reading. If Xcode shows "Register" or "Try Again", click it; that creates the App IDs, App Group and capabilities in the developer account. Development builds need no Apple approval for Family Controls.

- [ ] **Step 5: Device build from the terminal** (confirms signing; Xcode must be signed in to the account):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates build -quiet
```

Expected: `** BUILD SUCCEEDED **`. A provisioning error means Step 4 is not done.

Then verify both bundles carry the App Group and Family Controls (without the App Group the app and the extension silently stop sharing state):

```bash
codesign -d --entitlements - build/device/Build/Products/Debug-iphoneos/Tapout.app
codesign -d --entitlements - build/device/Build/Products/Debug-iphoneos/Tapout.app/PlugIns/TapoutMonitor.appex
```

Expected, in each: `group.com.raphymuthu.tapout` and `com.apple.developer.family-controls`.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add signing, entitlements and the DeviceActivity monitor extension`

---

### Task 5: Tag reader and the Lab screen

**Files:**
- Create: `Tapout/Engine/TagReader.swift`, `Tapout/Features/Lab/LabView.swift`
- Modify: `Tapout/App/RootView.swift` (settings sheet)

**Interfaces:**
- Consumes: `LockEngine` (Task 3), `TagUID` (Task 1), `Haptics`, `TimeFormat`, `Color.inkSecondary` (Phase 1).
- Produces: `TagReader.isAvailable`, `TagReader().readUID(prompt:) async throws -> TagUID`, `TagReader.ReadError` = `.unavailable | .busy | .unsupportedTag | .cancelled | .failed(String)`; `LabView()` (DEBUG only).

Core NFC and Screen Time do nothing in the simulator, so this task is checked by building, and by opening the Lab in the simulator to confirm it renders and shows "NFC isn't available on this device." The real check is Task 6.

- [ ] **Step 1: Write the tag reader**

<!-- file: Tapout/Engine/TagReader.swift -->
```swift
@preconcurrency import CoreNFC

/// Reads a tag's hardware UID through one system NFC sheet. Nothing is written to the tag.
/// Callbacks arrive on the main queue, which is the only place this class's state is touched.
final class TagReader: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    enum ReadError: Error, Equatable {
        case unavailable, busy, unsupportedTag, cancelled
        case failed(String)
    }

    static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<TagUID, any Error>?

    @MainActor
    func readUID(prompt: String) async throws -> TagUID {
        guard Self.isAvailable else { throw ReadError.unavailable }
        guard continuation == nil else { throw ReadError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            guard let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main) else {
                continuation.resume(throwing: ReadError.unavailable)
                return
            }
            self.continuation = continuation
            self.session = session
            session.alertMessage = prompt
            session.begin()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
        let code = (error as? NFCReaderError)?.code
        let cancelled = code == .readerSessionInvalidationErrorUserCanceled
            || code == .readerSessionInvalidationErrorSessionTimeout
        finish(.failure(cancelled ? .cancelled : .failed(error.localizedDescription)))
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "Hold one tag at a time."
            session.restartPolling()
            return
        }
        session.connect(to: tag) { [self] error in
            if let error {
                session.invalidate(errorMessage: "Try again.")
                finish(.failure(.failed(error.localizedDescription)))
                return
            }
            guard let uid = Self.identifier(of: tag) else {
                session.invalidate(errorMessage: "This tag isn't supported.")
                finish(.failure(.unsupportedTag))
                return
            }
            session.alertMessage = "Done."
            session.invalidate()
            finish(.success(TagUID(data: uid)))
        }
    }

    private static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let tag): tag.identifier
        case .iso15693(let tag): tag.identifier
        case .iso7816(let tag): tag.identifier
        case .feliCa: nil
        @unknown default: nil
        }
    }

    /// Resumes the waiting read once. Later callbacks (the invalidation after a success) are ignored.
    private func finish(_ result: Result<TagUID, ReadError>) {
        continuation?.resume(with: result.mapError { $0 as any Error })
        continuation = nil
    }
}
```

- [ ] **Step 2: Write the Lab**

<!-- file: Tapout/Features/Lab/LabView.swift -->
```swift
#if DEBUG
import FamilyControls
import SwiftUI

/// DEBUG-only test bench for the Phase 2 device spike: Screen Time access, app picking, tag
/// pairing and reads, emergency relock, and a log shared with the monitor extension.
/// Not a designed screen; it uses plain system list styling.
struct LabView: View {
    @State private var engine = LockEngine.live()
    @State private var reader = TagReader()
    @ObservedObject private var center = AuthorizationCenter.shared
    @State private var picking = false
    @State private var message: String?
    @Environment(\.scenePhase) private var scenePhase

    private let prompt = "Hold your tag near the top of your iPhone."

    var body: some View {
        NavigationStack {
            List {
                accessSection
                appsSection
                tagsSection
                sessionSection
                logSection
            }
            .navigationTitle("Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
        .familyActivityPicker(
            isPresented: $picking,
            selection: Binding(get: { engine.selection }, set: { engine.updateSelection($0) })
        )
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {}
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { engine.reload() }
        }
        .task { await runClock() }
    }

    // MARK: Sections

    private var accessSection: some View {
        Section("Screen Time") {
            LabeledContent("Access", value: accessText)
            if center.authorizationStatus != .approved {
                Button("Allow Screen Time access") {
                    Task {
                        do { try await center.requestAuthorization(for: .individual) }
                        catch { message = "Access failed: \(error.localizedDescription)" }
                    }
                }
            }
        }
    }

    private var appsSection: some View {
        Section("Blocked apps") {
            ForEach(Array(engine.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            if !engine.selection.categoryTokens.isEmpty {
                LabeledContent("Categories", value: "\(engine.selection.categoryTokens.count)")
            }
            Button("Choose apps") { picking = true }
                .disabled(center.authorizationStatus != .approved)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            ForEach(engine.pairedTags) { tag in
                LabeledContent(tag.name, value: tag.uid.display)
                    .swipeActions {
                        Button("Unpair", role: .destructive) { engine.unpair(tag) }
                    }
            }
            Button("Pair a tag") { Task { await pair() } }
            Button("Scan") { Task { await scan() } }
                .disabled(engine.pairedTags.isEmpty)
            if !TagReader.isAvailable {
                Text("NFC isn't available on this device.")
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LabeledContent("State", value: stateText(at: context.date))
            }
            LabeledContent("Passes left", value: "\(engine.passesLeft) of \(SharedStore.totalPasses)")
            Picker("Relock via", selection: Binding(get: { engine.relockStrategy }, set: { engine.setRelockStrategy($0) })) {
                Text("Warning").tag(RelockStrategy.warning)
                Text("Past start").tag(RelockStrategy.pastStart)
            }
            Button("Emergency pass") {
                do {
                    try engine.useEmergencyPass()
                    Haptics.unlock()
                } catch {
                    message = passMessage(error)
                }
            }
            .disabled(!isLocked)
            Button("Relock now") {
                engine.relockNow()
                Haptics.lock()
            }
            .disabled(!isEmergency)
            Button("Reset passes") { engine.resetPasses() }
        }
    }

    private var logSection: some View {
        Section {
            ForEach(engine.log.reversed()) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.date.formatted(date: .omitted, time: .standard)) · \(entry.source.rawValue)")
                        .font(.tCaption.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                    Text(entry.message)
                        .font(.tFootnote)
                }
            }
        } header: {
            HStack {
                Text("Log")
                Spacer()
                Button("Clear") { engine.clearLog() }
            }
        }
    }

    // MARK: Actions

    private func pair() async {
        do {
            let uid = try await reader.readUID(prompt: prompt)
            if engine.pair(uid, name: "Tag \(engine.pairedTags.count + 1)") {
                Haptics.select()
            } else {
                message = "That tag is already paired."
            }
        } catch TagReader.ReadError.cancelled {
        } catch {
            message = "Read failed: \(error)"
        }
    }

    private func scan() async {
        Haptics.prepare()
        do {
            let uid = try await reader.readUID(prompt: prompt)
            switch engine.handleTag(uid) {
            case .locked: Haptics.lock()
            case .unlocked: Haptics.unlock()
            case .rejected:
                Haptics.mismatch()
                message = "Not a paired tag."
            }
        } catch TagReader.ReadError.cancelled {
        } catch {
            message = "Read failed: \(error)"
        }
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if engine.tick() { Haptics.lock() }
        }
    }

    // MARK: Text

    private var accessText: String {
        switch center.authorizationStatus {
        case .approved: "Approved"
        case .denied: "Denied"
        case .notDetermined: "Not asked"
        @unknown default: "Unknown"
        }
    }

    private var isLocked: Bool {
        if case .locked = engine.session { true } else { false }
    }

    private var isEmergency: Bool {
        if case .emergency = engine.session { true } else { false }
    }

    private func stateText(at date: Date) -> String {
        switch engine.session {
        case .unlocked: "Unlocked"
        case .locked: "Locked \(TimeFormat.clock(engine.session.elapsed(at: date)))"
        case .emergency: "Open, relocks in \(TimeFormat.clock(engine.session.remaining(at: date)))"
        }
    }

    private func passMessage(_ error: any Error) -> String {
        switch error as? LockEngine.PassError {
        case .notLocked: "Lock first."
        case .noPassesLeft: "No passes left."
        case .couldNotSchedule(let reason): "Couldn't schedule the relock: \(reason)"
        case nil: error.localizedDescription
        }
    }
}
#endif
```

- [ ] **Step 3: Open the Lab from the settings button (DEBUG only)**

In `Tapout/App/RootView.swift`, replace the settings sheet:

```swift
        .sheet(isPresented: $showingSettings) {
            #if DEBUG
            LabView()
            #else
            PlaceholderView(title: "Settings")
            #endif
        }
```

- [ ] **Step 4: Run the build/test command and the device build from Task 4 Step 5** — both succeed, no warnings from `Tapout/`, `Shared/` or `TapoutMonitor/`.

- [ ] **Step 5: Simulator smoke check** — install on iPhone 17, tap the settings button: the Lab opens, shows Access "Not asked" (or "Denied"), "NFC isn't available on this device.", State "Unlocked", Passes left "5 of 5", and an empty log.

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add NFC tag reader and debug Lab screen`

---

### Task 6: Device spike run

Needs: the iPhone 16 with **Developer Mode** on (Settings → Privacy & Security → Developer Mode), connected by cable the first time; **two** NTAG stickers (one stays unpaired for Step 6). Don't substitute another NFC card as the unknown tag: Core NFC won't read most bank, transit or hotel cards with this setup, and a no-read looks like a timeout, so Step 6 would prove nothing. Use two harmless apps for blocking, for example Photos and Calendar. Run from Xcode: select "Raphy's iPhone" as the run destination, ⌘R.

Record every result in the table at the end of this plan.

- [ ] **Step 1: Access** — settings button → Lab → "Allow Screen Time access" → approve with Face ID/passcode. Expected: Access "Approved" and App Group "OK". If App Group says "Missing", stop and fix signing first (Task 4 Step 4 and the `codesign` check in Step 5).
- [ ] **Step 2: Apps** — "Choose apps", pick Photos and Calendar. Expected: both listed with icons; log line "Apps: 2, categories: 0".
- [ ] **Step 3: Pair** — "Pair a tag", hold sticker A to the top of the phone. Expected: NFC sheet says "Done.", "Tag 1" with its UID. Pair A again. Expected: "That tag is already paired."
- [ ] **Step 4: Lock** — "Scan", tag A. Expected: two firm taps, State "Locked 0:00" counting up. Open Photos from the Home Screen. Expected: iOS's default Screen Time block screen.
- [ ] **Step 5: Persistence** — swipe Tapout away in the app switcher, open Photos: still blocked. Restart the phone, open Photos: still blocked.
- [ ] **Step 6: Unknown tag** — "Scan", the unpaired tag/card. Expected: warning haptic, "Not a paired tag.", still locked, log "Rejected unknown tag …".
- [ ] **Step 7: Unlock** — "Scan", tag A. Expected: one soft tap, Unlocked, Photos opens.
- [ ] **Step 8: Relock, `warning` strategy** — Relock via "Warning". Scan tag A to lock, then "Emergency pass". Expected: Passes 4 of 5, Photos opens. Note the relock time in the log, and the `app · Scheduled: …` line under it (what DeviceActivity stored). For a second timing record, open Console.app on the Mac with the phone connected, select the phone, turn on Action → Include Info Messages, filter by subsystem `com.raphymuthu.tapout` and click Start streaming before you lock the phone. **Swipe Tapout away**, lock the phone, wait 6 minutes. Unlock the phone, open Photos. Expected: blocked. Open the Lab: log shows `monitor · intervalWillEndWarning: relocked, Ns after relock time`. Record N. Leave the phone alone 10 more minutes and check for `intervalDidEnd: nothing to relock`.
- [ ] **Step 9: Relock, `pastStart` strategy** — Reset passes, switch to "Past start", repeat Step 8. Expected either: the pass starts and `intervalDidEnd: relocked, Ns …` appears (record N), or "Couldn't schedule the relock: …" (record the error text; the pass is not spent), or accepted but no monitor callback: the Scheduled line shows `none` or an interval already in the past, and no `monitor` line appears. Record that too.
- [ ] **Step 10: Repeat the better strategy twice more**, once with Low Power Mode on. Record each N.
- [ ] **Step 11: Relock now** — lock, emergency pass, "Relock now". Expected: blocked again immediately; no monitor relock line afterwards.
- [ ] **Step 12: Back-to-back passes** — "Reset passes" first (this step needs two), keep the strategy chosen in Step 10, then lock, emergency pass, "Relock now", then another emergency pass right away. Expected: the monitor relocks only at the second pass's relock time, with no earlier relock line. An early relock means a stale interval from the first pass fired.
- [ ] **Step 13: Report** — fill in the results table below, pick the strategy for Phase 4 (the one that relocked closest to 0 s, never more than ~60 s late), and write anything surprising under "Findings". Leave all changes uncommitted with the suggested message `Record Phase 2 device spike results`.

## Device results

A negative N means the callback fired early, or came from a stale interval. Check the back-to-back result before deciding.

| Check | Expected | Result |
| --- | --- | --- |
| Screen Time access | Approved | |
| App Group | OK | |
| Shield on lock | Photos blocked | |
| Shield after app killed | Still blocked | |
| Shield after restart | Still blocked | |
| Unknown tag | Rejected, still locked | |
| Unlock | Photos opens | |
| `warning` relock, run 1 | Relocked, N ≈ 0 s | |
| `pastStart` relock, run 1 | Relocked or schedule error | |
| Chosen strategy, run 2 | | |
| Chosen strategy, run 3 (Low Power) | | |
| Relock now | Blocked immediately | |
| Back-to-back passes | Monitor relocks only at the second pass's time | |

**Chosen strategy for Phase 4:**

**Findings:**

## Phase 4 follow-ups (from the Phase 2 review)

- Give each pass its own activity name, with a matching `relockAt` guard in the monitor, so a stale callback from an earlier pass can't relock a later one.
- Forbid unpairing the last tag while locked.
- Move passes to the Keychain without carrying over the absent-means-5 default.
- Make `FakeShields` record the applied selection.
- Coordinate the cross-process log if it becomes user-facing.
