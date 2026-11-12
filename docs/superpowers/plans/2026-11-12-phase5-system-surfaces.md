# Phase 5: System Surfaces Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A running lock shows as a Live Activity on the Lock Screen and in the Dynamic Island, Home Screen and Lock Screen widgets show the lock or today's and this week's phone-free time, and Insights shares a 1080 × 1920 weekly recap image.

**Architecture:** A pure `LockSnapshot` turns the App Group store into what every surface shows. Widget faces and Live Activity views live in a new `Surfaces/` folder compiled into both the app and a new `TapoutWidgets` extension, so the app's DEBUG gallery can show them. The app reloads widget timelines and syncs the Live Activity (through a pure `LiveActivityPlan`) whenever the lock state changes; the monitor reloads widgets after its own changes. The recap is a SwiftUI view rendered with `ImageRenderer`.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, ActivityKit, Swift Testing, XcodeGen. iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-11-phase5-design.md`. Read it, and the screen specs `design/screens/LiveActivity.dc.html`, `Widgets.dc.html`, `Recap.dc.html`.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Bundle IDs: app `com.raphymuthu.tapout`, monitor `.monitor`, shield `.shield`, widgets `com.raphymuthu.tapout.widgets` (new). App Group `group.com.raphymuthu.tapout` (the widgets need it).
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.inkTertiary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.slate`, `.slateInk`, `.slateLine`, `.slateGlow`, `.track`). No raw hex. The Dynamic Island is always dark (`.environment(\.colorScheme, .dark)`); the Lock Screen card and widgets follow the system appearance.
- Fraunces for titles and static numbers of 20pt and up, through `Typography.swift`. Timers in widgets and the Live Activity are `Text(date, style: .timer)` in SF Pro with `.monospacedDigit()`.
- Copy, exactly: "Locked", "Open", "Unlocked", "Relocks in", "today", "phone-free this week", "phone-free", "Tap a tag to unlock", "Sealed at <place>" (or "Sealed" with no place), "Week of <Mon d>". Very few words; no guilt, emoji or exclamation marks.
- `Shared/` stays free of SwiftUI and doesn't import ActivityKit or WidgetKit (it compiles into the monitor, which only adds `import WidgetKit` in its own file). `Surfaces/` may use SwiftUI, WidgetKit and ActivityKit.
- Every new view has `#Preview`s in dark and light (Dynamic Island content: dark only).
- **Never commit, stage or stash.** The user commits manually; each task ends with a suggested commit message.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

