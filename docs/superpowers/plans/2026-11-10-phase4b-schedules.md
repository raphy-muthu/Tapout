# Phase 4B: Mode Schedules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A mode with a schedule locks by itself when its window starts, even with Tapout closed, and says so with a quiet notification. It never unlocks by itself; a tag does. A window it can't lock (no apps, or Screen Time off) is skipped with a notification saying why.

**Architecture:** Each scheduled mode gets one daily DeviceActivity activity (`tapout.mode.<uuid>`). The monitor extension's `intervalDidStart` asks a pure `ScheduledLock.decide` whether to lock (right weekday, unlocked, not unlocked or saved during this window, Screen Time on, apps chosen), then makes the mode active, writes `.locked(since:)` and applies the shields. Only the app writes lock records: the app's `reconcile` adds the record when it next sees the lock state change. `AppModel` keeps the activities in step with the modes through a `ScheduleRegistering` dependency.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XcodeGen, DeviceActivity, ManagedSettings, FamilyControls, UserNotifications. iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-08-phase4-design.md`, sections "4B: schedules" and "4A behaviour". Read them first.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor `com.raphymuthu.tapout.monitor`, shield `com.raphymuthu.tapout.shield`. App Group `group.com.raphymuthu.tapout`.
- **Schedules only lock. Nothing in this phase unlocks.** A tag unlock during a window holds until the next window.
- At most 19 mode activities (one of DeviceActivity's slots stays free for `tapout.emergency`).
- Only the app writes `lockHistory`. The monitor writes `session`, `activeModeID` and the log.
- Notification copy, exactly: title = the mode's name; body "Locked until you tap a tag.", "Didn't lock: no apps chosen.", "Didn't lock: Screen Time is off." or "Didn't lock: no tag paired."
- Copy rules: very few words, no guilt or shame, no emoji, no exclamation marks.
- `Shared/` stays free of SwiftUI (it compiles into the monitor extension).
- Colours only through asset-catalog tokens; 44pt targets with the frame and `contentShape` inside the label.
- **Never commit, stage or stash.** The user commits manually; each task ends with a suggested commit message.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

**Device compile check** (exit code must be 0; don't pipe it). Use the signed command once the owner has created the TapoutShield profile; until then the unsigned one:

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates build -quiet; echo "exit $?"
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device-nosign CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
```

**Test count chain:** 204 → 213 (Task 1) → 225 (Task 2) → 229 (Task 3) → 237 (Task 4) → 238 (Task 5). If a count differs, report it; never add or remove tests to hit a number.

**Known limits:** DeviceActivity doesn't run in the simulator, and Screen Time tokens can't be made in tests. So every decision is pure and tested, the monitor and the registrar are thin wrappers, and the iPhone run (Task 6) proves the real callbacks.

## File map

| File | Responsibility |
| --- | --- |
| `Shared/ScheduleActivity.swift` (new) | `ModeSchedule.window(containing:)`, `ModeActivity` names, schedules and plan |
| `Shared/ScheduledLock.swift` (new) | `decide`, `start`, `run`: what the monitor does at a window's start |
| `Shared/ScheduleNotice.swift` (new) | Notification copy, `LockNotifying`, `LocalNotifier` |
| `Shared/SharedStore.swift` | `lastUnlockAt`, `scheduleSavedAt`, `registeredSchedules` |
| `Shared/Mode.swift` | Doc fix: a schedule locks at `start` and never unlocks |
| `TapoutMonitor/TapoutMonitor.swift` | Routes mode activities to `ScheduledLock.run`; emergency unchanged |
| `Tapout/Engine/LockEngine.swift` | `lock() -> Bool`; `unlock()` records `lastUnlockAt` |
| `Tapout/Engine/ScheduleRegistrar.swift` (new) | Keeps DeviceActivity's activities matching the modes |
| `Tapout/Engine/NoticePermission.swift` (new) | Asks for notification permission |
| `Tapout/Model/AppModel.swift`, `Tapout/Model/DemoData.swift` | `schedules` dependency, `syncSchedules()`, stamping saves; `reconcile` reloads first |
| `Tapout/App/RootView.swift`, `Tapout/Features/Modes/ModeEditor.swift`, `Tapout/Features/Onboarding/OnboardingView.swift` | Follow the monitor; scan race; ask for notifications |

---

### Task 1: Schedule windows and activities

**Files:**
- Create: `Shared/ScheduleActivity.swift`, `TapoutTests/ScheduleActivityTests.swift`

