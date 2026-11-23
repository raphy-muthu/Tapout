# Phase 8: Timer Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock the active mode's apps for a chosen length of time, started from Home with no tag, ending by itself (even with Tapout closed), ended early only by a paired tag or an emergency pass.

**Architecture:** A pure `TimerLock` value in `Shared/` (start, duration, due rule, finish step) is stored beside the ordinary `.locked` session. The engine starts and finishes it and schedules a `tapout.timer` DeviceActivity; the monitor runs the same finish step. `AppModel` closes the history record at the timer's end. Home gets a Timer sheet, a countdown locked state and a Time's up cover; widgets and the Live Activity count down.

**Tech Stack:** Swift 6, SwiftUI, DeviceActivity, Swift Testing, XcodeGen. iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-22-phase8-timer-lock-design.md`. Read it first.

## Global Constraints

Same as Phase 7 (`.superpowers/sdd/p7-constraints.md`), restated:

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Colours only through asset-catalog tokens; Fraunces only through `Typography.swift`, never `.bold()`/`.weight()` on Fraunces styles; Fraunces numbers that tick use `FixedDigitText`/`TimerText`, SF Pro ticking numbers `.monospacedDigit()`.
- Copy: very few words, no guilt, emoji or exclamation marks. Reduce Motion crossfades. 44pt touch targets. Dark first, light must work. Dynamic Type up to accessibility sizes must not truncate or overlap.
- DEBUG-only code (launch-argument mocks, Lab pages) inside `#if DEBUG`. Release must compile: run the Release device build after every task that touches Swift.
- `Shared/` stays free of SwiftUI, ActivityKit and WidgetKit.
- Only the app writes `lockHistory`. The monitor changes the session, shields, `lastUnlockAt` and the timer markers only.
- **Never commit, stage or stash.** Each task ends with a suggested commit message. Two untracked Java files in `Tapout/App/` belong to the owner: leave them alone.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`; use the derived data path in your brief):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath build/dd-p8 test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

**Device compile checks** (real exit codes, no pipe):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/device-nosign CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/device-release CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
```

**Test count:** starts at 306. Report each task's count; never add or remove tests to hit a number.

## File map

| File | Responsibility |
| --- | --- |
| `Shared/TimerLock.swift` (new) | The value, its due rule, the shared finish step |
| `Shared/SharedStore.swift` | `timerLock` and `finishedTimer` keys |
| `Shared/ScheduleActivity.swift` | `ModeActivity.limit` 18 |
| `Shared/RelockPlan.swift` | `RelockScheduler(activity:)`, `TimerPlan.activity` |
| `Tapout/Engine/LockEngine.swift` (+ `SimulatorStandIns.swift`) | `lockTimed`, timer finish in `tick`/`syncShields`/`unlock` |
| `TapoutMonitor/TapoutMonitor.swift`, `Shared/ScheduleNotice.swift` | Timer end while Tapout is closed, the notice |
| `Tapout/Model/AppModel.swift`, `Shared/LockRecord.swift` | Timer records, `reconcile`, the pending Time's up |
| `Tapout/Features/Home/TimerSheet.swift` (new), `HomeView.swift`, `TimerDoneView.swift` (new), `Tapout/App/RootView.swift` | The UI |
| `Surfaces/*`, `TapoutWidgets/*` | Countdown on widgets and the Live Activity |

---

### Task 1: `TimerLock` and its store keys

**Files:**
- Create: `Shared/TimerLock.swift`, `TapoutTests/TimerLockTests.swift`
- Modify: `Shared/SharedStore.swift`, `Shared/ScheduleActivity.swift`, `TapoutTests/ScheduleActivityTests.swift`, `TapoutTests/SharedStoreTests.swift`

**Interfaces (Produces):**