**Device compile check** (unsigned until the owner creates profiles for the new extensions; real exit code, no pipe):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device-nosign CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
```

**Test count chain:** 257 → 265 (Task 1) → 265 (Task 2) → 266 (Task 3) → 273 (Task 4) → 274 (Task 5). If a count differs, report it; never add or remove tests to hit a number.

## File map

| File | Responsibility |
| --- | --- |
| `Surfaces/LockSnapshot.swift` (new) | What every surface shows; refresh timing; samples |
| `Surfaces/WidgetFaces.swift` (new) | Small, medium, circular and rectangular faces |
| `Surfaces/LockActivity.swift` (new) | `LockActivityAttributes`, `LiveActivityPlan` |
| `Surfaces/LiveActivityViews.swift` (new) | Lock Screen card and Dynamic Island pieces |
| `TapoutWidgets/*` (new target) | Widget bundle, timeline provider, widgets, `ActivityConfiguration` |
| `Tapout/Engine/LiveActivityController.swift` (new) | Applies `LiveActivityPlan` with ActivityKit |
| `Tapout/Features/Lab/SurfaceGallery.swift` (new) | DEBUG gallery of the faces, for simulator screenshots |
| `Tapout/Features/Insights/RecapView.swift` (new) | The recap story and its renderer |
| `project.yml`, `Tapout/Model/Insights.swift`, `Tapout/Model/AppModel.swift`, `Tapout/Model/AppSettings.swift`, `Tapout/App/RootView.swift`, `Tapout/Features/Lab/LabView.swift`, `Tapout/Features/Insights/InsightsView.swift`, `TapoutMonitor/TapoutMonitor.swift` | Wiring |

---

### Task 1: What the surfaces show

**Files:**
- Create: `Surfaces/LockSnapshot.swift`, `TapoutTests/LockSnapshotTests.swift`
- Modify: `project.yml` (add `- path: Surfaces` to the `Tapout` target's sources), `Tapout/Model/Insights.swift` (`Day` becomes `Sendable`)

**Interfaces:**
- Produces: `struct LockSnapshot: Equatable, Sendable` with `enum State { case unlocked; case locked(countingFrom: Date); case open(relockAt: Date, resumesFrom: Date) }`, `state`, `modeName`, `placeName: String?`, `today`, `weekTotal`, `days: [Insights.Day]`; `static func make(store:now:calendar:)`; `func nextRefresh(after:calendar:) -> Date`; `static let placeholder`, `static func sample(_ state: State) -> LockSnapshot`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/LockSnapshotTests.swift`:

```swift
import Foundation
import Testing
@testable import Tapout

struct LockSnapshotTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()
    private let store = SharedStore.makeTest()
    /// Monday 2026-11-09, 2 PM.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 14))! }
    private let mode = Mode(name: "Deep work")
    private let kitchen = TagUID(hex: "04AA01")

    private func snapshot() -> LockSnapshot { .make(store: store, now: now, calendar: calendar) }

    @Test func unlockedShowsTodayAndTheWeek() {
        store.lockHistory = [LockRecord(start: now - 7200, end: now - 3600, placeUID: nil, modeID: mode.id)]
        let shot = snapshot()
        #expect(shot.state == .unlocked)
        #expect(shot.today == 3600)
        #expect(shot.weekTotal == 3600)
        #expect(shot.days.count == 7)
    }

    @Test func aLockCountsFromItsStartWithoutPasses() {
        store.session = .locked(since: now - 3600)
        store.lockHistory = [LockRecord(start: now - 3600, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 1800, duration: 600)])]
        #expect(snapshot().state == .locked(countingFrom: now - 3000))
    }

    @Test func aLockWithoutARecordCountsFromTheLockState() {
        store.session = .locked(since: now - 120)
        #expect(snapshot().state == .locked(countingFrom: now - 120))
    }

    @Test func aPassResumesTheTimerAfterTheRelock() {
        store.session = .emergency(relockAt: now + 200, duration: 300)
        store.lockHistory = [LockRecord(start: now - 1000, end: nil, placeUID: nil, modeID: mode.id,
                                        passes: [DateInterval(start: now - 100, end: now + 200)])]
        #expect(snapshot().state == .open(relockAt: now + 200, resumesFrom: now - 700))
    }

    @Test func namesTheActiveModeAndTheLocksPlace() {
        store.modes = [Mode(name: "Focus"), mode]
        store.activeModeID = mode.id
        store.pairedTags = [PairedTag(uid: kitchen, name: "Kitchen", pairedAt: now - 86_400)]
        store.session = .locked(since: now - 60)
        store.lockHistory = [LockRecord(start: now - 60, end: nil, placeUID: kitchen, modeID: mode.id)]
        let shot = snapshot()
        #expect(shot.modeName == "Deep work")
        #expect(shot.placeName == "Kitchen")
    }

    @Test func refreshesAtTheRelockDuringAPass() {
        let shot = LockSnapshot.sample(.open(relockAt: now + 200, resumesFrom: now - 700))
        #expect(shot.nextRefresh(after: now, calendar: calendar) == now + 200)
    }

    @Test func refreshesWithinAQuarterHourOtherwise() {
        #expect(LockSnapshot.sample(.unlocked).nextRefresh(after: now, calendar: calendar) == now + 900)
    }

    @Test func refreshesAtMidnightAtTheLatest() {
        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 23, minute: 55))!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        #expect(LockSnapshot.sample(.unlocked).nextRefresh(after: lateNight, calendar: calendar) == midnight)
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`LockSnapshot` doesn't exist).

- [ ] **Step 3: Implement.** In `project.yml`, add `- path: Surfaces` to the `Tapout` target's `sources` (after `- path: Shared`). In `Tapout/Model/Insights.swift`, `struct Day: Equatable` becomes `struct Day: Equatable, Sendable`.

Create `Surfaces/LockSnapshot.swift`:

```swift
import Foundation

/// What the Live Activity and the widgets show, worked out from the App Group store at one moment.
/// They run outside Tapout's model, so they read the store the monitor and the app share.
struct LockSnapshot: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case unlocked
        /// A timer counting up from `countingFrom` shows the lock's time without pass time.
        case locked(countingFrom: Date)
        /// An emergency pass: apps are open until `relockAt`; then the locked timer resumes from `resumesFrom`.
        case open(relockAt: Date, resumesFrom: Date)
    }

    var state: State
    var modeName: String
    var placeName: String?
    /// Locked time since midnight, without pass time.
    var today: TimeInterval
    /// Locked time this week, and per day for the bars.
    var weekTotal: TimeInterval
    var days: [Insights.Day]

    static func make(store: SharedStore, now: Date, calendar: Calendar = .current) -> LockSnapshot {
        let history = store.lockHistory
        let running = history.last { $0.end == nil }
        let modes = store.modes
        let mode = modes.first { $0.id == store.activeModeID } ?? modes.first
        let place = running?.placeUID.flatMap { uid in store.pairedTags.first { $0.uid == uid }?.name }
        let lockedSoFar = running?.lockedTime(now: now)
        let state: State
        switch store.session {
        case .unlocked:
            state = .unlocked
        case .locked(let since):
            // Without a record yet (a schedule just locked), the lock state's start is the best guess.
            state = .locked(countingFrom: now - (lockedSoFar ?? now.timeIntervalSince(since)))
        case .emergency(let relockAt, _):
            state = .open(relockAt: relockAt, resumesFrom: relockAt - (lockedSoFar ?? 0))
        }
        let today = calendar.dateInterval(of: .day, for: now)
            .map { Insights.lockedTime(in: $0, history: history, now: now) } ?? 0
        return LockSnapshot(
            state: state,
            modeName: mode?.name ?? "Focus",
            placeName: place,
            today: today,
            weekTotal: Insights.lockedTime(in: Insights.week(of: now, calendar: calendar), history: history, now: now),
            days: Insights.days(weekOf: now, history: history, now: now, calendar: calendar)
        )
    }

    /// When a widget should next redraw by itself. A running timer ticks on its own; totals need a
    /// redraw now and then, a pass needs one at its relock time, and everything needs one at midnight.
    func nextRefresh(after now: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                         matchingPolicy: .nextTime) ?? now + 3600
        switch state {
        case .open(let relockAt, _): return min(max(relockAt, now + 1), midnight)
        case .locked, .unlocked: return min(now + 15 * 60, midnight)
        }
    }

    /// For previews, the widget gallery and the widget placeholder.
    static func sample(_ state: State) -> LockSnapshot {
        let bars: [TimeInterval] = [2700, 1800, 3720, 2280, 6000, 4200, 1200]
        let monday = Calendar.current.startOfDay(for: .now)
        return LockSnapshot(
            state: state,
            modeName: "Deep work",
            placeName: "Kitchen",
            today: 9600,
            weekTotal: bars.reduce(0, +),
            days: bars.enumerated().map { index, time in
                Insights.Day(start: monday + Double(index) * 86_400, letter: ["M", "T", "W", "T", "F", "S", "S"][index],
                             lockedTime: time, isToday: index == 4)
            }
        )
    }

    static let placeholder = sample(.unlocked)
}
```

- [ ] **Step 4: Run the tests.** Expected: TEST SUCCEEDED, 265 tests.

- [ ] **Step 5: Suggested commit message:** `Add LockSnapshot: what the Live Activity and widgets show`

---

### Task 2: The widget extension

**Files:**
- Modify: `project.yml` (new `TapoutWidgets` target; the app depends on it)
- Create: `Surfaces/WidgetFaces.swift`, `TapoutWidgets/TapoutWidgetsBundle.swift`, `TapoutWidgets/SnapshotProvider.swift`, `TapoutWidgets/Widgets.swift` (XcodeGen writes `TapoutWidgets/Info.plist` and `TapoutWidgets/TapoutWidgets.entitlements`)

**Interfaces:**
- Consumes: Task 1's `LockSnapshot`.
- Produces: `SmallFace(snapshot:)`, `MediumFace(snapshot:)`, `CircularFace(snapshot:)`, `RectangularFace(snapshot:)`; widgets with kinds `"tapout.status"` (`.systemSmall`, `.accessoryCircular`, `.accessoryRectangular`) and `"tapout.week"` (`.systemMedium`); `TapoutWidgetsBundle` (Task 4 adds the Live Activity to it).

- [ ] **Step 1: Add the target.** In `project.yml`, add `- target: TapoutWidgets` to the `Tapout` target's `dependencies`, and this target after `TapoutShield`:

```yaml
  TapoutWidgets:
    type: app-extension
    platform: iOS
    sources:
      - path: TapoutWidgets
      - path: Surfaces
      - path: Shared
      - path: Tapout/DesignSystem/Colors.xcassets
      - path: Tapout/DesignSystem/Fonts
      - path: Tapout/DesignSystem/Color+Tokens.swift
      - path: Tapout/DesignSystem/Layout.swift
      - path: Tapout/DesignSystem/FrauncesFace.swift
      - path: Tapout/DesignSystem/Typography.swift
      - path: Tapout/Components/OrbView.swift
      - path: Tapout/Model/TimeFormat.swift
      - path: Tapout/Model/Insights.swift
    info:
      path: TapoutWidgets/Info.plist
      properties:
        CFBundleDisplayName: Tapout
        UIAppFonts:
          - Fraunces-TapoutDisplay.ttf
          - Fraunces-TapoutNumber.ttf
          - Fraunces-TapoutTitle.ttf
          - Fraunces-TapoutDisplayBold.ttf
          - Fraunces-TapoutNumberBold.ttf
          - Fraunces-TapoutTitleBold.ttf
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    entitlements:
      path: TapoutWidgets/TapoutWidgets.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.raphymuthu.tapout
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout.widgets
        TARGETED_DEVICE_FAMILY: "1"
```

If a file listed under `sources` pulls in a type the extension doesn't have, add the smallest extra file that defines it (never the whole `Tapout` folder) and say so. If a framework imported by `Shared/` is unavailable to widget extensions, report the exact error.

- [ ] **Step 2: Write the faces.** Create `Surfaces/WidgetFaces.swift`:

```swift
import SwiftUI
import WidgetKit

/// The widgets' faces, from design/screens/Widgets.dc.html. In `Surfaces/` so the app's DEBUG gallery
/// can show them too. Timers tick on their own with `Text(date, style: .timer)`.

/// Small: the lock with its timer, a pass with its countdown, or today's phone-free time.
struct SmallFace: View {
    let snapshot: LockSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            orb
            Spacer(minLength: 0)
            value
            label
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private var orb: some View {
        switch snapshot.state {
        case .locked: OrbView(tone: .ember, ring: 1, size: 64)
        case .open: OrbView(tone: .slate, ringTone: .ember, ring: 1, size: 64)
        case .unlocked: OrbView(tone: .slate, size: 64)
        }
    }

    @ViewBuilder private var value: some View {
        switch snapshot.state {
        case .locked(let from):
            Text(from, style: .timer).font(.system(size: 28, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
        case .open(let relockAt, _):
            Text(relockAt, style: .timer).font(.system(size: 28, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
        case .unlocked:
            Text(TimeFormat.short(snapshot.today)).font(.numberMedium).foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder private var label: some View {
        switch snapshot.state {
        case .locked: Text("Locked").font(.tCaption).foregroundStyle(Color.emberInk)
        case .open: Text("Open").font(.tCaption).foregroundStyle(Color.emberInk)
        case .unlocked: Text("today").font(.tCaption).foregroundStyle(Color.inkTertiary)
        }
    }
}

/// Medium: this week's phone-free time and a bar per day, today in ember.
struct MediumFace: View {
    let snapshot: LockSnapshot

    var body: some View {
        HStack(spacing: Space.md) {
            if case .unlocked = snapshot.state {
                OrbView(tone: .slate, size: 112)
            } else {
                OrbView(tone: .ember, ring: 1, size: 112)
            }
            VStack(alignment: .leading, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeFormat.short(snapshot.weekTotal)).font(.numberMedium).foregroundStyle(Color.ink)
                    Text("phone-free this week").font(.tCaption).foregroundStyle(Color.inkTertiary)
                }
                bars
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bars: some View {
        let peak = max(snapshot.days.map(\.lockedTime).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(snapshot.days, id: \.start) { day in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(day.isToday ? Color.ember : Color.surface2)
                    .frame(width: 10, height: 6 + 34 * day.lockedTime / peak)
            }
        }
        .frame(height: 40, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Lock Screen circular: iOS tints it, so it uses no token colours.
struct CircularFace: View {
    let snapshot: LockSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).widgetAccentable()
                Group {
                    switch snapshot.state {
                    case .locked(let from): Text(from, style: .timer)
                    case .open(let relockAt, _): Text(relockAt, style: .timer)
                    case .unlocked: Text(TimeFormat.short(snapshot.today))
                    }
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            .padding(4)
        }
    }

    private var symbol: String {
        if case .unlocked = snapshot.state { "lock.open" } else { "lock.fill" }
    }
}

/// Lock Screen rectangular: the state, the time, and the mode while locked.
struct RectangularFace: View {
    let snapshot: LockSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(title, systemImage: symbol).font(.headline).widgetAccentable()
            Group {
                switch snapshot.state {
                case .locked(let from): Text(from, style: .timer)
                case .open(let relockAt, _): Text("Relocks in \(Text(relockAt, style: .timer))")
                case .unlocked: Text("\(TimeFormat.short(snapshot.today)) today")
                }
            }
            .font(.body.monospacedDigit())
            if case .unlocked = snapshot.state {} else {
                Text(snapshot.modeName).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        switch snapshot.state {
        case .locked: "Locked"
        case .open: "Open"
        case .unlocked: "Unlocked"
        }
    }

    private var symbol: String {
        if case .unlocked = snapshot.state { "lock.open" } else { "lock.fill" }
    }
}
```

- [ ] **Step 3: Write the extension.** Create `TapoutWidgets/SnapshotProvider.swift`:

```swift
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: LockSnapshot
}

/// One entry from the shared store, redrawn by `LockSnapshot.nextRefresh` or when the app or the
/// monitor reloads the timelines after a change.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = entry(at: .now)
        completion(Timeline(entries: [entry], policy: .after(entry.snapshot.nextRefresh(after: entry.date))))
    }

    private func entry(at date: Date) -> SnapshotEntry {
        SnapshotEntry(date: date, snapshot: .make(store: .appGroup(), now: date))
    }
}
```

Create `TapoutWidgets/Widgets.swift`:

```swift
import SwiftUI
import WidgetKit

/// Small on the Home Screen; circular and rectangular on the Lock Screen.
struct StatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tapout.status", provider: SnapshotProvider()) { entry in
            StatusFamilyView(snapshot: entry.snapshot)
                .containerBackground(Color.surface1, for: .widget)
        }
        .configurationDisplayName("Tapout")
        .description("Locked, or phone-free today.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private struct StatusFamilyView: View {
    let snapshot: LockSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular: CircularFace(snapshot: snapshot)
        case .accessoryRectangular: RectangularFace(snapshot: snapshot)
        default: SmallFace(snapshot: snapshot)
        }
    }
}

/// Medium on the Home Screen: this week.
struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tapout.week", provider: SnapshotProvider()) { entry in
            MediumFace(snapshot: entry.snapshot)
                .containerBackground(Color.surface1, for: .widget)
        }
        .configurationDisplayName("This week")
        .description("Phone-free time this week.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("Small · locked", as: .systemSmall) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
    SnapshotEntry(date: .now, snapshot: .sample(.unlocked))
}

#Preview("Medium", as: .systemMedium) {
    WeekWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
}

#Preview("Circular", as: .accessoryCircular) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.locked(countingFrom: .now - 2832)))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    StatusWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
}
```

Create `TapoutWidgets/TapoutWidgetsBundle.swift`:

```swift
import SwiftUI
import WidgetKit

@main
struct TapoutWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        WeekWidget()
    }
}
```

The widget previews follow the canvas appearance; check them in dark and light.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 265 tests; device exit 0; the built app contains `PlugIns/TapoutWidgets.appex`.

- [ ] **Step 5: Suggested commit message:** `Add Home Screen and Lock Screen widgets`

---

### Task 3: Keep the widgets current, and a gallery to see them

**Files:**
- Modify: `Tapout/Model/AppModel.swift`, `Tapout/App/RootView.swift`, `TapoutMonitor/TapoutMonitor.swift`, `Tapout/Features/Lab/LabView.swift`
- Create: `Tapout/Features/Lab/SurfaceGallery.swift`
- Test: `TapoutTests/AppModelLockTests.swift`

**Interfaces:**
- Consumes: Task 1's `LockSnapshot`; Task 2's faces.
- Produces: `AppModel.lockSnapshot(at: Date) -> LockSnapshot`; `RootView.refreshSurfaces()` (Task 4 extends it); DEBUG `SurfaceGallery`.

- [ ] **Step 1: Write the failing test.** Add inside `struct AppModelLockTests`:

```swift
    @Test func theSnapshotComesFromTheSameStore() {
        let model = pairedModel()
        model.startLock(placeUID: kitchen, intention: nil)
        store.session = .locked(since: clock.now)
        clock.now += 600
        let snapshot = model.lockSnapshot(at: clock.now)
        #expect(snapshot.state == .locked(countingFrom: clock.now - 600))
        #expect(snapshot.placeName == "Kitchen")
    }
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`lockSnapshot` doesn't exist).

- [ ] **Step 3: Implement.** In `AppModel`, add:

```swift
    /// What the Live Activity and the widgets show now, from the same store they read.
    func lockSnapshot(at date: Date) -> LockSnapshot {
        LockSnapshot.make(store: store, now: date)
    }
```

In `Tapout/App/RootView.swift`, add `import WidgetKit` and:

```swift
    /// Widgets and the Live Activity read the store; tell them it changed.
    private func refreshSurfaces() {
        WidgetCenter.shared.reloadAllTimelines()
    }
```

Call `refreshSurfaces()` at the end of the `.onChange(of: engine.session)` closure (after `model.reconcile`), in the scene-phase `.active` branch (last), and in `.task` before `await runClock()`.

In `TapoutMonitor/TapoutMonitor.swift`, add `import WidgetKit`, and call `WidgetCenter.shared.reloadAllTimelines()` at the end of `intervalDidStart` (after logging) and at the end of `relock(_:callback:)` when it relocked.

Create `Tapout/Features/Lab/SurfaceGallery.swift`:

```swift
#if DEBUG
import SwiftUI
import WidgetKit

/// DEBUG-only: the widget faces at their real sizes, for the live store and three sample states, so
/// the simulator can show and screenshot them without adding widgets by hand.
struct SurfaceGallery: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    row("Now", model.lockSnapshot(at: context.date))
                }
                row("Locked", .sample(.locked(countingFrom: .now - 2832)))
                row("Open", .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
                row("Unlocked", .sample(.unlocked))
            }
            .padding(Space.md)
        }
        .background(Color.bg)
        .navigationTitle("Widgets")
    }

    private func row(_ title: String, _ snapshot: LockSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(.tHeadline)
            HStack(alignment: .top, spacing: Space.sm) {
                tile(SmallFace(snapshot: snapshot), width: 170, height: 170)
                VStack(spacing: Space.sm) {
                    tile(CircularFace(snapshot: snapshot), width: 76, height: 76, radius: 38)
                    tile(RectangularFace(snapshot: snapshot), width: 172, height: 76, radius: 16)
                }
            }
            tile(MediumFace(snapshot: snapshot), width: 364, height: 170)
        }
    }

    private func tile(_ face: some View, width: CGFloat, height: CGFloat, radius: CGFloat = 22) -> some View {
        face
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
#endif
```

In `LabView`, `LabView` needs the model to show the live snapshot: give it `let model: AppModel` (update its only caller in `SettingsView`, which has `model`), and add a section before `logSection`:

```swift
            Section("Surfaces") {
                NavigationLink("Widgets") { SurfaceGallery(model: model) }
            }
```

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 266 tests; device exit 0.

- [ ] **Step 5: Suggested commit message:** `Refresh widgets on every lock change; add a DEBUG widget gallery`

---

### Task 4: The Live Activity

**Files:**
- Create: `Surfaces/LockActivity.swift`, `Surfaces/LiveActivityViews.swift`, `TapoutWidgets/LockActivityWidget.swift`, `Tapout/Engine/LiveActivityController.swift`, `TapoutTests/LiveActivityPlanTests.swift`
- Modify: `TapoutWidgets/TapoutWidgetsBundle.swift`, `project.yml` (app Info.plist: `NSSupportsLiveActivities: true`), `Tapout/Model/AppSettings.swift`, `Tapout/App/RootView.swift`, `Tapout/Features/Lab/SurfaceGallery.swift`

**Interfaces:**
- Consumes: Task 1's `LockSnapshot`; Task 3's `refreshSurfaces()`, `lockSnapshot(at:)`.
- Produces: `LockActivityAttributes` with `ContentState { lockedFrom: Date, openUntil: Date?, modeName: String, placeName: String? }`; `LiveActivityPlan.content(for:)`, `LiveActivityPlan.decide(snapshot:enabled:current:) -> Action` (`.none`, `.start(state)`, `.update(state)`, `.end`); `LiveActivityController.sync(_:enabled:)`; `AppSettings.liveActivityEnabled(in:)`; `LockScreenCard(state:isStale:)`, `IslandTimer(state:isStale:compact:)`.

- [ ] **Step 1: Write the failing tests.** Create `TapoutTests/LiveActivityPlanTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`LiveActivityPlan` doesn't exist).

- [ ] **Step 3: Implement the model.** Create `Surfaces/LockActivity.swift`:

```swift
import ActivityKit
import Foundation

/// The lock's Live Activity. Everything it shows is in the content state; no static attributes.
struct LockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// The locked timer counts up from here, so it leaves out pass time.
        var lockedFrom: Date
        /// During an emergency pass, apps are open until then. Also the activity's stale date, so it
        /// shows the locked timer again after the relock even if Tapout stays closed.
        var openUntil: Date?
        var modeName: String
        var placeName: String?
    }
}

/// What to do with the Live Activity so it matches the lock. Pure, so it can be tested.
enum LiveActivityPlan {
    enum Action: Equatable {
        case none
        case start(LockActivityAttributes.ContentState)
        case update(LockActivityAttributes.ContentState)
        case end
    }

    /// nil while unlocked. Dates are whole seconds, so recomputing a snapshot doesn't cause updates.
    static func content(for snapshot: LockSnapshot) -> LockActivityAttributes.ContentState? {
        func whole(_ date: Date) -> Date { Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded()) }
        switch snapshot.state {
        case .unlocked:
            return nil
        case .locked(let from):
            return .init(lockedFrom: whole(from), openUntil: nil, modeName: snapshot.modeName, placeName: snapshot.placeName)
        case .open(let relockAt, let resumesFrom):
            return .init(lockedFrom: whole(resumesFrom), openUntil: whole(relockAt), modeName: snapshot.modeName, placeName: snapshot.placeName)
        }
    }

    static func decide(snapshot: LockSnapshot, enabled: Bool, current: LockActivityAttributes.ContentState?) -> Action {
        guard enabled, let wanted = content(for: snapshot) else { return current == nil ? .none : .end }
        guard let current else { return .start(wanted) }
        return current == wanted ? .none : .update(wanted)
    }
}
```

In `Tapout/Model/AppSettings.swift`, replace the `liveActivityKey` doc comment with `/// The Live Activity for a running lock. On unless the owner turned it off.` and add:

```swift
    static func liveActivityEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: liveActivityKey) as? Bool ?? true
    }
```

Create `Tapout/Engine/LiveActivityController.swift`:

```swift
import ActivityKit
import Foundation

/// Starts, updates and ends the lock's Live Activity to match `LiveActivityPlan`. ActivityKit lets the
/// app start one only while it's in the foreground, so a lock a schedule started appears the next time
/// Tapout opens. Never more than one.
@MainActor
enum LiveActivityController {
    static func sync(_ snapshot: LockSnapshot, enabled: Bool) {
        let activities = Activity<LockActivityAttributes>.activities
        let allowed = enabled && ActivityAuthorizationInfo().areActivitiesEnabled
        let action = LiveActivityPlan.decide(snapshot: snapshot, enabled: allowed, current: activities.first?.content.state)
        let extras = Array(activities.dropFirst())
        switch action {
        case .none:
            end(extras)
        case .end:
            end(activities)
        case .start(let state):
            end(extras)
            _ = try? Activity.request(attributes: LockActivityAttributes(),
                                      content: ActivityContent(state: state, staleDate: state.openUntil),
                                      pushType: nil)
        case .update(let state):
            end(extras)
            guard let id = activities.first?.id else { return }
            Task {
                let activity = Activity<LockActivityAttributes>.activities.first { $0.id == id }
                await activity?.update(ActivityContent(state: state, staleDate: state.openUntil))
            }
        }
    }

    private static func end(_ activities: [Activity<LockActivityAttributes>]) {
        let ids = activities.map(\.id)
        guard !ids.isEmpty else { return }
        Task {
            for activity in Activity<LockActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
```

If Swift 6 rejects these `Task` closures, keep the logic and report the smallest fix you used.

In `project.yml`, add `NSSupportsLiveActivities: true` to the `Tapout` target's `info.properties`.

In `Tapout/App/RootView.swift`, add `@AppStorage(AppSettings.liveActivityKey) private var liveActivity = true`, extend `refreshSurfaces()`:

```swift
    /// Widgets and the Live Activity read the store; tell them it changed.
    private func refreshSurfaces() {
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityController.sync(model.lockSnapshot(at: .now), enabled: liveActivity)
    }
```

and add `.onChange(of: liveActivity) { _, _ in refreshSurfaces() }` beside the other `onChange` handlers.

- [ ] **Step 4: Write the views.** Create `Surfaces/LiveActivityViews.swift`:

```swift
import SwiftUI

/// The Live Activity from design/screens/LiveActivity.dc.html. During a pass (and until its stale date),
/// a slate orb, "Open" and the countdown; otherwise the ember orb and the locked timer.
private func isOpen(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> Bool {
    state.openUntil != nil && !isStale
}

/// The Lock Screen card. Follows the system appearance.
struct LockScreenCard: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let open = isOpen(state, isStale: isStale)
        HStack(spacing: Space.md) {
            OrbView(tone: open ? .slate : .ember, ringTone: .ember, ring: 1, size: 80)
            VStack(alignment: .leading, spacing: Space.xxs) {
                if open, let until = state.openUntil {
                    Text("Open").font(.tCaption).foregroundStyle(Color.emberInk)
                    Text(until, style: .timer).font(.system(size: 34, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
                } else {
                    Text(state.lockedFrom, style: .timer).font(.system(size: 34, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
                }
                Label(caption, systemImage: "lock").font(.tSubhead).foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private var caption: String {
        state.placeName.map { "\(state.modeName) · \($0)" } ?? state.modeName
    }
}

/// The Dynamic Island's orb; the island is always dark.
struct IslandOrb: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    let size: CGFloat

    var body: some View {
        OrbView(tone: isOpen(state, isStale: isStale) ? .slate : .ember, ringTone: .ember, ring: 1, size: size)
            .environment(\.colorScheme, .dark)
    }
}

/// The island's timer: the countdown during a pass, the locked timer otherwise.
struct IslandTimer: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    var compact = false

    var body: some View {
        Group {
            if isOpen(state, isStale: isStale), let until = state.openUntil {
                Text(until, style: .timer)
            } else {
                Text(state.lockedFrom, style: .timer)
            }
        }
        .font(.system(size: compact ? 14 : 28, weight: compact ? .semibold : .light).monospacedDigit())
        .foregroundStyle(Color.emberInk)
        .frame(maxWidth: compact ? 56 : nil)
        .environment(\.colorScheme, .dark)
    }
}

/// The expanded island's middle: the mode and where it was sealed.
struct IslandTitle: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isOpen(state, isStale: isStale) ? "Open" : state.modeName).font(.tHeadline).foregroundStyle(Color.ink)
            Text(state.placeName.map { "Sealed at \($0)" } ?? "Sealed").font(.tCaption).foregroundStyle(Color.inkTertiary)
        }
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Lock Screen · dark") {
    LockScreenCard(state: .init(lockedFrom: .now - 2832, openUntil: nil, modeName: "Deep work", placeName: "Kitchen"), isStale: false)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · light, open") {
    LockScreenCard(state: .init(lockedFrom: .now - 2832, openUntil: .now + 272, modeName: "Deep work", placeName: "Kitchen"), isStale: false)
        .background(Color.surface1).preferredColorScheme(.light)
}
```

Create `TapoutWidgets/LockActivityWidget.swift`:

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct LockActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockActivityAttributes.self) { context in
            LockScreenCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.surface1)
                .activitySystemActionForegroundColor(Color.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandOrb(state: context.state, isStale: context.isStale, size: 64)
                }
                DynamicIslandExpandedRegion(.center) {
                    IslandTitle(state: context.state, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandTimer(state: context.state, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label("Tap a tag to unlock", systemImage: "wave.3.right")
                        .font(.tCaption)
                        .foregroundStyle(Color.inkTertiary)
                        .environment(\.colorScheme, .dark)
                }
            } compactLeading: {
                IslandOrb(state: context.state, isStale: context.isStale, size: 26)
            } compactTrailing: {
                IslandTimer(state: context.state, isStale: context.isStale, compact: true)
            } minimal: {
                IslandOrb(state: context.state, isStale: context.isStale, size: 26)
            }
            .keylineTint(Color.ember)
        }
    }
}
```

In `TapoutWidgets/TapoutWidgetsBundle.swift`, add `LockActivityWidget()` after `WeekWidget()`.

In `SurfaceGallery`, add after the widget rows a "Live Activity" row showing `LockScreenCard` (locked and open samples, 364 wide) and, on a black capsule, `IslandOrb` + `IslandTimer(compact: true)` as the compact island.

- [ ] **Step 5: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 273 tests; device exit 0.

- [ ] **Step 6: Suggested commit message:** `Add the lock's Live Activity and Dynamic Island`

---

### Task 5: The weekly recap image

**Files:**
- Create: `Tapout/Features/Insights/RecapView.swift`, `TapoutTests/RecapImageTests.swift`
- Modify: `Tapout/Features/Insights/InsightsView.swift` (the Share button)

**Interfaces:**
- Consumes: `Insights.days`, `Insights.week`, `Comparison.best(for:interests:)`, `Comparison.asLongAs(_:)`, `OrbView`, `TimeFormat`.
- Produces: `RecapView(weekStart:total:days:comparison:)` (360 × 640 points, `static let size`); `RecapImage.render(_:colorScheme:) -> UIImage?` at scale 3 (1080 × 1920 pixels).

- [ ] **Step 1: Write the failing test.** Create `TapoutTests/RecapImageTests.swift`:

```swift
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct RecapImageTests {
    @Test func rendersAStorySizedImage() throws {
        let sample = LockSnapshot.sample(.unlocked)
        let view = RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                             comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        let image = try #require(RecapImage.render(view, colorScheme: .dark))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }
}
```

- [ ] **Step 2: Run the tests.** Expected: the build fails (`RecapView` doesn't exist).

- [ ] **Step 3: Implement.** Create `Tapout/Features/Insights/RecapView.swift`. Lay it out from `design/screens/Recap.dc.html` at one third of its pixel sizes (it is 1080 × 1920 px; this view is 360 × 640 points rendered at 3×), with the tokens and fonts the constraints name:

```swift
import SwiftUI

/// The weekly recap story from design/screens/Recap.dc.html, laid out at 360 × 640 points and
/// rendered at 3× into a 1080 × 1920 image for sharing (Instagram Stories' size).
struct RecapView: View {
    let weekStart: Date
    let total: TimeInterval
    let days: [Insights.Day]
    let comparison: Comparison?

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tapout").font(.tTitle).foregroundStyle(Color.ink)
                Spacer()
                Text("Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.tSubhead).foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
            OrbView(tone: .ember, ring: 1, size: 187)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                Text(TimeFormat.short(total)).font(.numberDisplay).foregroundStyle(Color.ink)
                Text("phone-free").font(.tBody).foregroundStyle(Color.inkSecondary)
            }
            if let comparison {
                HStack(spacing: Space.sm) {
                    Image(systemName: comparison.symbol)
                        .font(.system(size: 22))
                        .foregroundStyle(Color.emberInk)
                        .frame(width: 44, height: 44)
                        .background(Color.emberGlow, in: Circle())
                    Text(comparison.asLongAs(total)).font(.tTitle).foregroundStyle(Color.ink)
                    Spacer(minLength: 0)
                }
                .padding(Space.md)
                .background(Color.surface1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .padding(.top, Space.lg)
            }
            bars.padding(.top, Space.lg)
        }
        .padding(Space.lg)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.bg)
    }

    private var bars: some View {
        let peak = max(days.map(\.lockedTime).max() ?? 0, 1)
        return VStack(spacing: Space.xs) {
            HStack(alignment: .bottom, spacing: Space.xs) {
                ForEach(days, id: \.start) { day in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(day.isToday ? Color.ember : Color.surface2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 8 + 45 * day.lockedTime / peak)
                }
            }
            .frame(height: 56, alignment: .bottom)
            HStack(spacing: Space.xs) {
                ForEach(days, id: \.start) { day in
                    Text(day.letter).font(.tCaption).foregroundStyle(Color.inkTertiary).frame(maxWidth: .infinity)
                }
            }
        }
    }
}

enum RecapImage {
    /// The recap at 3×: 1080 × 1920 pixels.
    @MainActor static func render(_ view: RecapView, colorScheme: ColorScheme) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, colorScheme))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(RecapView.size)
        return renderer.uiImage
    }
}

#Preview("Recap · dark") {
    let sample = LockSnapshot.sample(.unlocked)
    return RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                     comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        .preferredColorScheme(.dark)
}

#Preview("Recap · light") {
    let sample = LockSnapshot.sample(.unlocked)
    return RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                     comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        .preferredColorScheme(.light)
}
```

Compare it with `Recap.dc.html` and adjust spacing and sizes to match (keep 360 × 640).

In `Tapout/Features/Insights/InsightsView.swift`: add `@State private var recap: Image?` and `@Environment(\.colorScheme) private var colorScheme`. Where the hero total is computed, attach `.task(id: TimeFormat.short(total))` (a change of the shown total, at most once a minute) that renders `RecapView(weekStart: Insights.week(of: now, calendar: calendar).start, total: total, days: Insights.days(weekOf: now, history: model.history, now: now, calendar: calendar), comparison: Comparison.best(for: total, interests: model.interests))` with `RecapImage.render(_:colorScheme:)` and stores `Image(uiImage:)` in `recap`. The Share button becomes:

```swift
                if let recap {
                    ShareLink(item: recap,
                              message: Text("\(TimeFormat.short(total)) phone-free this week, with Tapout."),
                              preview: SharePreview("Your week", image: recap)) {
                        shareIcon
                    }
                    .accessibilityLabel("Share")
                } else {
                    ShareLink(item: "\(TimeFormat.short(total)) phone-free this week, with Tapout.") { shareIcon }
                        .accessibilityLabel("Share")
                }
```

with the existing icon (`Image(systemName: "square.and.arrow.up")` and its modifiers) moved into a `shareIcon` property. Keep the `total > 0` condition around the button.

- [ ] **Step 4: Run the tests and the device compile check.** Expected: TEST SUCCEEDED, 274 tests; device exit 0.

- [ ] **Step 5: Suggested commit message:** `Share a weekly recap image from Insights`

---

### Task 6: Verify

- [ ] **Step 1:** Run the build/test command and the device compile check (Debug, and Release with `-configuration Release -derivedDataPath <scratch>`). Expected: 274 tests, no warnings from `Tapout/`, `Shared/`, `Surfaces/`, `TapoutTests/`, `TapoutMonitor/`, `TapoutShield/` or `TapoutWidgets/`, all exits 0.
- [ ] **Step 2: Simulator, dark and light.**
  - Settings → Lab → Widgets: every face for Now, Locked, Open and Unlocked; compare with `Widgets.dc.html`.
  - Lock with `-demoData`, then press Home: the compact Dynamic Island (orb and timer). Long-press the island for the expanded view. Lock the simulator (side button): the Lock Screen card. Use a pass: "Open" and the countdown. Relock: the locked timer leaves out the pass time. Unlock: the activity ends.
  - Settings → Live Activity off while locked: the activity ends; on again: it returns.
  - Insights → Share: the share sheet previews the recap image; save it to Photos and check it is 1080 × 1920 and matches `Recap.dc.html`.
  - Save contact sheets as `docs/superpowers/verification/phase5-*.png`.
- [ ] **Step 3: iPhone run (the user's; give these steps exactly).** First, in Xcode, select the TapoutWidgets target, open Signing & Capabilities, and let Xcode create its profile (and TapoutShield's if not done). Then install.
  1. Add the small and medium widgets to the Home Screen, and the circular and rectangular widgets to the Lock Screen.
  2. Lock with your tag: every widget shows Locked with a ticking timer; the Dynamic Island and the Lock Screen show the Live Activity.
  3. Use an emergency pass: "Open" with the countdown everywhere. Close Tapout and wait for the relock: the Live Activity and widgets show the locked timer again, without the 5 minutes.
  4. Unlock: the Live Activity ends; widgets show today's time.
  5. Let a schedule lock while Tapout is closed: widgets update (within a minute or so). Tap the notification to open Tapout: the Live Activity starts.
  6. Settings → Live Activity off and on while locked.
  7. Share the recap from Insights to Instagram Stories or Photos.
  8. Report each result.
- [ ] **Step 4:** Report, leaving all changes uncommitted, with the suggested message `Phase 5: Live Activity, widgets and the weekly recap`.

## Notes for later

- Push-started Live Activities would let a scheduled lock show one while Tapout stays closed; that needs a server (out of scope for v1).
- Widgets are not interactive; a "Lock" button would need an App Intent and a tag tap anyway.
- The Live Activity ends after 8 hours on its own (an iOS limit); a longer lock keeps running, and the activity returns the next time Tapout opens.