**Interfaces:**
- Produces: `ModeSchedule.window(containing: Date, calendar: Calendar = .current) -> DateInterval?`; `enum ModeActivity` with `prefix`, `limit` (19), `name(for: UUID) -> DeviceActivityName`, `modeID(of: DeviceActivityName) -> UUID?`, `deviceSchedule(for: ModeSchedule) -> DeviceActivitySchedule`, `plan(for: [Mode]) -> [(name: DeviceActivityName, schedule: ModeSchedule)]`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/ScheduleActivityTests.swift`:

```swift
import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct ScheduleActivityTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// 2026-11-09 is a Monday; the 13th is a Friday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)
    private let fridayNights = ModeSchedule(days: [6], start: 22 * 60, end: 6 * 60)

    @Test func aWeekdayWindowContainsItsAfternoon() {
        #expect(afternoons.window(containing: date(9, 14), calendar: calendar)
            == DateInterval(start: date(9, 13), end: date(9, 17)))
    }

    @Test func beforeTheStartIsOutside() {
        #expect(afternoons.window(containing: date(9, 12, 59), calendar: calendar) == nil)
    }

    @Test func anUnscheduledDayIsOutside() {
        #expect(afternoons.window(containing: date(14, 14), calendar: calendar) == nil)
    }

    @Test func anOvernightWindowRunsPastMidnight() {
        #expect(fridayNights.window(containing: date(14, 2), calendar: calendar)
            == DateInterval(start: date(13, 22), end: date(14, 6)))
    }

    @Test func anOvernightWindowBelongsToItsStartDay() {
        // Saturday night is not scheduled, so Sunday 2 AM is outside.
        #expect(fridayNights.window(containing: date(15, 2), calendar: calendar) == nil)
        #expect(fridayNights.window(containing: date(13, 21, 59), calendar: calendar) == nil)
    }

    @Test func aTooShortScheduleNeverRuns() {
        let short = ModeSchedule(days: ModeSchedule.everyDay, start: 600, end: 610)
        #expect(short.window(containing: date(9, 10, 5), calendar: calendar) == nil)
    }

    @Test func activityNamesRoundTrip() {
        let id = UUID()
        #expect(ModeActivity.modeID(of: ModeActivity.name(for: id)) == id)
        #expect(ModeActivity.modeID(of: RelockPlan.activity) == nil)
    }

    @Test func theDeviceScheduleRepeatsDailyFromStartToEnd() {
        let schedule = ModeActivity.deviceSchedule(for: fridayNights)
        #expect(schedule.intervalStart.hour == 22)
        #expect(schedule.intervalStart.minute == 0)
        #expect(schedule.intervalEnd.hour == 6)
        #expect(schedule.repeats)
    }

    @Test func thePlanSkipsManualAndShortSchedulesAndStopsAtTheLimit() {
        let manual = Mode(name: "Manual")
        let short = Mode(name: "Short", schedule: ModeSchedule(days: [2], start: 600, end: 610))
        let many = (0..<25).map { Mode(name: "M\($0)", schedule: afternoons) }
        let plan = ModeActivity.plan(for: [manual, short] + many)
        #expect(plan.count == ModeActivity.limit)
        #expect(plan.first?.name == ModeActivity.name(for: many[0].id))
        #expect(plan.first?.schedule == afternoons)
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`window(containing:)` and `ModeActivity` don't exist).

- [ ] **Step 3: Implement.** Create `Shared/ScheduleActivity.swift`:

```swift
import DeviceActivity
import Foundation

extension ModeSchedule {
    /// The window around `date`: it starts at `start` on one of `days` and lasts `duration` minutes,
    /// into the next day when `end` is before `start`. nil outside every window, or when the schedule
    /// is too short to run.
    func window(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        guard isRunnable else { return nil }
        let today = calendar.startOfDay(for: date)
        // A window that crosses midnight may have started yesterday.
        for offset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  days.contains(calendar.component(.weekday, from: day)),
                  let start = calendar.date(byAdding: .minute, value: self.start, to: day) else { continue }
            let window = DateInterval(start: start, duration: TimeInterval(duration * 60))
            if date >= window.start && date < window.end { return window }
        }
        return nil
    }
}

/// The DeviceActivity side of mode schedules: one daily activity per scheduled mode. The monitor
/// checks the weekday itself, because one activity per weekday would soon pass DeviceActivity's limit.
enum ModeActivity {
    static let prefix = "tapout.mode."
    /// DeviceActivity throws `excessiveActivities` past its limit; one slot stays free for the emergency relock.
    static let limit = 19

    static func name(for modeID: UUID) -> DeviceActivityName {
        DeviceActivityName(prefix + modeID.uuidString)
    }

    /// The mode behind an activity, or nil for anything else (the emergency relock).
    static func modeID(of activity: DeviceActivityName) -> UUID? {
        guard activity.rawValue.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(activity.rawValue.dropFirst(prefix.count)))
    }

    /// Repeats every day from the mode's start to its end, past midnight when the end is earlier.
    static func deviceSchedule(for schedule: ModeSchedule) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: schedule.start / 60, minute: schedule.start % 60),
            intervalEnd: DateComponents(hour: schedule.end / 60, minute: schedule.end % 60),
            repeats: true
        )
    }

    /// The activities the modes need: runnable schedules only, in mode order, at most `limit`.
    static func plan(for modes: [Mode]) -> [(name: DeviceActivityName, schedule: ModeSchedule)] {
        let wanted: [(name: DeviceActivityName, schedule: ModeSchedule)] = modes.compactMap { mode in
            guard let schedule = mode.schedule, schedule.isRunnable else { return nil }
            return (name(for: mode.id), schedule)
        }
        return Array(wanted.prefix(limit))
    }
}
```

In `Shared/Mode.swift`, change `ModeSchedule`'s doc comment to: `/// When a mode locks by itself: at \`start\` on each of \`days\`. Schedules never unlock; a tag does.`

- [ ] **Step 4: Run the tests.** Expected: TEST SUCCEEDED, 213 tests.

- [ ] **Step 5: Suggested commit message:** `Add schedule windows and one DeviceActivity activity per scheduled mode`

---

### Task 2: Deciding a scheduled lock

**Files:**
- Create: `Shared/ScheduledLock.swift`, `TapoutTests/ScheduledLockTests.swift`
- Modify: `Shared/SharedStore.swift`, `Tapout/Engine/LockEngine.swift`
- Test: `TapoutTests/LockEngineTests.swift`

**Interfaces:**
- Consumes: Task 1's `window(containing:)`; `ShieldPlan`, `Shielding`, `SharedStore.activeShieldPlan`.
- Produces: `SharedStore.lastUnlockAt: Date?`, `SharedStore.scheduleSavedAt: [String: Date]` (keyed by mode id string); `ScheduledLock.Decision` (`.lock(Mode)`, `.skip(Reason, Mode)`, `.skipQuietly(String)`), `ScheduledLock.Reason` (`.noApps`, `.noAccess`), `ScheduledLock.decide(mode:store:now:accessApproved:hasApps:calendar:)`, `ScheduledLock.start(_:store:shields:now:)`; `@discardableResult LockEngine.lock() -> Bool`; `LockEngine.unlock()` writes `lastUnlockAt`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/ScheduledLockTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

struct ScheduledLockTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let mode = Mode(name: "Focus", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))

    /// 2026-11-09 is a Monday.
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }

    private func decide(at now: Date, access: Bool = true, apps: Bool = true) -> ScheduledLock.Decision {
        ScheduledLock.decide(mode: mode, store: store, now: now, accessApproved: access, hasApps: apps, calendar: calendar)
    }

    @Test func locksAtTheStartOfAWindow() {
        #expect(decide(at: date(9, 13, 0, 5)) == .lock(mode))
    }

    @Test func aCallbackAMinuteEarlyStillLocks() {
        #expect(decide(at: date(9, 12, 59, 30)) == .lock(mode))
    }

    @Test func skipsQuietlyOnAnotherDay() {
        guard case .skipQuietly = decide(at: date(14, 13)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func skipsQuietlyWhenAlreadyLocked() {
        store.session = .locked(since: date(9, 12))
        guard case .skipQuietly = decide(at: date(9, 13)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func skipsAWindowTheOwnerUnlockedIn() {
        store.lastUnlockAt = date(9, 13, 30)
        guard case .skipQuietly = decide(at: date(9, 14)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func anUnlockBeforeTheWindowDoesNotCount() {
        store.lastUnlockAt = date(9, 12)
        #expect(decide(at: date(9, 13)) == .lock(mode))
    }

    @Test func skipsAWindowTheScheduleWasSavedIn() {
        store.scheduleSavedAt = [mode.id.uuidString: date(9, 14)]
        guard case .skipQuietly = decide(at: date(9, 14, 1)) else {
            Issue.record("expected a quiet skip")
            return
        }
    }

    @Test func tellsWhenScreenTimeIsOff() {
        #expect(decide(at: date(9, 13), access: false) == .skip(.noAccess, mode))
    }

    @Test func tellsWhenTheModeHasNoApps() {
        #expect(decide(at: date(9, 13), apps: false) == .skip(.noApps, mode))
    }

    @Test func startMakesTheModeActiveThenLocksThenShields() {
        let other = Mode(name: "Other")
        store.modes = [other, mode]
        store.activeModeID = other.id
        let shields = FakeShields()
        ScheduledLock.start(mode, store: store, shields: shields, now: date(9, 13))
        #expect(store.activeModeID == mode.id)
        #expect(store.session == .locked(since: date(9, 13)))
        #expect(shields.plans == [store.activeShieldPlan])
    }
}
```

Add inside `struct LockEngineTests`:

```swift
    @Test func unlockRecordsWhen() {
        let engine = lockedEngine()
        clock.now += 60
        engine.unlock()
        #expect(store.lastUnlockAt == clock.now)
    }

    @Test func lockSaysWhetherItLocked() {
        let engine = makeEngine()
        #expect(engine.lock())
        #expect(!engine.lock())
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`ScheduledLock` doesn't exist).

- [ ] **Step 3: Implement.** In `Shared/SharedStore.swift`, add after `seenMilestones`:

```swift
    /// When the owner last unlocked. A schedule doesn't relock a window the owner unlocked in.
    var lastUnlockAt: Date? {
        get { read(.lastUnlockAt, absent: nil, corrupt: nil) }
        set { write(newValue, .lastUnlockAt) }
    }

    /// When each mode's schedule was last saved, by mode id. A window the schedule was saved in doesn't lock.
    var scheduleSavedAt: [String: Date] {
        get { read(.scheduleSavedAt, absent: [:], corrupt: [:]) }
        set { write(newValue, .scheduleSavedAt) }
    }
```

and add `case lastUnlockAt, scheduleSavedAt` to `Key`.

Create `Shared/ScheduledLock.swift`:

```swift
import Foundation

/// What the monitor does when a mode's daily window starts. Schedules only lock, never unlock.
enum ScheduledLock {
    enum Reason: Equatable {
        case noApps, noAccess
    }

    enum Decision: Equatable {
        case lock(Mode)
        /// The owner expects a lock, so a notification says why there isn't one.
        case skip(Reason, Mode)
        /// Nothing to say: another day, already locked, or unlocked or saved during this window.
        case skipQuietly(String)
    }

    /// A start callback this much early still counts as the window's start.
    static let earlyTolerance: TimeInterval = 60

    static func decide(
        mode: Mode?,
        store: SharedStore,
        now: Date,
        accessApproved: Bool,
        hasApps: Bool,
        calendar: Calendar = .current
    ) -> Decision {
        guard let mode, let schedule = mode.schedule,
              let window = schedule.window(containing: now, calendar: calendar)
                ?? schedule.window(containing: now + earlyTolerance, calendar: calendar)
        else { return .skipQuietly("not a scheduled day") }
        guard store.session == .unlocked else { return .skipQuietly("already locked") }
        if let unlocked = store.lastUnlockAt, unlocked >= window.start {
            return .skipQuietly("unlocked during this window")
        }
        if let saved = store.scheduleSavedAt[mode.id.uuidString], saved > window.start {
            return .skipQuietly("saved during this window")
        }
        guard accessApproved else { return .skip(.noAccess, mode) }
        guard hasApps else { return .skip(.noApps, mode) }
        return .lock(mode)
    }

    /// Starts the lock: the scheduled mode becomes active, then the lock state is written, then the shields
    /// go on. No lock record here: the app adds it from the lock state (`AppModel.reconcile`), so only the
    /// app ever writes the history.
    static func start(_ mode: Mode, store: SharedStore, shields: some Shielding, now: Date) {
        store.activeModeID = mode.id
        store.session = .locked(since: now)
        shields.apply(store.activeShieldPlan)
    }
}
```

In `Tapout/Engine/LockEngine.swift`:
- `lock()` becomes `@discardableResult func lock() -> Bool`: `guard store.session == .unlocked else { return false }`, and `return true` at the end. Update its doc comment: "Returns false when already locked (a schedule may have locked while a tag was being read)."
- In `unlock()`, add `store.lastUnlockAt = now()` right after `store.session = .unlocked`.

- [ ] **Step 4: Run the tests.** Expected: TEST SUCCEEDED, 225 tests.

- [ ] **Step 5: Suggested commit message:** `Decide when a schedule may lock, and remember unlocks`

---

### Task 3: The monitor locks on schedule and says so

**Files:**
- Create: `Shared/ScheduleNotice.swift`, `TapoutTests/ScheduleRunTests.swift`
- Modify: `Shared/ScheduledLock.swift` (add `run`), `TapoutMonitor/TapoutMonitor.swift`, `TapoutTests/Fakes.swift`

**Interfaces:**
- Consumes: Task 2's `decide` and `start`; Task 1's `ModeActivity.modeID(of:)`.
- Produces: `ScheduleNotice.locked(_:)`, `ScheduleNotice.skipped(_:_:)` (each `(title: String, body: String)`); `protocol LockNotifying { func post(title: String, body: String) }`; `struct LocalNotifier: LockNotifying`; `@discardableResult ScheduledLock.run(modeID:store:shields:notifier:now:accessApproved:hasApps:calendar:) -> String` (the log line); `FakeNotifier` in tests.

- [ ] **Step 1: Write the failing tests.** Add to `TapoutTests/Fakes.swift`:

```swift
/// Records notifications instead of posting them, as "title|body".
final class FakeNotifier: LockNotifying {
    private(set) var posted: [String] = []

    func post(title: String, body: String) { posted.append("\(title)|\(body)") }
}
```

Create `TapoutTests/ScheduleRunTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

struct ScheduleRunTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    private let shields = FakeShields()
    private let notifier = FakeNotifier()
    private let mode = Mode(name: "Focus", schedule: ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60))
    /// Monday 2026-11-09, 1 PM.
    private var monday1PM: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 13))! }

    private func run(access: Bool = true, apps: Bool = true, at now: Date? = nil) -> String {
        store.modes = [mode]
        return ScheduledLock.run(modeID: mode.id, store: store, shields: shields, notifier: notifier,
                                 now: now ?? monday1PM, accessApproved: access, hasApps: { _ in apps }, calendar: calendar)
    }

    @Test func aWindowStartLocksAndSaysSo() {
        let line = run()
        #expect(store.session == .locked(since: monday1PM))
        #expect(shields.applied == 1)
        #expect(notifier.posted == ["Focus|Locked until you tap a tag."])
        #expect(line == "Scheduled lock: Focus")
    }

    @Test func aWindowItCantLockIsSkippedWithAReason() {
        _ = run(apps: false)
        #expect(store.session == .unlocked)
        #expect(shields.applied == 0)
        #expect(notifier.posted == ["Focus|Didn't lock: no apps chosen."])
        _ = run(access: false)
        #expect(notifier.posted.last == "Focus|Didn't lock: Screen Time is off.")
    }

    @Test func aQuietSkipPostsNothing() {
        store.session = .locked(since: monday1PM - 600)
        let line = run()
        #expect(notifier.posted.isEmpty)
        #expect(line == "Schedule skipped: already locked")
    }

    @Test func anUnknownModeIsSkippedQuietly() {
        let line = ScheduledLock.run(modeID: UUID(), store: store, shields: shields, notifier: notifier,
                                     now: monday1PM, accessApproved: true, calendar: calendar)
        #expect(notifier.posted.isEmpty)
        #expect(line == "Schedule skipped: not a scheduled day")
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`LockNotifying` and `run` don't exist).

- [ ] **Step 3: Implement.** Create `Shared/ScheduleNotice.swift`:

```swift
import Foundation
import UserNotifications

/// The few words a schedule says through a notification.
enum ScheduleNotice {
    static func locked(_ mode: Mode) -> (title: String, body: String) {
        (mode.name, "Locked until you tap a tag.")
    }

    static func skipped(_ mode: Mode, _ reason: ScheduledLock.Reason) -> (title: String, body: String) {
        switch reason {
        case .noApps: (mode.name, "Didn't lock: no apps chosen.")
        case .noAccess: (mode.name, "Didn't lock: Screen Time is off.")
        }
    }
}

/// Posts a notification. A protocol, so tests can record instead.
protocol LockNotifying {
    func post(title: String, body: String)
}

/// A local notification, shown at once. Silently nothing when the owner said no to notifications.
struct LocalNotifier: LockNotifying {
    func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
```

Add to `enum ScheduledLock` in `Shared/ScheduledLock.swift`:

```swift
    /// The monitor's `intervalDidStart` for a mode activity: decide, then lock or say why not.
    /// `hasApps` is a parameter only so tests can answer it; Screen Time tokens can't be made in tests.
    /// Returns the line for the shared log.
    @discardableResult
    static func run(
        modeID: UUID,
        store: SharedStore,
        shields: some Shielding,
        notifier: some LockNotifying,
        now: Date,
        accessApproved: Bool,
        hasApps: ((Mode) -> Bool)? = nil,
        calendar: Calendar = .current
    ) -> String {
        let mode = store.modes.first { $0.id == modeID }
        let alwaysAllowed = store.alwaysAllowed
        let appsChosen = mode.map { hasApps?($0) ?? !ShieldPlan(blocking: $0.selection, allowing: alwaysAllowed).isEmpty } ?? false
        switch decide(mode: mode, store: store, now: now, accessApproved: accessApproved, hasApps: appsChosen, calendar: calendar) {
        case .lock(let mode):
            start(mode, store: store, shields: shields, now: now)
            let notice = ScheduleNotice.locked(mode)
            notifier.post(title: notice.title, body: notice.body)
            return "Scheduled lock: \(mode.name)"
        case .skip(let reason, let mode):
            let notice = ScheduleNotice.skipped(mode, reason)
            notifier.post(title: notice.title, body: notice.body)
            return "Schedule skipped: \(notice.body)"
        case .skipQuietly(let why):
            return "Schedule skipped: \(why)"
        }
    }
```

Replace `TapoutMonitor/TapoutMonitor.swift` with:

```swift
import DeviceActivity
import FamilyControls
import Foundation
import os

/// Runs in its own process, woken by DeviceActivity. Starts scheduled locks when a mode's window
/// begins (schedules never unlock), relocks an emergency pass at its relock time, and logs every
/// callback so the Lab shows when it fired.
final class TapoutMonitor: DeviceActivityMonitor {
    /// A second timing record, independent of the shared log (read it in Console.app).
    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "monitor")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let store = SharedStore.appGroup()
        let now = Date()
        guard let modeID = ModeActivity.modeID(of: activity) else {
            log("intervalDidStart \(activity.rawValue)", store, now)
            return
        }
        let line = ScheduledLock.run(modeID: modeID, store: store, shields: ShieldController(),
                                     notifier: LocalNotifier(), now: now, accessApproved: Self.screenTimeApproved)
        log(line, store, now)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        relock(activity, callback: "intervalWillEndWarning")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if ModeActivity.modeID(of: activity) != nil {
            // Schedules never unlock: the end of a window changes nothing.
            log("Schedule window ended: \(activity.rawValue)", SharedStore.appGroup(), Date())
            return
        }
        relock(activity, callback: "intervalDidEnd")
    }

    /// Whether Tapout may shield apps. A scheduled start without access is skipped, with a notice.
    private static var screenTimeApproved: Bool {
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved { return true }
        if #available(iOS 26.4, *) { return status == .approvedWithDataAccess }
        return false
    }

    private func log(_ line: String, _ store: SharedStore, _ now: Date) {
        Self.logger.info("\(line, privacy: .public) at \(now.formatted(date: .omitted, time: .standard), privacy: .public)")
        store.appendLog(line, source: .monitor, at: now)
    }

    private func relock(_ activity: DeviceActivityName, callback: String) {
        guard activity == RelockPlan.activity else { return }
        let store = SharedStore.appGroup()
        let now = Date()
        if let late = EmergencyRelock.perform(store: store, shields: ShieldController(), now: now) {
            log("\(callback): relocked, \(Int(late))s after relock time", store, now)
        } else {
            let reason = if case .emergency = store.session { "not due yet" } else { "nothing to relock" }
            log("\(callback): \(reason)", store, now)
        }
    }
}
```

If Swift 6 rejects reading `AuthorizationCenter.shared` from this nonisolated context, keep the logic and report the exact error and the smallest fix you used.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 229 tests; device exit 0.

- [ ] **Step 5: Suggested commit message:** `Lock on schedule from the monitor, with a notice either way`

---

### Task 4: The app keeps activities in step with modes

**Files:**
- Create: `Tapout/Engine/ScheduleRegistrar.swift`, `Tapout/Engine/NoticePermission.swift`, `TapoutTests/ScheduleRegistrarTests.swift`, `TapoutTests/AppModelScheduleTests.swift`
- Modify: `Shared/SharedStore.swift` (`registeredSchedules`), `Tapout/Model/AppModel.swift`, `Tapout/Model/DemoData.swift:87`, `Tapout/Features/Modes/ModeEditor.swift` (`save()`), `Tapout/Features/Onboarding/OnboardingView.swift` (`finish()`), `TapoutTests/Fakes.swift`

**Interfaces:**
- Consumes: Task 1's `ModeActivity`; Task 2's `scheduleSavedAt`.
- Produces: `protocol ScheduleRegistering { func sync(_ modes: [Mode]) -> [String] }`; `protocol ActivityCentering`; `struct LiveActivityCenter: ActivityCentering`; `struct ScheduleRegistrar<Center: ActivityCentering>: ScheduleRegistering` (`init(center:store:)`); `struct NoSchedules: ScheduleRegistering`; `enum ScheduleRegistrars { static func live(store:) -> any ScheduleRegistering }`; `SharedStore.registeredSchedules: [String: ModeSchedule]`; `AppModel.init(store:schedules:now:)` with `schedules` defaulting to `NoSchedules()`; `AppModel.syncSchedules()`; `NoticePermission.request()`. Test fakes `FakeActivityCenter`, `FakeSchedules`.

- [ ] **Step 1: Write the failing tests.** Add to `TapoutTests/Fakes.swift` (add `import DeviceActivity` at the top):

```swift
/// Records DeviceActivity calls.
final class FakeActivityCenter: ActivityCentering {
    var failure: (any Error)?
    private(set) var activities: [DeviceActivityName] = []
    private(set) var started: [DeviceActivityName] = []
    private(set) var stopped: [DeviceActivityName] = []

    init(running: [DeviceActivityName] = []) { activities = running }

    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        if let failure { throw failure }
        started.append(activity)
        if !activities.contains(activity) { activities.append(activity) }
    }

    func stopMonitoring(_ names: [DeviceActivityName]) {
        stopped += names
        activities.removeAll { names.contains($0) }
    }
}

/// Records what the model asked to register.
final class FakeSchedules: ScheduleRegistering {
    private(set) var synced: [[Mode]] = []

    func sync(_ modes: [Mode]) -> [String] {
        synced.append(modes)
        return []
    }
}
```

Create `TapoutTests/ScheduleRegistrarTests.swift`:

```swift
import DeviceActivity
import Foundation
import Testing
@testable import Tapout

struct ScheduleRegistrarTests {
    private let store = SharedStore.makeTest()
    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)

    @Test func startsEachRunnableSchedule() {
        let center = FakeActivityCenter()
        let focus = Mode(name: "Focus", schedule: afternoons)
        #expect(ScheduleRegistrar(center: center, store: store).sync([focus, Mode(name: "Manual")]).isEmpty)
        #expect(center.started == [ModeActivity.name(for: focus.id)])
        #expect(store.registeredSchedules == [ModeActivity.name(for: focus.id).rawValue: afternoons])
    }

    @Test func leavesAnUnchangedRunningActivityAlone() {
        let focus = Mode(name: "Focus", schedule: afternoons)
        let name = ModeActivity.name(for: focus.id)
        store.registeredSchedules = [name.rawValue: afternoons]
        let center = FakeActivityCenter(running: [name])
        _ = ScheduleRegistrar(center: center, store: store).sync([focus])
        #expect(center.started.isEmpty)
    }

    @Test func restartsAChangedSchedule() {
        var focus = Mode(name: "Focus", schedule: afternoons)
        let name = ModeActivity.name(for: focus.id)
        store.registeredSchedules = [name.rawValue: afternoons]
        let center = FakeActivityCenter(running: [name])
        focus.schedule = ModeSchedule(days: ModeSchedule.weekdays, start: 9 * 60, end: 12 * 60)
        _ = ScheduleRegistrar(center: center, store: store).sync([focus])
        #expect(center.stopped == [name])
        #expect(center.started == [name])
    }

    @Test func stopsModeActivitiesThatAreNoLongerWantedButNotTheRelock() {
        let gone = ModeActivity.name(for: UUID())
        let center = FakeActivityCenter(running: [gone, RelockPlan.activity])
        _ = ScheduleRegistrar(center: center, store: store).sync([])
        #expect(center.stopped == [gone])
        #expect(center.activities == [RelockPlan.activity])
    }

    @Test func reportsAStartThatFailed() {
        let center = FakeActivityCenter()
        center.failure = FakeError()
        let problems = ScheduleRegistrar(center: center, store: store).sync([Mode(name: "Focus", schedule: afternoons)])
        #expect(problems.count == 1)
        #expect(store.registeredSchedules.isEmpty)
    }
}
```

Create `TapoutTests/AppModelScheduleTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct AppModelScheduleTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()
    private let store = SharedStore.makeTest()
    private let schedules = FakeSchedules()
    private let afternoons = ModeSchedule(days: ModeSchedule.weekdays, start: 13 * 60, end: 17 * 60)

    private func makeModel() -> AppModel {
        AppModel(store: store, schedules: schedules, now: { [clock] in clock.now })
    }

    @Test func savingAScheduleStampsItAndRegisters() {
        let model = makeModel()
        var mode = model.activeMode
        mode.schedule = afternoons
        model.save(mode)
        #expect(store.scheduleSavedAt[mode.id.uuidString] == clock.now)
        #expect(schedules.synced.last?.first?.schedule == afternoons)
    }

    @Test func savingWithoutChangingTheScheduleDoesNotStamp() {
        let model = makeModel()
        var mode = model.activeMode
        mode.schedule = afternoons
        model.save(mode)
        let stamped = clock.now
        clock.now += 3600
        mode.name = "Deep work"
        model.save(mode)
        #expect(store.scheduleSavedAt[mode.id.uuidString] == stamped)
    }

    @Test func deletingAModeDropsItsStampAndRegisters() {
        let model = makeModel()
        let extra = Mode(name: "Evenings", schedule: afternoons)
        model.save(extra)
        #expect(model.deleteMode(id: extra.id))
        #expect(store.scheduleSavedAt[extra.id.uuidString] == nil)
        #expect(schedules.synced.last?.contains { $0.id == extra.id } == false)
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`ActivityCentering` doesn't exist).

- [ ] **Step 3: Implement.** In `Shared/SharedStore.swift`, add after `scheduleSavedAt`:

```swift
    /// The schedule each mode activity was last started with, by activity name, so a launch only
    /// restarts activities that changed or stopped (a restart could re-fire a window's start).
    var registeredSchedules: [String: ModeSchedule] {
        get { read(.registeredSchedules, absent: [:], corrupt: [:]) }
        set { write(newValue, .registeredSchedules) }
    }
```

and add `registeredSchedules` to the `Key` case you added in Task 2.

Create `Tapout/Engine/ScheduleRegistrar.swift`:

```swift
import DeviceActivity
import Foundation

/// Keeps DeviceActivity's activities matching the modes' schedules. Returns problems for the log.
protocol ScheduleRegistering {
    func sync(_ modes: [Mode]) -> [String]
}

/// The part of `DeviceActivityCenter` the registrar uses, so tests can record instead.
protocol ActivityCentering {
    var activities: [DeviceActivityName] { get }
    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ activities: [DeviceActivityName])
}

struct LiveActivityCenter: ActivityCentering {
    private let center = DeviceActivityCenter()

    var activities: [DeviceActivityName] { center.activities }

    func startMonitoring(_ activity: DeviceActivityName, during schedule: DeviceActivitySchedule) throws {
        try center.startMonitoring(activity, during: schedule)
    }

    func stopMonitoring(_ activities: [DeviceActivityName]) {
        center.stopMonitoring(activities)
    }
}

struct ScheduleRegistrar<Center: ActivityCentering>: ScheduleRegistering {
    let center: Center
    let store: SharedStore

    func sync(_ modes: [Mode]) -> [String] {
        let plan = ModeActivity.plan(for: modes)
        let wanted = Set(plan.map(\.name))
        let running = center.activities
        let stale = running.filter { ModeActivity.modeID(of: $0) != nil && !wanted.contains($0) }
        if !stale.isEmpty { center.stopMonitoring(stale) }
        var registered = store.registeredSchedules.filter { wanted.contains(DeviceActivityName($0.key)) }
        var problems: [String] = []
        for entry in plan {
            let key = entry.name.rawValue
            let isRunning = running.contains(entry.name)
            // Unchanged and running: leave it, so its window doesn't start again.
            if isRunning, registered[key] == entry.schedule { continue }
            if isRunning { center.stopMonitoring([entry.name]) }
            do {
                try center.startMonitoring(entry.name, during: ModeActivity.deviceSchedule(for: entry.schedule))
                registered[key] = entry.schedule
            } catch {
                registered[key] = nil
                problems.append("Schedule \(key) not started: \(error)")
            }
        }
        store.registeredSchedules = registered
        return problems
    }
}

/// For the simulator, previews and tests: DeviceActivity doesn't run there.
struct NoSchedules: ScheduleRegistering {
    func sync(_ modes: [Mode]) -> [String] { [] }
}

enum ScheduleRegistrars {
    static func live(store: SharedStore) -> any ScheduleRegistering {
        #if targetEnvironment(simulator)
        NoSchedules()
        #else
        ScheduleRegistrar(center: LiveActivityCenter(), store: store)
        #endif
    }
}
```

Create `Tapout/Engine/NoticePermission.swift`:

```swift
import UserNotifications

/// Scheduled locks happen while Tapout is closed, so a notification says when one starts or can't.
enum NoticePermission {
    /// Asks once; later calls return the first answer without asking again.
    static func request() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
```

In `Tapout/Model/AppModel.swift`:
- Add `@ObservationIgnored private let schedules: any ScheduleRegistering` beside `store`.
- The init becomes `init(store: SharedStore, schedules: any ScheduleRegistering = NoSchedules(), now: @escaping () -> Date = Date.init)` and assigns it.
- `live()` becomes:

```swift
    static func live() -> AppModel {
        let store = SharedStore.appGroup()
        return AppModel(store: store, schedules: ScheduleRegistrars.live(store: store))
    }
```

- In `save(_:)`, read `let previous = store.modes.first { $0.id == mode.id }?.schedule` before changing `all`, and after `store.modes = all` add:

```swift
        if previous != mode.schedule { stampSchedule(of: mode.id) }
        syncSchedules()
```

- In `deleteMode(id:)`, after `store.modes = all`, add:

```swift
        var stamps = store.scheduleSavedAt
        stamps[id.uuidString] = nil
        store.scheduleSavedAt = stamps
        syncSchedules()
```

- Add, in the Modes section:

```swift
    /// Starts or stops DeviceActivity's activities to match the modes. Problems go to the log.
    /// Also called at launch, which restarts only activities that changed or stopped.
    func syncSchedules() {
        for problem in schedules.sync(store.modes) {
            store.appendLog(problem, source: .app)
        }
    }

    /// A schedule saved during one of its windows starts from the next window.
    private func stampSchedule(of id: UUID) {
        var stamps = store.scheduleSavedAt
        stamps[id.uuidString] = now()
        store.scheduleSavedAt = stamps
    }
```

In `Tapout/Model/DemoData.swift:87` (inside `fromLaunchArguments`), `return AppModel(store: store)` becomes `return AppModel(store: store, schedules: ScheduleRegistrars.live(store: store))`. Leave `previewModel()` as it is.

In `Tapout/Features/Modes/ModeEditor.swift` `save()`, after `model.save(mode)`, add `if mode.schedule != nil { Task { await NoticePermission.request() } }`.

In `Tapout/Features/Onboarding/OnboardingView.swift` `finish()`, before `onFinish()`, add `if draft.schedule != nil { Task { await NoticePermission.request() } }`.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 237 tests; device exit 0.

- [ ] **Step 5: Suggested commit message:** `Register a DeviceActivity schedule for each scheduled mode`

---

### Task 5: The app follows the monitor

**Files:**
- Modify: `Tapout/Model/AppModel.swift` (`reconcile`), `Tapout/App/RootView.swift`
- Test: `TapoutTests/AppModelLockTests.swift`

**Interfaces:**
- Consumes: Task 2's `lock() -> Bool`; Task 4's `syncSchedules()`.
- Produces: `reconcile(with:)` re-reads the store first; RootView reconciles on every session change and foreground, registers schedules at launch, and drops a tag read that the lock state outran.

- [ ] **Step 1: Write the failing test.** Add inside `struct AppModelLockTests`:

```swift
    @Test func reconcileSeesAModeTheMonitorMadeActive() throws {
        let model = pairedModel()
        let evenings = Mode(name: "Evenings")
        model.save(evenings)
        // The monitor writes straight to the store: the scheduled mode becomes active and the lock starts.
        store.activeModeID = evenings.id
        model.reconcile(with: .locked(since: clock.now))
        #expect(try #require(model.history.last).modeID == evenings.id)
        #expect(model.activeMode.id == evenings.id)
    }
```

- [ ] **Step 2: Run the tests.** Expected: the new test fails (the record gets the old active mode).

- [ ] **Step 3: Implement.** In `AppModel.reconcile(with:)`, add `reload()` as the first line, and add to its doc comment: "It re-reads the store first: the monitor may have made a scheduled mode active."

In `Tapout/App/RootView.swift`:
- After `.onChange(of: screenTimeNeeded) { ... }`, add:

```swift
        // A lock the monitor started (a schedule) gets its record here; for the app's own lock,
        // unlock, pass and relock the record is already right, so this changes nothing.
        .onChange(of: engine.session) { _, session in model.reconcile(with: session) }
```

- In the `.onChange(of: scenePhase)` handler, the `.active` branch becomes:

```swift
            if phase == .active {
                engine.syncShields()
                model.reconcile(with: engine.session)
                checkScreenTime()
            }
```

- In `.task`, add `model.syncSchedules()` after `model.reconcile(with: engine.session)`.
- In `scan()`, right after the `do { uid = ... } catch { return }` block, add:

```swift
        // A schedule may have locked while the tag was being read. Drop the read rather than act on old state.
        engine.reload()
        guard (engine.session.lockState == .locked) == unlocking else { return }
```

- In `lock(at:)`, the first line becomes `guard engine.lock() else { return }`.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 238 tests; device exit 0.

- [ ] **Step 5: Suggested commit message:** `Follow scheduled locks in the app and drop tag reads the lock state outran`

---

### Task 6: Verify

- [ ] **Step 1:** Run the build/test command and the device compile check (Debug, and Release with `-configuration Release -derivedDataPath <scratch>`). Expected: 257 tests, no warnings from `Tapout/`, `Shared/`, `TapoutTests/`, `TapoutMonitor/` or `TapoutShield/`, all exits 0.
- [ ] **Step 2: Simulator.** DeviceActivity doesn't run there, so check only that nothing broke: fresh install, onboarding with Afternoons (expected: the notification permission prompt appears after onboarding), lock, unlock, emergency pass, and saving a schedule in Modes (no crash; the prompt doesn't appear twice). Save contact sheets as `docs/superpowers/verification/phase4b-*.png`.
- [ ] **Step 3: iPhone run (the user's; give these steps exactly).** Do 4A's iPhone run first if it hasn't passed. Install, and open Settings → Lab to watch the log.
  0. Before installing, note which modes already have schedules: they start on install.
  1. In Modes, give a mode at least one app and a schedule for today starting about 3 minutes from now, at least 15 minutes long, on days that include tomorrow. Allow notifications when asked. Force-quit Tapout and let the phone sleep.
  2. At the start time: a notification with the mode's name and "Locked until you tap a tag."; a blocked app shows Sealed. Open Tapout: Locked, the mode pill shows that mode, the timer counts from the start time. In Lab, note the "Scheduled lock" line and its access readout.
  3. Unlock with your tag during the window. Force-quit and reopen after 2 minutes: still unlocked, and no restart line in the Lab.
  4. Lock with your tag before the window ends and let the end time pass: still locked; Lab shows "Schedule window ended". Unlock with your tag.
  5. Tomorrow at the same time: it locks again with a notice (the repeat works).
  6. With Tapout open at a window start: Home flips to Locked within about a second with the scheduled mode.
  7. On a day the schedule doesn't include: nothing at the start time; Lab shows "Schedule skipped: not a scheduled day".
  8. A second mode with a schedule but no apps: "Didn't lock: no apps chosen." Remove all paired places (only for this test, then re-pair): "Didn't lock: no tag paired."
  9. Edit a schedule so its window is already running: Lab shows "Schedule started" and then "Schedule skipped: saved during this window"; nothing locks until the next window.
  10. Turn Tapout's Screen Time access off before a window: "Didn't lock: Screen Time is off." (note the Lab's access readout). Allow access again from Tapout's page without force-quitting; the next window still locks.
  11. An overnight schedule (for example 11 PM to 6 AM) locks at the start and stays locked past the end.
  12. An emergency pass during a scheduled lock with Tapout closed relocks after 5 minutes in the same mode.
  13. With notifications denied in iOS Settings, a window still locks, silently.
  14. Delete a scheduled mode before its window: nothing happens at its start time.
  15. Report each result and the Lab lines.
- [ ] **Step 4:** Report, leaving all changes uncommitted, with the suggested message `Phase 4B: mode schedules`.

## Notes for later phases

- The Live Activity (Phase 5) can show a scheduled lock: `currentIntention` is nil for it, and the mode name is in `activeMode`.
- ManagedSettings caps shielded app tokens (about 50 per setting). A mode over the cap may not shield every app; add a note in the mode editor if the device run shows it.
- Locked time keeps counting while Screen Time access is off (design decision); revisit if it matters.
- A crash between `engine.unlock` and `finishLock` still drops that lock's record (4A behaviour).