```swift
struct TimerLock: Codable, Equatable, Sendable {
    static let minimum: TimeInterval = 5 * 60
    static let maximum: TimeInterval = 12 * 3600
    static let earlyTolerance: TimeInterval = 60      // the monitor's
    let start: Date
    let duration: TimeInterval
    var endsAt: Date { start + duration }
    /// Seconds left, 0 when over. A clock set back never shows more than `duration`.
    func remaining(at now: Date) -> TimeInterval
    /// 0...1, share of the timer still left, for the orb ring.
    func remainingFraction(at now: Date) -> Double
    /// Same rule as `EmergencyRelock.isDue`: now >= endsAt - early, or endsAt is further away than duration.
    func isDue(now: Date, early: TimeInterval) -> Bool
    /// `duration` clamped to minimum...maximum.
    static func clamped(_ duration: TimeInterval) -> TimeInterval

    /// The finish step both the app and the monitor run: if the store holds a due timer and the
    /// session is `.locked` or `.emergency`, clear the shields, stamp `lastUnlockAt = now`, set the
    /// session to `.unlocked`, move the timer to `finishedTimer`, and return it. Otherwise return nil
    /// and write nothing. (Order: lastUnlockAt, session, then timer markers, like `LockEngine.unlock`.)
    static func finish(store: SharedStore, shields: some Shielding, now: Date, early: TimeInterval) -> TimerLock?
}
```

`SharedStore` gains `var timerLock: TimerLock?` (running) and `var finishedTimer: TimerLock?` (ended, the app has not yet closed the record), both absent/corrupt → `nil` (a damaged value must never keep a lock timed forever, and a lost timer leaves an ordinary lock, which a tag still opens). `ModeActivity.limit` becomes 18 with its comment updated (20 allowed: 18 modes, the emergency relock, the timer).

- [ ] **Step 1: Write failing tests** (`TimerLockTests`): `remaining` counts down and floors at 0; `remainingFraction` is 1 at start, 0.5 halfway, 0 at the end, never above 1 when the clock moved back; `isDue` false before, true at `endsAt`, true within `early` of it, true when `endsAt - now > duration`; `clamped` bounds 5 min and 12 h; `finish` on a due `.locked` session with a recording `Shielding` fake (see `TapoutTests/Fakes.swift`): shields cleared once, session `.unlocked`, `lastUnlockAt == now`, `timerLock == nil`, `finishedTimer == timer`, returns the timer; `finish` on a due timer during `.emergency` ends the pass too (session `.unlocked`); `finish` not due, no timer, or already `.unlocked`: returns nil and writes nothing. Store tests: both keys round-trip and read `nil` when absent or corrupt. `ScheduleActivityTests`: update the limit expectation to 18.
- [ ] **Step 2:** Run the suite; the new tests fail to compile or fail.
- [ ] **Step 3: Implement** as specified.
- [ ] **Step 4:** Run the suite, then both device builds. Expected: all pass, exit 0 and 0.
- [ ] **Step 5:** Write `.superpowers/sdd/p8-1-report.md` (what changed, test count, device build exit codes, suggested commit message `Phase 8: TimerLock and store keys`). Do not commit.

---

### Task 2: The engine and the monitor end a timer

**Files:**
- Modify: `Shared/RelockPlan.swift`, `Tapout/Engine/LockEngine.swift`, `Tapout/Engine/SimulatorStandIns.swift`, `TapoutMonitor/TapoutMonitor.swift`, `Shared/ScheduleNotice.swift`, `TapoutTests/Fakes.swift`, `TapoutTests/LockEngineTests.swift`, `TapoutTests/ScheduleRunTests.swift` (or a new `TimerMonitorTests.swift`)

