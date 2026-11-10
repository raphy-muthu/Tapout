# Phase 4A: Real Locking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `MockLockController` with the real `LockEngine`, so a tag tap shields the active mode's apps on the iPhone, the lock survives quitting and restarts, passes can't be refilled by reinstalling, pass time stops counting as locked, blocked apps show the Sealed screen, and lost Screen Time access is caught at launch.

**Architecture:** `LockEngine` (Phase 2's spike, reshaped) owns lock state, shields, passes and the emergency relock, all in the App Group store. `AppModel` keeps places, modes and lock records, and gains pass windows and a launch `reconcile`. `RootView` still decides which tags may lock or unlock (`AppModel.check`) and calls the engine. One `SharedStore.activeShieldPlan` feeds every shield call in the app and the monitor. A new `TapoutShield` extension draws the block screen.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XcodeGen, FamilyControls, ManagedSettings, ManagedSettingsUI, DeviceActivity, Security (Keychain). iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-08-phase4-design.md`. Read it first.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor `com.raphymuthu.tapout.monitor`, shield `com.raphymuthu.tapout.shield` (new). App Group `group.com.raphymuthu.tapout`. Team `HM34P4HC4F`.
- Five emergency passes total, ever (`SharedStore.totalPasses`). An emergency pass opens apps for 5 minutes (`LockEngine.emergencyDuration`).
- Schedules never unlock (4B). Pass time never counts as locked time.
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.inkTertiary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.onEmber`, `.slate`, `.slateInk`, `.slateLine`, `.slateGlow`, `.track`, `.danger`; asset names are kebab-case, e.g. `ink-secondary`, `surface-2`). No raw hex.
- Fraunces for titles and numbers of 20pt and up, through `Typography.swift`; SF Pro for everything else. Anything in Fraunces that ticks uses `FixedDigitText`.
- 44pt minimum touch targets, with the frame and `contentShape` inside the button's label. Continuous corners. No borders on cards.
- Copy: very few words, no guilt or shame, no emoji, no exclamation marks, no miss counters.
- `Shared/` stays free of SwiftUI (it compiles into the monitor extension).
- Every new screen has `#Preview`s in dark and light (the block screen is dark only and has no SwiftUI preview).
- **Never commit, stage or stash.** The user commits manually; each task ends with a suggested commit message.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

`[store] Unreadable` lines and `appintentsmetadataprocessor` warnings are expected.

**Device compile check** (exit code must be 0; don't pipe it):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates build -quiet; echo "exit $?"
```

**Test count chain:** 170 → 181 (Task 1) → 189 (Task 2) → 191 (Task 3) → 194 (Task 4) → 184 (Task 5) → 189 (Task 6) → 189 (Task 7) → 190 (Task 8). If a count differs, report it; never add or remove tests to hit a number.

**Known limit:** Screen Time tokens can't be created in tests, so tests can't prove which apps a plan holds. They prove that every shield call goes through `SharedStore.activeShieldPlan`, and the device run proves what gets blocked.

## File map

| File | Responsibility |
| --- | --- |
| `Shared/LockRecord.swift` | Records gain `passes` and `lockedTime(in:now:)`, the one place lock time is computed |
| `Tapout/Model/Insights.swift`, `Tapout/Model/LockStats.swift` | Use `lockedTime`, so pass time drops out everywhere |
| `Tapout/Model/AppModel.swift` | `startPass`, `endPass`, `runningLockTime`, `reconcile(with:)` |
| `Shared/ShieldPlan.swift` (new) | Mode apps minus always-allowed; `SharedStore.activeShieldPlan` |
| `Shared/ShieldController.swift`, `Shared/EmergencyRelock.swift`, `Shared/SharedStore.swift` | Shield by plan; drop the spike's `selection` key |
| `Tapout/Engine/LockEngine.swift` | The app's lock: `lock`, `unlock`, `syncShields`, passes, relock |
| `Tapout/Engine/SimulatorStandIns.swift` (new) | `NoShields`, `NoRelock` |
| `Tapout/Engine/LockEngine+Debug.swift` (new) | `-mockState`, `preview(...)` |
| `Tapout/Engine/PassVault.swift` (new) | Keychain pass count |
| `Tapout/App/TapoutApp.swift`, `Tapout/App/RootView.swift`, `Tapout/Features/Home/HomeView.swift`, `Tapout/Features/EmergencyPass/EmergencyPassView.swift`, `Tapout/Features/Lab/LabView.swift` | Use the engine |
| `Tapout/Model/MockLockController.swift`, `TapoutTests/MockLockControllerTests.swift` | Deleted |
| `TapoutShield/ShieldConfigurationExtension.swift` (new), `project.yml` | Sealed block screen |
| `Tapout/Engine/ScreenTimeAccess.swift`, `Tapout/Features/Onboarding/ScreenTimeAgainView.swift` (new), `Tapout/Features/Onboarding/OnboardingView.swift` | Screen Time check on launch |

---

### Task 1: Pass windows and one way to count locked time

**Files:**
- Modify: `Shared/LockRecord.swift`, `Tapout/Model/Insights.swift:50-63,89-94`, `Tapout/Model/LockStats.swift:9-17`
- Create: `TapoutTests/LockRecordTests.swift`
- Test: `TapoutTests/InsightsTests.swift`, `TapoutTests/LockStatsTests.swift`

**Interfaces:**
- Produces: `LockRecord.passes: [DateInterval]` (default `[]`, decodes as `[]` when absent); `LockRecord.lockedTime(in: DateInterval? = nil, now: Date) -> TimeInterval`; `mutating LockRecord.endPass(at: Date)`. The memberwise init keeps its current parameters, plus `passes:` last with a default.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/LockRecordTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

struct LockRecordTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let mode = UUID()

    private func record(end: TimeInterval? = nil, passes: [(TimeInterval, TimeInterval)] = []) -> LockRecord {
        LockRecord(start: t0, end: end.map { t0 + $0 }, placeUID: nil, modeID: mode,
                   passes: passes.map { DateInterval(start: t0 + $0.0, end: t0 + $0.1) })
    }

    @Test func finishedLockCountsStartToEnd() {
        #expect(record(end: 3600).lockedTime(now: t0 + 9000) == 3600)
    }

    @Test func runningLockCountsUpToNow() {
        #expect(record().lockedTime(now: t0 + 600) == 600)
    }

    @Test func passTimeIsLeftOut() {
        #expect(record(end: 7200, passes: [(3600, 3900)]).lockedTime(now: t0 + 9000) == 6900)
    }

    @Test func aRunningPassCountsOnlyUpToNow() {
        // The pass opened at 50 s and runs to 350 s. At 100 s, 50 s were locked.
        #expect(record(passes: [(50, 350)]).lockedTime(now: t0 + 100) == 50)
    }

    @Test func clipsToAnInterval() {
        let interval = DateInterval(start: t0 + 3600, end: t0 + 7200)
        #expect(record(end: 7200, passes: [(3000, 3900)]).lockedTime(in: interval, now: t0 + 9000) == 3300)
    }

    @Test func outsideTheIntervalIsZero() {
        let interval = DateInterval(start: t0 + 9000, end: t0 + 10_000)
        #expect(record(end: 3600).lockedTime(in: interval, now: t0 + 20_000) == 0)
    }

    @Test func endPassShortensOnlyARunningPass() {
        var lock = record(passes: [(50, 350)])
        lock.endPass(at: t0 + 120)
        #expect(lock.passes == [DateInterval(start: t0 + 50, end: t0 + 120)])
        lock.endPass(at: t0 + 200)
        #expect(lock.passes == [DateInterval(start: t0 + 50, end: t0 + 120)])
    }

    @Test func decodesRecordsSavedBeforePasses() throws {
        let json = #"{"start":0,"end":60,"modeID":"\#(mode.uuidString)"}"#
        let decoded = try JSONDecoder().decode(LockRecord.self, from: Data(json.utf8))
        #expect(decoded.passes.isEmpty)
        #expect(decoded.lockedTime(now: .distantFuture) == 60)
    }

    @Test func passesSurviveSaving() throws {
        let lock = record(end: 7200, passes: [(3600, 3900)])
        let decoded = try JSONDecoder().decode(LockRecord.self, from: JSONEncoder().encode(lock))
        #expect(decoded == lock)
    }
}
```

Add inside `struct InsightsTests` in `TapoutTests/InsightsTests.swift`:

```swift
    @Test func passTimeIsNotPhoneFree() {
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let lock = LockRecord(start: start, end: start + 3600, placeUID: nil, modeID: UUID(),
                              passes: [DateInterval(start: start + 600, duration: 300)])
        #expect(Insights.totalLocked(history: [lock], now: start + 7200) == 3300)
        #expect(Insights.lockedTime(in: DateInterval(start: start, end: start + 3600), history: [lock], now: start + 7200) == 3300)
        #expect(Insights.longest(weekOf: start, history: [lock], calendar: .current) == 3300)
    }
```

Add inside `struct LockStatsTests` in `TapoutTests/LockStatsTests.swift`:

```swift
    @Test func modeTimeLeavesOutPasses() {
        let mode = UUID()
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let lock = LockRecord(start: start, end: start + 3600, placeUID: nil, modeID: mode,
                              passes: [DateInterval(start: start + 600, duration: 300)])
        #expect(LockStats.lockedTime(modeID: mode, weekOf: start + 3600, in: [lock]) == 3300)
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails because `passes` and `lockedTime` don't exist.

- [ ] **Step 3: Implement.** Replace `Shared/LockRecord.swift` with:

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
    /// Emergency passes inside this lock. Apps were open then, so that time isn't locked time.
    /// A running pass ends at its relock time; relocking early or unlocking shortens it.
    var passes: [DateInterval] = []

    /// Locked time without pass time, only inside `interval` when given.
    /// A running lock counts up to `now`, and nothing counts past `now`.
    func lockedTime(in interval: DateInterval? = nil, now: Date) -> TimeInterval {
        let end = min(self.end ?? now, now)
        guard end > start else { return 0 }
        var span = DateInterval(start: start, end: end)
        if let interval {
            guard let clipped = span.intersection(with: interval) else { return 0 }
            span = clipped
        }
        let open = passes.reduce(0) { total, pass in
            total + (pass.intersection(with: span)?.duration ?? 0)
        }
        return max(0, span.duration - open)
    }

    /// Ends the running pass at `date`, if it would otherwise run past it.
    mutating func endPass(at date: Date) {
        guard let last = passes.last, date < last.end else { return }
        passes[passes.count - 1] = DateInterval(start: last.start, end: max(last.start, date))
    }
}

extension LockRecord {
    private enum CodingKeys: String, CodingKey {
        case start, end, placeUID, modeID, intention, intentionDone, passes
    }

    /// Records saved before Phase 4 have no `passes`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        placeUID = try container.decodeIfPresent(TagUID.self, forKey: .placeUID)
        modeID = try container.decode(UUID.self, forKey: .modeID)
        intention = try container.decodeIfPresent(String.self, forKey: .intention)
        intentionDone = try container.decodeIfPresent(Bool.self, forKey: .intentionDone)
        passes = try container.decodeIfPresent([DateInterval].self, forKey: .passes) ?? []
    }
}
```

In `Tapout/Model/Insights.swift`, replace `lockedTime(in:history:now:)` and `totalLocked(history:now:)` with:

```swift
    /// Locked time inside `interval`, without pass time. A running lock counts up to `now`.
    static func lockedTime(in interval: DateInterval, history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { $0 + $1.lockedTime(in: interval, now: now) }
    }

    /// All locked time so far, without pass time.
    static func totalLocked(history: [LockRecord], now: Date) -> TimeInterval {
        history.reduce(0) { $0 + $1.lockedTime(now: now) }
    }
```

and replace `longest(weekOf:history:calendar:)` with:

```swift
    /// The longest finished lock this week, without pass time; nil before the first one.
    static func longest(weekOf date: Date, history: [LockRecord], calendar: Calendar) -> TimeInterval? {
        finished(in: week(of: date, calendar: calendar), history: history)
            .map { $0.lockedTime(now: .distantFuture) }
            .max()
    }
```

In `Tapout/Model/LockStats.swift`, replace `lockedTime(modeID:weekOf:in:calendar:)` with:

```swift
    /// Time locked in `modeID` during the week that contains `now`, without pass time.
    /// A lock still running counts up to `now`.
    static func lockedTime(modeID: UUID, weekOf now: Date, in history: [LockRecord], calendar: Calendar = .current) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return history.filter { $0.modeID == modeID }.reduce(0) { $0 + $1.lockedTime(in: week, now: now) }
    }
```

- [ ] **Step 4: Run the tests.** Expected: TEST SUCCEEDED, 181 tests.

- [ ] **Step 5: Suggested commit message:** `Count lock time in one place and leave out pass windows`

---

### Task 2: AppModel records passes and matches the lock state at launch

**Files:**
- Modify: `Tapout/Model/AppModel.swift` (Locks section, around lines 192-272)
- Test: `TapoutTests/AppModelLockTests.swift`

**Interfaces:**
- Consumes: Task 1's `LockRecord.passes`, `endPass(at:)`, `lockedTime(now:)`.
- Produces: `AppModel.startPass(until relockAt: Date)`, `AppModel.endPass()`, `AppModel.runningLockTime(at: Date) -> TimeInterval?` (nil when no lock record is running), `AppModel.reconcile(with session: LockSession)`. `finishLock()` now also ends a running pass.

- [ ] **Step 1: Write the failing tests.** Add inside `struct AppModelLockTests` (it already has `clock`, `store`, `kitchen`, `makeModel()` and `pairedModel()`):

```swift
    @Test func aPassIsNotedInTheRunningLock() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        let start = clock.now
        clock.now += 600
        model.startPass(until: clock.now + 300)
        #expect(try #require(model.history.last).passes == [DateInterval(start: start + 600, duration: 300)])
    }

    @Test func relockingEarlyEndsThePass() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        let passStart = clock.now
        model.startPass(until: passStart + 300)
        clock.now += 60
        model.endPass()
        #expect(try #require(model.history.last).passes == [DateInterval(start: passStart, duration: 60)])
    }

    @Test func unlockingDuringAPassEndsIt() throws {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        model.startPass(until: clock.now + 300)
        clock.now += 100
        let record = try #require(model.finishLock())
        #expect(record.passes.first?.duration == 100)
        #expect(record.end == clock.now)
    }

    @Test func runningLockTimeLeavesOutThePass() {
        let model = pairedModel()
        #expect(model.runningLockTime(at: clock.now) == nil)
        model.startLock(placeUID: kitchen, intention: nil)
        clock.now += 600
        model.startPass(until: clock.now + 300)
        clock.now += 900
        #expect(model.runningLockTime(at: clock.now) == 1200)
    }

    @Test func reconcileWhileUnlockedDropsAnOpenRecord() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: "Essay")
        model.reconcile(with: .unlocked)
        #expect(model.history.isEmpty)
        #expect(model.currentIntention == nil)
    }

    @Test func reconcileAddsARecordForALockWithoutOne() {
        let model = pairedModel()
        let since = clock.now - 600
        model.reconcile(with: .locked(since: since))
        #expect(model.history == [LockRecord(start: since, end: nil, placeUID: nil, modeID: model.activeMode.id)])
    }

    @Test func reconcileAddsTheOpenPassToo() throws {
        let model = pairedModel()
        let relockAt = clock.now + 200
        model.reconcile(with: .emergency(relockAt: relockAt, duration: 300))
        let record = try #require(model.history.last)
        #expect(record.start == relockAt - 300)
        #expect(record.passes == [DateInterval(start: relockAt - 300, end: relockAt)])
    }

    @Test func reconcileKeepsARunningRecord() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        model.reconcile(with: .locked(since: clock.now - 9999))
        #expect(model.history.count == 1)
        #expect(model.history.first?.start == clock.now)
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`startPass` and the others don't exist).

- [ ] **Step 3: Implement.** In `Tapout/Model/AppModel.swift`:

Replace the doc comment of `discardInterruptedLocks()` with:

```swift
    /// Drops locks left open while the lock state says unlocked: nobody knows how long they really
    /// ran, so they don't count. `reconcile(with:)` calls this at launch; `startLock` calls it too.
```

In `finishLock()`, add `all[index].endPass(at: now())` on the line before `all[index].end = now()`.

Add after `answerIntention(forLockStartedAt:done:)`:

```swift
    // MARK: Emergency passes

    /// Notes an emergency pass in the running lock, from now until `relockAt`.
    func startPass(until relockAt: Date) {
        var all = store.lockHistory
        guard let index = all.lastIndex(where: { $0.end == nil }), relockAt > now() else { return }
        all[index].passes.append(DateInterval(start: now(), end: relockAt))
        store.lockHistory = all
        reload()
    }

    /// Ends the running pass now, for Relock now.
    func endPass() {
        var all = store.lockHistory
        guard let index = all.lastIndex(where: { $0.end == nil }) else { return }
        all[index].endPass(at: now())
        store.lockHistory = all
        reload()
    }

    /// Locked time of the running lock without pass time, for Home's timer. nil when none runs.
    func runningLockTime(at date: Date) -> TimeInterval? {
        history.last { $0.end == nil }?.lockedTime(now: date)
    }

    /// Matches the history to the lock state at launch. The lock state wins: shields follow it,
    /// it survives quitting, and the monitor can relock while Tapout is closed.
    func reconcile(with session: LockSession) {
        let running = history.contains { $0.end == nil }
        switch session {
        case .unlocked:
            discardInterruptedLocks()
        case .locked(let since):
            guard !running else { return }
            append(LockRecord(start: since, end: nil, placeUID: nil, modeID: activeMode.id))
        case .emergency(let relockAt, let duration):
            guard !running else { return }
            let start = relockAt - duration
            append(LockRecord(start: start, end: nil, placeUID: nil, modeID: activeMode.id,
                              passes: [DateInterval(start: start, end: relockAt)]))
        }
    }

    private func append(_ record: LockRecord) {
        store.lockHistory = store.lockHistory + [record]
        reload()
    }
```

- [ ] **Step 4: Run the tests.** Expected: TEST SUCCEEDED, 189 tests.

- [ ] **Step 5: Suggested commit message:** `Record emergency pass windows and reconcile lock records at launch`

---

### Task 3: One shield plan for every shield call

**Files:**
- Create: `Shared/ShieldPlan.swift`, `TapoutTests/ShieldPlanTests.swift`
- Modify: `Shared/ShieldController.swift`, `Shared/EmergencyRelock.swift:10`, `Shared/SharedStore.swift` (remove `selection`), `Tapout/Engine/LockEngine.swift`, `Tapout/Features/Lab/LabView.swift`, `TapoutTests/Fakes.swift`, `TapoutTests/LockEngineTests.swift`

**Interfaces:**
- Produces: `struct ShieldPlan: Equatable` with `applications`, `categories`, `webDomains`, `allowedApplications`, `allowedWebDomains`, `init(blocking: FamilyActivitySelection, allowing: FamilyActivitySelection)` and `isEmpty`; `SharedStore.activeShieldPlan: ShieldPlan`; `protocol Shielding { func apply(_ plan: ShieldPlan); func clear() }`; `FakeShields.plans: [ShieldPlan]` (with `applied` = `plans.count`).
- Removes: `SharedStore.selection`, `LockEngine.selection`, `LockEngine.updateSelection(_:)`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/ShieldPlanTests.swift`:

```swift
import FamilyControls
import Foundation
import Testing
@testable import Tapout

struct ShieldPlanTests {
    @Test func emptySelectionsShieldNothing() {
        let plan = ShieldPlan(blocking: FamilyActivitySelection(), allowing: FamilyActivitySelection())
        #expect(plan.isEmpty)
        #expect(plan.allowedApplications.isEmpty)
    }

    @Test func aStoreWithoutModesGivesAnEmptyPlan() {
        #expect(SharedStore.makeTest().activeShieldPlan.isEmpty)
    }

    @Test func relockAppliesTheStoresPlan() {
        let store = SharedStore.makeTest()
        let shields = FakeShields()
        let relockAt = Date(timeIntervalSinceReferenceDate: 800_000_300)
        store.session = .emergency(relockAt: relockAt, duration: 300)
        _ = EmergencyRelock.perform(store: store, shields: shields, now: relockAt)
        #expect(shields.plans == [store.activeShieldPlan])
    }
}
```

Replace `FakeShields` in `TapoutTests/Fakes.swift` with:

```swift
/// Records shield calls instead of touching Screen Time.
final class FakeShields: Shielding {
    private(set) var plans: [ShieldPlan] = []
    private(set) var cleared = 0

    var applied: Int { plans.count }

    func apply(_ plan: ShieldPlan) { plans.append(plan) }
    func clear() { cleared += 1 }
}
```

In `TapoutTests/LockEngineTests.swift`, delete `changingAppsWhileLockedReshields()`; `updateSelection` goes away.

- [ ] **Step 2: Run the tests.** Expected: the build fails (`ShieldPlan` doesn't exist).

- [ ] **Step 3: Implement.** Create `Shared/ShieldPlan.swift`:

```swift
import FamilyControls
import ManagedSettings

/// What one lock shields: the mode's apps, categories and sites, minus the always-allowed ones.
/// A category can't drop single apps from its token, so allowed apps become category exceptions.
struct ShieldPlan: Equatable {
    var applications: Set<ApplicationToken>
    var categories: Set<ActivityCategoryToken>
    var webDomains: Set<WebDomainToken>
    var allowedApplications: Set<ApplicationToken>
    var allowedWebDomains: Set<WebDomainToken>

    init(blocking blocked: FamilyActivitySelection, allowing allowed: FamilyActivitySelection) {
        applications = blocked.applicationTokens.subtracting(allowed.applicationTokens)
        categories = blocked.categoryTokens
        webDomains = blocked.webDomainTokens.subtracting(allowed.webDomainTokens)
        allowedApplications = allowed.applicationTokens
        allowedWebDomains = allowed.webDomainTokens
    }

    /// Nothing to shield, because the mode has no apps yet.
    var isEmpty: Bool {
        applications.isEmpty && categories.isEmpty && webDomains.isEmpty
    }
}

extension SharedStore {
    /// The active mode's shield. Every lock, relock and pass end uses it, in the app and in the
    /// monitor, so they always agree. Modes are read-only while locked, so it can't change mid-lock.
    var activeShieldPlan: ShieldPlan {
        let modes = self.modes
        let mode = modes.first { $0.id == activeModeID } ?? modes.first
        return ShieldPlan(blocking: mode?.selection ?? FamilyActivitySelection(), allowing: alwaysAllowed)
    }
}
```

Replace the protocol and `apply` in `Shared/ShieldController.swift`:

```swift
/// Puts the planned apps behind a shield, or takes it away.
protocol Shielding {
    func apply(_ plan: ShieldPlan)
    func clear()
}
```

```swift
    func apply(_ plan: ShieldPlan) {
        let categories = plan.categories
        store.shield.applications = plan.applications.isEmpty ? nil : plan.applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: plan.allowedApplications)
        store.shield.webDomains = plan.webDomains.isEmpty ? nil : plan.webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: plan.allowedWebDomains)
    }
```

In `Shared/EmergencyRelock.swift`, change `shields.apply(store.selection)` to `shields.apply(store.activeShieldPlan)`.

In `Shared/SharedStore.swift`, delete the `selection` property and remove `selection` from `Key`'s first `case` line (it becomes `case session, pairedTags, passesLeft, relockStrategy, log`). An old stored value is ignored.

In `Tapout/Engine/LockEngine.swift`: delete `private(set) var selection = FamilyActivitySelection()`, the `selection = store.selection` line in `reload()`, and `updateSelection(_:)`. Change both `shields.apply(store.selection)` calls (in `handleTag` and `relockNow`) to `shields.apply(store.activeShieldPlan)`. Remove `import FamilyControls` if nothing else in the file needs it.

In `Tapout/Features/Lab/LabView.swift`: delete `appsSection` (the property and its use in the `List`), `@State private var picking`, and the `.familyActivityPicker(...)` modifier.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 191 tests; device exit 0. `grep -rn "store.selection\|updateSelection" Tapout Shared TapoutMonitor TapoutTests` finds nothing.

- [ ] **Step 5: Suggested commit message:** `Shield the active mode's apps minus always-allowed, everywhere`

---

### Task 4: LockEngine becomes the app's lock

**Files:**
- Modify: `Tapout/Engine/LockEngine.swift` (rewrite), `Tapout/Features/Lab/LabView.swift` (rewrite)
- Create: `Tapout/Engine/SimulatorStandIns.swift`
- Test: `TapoutTests/LockEngineTests.swift` (rewrite)

**Interfaces:**
- Consumes: Task 3's `Shielding`, `SharedStore.activeShieldPlan`.
- Produces (used by Task 5): `LockEngine.lock()`, `LockEngine.unlock()`, `LockEngine.syncShields()`, `@discardableResult LockEngine.useEmergencyPass() throws -> Date` (the relock time), `LockEngine.relockNow()`, `@discardableResult LockEngine.tick() -> Bool`, `LockEngine.live(store: SharedStore = .appGroup())`, `session`, `passesLeft`, `relockStrategy`, `log`, `setRelockStrategy(_:)`, `reload()`, DEBUG `resetPasses()` and `clearLog()`, `static let emergencyDuration`. `struct NoShields: Shielding`, `struct NoRelock: RelockScheduling`.
- Removes: `pair`, `unpair`, `pairedTags`, `handleTag`, `TagOutcome`. Places live in `AppModel`.

- [ ] **Step 1: Write the failing tests.** Replace `TapoutTests/LockEngineTests.swift` with:

```swift
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

    private func makeEngine() -> LockEngine {
        LockEngine(store: store, shields: shields, relock: relock, now: { [clock] in clock.now })
    }

    private func lockedEngine() -> LockEngine {
        let engine = makeEngine()
        engine.lock()
        return engine
    }

    @Test func freshEngineIsUnlockedWithFivePasses() {
        let engine = makeEngine()
        #expect(engine.session == .unlocked)
        #expect(engine.passesLeft == 5)
    }

    @Test func lockShieldsTheActivePlanAndStartsTheLock() {
        let engine = lockedEngine()
        #expect(engine.session == .locked(since: clock.now))
        #expect(shields.plans == [store.activeShieldPlan])
    }

    @Test func lockingAgainChangesNothing() {
        let engine = lockedEngine()
        let since = clock.now
        clock.now += 60
        engine.lock()
        #expect(engine.session == .locked(since: since))
        #expect(shields.applied == 1)
    }

    @Test func unlockClearsEverything() {
        let engine = lockedEngine()
        engine.unlock()
        #expect(engine.session == .unlocked)
        #expect(shields.cleared == 1)
        #expect(relock.cancelled == 1)
    }

    @Test func unlockingWhileUnlockedChangesNothing() {
        makeEngine().unlock()
        #expect(shields.cleared == 0)
        #expect(relock.cancelled == 0)
    }

    @Test func emergencyPassSpendsOneOpensAppsAndSchedulesRelock() throws {
        let engine = lockedEngine()
        let relockAt = try engine.useEmergencyPass()
        #expect(relockAt == clock.now + 300)
        #expect(engine.passesLeft == 4)
        #expect(shields.cleared == 1)
        #expect(engine.session == .emergency(relockAt: clock.now + 300, duration: 300))
        #expect(relock.scheduled == [.init(relockAt: clock.now + 300, now: clock.now, strategy: .warning)])
    }

    @Test func emergencyPassLogsWhatWasScheduled() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(engine.log.last?.message == "Scheduled: fake schedule")
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
        // The monitor schedule stays running, so its callback still shows up in the log.
        #expect(relock.cancelled == 0)
    }

    @Test func tickPicksUpARelockMadeByTheMonitor() throws {
        let engine = lockedEngine()
        let relockAt = clock.now + 300
        try engine.useEmergencyPass()
        _ = EmergencyRelock.perform(store: store, shields: FakeShields(), now: relockAt)
        #expect(!engine.tick())
        #expect(engine.session == .locked(since: relockAt))
    }

    @Test func unlockingDuringAPassCancelsTheRelock() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        engine.unlock()
        #expect(engine.session == .unlocked)
        #expect(relock.cancelled == 1)
    }

    @Test func syncShieldsPutsASurvivingLockBack() {
        store.session = .locked(since: clock.now)
        makeEngine().syncShields()
        #expect(shields.plans == [store.activeShieldPlan])
    }

    @Test func syncShieldsClearsWhenUnlocked() {
        makeEngine().syncShields()
        #expect(shields.cleared == 1)
    }

    @Test func syncShieldsLeavesAnOpenPassAlone() {
        store.session = .emergency(relockAt: clock.now + 100, duration: 300)
        makeEngine().syncShields()
        #expect(shields.applied == 0)
        #expect(shields.cleared == 0)
    }

    @Test func stateSurvivesANewEngine() {
        _ = lockedEngine()
        #expect(makeEngine().session == .locked(since: clock.now))
    }

    @Test func actionsAreLogged() {
        let engine = lockedEngine()
        engine.unlock()
        #expect(engine.log.map(\.message) == ["Locked", "Unlocked"])
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`lock()` doesn't exist).

- [ ] **Step 3: Implement.** Create `Tapout/Engine/SimulatorStandIns.swift`:

```swift
import Foundation

/// Stand-ins for the simulator and previews, where Screen Time shields and DeviceActivity don't run.
/// The app's own clock still relocks an expired pass.
struct NoShields: Shielding {
    func apply(_ plan: ShieldPlan) {}
    func clear() {}
}

struct NoRelock: RelockScheduling {
    func schedule(relockAt: Date, now: Date, strategy: RelockStrategy) throws {}
    func cancel() {}
    func scheduledSummary() -> String { "none (simulator)" }
}
```

Replace `Tapout/Engine/LockEngine.swift` with:

```swift
import Foundation
import Observation

/// The real lock: shields, emergency passes and relock, kept in the App Group store, so the monitor
/// extension can relock while Tapout is closed and a lock survives quitting and restarts.
/// Which tags may lock or unlock is `AppModel.check`'s job; the engine trusts its caller.
@MainActor
@Observable
final class LockEngine {
    enum PassError: Error, Equatable {
        case notLocked, noPassesLeft
        case couldNotSchedule(String)
    }

    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60

    private(set) var session: LockSession = .unlocked
    private(set) var passesLeft = SharedStore.totalPasses
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

    /// Screen Time on an iPhone; stand-ins in the simulator, where shields and DeviceActivity don't run.
    static func live(store: SharedStore = .appGroup()) -> LockEngine {
        #if targetEnvironment(simulator)
        LockEngine(store: store, shields: NoShields(), relock: NoRelock())
        #else
        LockEngine(store: store, shields: ShieldController(), relock: RelockScheduler())
        #endif
    }

    /// Re-reads the store. The monitor extension may have relocked while Tapout was in the background.
    func reload() {
        session = store.session
        passesLeft = store.passesLeft
        relockStrategy = store.relockStrategy
        log = store.log
    }

    func setRelockStrategy(_ strategy: RelockStrategy) {
        store.relockStrategy = strategy
        reload()
    }

    /// Starts a lock and shields the active mode's apps. Does nothing while locked.
    /// The lock state is written first: if Tapout dies before the shields go on, `syncShields` at the
    /// next launch puts them on.
    func lock() {
        guard store.session == .unlocked else { return }
        store.session = .locked(since: now())
        shields.apply(store.activeShieldPlan)
        record("Locked")
    }

    /// Ends the lock and any open pass. Does nothing while unlocked.
    func unlock() {
        guard store.session != .unlocked else { return }
        relock.cancel()
        shields.clear()
        store.session = .unlocked
        record("Unlocked")
    }

    /// Makes the shields match the lock state: back on at launch for a lock that survived a quit or
    /// restart, off when unlocked, and back on after Screen Time access returns. An open pass is
    /// left alone; the clock or the monitor relocks it.
    func syncShields() {
        switch store.session {
        case .locked: shields.apply(store.activeShieldPlan)
        case .unlocked: shields.clear()
        case .emergency: break
        }
    }

    /// Spends one pass and opens apps for five minutes; returns the relock time. The pass is only spent
    /// once the relock is scheduled, so a scheduling failure never leaves apps open for good.
    @discardableResult
    func useEmergencyPass() throws -> Date {
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
        // Session first: if the process dies before the shields drop, the monitor still sees an open pass
        // and re-shields at the relock time.
        store.session = .emergency(relockAt: relockAt, duration: Self.emergencyDuration)
        shields.clear()
        record("Emergency pass, relock at \(relockAt.formatted(date: .omitted, time: .standard)) via \(strategy.rawValue)")
        record("Scheduled: \(relock.scheduledSummary())")
        return relockAt
    }

    /// Ends an emergency pass early.
    func relockNow() {
        guard case .emergency = store.session else { return }
        relock.cancel()
        shields.apply(store.activeShieldPlan)
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

Replace `Tapout/Features/Lab/LabView.swift` with (DEBUG-only status page; it no longer pairs, scans or spends passes, because those would bypass `AppModel`):

```swift
#if DEBUG
import FamilyControls
import SwiftUI

/// DEBUG-only status page for device runs: Screen Time access, the App Group, the lock, passes,
/// the relock strategy, and the log shared with the monitor extension.
/// Not a designed screen; it uses plain system list styling.
struct LabView: View {
    @State private var engine = LockEngine.live()
    @ObservedObject private var center = AuthorizationCenter.shared

    var body: some View {
        NavigationStack {
            List {
                accessSection
                sessionSection
                logSection
            }
            .navigationTitle("Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await refresh() }
    }

    // MARK: Sections

    private var accessSection: some View {
        Section("Screen Time") {
            LabeledContent("Access", value: accessText)
            LabeledContent("App Group", value: SharedStore.isAppGroupAvailable ? "OK" : "Missing")
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

    /// The app's own engine runs the lock; this one only reads the store.
    private func refresh() async {
        while !Task.isCancelled {
            engine.reload()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    // MARK: Text

    private var accessText: String {
        switch center.authorizationStatus {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .notDetermined: return "Not asked"
        default:
            if #available(iOS 26.4, *), center.authorizationStatus == .approvedWithDataAccess { return "Approved" }
            return "Unknown"
        }
    }

    private func stateText(at date: Date) -> String {
        switch engine.session {
        case .unlocked: "Unlocked"
        case .locked: "Locked \(TimeFormat.clock(engine.session.elapsed(at: date)))"
        case .emergency: "Open, relocks in \(TimeFormat.clock(engine.session.remaining(at: date)))"
        }
    }
}
#endif
```

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 194 tests; device exit 0. `MockLockController` still drives the app until Task 5.

- [ ] **Step 5: Suggested commit message:** `Reshape LockEngine into the app's lock and slim the Lab`

---

### Task 5: The app runs on LockEngine

**Files:**
- Modify: `Tapout/App/TapoutApp.swift`, `Tapout/App/RootView.swift`, `Tapout/Features/Home/HomeView.swift`, `Tapout/Features/EmergencyPass/EmergencyPassView.swift:40`
- Create: `Tapout/Engine/LockEngine+Debug.swift`, `TapoutTests/LockEngineDebugTests.swift`
- Delete: `Tapout/Model/MockLockController.swift`, `TapoutTests/MockLockControllerTests.swift`

**Interfaces:**
- Consumes: Task 2 (`startPass(until:)`, `endPass()`, `runningLockTime(at:)`, `reconcile(with:)`) and Task 4 (`LockEngine` API, `NoShields`, `NoRelock`).
- Produces: DEBUG `LockEngine.fromLaunchArguments(_:store:)`, DEBUG `LockEngine.preview(session:passesLeft:)`; `RootView(engine:model:)`; `HomeView(engine:model:intentionDraft:onScan:onEmergencyPass:onOpenSettings:)`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/LockEngineDebugTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct LockEngineDebugTests {
    private let store = SharedStore.makeTest()

    @Test func withoutArgumentsItReadsTheStore() {
        let since = Date(timeIntervalSinceReferenceDate: 800_000_000)
        store.session = .locked(since: since)
        #expect(LockEngine.fromLaunchArguments([], store: store).session == .locked(since: since))
    }

    @Test func mockLockedWritesALock() {
        let engine = LockEngine.fromLaunchArguments(["-mockState", "locked"], store: store)
        guard case .locked = store.session else {
            Issue.record("store not locked")
            return
        }
        #expect(engine.session == store.session)
    }

    @Test func mockEmergencyLeavesTheStoreAlone() {
        let engine = LockEngine.fromLaunchArguments(["-mockState", "emergency"], store: store)
        #expect(engine.passesLeft == 2)
        #expect(store.passesLeft == 5)
        #expect(store.session == .unlocked)
    }

    @Test func previewStartsWhereItIsTold() {
        let since = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let engine = LockEngine.preview(session: .locked(since: since), passesLeft: 3)
        #expect(engine.session == .locked(since: since))
        #expect(engine.passesLeft == 3)
    }
}
```

Delete `TapoutTests/MockLockControllerTests.swift`.

- [ ] **Step 2: Run the tests.** Expected: the build fails (`fromLaunchArguments` doesn't exist on `LockEngine`).

- [ ] **Step 3: Add the DEBUG helpers.** Create `Tapout/Engine/LockEngine+Debug.swift`:

```swift
#if DEBUG
import Foundation

extension LockEngine {
    /// `-mockState locked|emergency` starts in that state, for screenshots. `locked` writes the
    /// App Group like a real lock; `emergency` runs on a scratch store, so it can't spend a real pass.
    static func fromLaunchArguments(
        _ arguments: [String] = ProcessInfo.processInfo.arguments,
        store: SharedStore = .appGroup()
    ) -> LockEngine {
        guard let index = arguments.firstIndex(of: "-mockState"), index + 1 < arguments.count else {
            return live(store: store)
        }
        let now = Date()
        switch arguments[index + 1] {
        case "locked":
            store.session = .locked(since: now - (47 * 60 + 12))
            return live(store: store)
        case "emergency":
            return preview(session: .emergency(relockAt: now + (4 * 60 + 32), duration: emergencyDuration), passesLeft: 2)
        default:
            return live(store: store)
        }
    }

    /// An engine on a scratch store with no Screen Time, for `#Preview`s.
    static func preview(session: LockSession = .unlocked, passesLeft: Int = SharedStore.totalPasses) -> LockEngine {
        let store = SharedStore(defaults: UserDefaults(suiteName: "tapout.preview.\(UUID().uuidString)")!)
        store.session = session
        store.passesLeft = passesLeft
        return LockEngine(store: store, shields: NoShields(), relock: NoRelock())
    }
}
#endif
```

- [ ] **Step 4: Swap the app.** `Tapout/App/TapoutApp.swift` becomes:

```swift
import SwiftUI

@main
struct TapoutApp: App {
    // State, so a body re-evaluation can't rebuild the model (and re-run -demoData seeding).
    // The model comes first: -demoData seeds the passes the engine reads.
    #if DEBUG
    @State private var model = AppModel.fromLaunchArguments()
    @State private var engine = LockEngine.fromLaunchArguments()
    #else
    @State private var model = AppModel.live()
    @State private var engine = LockEngine.live()
    #endif

    var body: some Scene {
        WindowGroup {
            RootView(engine: engine, model: model)
        }
    }
}
```

In `Tapout/App/RootView.swift`:
- `@State private var controller: MockLockController` → `@State private var engine: LockEngine`.
- The init becomes:

```swift
    init(engine: LockEngine, model: AppModel) {
        _engine = State(initialValue: engine)
        _model = State(initialValue: model)
    }
```

- Replace every remaining `controller.session` with `engine.session` and `controller.passesLeft` with `engine.passesLeft` (body, Settings destination, `scan()`, `showMilestone()`).
- In `screen`, pass `engine: engine` instead of `controller: controller` to `HomeView`.
- The `.emergencyPass` cover case becomes:

```swift
            case .emergencyPass:
                EmergencyPassView(passesLeft: engine.passesLeft) {
                    do {
                        let relockAt = try withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) {
                            try engine.useEmergencyPass()
                        }
                        model.startPass(until: relockAt)
                        return true
                    } catch {
                        return false
                    }
                }
```

- The `.task` becomes:

```swift
        .task {
            // The lock state is the truth: it survives quitting, and the monitor can relock while Tapout is closed.
            engine.syncShields()
            model.reconcile(with: engine.session)
            await runClock()
        }
```

- In `lock(at:)`, replace `controller.simulateTagRead()` with `engine.lock()`.
- In `unlock()`, replace `withAnimation(...) { controller.simulateTagRead() }` with `withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { engine.unlock() }`.
- In `runClock()`, replace the three `controller` uses:

```swift
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            let relocked = withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { engine.tick() }
            if relocked { Haptics.lock() }
        }
    }
```

In `Tapout/Features/Home/HomeView.swift`:
- `let controller: MockLockController` → `let engine: LockEngine`; replace every `controller.` with `engine.`.
- In `locked(at:)`, the first line becomes:

```swift
        // Without pass time. The record can be a moment behind the lock state at launch, and previews have none.
        let elapsed = model.runningLockTime(at: date) ?? engine.session.elapsed(at: date)
```

- In `emergency(at:)`, `MockLockController.totalPasses` → `SharedStore.totalPasses`.
- `relockNow()` becomes:

```swift
    private func relockNow() {
        Haptics.lock()
        withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { engine.relockNow() }
        model.endPass()
    }
```

- Previews: replace `RootView(model:` with `RootView(engine: .preview(), model:`; replace `RootView(controller: MockLockController(` with `RootView(engine: .preview(`. The argument lists stay the same (`session:` and `passesLeft:`).

In `Tapout/Features/EmergencyPass/EmergencyPassView.swift:40`, `MockLockController.emergencyDuration` → `LockEngine.emergencyDuration`.

Delete `Tapout/Model/MockLockController.swift`.

- [ ] **Step 5: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 184 tests; device exit 0. `grep -rn "MockLockController\|simulateTagRead" Tapout TapoutTests` finds nothing.

- [ ] **Step 6: Check the simulator.** Install and launch with `-demoData` (iPhone 17, id `33A5EBE9-5D77-488C-85C0-FDBC419C7ECE`; tap points: Scan (201, 723), locked orb (201, 319), emergency link (201, 730), hold centre (201, 468), Relock now (201, 723)).
  - Lock, wait 20 s, use a pass (hold 11 s), tap Relock now. Expected: the locked timer carries on from about 0:20, not 0:00.
  - With the app locked, `xcrun simctl terminate` then relaunch. Expected: still locked, and the timer has kept counting.
  - Unlock. Expected: the "Did you do it?" flow is unchanged.

- [ ] **Step 7: Suggested commit message:** `Run the app on LockEngine; remove MockLockController`

---

### Task 6: Passes survive reinstalling

**Files:**
- Create: `Tapout/Engine/PassVault.swift`, `TapoutTests/PassVaultTests.swift`
- Modify: `Tapout/Engine/LockEngine.swift`, `Tapout/Engine/LockEngine+Debug.swift`
- Test: `TapoutTests/LockEngineTests.swift`

**Interfaces:**
- Consumes: Task 4's `LockEngine`.
- Produces: `protocol PassCounting { func used() -> Int; func setUsed(_ count: Int) }`, `struct KeychainPassVault: PassCounting` (`var service`, DEBUG `delete()`), `final class MemoryPassVault: PassCounting` (`init(used: Int = 0)`); `LockEngine.init(store:shields:relock:passes: any PassCounting = MemoryPassVault(), now:)`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/PassVaultTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

struct PassVaultTests {
    @Test func keychainStartsAtZeroAndKeepsTheCount() {
        let vault = KeychainPassVault(service: "com.raphymuthu.tapout.tests.\(UUID().uuidString)")
        defer { vault.delete() }
        #expect(vault.used() == 0)
        vault.setUsed(2)
        #expect(vault.used() == 2)
        vault.setUsed(3)
        #expect(KeychainPassVault(service: vault.service).used() == 3)
    }
}
```

In `TapoutTests/LockEngineTests.swift`, add `private let vault = MemoryPassVault()` beside the other properties, change `makeEngine()` to pass `passes: vault` (`LockEngine(store: store, shields: shields, relock: relock, passes: vault, now: { [clock] in clock.now })`), and add:

```swift
    @Test func theKeychainCountWinsWhenTheStoreForgets() {
        vault.setUsed(2)
        #expect(makeEngine().passesLeft == 3)
    }

    @Test func theStoreCountWinsWhenTheKeychainForgets() {
        store.passesLeft = 1
        #expect(makeEngine().passesLeft == 1)
    }

    @Test func spendingAPassWritesBoth() throws {
        let engine = lockedEngine()
        try engine.useEmergencyPass()
        #expect(store.passesLeft == 4)
        #expect(vault.used() == 1)
    }

    @Test func aFailedScheduleWritesNeither() {
        let engine = lockedEngine()
        relock.failure = FakeError()
        _ = try? engine.useEmergencyPass()
        #expect(store.passesLeft == 5)
        #expect(vault.used() == 0)
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`MemoryPassVault` doesn't exist).

- [ ] **Step 3: Implement.** Create `Tapout/Engine/PassVault.swift`:

```swift
import Foundation
import Security

/// A second count of spent passes, beside the App Group. The Keychain outlives deleting the app,
/// so reinstalling doesn't refill passes. The item is this-device-only, so a new iPhone starts fresh.
protocol PassCounting {
    /// Passes spent so far, ever. Zero when nothing is stored.
    func used() -> Int
    func setUsed(_ count: Int)
}

struct KeychainPassVault: PassCounting {
    var service = "com.raphymuthu.tapout.passes"
    private let account = "used"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func used() -> Int {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let count = Int(String(decoding: data, as: UTF8.self))
        else { return 0 }
        return count
    }

    func setUsed(_ count: Int) {
        let data = Data(String(count).utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    #if DEBUG
    func delete() {
        SecItemDelete(query as CFDictionary)
    }
    #endif
}

/// In memory, for previews and tests.
final class MemoryPassVault: PassCounting {
    private var count: Int

    init(used: Int = 0) {
        count = used
    }

    func used() -> Int { count }
    func setUsed(_ count: Int) { self.count = count }
}
```

In `Tapout/Engine/LockEngine.swift`:
- Add `@ObservationIgnored private let passes: any PassCounting` and the init parameter `passes: any PassCounting = MemoryPassVault(),` after `relock:`; assign it.
- `live(store:)` passes `passes: KeychainPassVault()` in both branches.
- In `reload()`, `passesLeft = store.passesLeft` becomes `passesLeft = currentPassesLeft`, and add:

```swift
    /// The lower of the two counts, so losing either one never refills a pass.
    private var currentPassesLeft: Int {
        max(0, min(store.passesLeft, SharedStore.totalPasses - passes.used()))
    }
```

- In `useEmergencyPass()`, `guard store.passesLeft > 0` becomes `guard currentPassesLeft > 0`, and `store.passesLeft -= 1` becomes:

```swift
        let left = currentPassesLeft - 1
        store.passesLeft = left
        passes.setUsed(SharedStore.totalPasses - left)
```

- DEBUG `resetPasses()` also calls `passes.setUsed(0)`.

In `Tapout/Engine/LockEngine+Debug.swift`, `preview(...)` passes `passes: MemoryPassVault()`.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 189 tests; device exit 0. If the Keychain test fails with `errSecMissingEntitlement` (-34018), stop and report: the test host has lost its Keychain access.

- [ ] **Step 5: Suggested commit message:** `Count spent passes in the Keychain so reinstalling doesn't refill them`

---

### Task 7: The Sealed block screen

**Files:**
- Modify: `project.yml`
- Create: `TapoutShield/ShieldConfigurationExtension.swift` (XcodeGen writes `TapoutShield/Info.plist` and `TapoutShield/TapoutShield.entitlements`)

**Interfaces:**
- Consumes: the colour assets in `Tapout/DesignSystem/Colors.xcassets` (`bg`, `ink`, `ink-secondary`, `ember`, `surface-2`).
- Produces: the `TapoutShield` app extension, embedded in the app.

- [ ] **Step 1: Add the target.** In `project.yml`, add to the `Tapout` target's `dependencies` (after `- target: TapoutMonitor`):

```yaml
      - target: TapoutShield
```

and add this target after `TapoutMonitor`:

```yaml
  TapoutShield:
    type: app-extension
    platform: iOS
    sources:
      - path: TapoutShield
      - path: Tapout/DesignSystem/Colors.xcassets
    info:
      path: TapoutShield/Info.plist
      properties:
        CFBundleDisplayName: Tapout Shield
        NSExtension:
          NSExtensionPointIdentifier: com.apple.ManagedSettingsUI.shield-configuration-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShieldConfigurationExtension
    entitlements:
      path: TapoutShield/TapoutShield.entitlements
      properties:
        com.apple.developer.family-controls: true
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout.shield
        TARGETED_DEVICE_FAMILY: "1"
```

- [ ] **Step 2: Write the extension.** Create `TapoutShield/ShieldConfigurationExtension.swift`:

```swift
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The block screen from design/screens/Block.dc.html: a sealed ember orb, "Sealed" and
/// "Tap a tag to open this app.", dark only. iOS shows a button whatever the design says, so it is a
/// quiet Close. The system font is the only one a shield can use.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        SealedShield.configuration
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        SealedShield.configuration
    }
}

enum SealedShield {
    static var configuration: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: color("bg"),
            icon: orb,
            title: ShieldConfiguration.Label(text: "Sealed", color: color("ink")),
            subtitle: ShieldConfiguration.Label(text: "Tap a tag to open this app.", color: color("ink-secondary")),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Close", color: color("ink")),
            primaryButtonBackgroundColor: color("surface-2"),
            secondaryButtonLabel: nil
        )
    }

    /// The spec's 120pt orb: an ember ring, a faint halo, the solid orb and its highlight.
    private static var orb: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            let cg = context.cgContext
            let ember = color("ember")
            cg.setStrokeColor(ember.cgColor)
            cg.setLineWidth(3)
            cg.strokeEllipse(in: CGRect(x: 6, y: 6, width: 108, height: 108))
            cg.setFillColor(ember.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(in: CGRect(x: 20, y: 20, width: 80, height: 80))
            cg.setFillColor(ember.cgColor)
            cg.fillEllipse(in: CGRect(x: 30, y: 30, width: 60, height: 60))
            cg.setFillColor(color("ink").withAlphaComponent(0.85).cgColor)
            cg.fillEllipse(in: CGRect(x: 42, y: 43, width: 18, height: 12))
        }
    }

    private static let dark = UITraitCollection(userInterfaceStyle: .dark)

    /// A design-system colour from this extension's asset catalog, always in its dark appearance.
    private static func color(_ name: String) -> UIColor {
        (UIColor(named: name, in: .main, compatibleWith: dark) ?? .gray).resolvedColor(with: dark)
    }
}
```

- [ ] **Step 3: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 189 tests; device exit 0. The device build signs `com.raphymuthu.tapout.shield` with the Family Controls development entitlement (automatic signing registers the new App ID). If signing fails, report the exact error; the user may need to open Signing & Capabilities once.

- [ ] **Step 4: Suggested commit message:** `Add the Sealed block screen extension`

---

### Task 8: Catch lost Screen Time access

**Files:**
- Modify: `Tapout/Engine/ScreenTimeAccess.swift`, `Tapout/Features/Onboarding/OnboardingView.swift:139` (make `ScrollsWhenTall` internal), `Tapout/App/RootView.swift`
- Create: `Tapout/Features/Onboarding/ScreenTimeAgainView.swift`
- Test: `TapoutTests/ScreenTimeAccessTests.swift`

**Interfaces:**
- Consumes: `ScreenTimeAccess.request()` and `Outcome`, `ScreenTimeStep`, `ScrollsWhenTall`, `PrimaryButton`, Task 4's `syncShields()`.
- Produces: `@MainActor ScreenTimeAccess.isApproved: Bool`; `ScreenTimeAgainView(onGranted:)`.

- [ ] **Step 1: Write the failing test.** Add inside `struct ScreenTimeAccessTests`:

```swift
    @MainActor @Test func theSimulatorCountsAsApproved() {
        #expect(ScreenTimeAccess.isApproved)
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`isApproved` doesn't exist).

- [ ] **Step 3: Implement.** Add to `enum ScreenTimeAccess`:

```swift
    /// Whether Tapout may shield apps right now; access can be turned off in Settings at any time.
    /// The simulator counts as approved, unless launched with -mockScreenTimeRevoked.
    @MainActor static var isApproved: Bool {
        #if targetEnvironment(simulator)
        return !ProcessInfo.processInfo.arguments.contains("-mockScreenTimeRevoked")
        #else
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved { return true }
        if #available(iOS 26.4, *) { return status == .approvedWithDataAccess }
        return false
        #endif
    }
```

In `Tapout/Features/Onboarding/OnboardingView.swift`, change `private struct ScrollsWhenTall` to `struct ScrollsWhenTall` and give it a doc comment: `/// Scrolls only when the content is taller than the space, as at the largest text sizes.`

Create `Tapout/Features/Onboarding/ScreenTimeAgainView.swift`:

```swift
import SwiftUI

/// Shown over everything when Screen Time access was turned off after onboarding: onboarding's
/// step 2 without the dots. Locks can't shield anything until access is back.
struct ScreenTimeAgainView: View {
    let onGranted: () -> Void

    @State private var outcome: ScreenTimeAccess.Outcome?
    @State private var requesting = false

    var body: some View {
        VStack(spacing: Space.lg) {
            ScrollsWhenTall { ScreenTimeStep() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: Space.md) {
                if let message = outcome?.message {
                    Text(message)
                        .font(.tFootnote)
                        .foregroundStyle(Color.danger)
                        .multilineTextAlignment(.center)
                }
                PrimaryButton(title: "Allow") { Task { await allow() } }
                if outcome?.offersSettings == true {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.tBody)
                            .foregroundStyle(Color.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, .for(.unlocked))
    }

    private func allow() async {
        guard !requesting else { return }
        requesting = true
        defer { requesting = false }
        let result = await ScreenTimeAccess.request()
        outcome = result
        if result == .granted { onGranted() }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Screen Time again · dark") {
    ScreenTimeAgainView {}.preferredColorScheme(.dark)
}

#Preview("Screen Time again · light") {
    ScreenTimeAgainView {}.preferredColorScheme(.light)
}
```

In `Tapout/App/RootView.swift`:
- Add `@State private var screenTimeNeeded = false` and `@Environment(\.scenePhase) private var scenePhase`.
- After the onboarding `.background { ... }` block, add:

```swift
        // Its own host too, for the same reason. It needs onboarding done, so the two never overlap.
        .background {
            Color.clear.fullScreenCover(isPresented: $screenTimeNeeded) {
                ScreenTimeAgainView {
                    screenTimeNeeded = false
                    engine.syncShields()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkScreenTime() }
        }
```

- In `.task`, call `checkScreenTime()` after `model.reconcile(with: engine.session)`.
- Add:

```swift
    /// Screen Time access can be turned off in Settings; until it's back, nothing can be shielded.
    private func checkScreenTime() {
        screenTimeNeeded = hasOnboarded && !ScreenTimeAccess.isApproved
    }
```

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 190 tests; device exit 0.

- [ ] **Step 5: Check the simulator.** Launch with `-skipOnboarding -mockScreenTimeRevoked`. Expected: the Screen Time page over Home; Allow dismisses it. Launch with `-skipOnboarding -mockScreenTimeRevoked -mockScreenTimeDenied`. Expected: the declined message and Open Settings, and the page stays.

- [ ] **Step 6: Suggested commit message:** `Ask for Screen Time again when access was turned off`

---

### Task 9: Verify

- [ ] **Step 1:** Run the build/test command, the device compile check, and the device check with `-configuration Release -derivedDataPath <scratch>`. Expected: 204 tests, no warnings from `Tapout/`, `Shared/`, `TapoutTests/`, `TapoutMonitor/` or `TapoutShield/`, all exits 0.
- [ ] **Step 2: Simulator, dark and light.** Fresh install, onboarding, lock, unlock with an intention, milestone; emergency pass then Relock now (the timer carries on); force quit while locked (still locked after relaunch); Insights leaves out pass time (lock with `-demoData`, use a pass, wait for the relock, unlock, then compare totals); the Screen Time page with `-mockScreenTimeRevoked`. Save contact sheets as `docs/superpowers/verification/phase4a-*.png`.
- [ ] **Step 3: iPhone run (the user's; give these steps exactly).** Install with `xcrun devicectl device install app --device 00008140-000A28340E29401C build/device/Build/Products/Debug-iphoneos/Tapout.app`. In Settings → Lab, tap Reset passes first: old Phase 2 data may hold a lower count.
  0. In Xcode, open the project, select the TapoutShield target, Signing & Capabilities, and let it create a profile (your account must be signed in). Then run the device build; it must exit 0.
  1. In Modes, give the active mode a whole category (for example Social) and one single app (for example a game). In Always allowed, add one app inside that category (for example WhatsApp or Messages).
  2. Lock with your tag. Open an app from the blocked category and the single app: both show the Sealed screen (orb, "Sealed", "Tap a tag to open this app.", Close). Note whether the orb looks crisp and what Close does. Open the always-allowed app: it opens.
  3. Force quit Tapout, then open a blocked app: still Sealed. Reopen Tapout: locked, and the timer kept counting.
  4. Restart the iPhone: blocked apps are still Sealed.
  5. Use an emergency pass: blocked apps open. Leave Tapout closed for 5 minutes, then open a blocked app: Sealed again. Open Tapout: the timer is about 5 minutes behind the time since you locked. Within 10 minutes of that first pass, use a second pass: apps must stay open for the full 5 minutes (not close at once). Lab's log shows the monitor's relock lines.
  6. Unlock with your tag: blocked apps open.
  7. Note the pass count, delete Tapout, reinstall, finish onboarding: the same pass count.
  8. Turn off Tapout's Screen Time access in iOS Settings, then switch back to Tapout without quitting: the Screen Time page appears. Note whether blocked apps opened while access was off. Tap Allow (or use Open Settings if iOS doesn't ask again): Home returns and blocked apps are Sealed again. Repeat with a force quit instead of switching back.
  9. With access on, a cold launch never flashes the Screen Time page.
  10. Report each result, plus anything that looked or felt wrong (the lock moment against the NFC sheet, haptics, the milestone cover against the unlock).
- [ ] **Step 4:** Report, leaving all changes uncommitted, with the suggested message `Phase 4A: real locking`.

## Notes for 4B (from this plan)

- Schedules never unlock: `intervalDidEnd` does nothing. `intervalDidStart` locks only when unlocked: it makes the scheduled mode active, writes the record, sets `.locked(since:)` and applies the plan.
- The monitor has no `AppModel`, so lock-record writing (`startLock`, `finishLock`, `startPass`, `endPass`, `reconcile`) should move into `Shared/` as functions over `SharedStore`, with `AppModel` calling them.
- DeviceActivity's activity limit (about 20; check the current docs) suggests one daily activity per scheduled mode, with the weekday checked in the monitor.
- The Family Controls **distribution** request must cover three bundle IDs: the app, `.monitor` and `.shield`.
- If Close on the Sealed screen doesn't close on the iPhone, add a `ShieldAction` extension (a fourth bundle ID for the request).
- State goes stale: AppModel and LockEngine only re-read on their own writes and `tick`. Once the monitor can lock, AppModel needs `reload()` and `reconcile` on every foreground and whenever `engine.session` changes.
- Scan race: `unlocking` is computed before the NFC wait, and `lock(at:)` calls `model.startLock` even if `engine.lock()` did nothing; `startLock` → `discardInterruptedLocks` would delete a monitor-started record. Make `engine.lock()` return Bool and re-read state after the scan.
- Cross-process writes: the app and the monitor would both read-modify-write `lockHistory`; use one writer or a coordinated write.
- `.locked(since:)` isn't the lock start after a relock; only use it to create a missing record.
- The monitor must route by activity name; `tapout.emergency`'s callbacks still relock; the relock activity counts toward the activity limit; `.emergency` counts as already locked in `intervalDidStart`.
- Register activities from `completeOnboarding` as well as Modes' save, and re-register at launch (activities don't survive a reinstall).
- "Changes while locked apply to the next window" conflicts with the read-only mode editor while locked: allow schedule edits while locked, or drop that line.
- Owner decisions: what a scheduled start does when Screen Time access is off or the mode has no apps (an empty plan fails open today). Whether locked time should keep counting while access is off.
- Carried over: a crash between `engine.unlock` and `finishLock` drops that record (fix when record writing moves to `Shared/`); the monitor-mid-unlock race (covered in 4A by the foreground sync) widens once `intervalDidStart` locks.
- ManagedSettings caps shielded app tokens (about 50); a mode over the cap may not shield. Check and guard.