**Interfaces:**
- Consumes: `TimerLock`, `SharedStore.timerLock/finishedTimer` (Task 1).
- Produces:
  - `enum TimerPlan { nonisolated(unsafe) static let activity = DeviceActivityName("tapout.timer") }`; `RelockScheduler` takes `activity: DeviceActivityName = RelockPlan.activity` (its `schedule`, `cancel` and `scheduledSummary` use it) and `RelockPlan.schedule(...)` is reused unchanged.
  - `LockEngine.init(..., timers: any RelockScheduling = NoRelock-like default)`; `LockEngine.live` passes `RelockScheduler(activity: TimerPlan.activity)` on device and `NoRelock()` in the simulator.
  - `func lockTimed(duration: TimeInterval) throws -> TimerLock` (throws `PassError`-style `TimerError.couldNotSchedule(String)`): returns the started timer; `@discardableResult`-free. Behaviour in order: guard `store.session == .unlocked` else throw `TimerError.alreadyLocked`; clamp the duration; schedule `timers.schedule(relockAt: endsAt, now:, strategy: store.relockStrategy)` first (a scheduling failure throws and writes nothing, so a timer never locks without a way to end); then `store.timerLock = timer`, `store.finishedTimer = nil`, session `.locked(since: now)`, `shields.apply(store.activeShieldPlan)`, log "Timer lock, N min". A simulator engine (`NoRelock`) still ends the timer through `tick()`.
  - `unlock()` also sets `store.timerLock = nil` and calls `timers.cancel()` (after the existing steps, like `relock.cancel()`).
  - `func finishTimerIfDue() -> TimerLock?`: runs `TimerLock.finish(store:shields:now:early: 0)`; on a result, `timers.cancel()`, `relock.cancel()` (an open pass's relock), log "Timer finished" and `reload()`; returns the timer.
  - `tick()` and `syncShields()` call `finishTimerIfDue()` first. `tick()` returns `true` for "relocked" today; add a separate `private(set) var finishedTimerPending: TimerLock?`-style published value: `engine.timerJustFinished` (a `TimerLock?`, set by `finishTimerIfDue`, cleared by `acknowledgeTimerFinish()`), so the UI can react. Keep `tick()`'s Bool meaning unchanged.
  - Monitor: `intervalWillEndWarning` and `intervalDidEnd` for `TimerPlan.activity` call `TimerLock.finish(store:..., shields: ShieldController(), now:, early: TimerLock.earlyTolerance)`, log "timer: finished" or "timer: not due yet"/"nothing to finish", post `ScheduleNotice.timerFinished(duration:)` through `LocalNotifier()` when it finished, reload widget timelines. The emergency relock callbacks, after `EmergencyRelock.perform`, also run the timer finish (a pass's relock must not re-lock a due timer): order is timer finish first, then the pass relock only if the session is still `.emergency`.
  - `ScheduleNotice.timerFinished(duration:) -> (title: String, body: String)`: title "Time's up", body "\(TimeFormat.short(duration)) locked. Your apps are open." (`TimeFormat` lives in `Tapout/Model`, not `Shared`: build the text inside `Shared` with a small private formatter that gives "45 min", "1 h" or "1 h 30 min").

- **Stale marker (from Task 1's review):** `TimerLock.finish` writes `finishedTimer` before clearing `timerLock`, so a crash between the two leaves both set with the session unlocked. `syncShields()` and `tick()` must clear a `timerLock` found while the session is `.unlocked` (and test it); `finishedTimer` is left for the app to close.

- [ ] **Step 1: Write failing tests** with the existing fakes (extend `FakeRelock` use: a second instance for `timers`): `lockTimed` locks, stores the timer, applies shields once, schedules `endsAt` with the stored strategy; refuses (throws, writes nothing) when locked; a scheduling failure throws and leaves the engine unlocked with no timer; `unlock()` clears the timer and cancels the timer schedule; `tick()` at `endsAt - 1` does nothing, at `endsAt` finishes (session unlocked, shields cleared, `finishedTimer` set, `timerJustFinished` set); `tick` finishing during an emergency pass leaves apps open and the session unlocked; `syncShields()` after a restart past `endsAt` finishes instead of re-applying shields; a not-timed lock is untouched by all of this. Monitor side (pure, through `TimerLock.finish` and the notice builder): the notice text for 45 min and 90 min; the "pass relock callback with a due timer" ordering as a store-level test calling the same helper the monitor uses (put the monitor's logic in a `Shared` function `TimerLock.runMonitorEnd(...)` returning the log line, so it is testable; the extension only calls it).
- [ ] **Step 2:** Run the suite; new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run the suite and both device builds.
- [ ] **Step 5:** Write `.superpowers/sdd/p8-2-report.md` with suggested message `Phase 8: engine and monitor end a timer lock`.

---

### Task 3: History and the model

**Files:**
- Modify: `Tapout/Model/AppModel.swift`, `TapoutTests/AppModelLockTests.swift`

**Interfaces:**
- Consumes: `LockEngine.lockTimed`, `SharedStore.timerLock/finishedTimer`.
- Produces on `AppModel`:
  - `var activeModeHasApps: Bool` (the active mode's `ShieldPlan` is non-empty, using the always-allowed apps like `activeShieldPlan` does).
  - `func startLock(placeUID:intention:)` already starts a record at `now()`; a timer lock calls it with `placeUID: nil` (no change to its signature). Nothing new there beyond a test that a nil place works.
  - `var timerLock: TimerLock?` (read from the store in `reload()`, like `currentIntention`).
  - `func finishLock(at end: Date) -> LockRecord?`: the existing `finishLock()` body with an explicit end (the existing one calls it with `now()`); the pass end uses the same instant. Never an end before `start`.
  - `func closeFinishedTimer() -> TimerFinish?` where `struct TimerFinish: Equatable { let timer: TimerLock; let record: LockRecord? }`: when `store.finishedTimer` is set, finishes the open record at `timer.endsAt`, clears `finishedTimer` (and `currentIntention`), returns it; otherwise nil.
  - `reconcile(with:)` changes: when the session is `.unlocked`, an open record exists and `store.finishedTimer` is set, **do not discard** it: leave it for `closeFinishedTimer()`. With no `finishedTimer`, the interrupted-lock rule is unchanged. While locked with a `timerLock`, nothing changes.
  - `discardInterruptedLocks()` keeps its rule but must not drop the record while `finishedTimer` is set.

- [ ] **Step 1: Write failing tests** (`AppModelLockTests`): `activeModeHasApps` false for an empty mode (a real selection can't be made in tests: expose the check through the `ShieldPlan.isEmpty` rule and test the empty case); a timer lock record with `placeUID` nil starts and finishes, counting in `phoneFreeToday`/`totalLocked`; `closeFinishedTimer()` ends the record exactly at `endsAt` even when `now` is an hour later, clears the marker, and is nil the second time; `reconcile(with: .unlocked)` with an open record and a `finishedTimer` keeps the record, and without the marker still discards it; a pass open at the end of the timer is shortened to `endsAt`; intention survives to the returned record for "Did you do it?".
- [ ] **Step 2:** Run the suite; new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run the suite and both device builds.
- [ ] **Step 5:** Report `.superpowers/sdd/p8-3-report.md`, suggested message `Phase 8: timer records in history`.

---

### Task 4: The screens

**Files:**
- Create: `Tapout/Features/Home/TimerSheet.swift`, `Tapout/Features/Home/TimerDoneView.swift`
- Modify: `Tapout/Features/Home/HomeView.swift`, `Tapout/App/RootView.swift`, `Tapout/Model/DemoData.swift` (+ DEBUG launch arguments in `LockEngine+Debug.swift`), `Tapout/Model/TimeFormat.swift` if a "ends at" helper is needed, `TapoutTests/TimeFormatTests.swift`

**Interfaces:**
- Consumes: `LockEngine.lockTimed`, `engine.timerJustFinished`, `AppModel.timerLock`, `activeModeHasApps`, `closeFinishedTimer()`, `finishLock(at:)`.
- Produces: `TimerSheet(modeName:, hasApps:, hasTags:, intention: Binding<String>, recent: [String], onStart: (TimeInterval) -> Void)`; `TimerDoneView(duration:, onDone:)`; `Cover.timerDone(TimeInterval)`; `HomeView` gets `onTimer: () -> Void`.

**Behaviour:**
- Home, unlocked: below the intention field, **Scan** (primary) with a **Timer** secondary button (`timer` SF Symbol) beside it (stacked at accessibility sizes). Timer opens the sheet; Start is off while the mode has no apps.
- Sheet: Fraunces large duration ("45 min", "1 h 30 min") above a native `DatePicker` in `.countDownTimer` style (5 min to 12 h, snapped to 1 min), preset chips (`ChoiceChip`: 15 min, 30 min, 45 min, 1 h, 2 h; selecting one sets the wheel), `IntentionField`, a footnote "Locks \(modeName)'s apps" (or "Choose apps in Modes first"), the no-tag line when none is paired, and **Start** (primary). Sheet detents `.medium`/`.large`; it scrolls at large text sizes.
- Start: `try engine.lockTimed(duration:)`, then `model.startLock(placeUID: nil, intention:)`, clear the draft, play the lock moment (existing `showingLockMoment`, `lockPlaceName` = "Timer"), and `await NoticePermission.request()` in its own task unless `-demoData`. A `couldNotSchedule` failure shows the existing rejection pattern? No: a short inline message in the sheet ("Couldn't start the timer. Try again.") and nothing locks.
- Locked state (a `timerLock` exists): ring = `remainingFraction`, count-down number via `TimerText`, label "Locked · timer" (accessibility: "Locked, timer, N minutes left"), "Ends at 3:45 PM" in `.tSubhead`/`inkTertiary`. Orb tap still scans to unlock early. Emergency pass link unchanged.
- Finish in the app: `RootView.runClock` sees `engine.timerJustFinished` after `tick()`: `Haptics.unlock()`, `model.closeFinishedTimer()` (a record with an intention queues the "Did you do it?" sheet after the cover, as `unlock()` does), `engine.acknowledgeTimerFinish()`, `cover = .timerDone(duration)`. On launch and on foreground (`.task`, `scenePhase == .active`), after `engine.syncShields()`, the same handling runs for a timer that finished while closed. The Time's up cover appears once; it waits behind other covers like milestones do (`afterCover`).
- `TimerDoneView`: calm, like the milestone cover but small: slate orb with a full ember ring, "Time's up" (Fraunces title), "\(duration) locked. Your apps are open." (SF Pro), **Done** primary button. Crossfade under Reduce Motion. A DEBUG Lab link in `MomentsGallery` shows it and the sheet.
- DEBUG: launch arguments `-demoTimer` (a locked timer of 45 min with 31:20 left, in `LockEngine.preview` terms) and `-demoTimerDone` (the Time's up cover on launch) for screenshots.
- Unlocking early with a tag clears the timer through `engine.unlock()` (Task 2); no new UI.

- [ ] **Step 1: Write failing tests** for the pure pieces: `TimeFormat` helpers (`TimeFormat.length(_:)` giving "45 min", "1 h", "1 h 30 min", "12 h" and its spoken form; `TimeFormat.clockTime(_:)` if used); the preset list is within `TimerLock.minimum...maximum`.
- [ ] **Step 2:** Run the suite; new tests fail.
- [ ] **Step 3: Implement the views and wiring.**
- [ ] **Step 4:** Run the suite and both device builds. Then verify in the simulator (iPhone 17, UDID 33A5EBE9-5D77-488C-85C0-FDBC419C7ECE) with `.superpowers/sdd/bin/shot`/`relaunch`: Home unlocked with the Timer button, the sheet (dark, light, large text), the locked countdown (`-demoTimer`), the Time's up cover (`-demoTimerDone`). Save screenshots to `.superpowers/sdd/shots/`. The simulator can't lock for real, but `NoRelock`/`NoShields` still end a timer through `tick()`, so also add a DEBUG `-demoTimerShort` argument (a locked timer with 8 s left) and watch it finish into the cover.
- [ ] **Step 5:** Report `.superpowers/sdd/p8-4-report.md`, suggested message `Phase 8: timer sheet, countdown and Time's up`.

---

### Task 5: Widgets and the Live Activity count down

**Files:**
- Modify: `Surfaces/LockSnapshot.swift`, `Surfaces/LockActivity.swift`, `Surfaces/LiveActivityViews.swift`, `Surfaces/WidgetFaces.swift`, `TapoutWidgets/*` as needed, `Tapout/Engine/LiveActivityController.swift`, `Tapout/Features/Lab/SurfaceGallery.swift`, `TapoutTests/LockSnapshotTests.swift`, `TapoutTests/SnapshotTimelineTests.swift`, `TapoutTests/LiveActivityPlanTests.swift`

**Interfaces:**
- `LockSnapshot` gains `var timerEndsAt: Date?` (a **field**, not a new `State` case, so existing switches keep compiling): set from `store.timerLock?.endsAt` while the session is `.locked` and the timer is not yet due, else nil. `LockSnapshot.timeline` adds an entry at `timerEndsAt` (the unlocked look) and ends the locked window there when it is sooner than 4 hours.
- `LockActivityAttributes.ContentState` gains the same optional end date (Codable, backwards compatible: absent decodes as nil). While it is set, the Live Activity and the faces show `Text(timerInterval: now...endsAt, countsDown: true)` with "left" instead of the count-up, in every Live Activity presentation (lock screen, expanded, compact, minimal) and the small and medium widgets; passes still show their own countdown when open. `LiveActivityPlan.decide` treats a changed end date as an update.
- Gallery: add a timer sample row (45 min timer, 31 min left; 10 h timer) so layout is checked at long and short lengths.

- [ ] **Step 1: Write failing tests:** snapshot from a store with a `timerLock` has the end date; none without or when due; the timeline includes an entry at the end that reads unlocked; `LiveActivityPlan` updates when only the end date changes; content state encodes and decodes with and without the field.
- [ ] **Step 2:** Run the suite; new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4:** Run the suite and both device builds; check the gallery on the simulator (dark, light, large text).
- [ ] **Step 5:** Report `.superpowers/sdd/p8-5-report.md`, suggested message `Phase 8: widgets and Live Activity count down`.
