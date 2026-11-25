# Phase 10: Home and the Lock Moment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** With the Lab's Living glass switch on: route every lock and unlock haptic through the new patterns, warm the background behind the glass orb, play the lock moment with one glass orb, show the glass orb on Time's up and the milestone, and replace the timer wheel with a two-lap dial (5 min to 2 h). With the switch off, nothing changes.

**Architecture:** One `LivingGlassReader` view decides glass or classic for everything. `LivingFeedback` routes haptics on the switch. `DialMath` is pure and tested; `TimerDial` draws it. `OrbWarmth` is a token-colored glow circle that `LivingOrb` puts behind the glass orb.

**Tech Stack:** SwiftUI, Swift Testing, the Phase 9 effects (`Tapout/Effects/`).

## Global Constraints

See `.superpowers/sdd/p10-constraints.md`. Key lines: iOS 17 floor, Swift 6, no packages; the Debug-only switch gates everything and switch-off must be unchanged; no logic changes; never commit, stage or stash; tests start at 478.

## File Structure

| File | Responsibility |
| --- | --- |
| `Tapout/Effects/LivingOrb.swift` (modify) | Add `LivingGlassReader`; `LivingOrb` uses it; `warmth` parameter. |
| `Tapout/Effects/LivingFeedback.swift` (new) | `HapticRoute` (pure) and `LivingFeedback.lock()/unlock()`. |
| `Tapout/Effects/OrbWarmth.swift` (new) | The glow circle that warms or cools on appear. |
| `Tapout/Effects/DialMath.swift` (new) | Pure angle, drag, snap and tick maths for the two-lap dial. |
| `Tapout/Features/Home/TimerDial.swift` (new) | The dial view. |
| `Tapout/Features/Home/TimerSheet.swift` (modify) | Dial or wheel; the Longer chip. |
| `Tapout/Features/Home/HomeView.swift`, `LockMomentView.swift`, `TimerDoneView.swift`, `Tapout/Features/Insights/MilestoneView.swift`, `Tapout/App/RootView.swift`, `Tapout/Features/EmergencyPass/EmergencyPassView.swift` (modify) | Wiring. |

---

### Task 1: One reader and the haptic route

**Files:**
- Modify: `Tapout/Effects/LivingOrb.swift`
- Create: `Tapout/Effects/LivingFeedback.swift`
- Modify (call sites): `Tapout/Features/Home/LockMomentView.swift` (the `if AppSettings.livingGlassEnabled()` block from Phase 9), `Tapout/Features/Home/HomeView.swift` (`relockNow`), `Tapout/App/RootView.swift` (`unlock()`, `present(_:heard:)`, `runClock()`), `Tapout/Features/EmergencyPass/EmergencyPassView.swift` (the pass use)
- Test: `TapoutTests/LivingFeedbackTests.swift`, extend `TapoutTests/LivingOrbTests.swift` if needed

**Interfaces:**
- Produces: `struct LivingGlassReader<Content: View>: View` with `init(@ViewBuilder content: @escaping (LivingOrbChoice) -> Content)`. It owns what `LivingOrb` reads today (the Debug-only stored flag, Reduce Motion, scene phase, `MotionEnvironment.shared`, `GlassOrbShader.isAvailable` only when the flag is on) and calls `content` with `LivingOrbChoice.choose(...)`.
- Produces: `enum HapticRoute: Equatable { case classic, engine; static func choose(livingGlass: Bool) -> HapticRoute }`; `@MainActor enum LivingFeedback { static func lock(); static func unlock() }`.

- [ ] **Step 1: Write the failing test**

```swift
// TapoutTests/LivingFeedbackTests.swift
import Testing
@testable import Tapout

struct LivingFeedbackTests {
    @Test func theSwitchChoosesTheEngine() {
        #expect(HapticRoute.choose(livingGlass: true) == .engine)
        #expect(HapticRoute.choose(livingGlass: false) == .classic)
    }
}
```

- [ ] **Step 2: Run to verify it fails.**

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/LivingFeedback.swift
import Foundation

/// Which haptics a lock or unlock plays.
enum HapticRoute: Equatable {
    case classic, engine

    static func choose(livingGlass: Bool) -> HapticRoute { livingGlass ? .engine : .classic }
}

/// Lock and unlock haptics for the whole app: the Core Haptics patterns with the Living glass switch on,
/// today's `Haptics` with it off (the switch is Debug-only, so Release always plays today's).
@MainActor
enum LivingFeedback {
    static func lock() {
        switch HapticRoute.choose(livingGlass: AppSettings.livingGlassEnabled()) {
        case .engine: HapticEngine.shared.play(.lock)
        case .classic: Haptics.lock()
        }
    }

    static func unlock() {
        switch HapticRoute.choose(livingGlass: AppSettings.livingGlassEnabled()) {
        case .engine: HapticEngine.shared.play(.unlock)
        case .classic: Haptics.unlock()
        }
    }
}
```

Move `LivingOrb`'s reading of the flag and environment into `LivingGlassReader` (same file), keeping every behaviour from the Phase 9 fixes: the flag reads false outside DEBUG, only `.background` counts as inactive (`LivingOrbChoice.sceneCountsAsActive`), the shader is probed only when the flag is on. `LivingOrb.body` becomes `LivingGlassReader { choice in switch choice { ... } }` with the same two branches as today.

Replace every `Haptics.lock()` and `Haptics.unlock()` call outside `Tapout/Effects/` and `Tapout/DesignSystem/Haptics.swift` with `LivingFeedback.lock()` / `.unlock()`, including the Phase 9 `if AppSettings.livingGlassEnabled()` block in `LockMomentView.play()`. Check with `grep -rn "Haptics.lock()\|Haptics.unlock()" Tapout --include='*.swift'`: only `LivingFeedback`, `HapticEngine` (fallback) and `Haptics.swift` itself may remain.

- [ ] **Step 4: Run the full suite and both device builds.** Switch-off behaviour is unchanged by construction (`.classic` calls the same functions).
- [ ] **Step 5: Report.** Suggested message: `Phase 10: one living-glass reader and the haptic route`.

---

### Task 2: The two-lap timer dial

**Files:**
- Create: `Tapout/Effects/DialMath.swift`, `Tapout/Features/Home/TimerDial.swift`
- Modify: `Tapout/Features/Home/TimerSheet.swift`
- Test: `TapoutTests/DialMathTests.swift`, extend the timer sheet tests if any exist (search `TimerSheet` in `TapoutTests`)

**Interfaces:**
- Consumes: `LivingGlassReader` (Task 1), `HapticEngine.shared.play(.detent)`, `TimeFormat.length`, `TimeFormat.spokenLength`, `TimerSheet.presets`.
- Produces: `enum DialMath` (below); `struct TimerDial: View` with `init(minutes: Binding<Int>)`; `TimerSheet` shows the dial when the reader says `.glass`, the text size is not an accessibility size and VoiceOver is off.

- [ ] **Step 1: Write the failing tests**

```swift
// TapoutTests/DialMathTests.swift
import Testing
@testable import Tapout

struct DialMathTests {
    @Test func anglesRunClockwiseFromTwelve() {
        #expect(DialMath.angle(dx: 0, dy: -10) == 0)
        #expect(abs(DialMath.angle(dx: 10, dy: 0) - 90) < 0.0001)
        #expect(abs(DialMath.angle(dx: 0, dy: 10) - 180) < 0.0001)
        #expect(abs(DialMath.angle(dx: -10, dy: 0) - 270) < 0.0001)
    }

    @Test func deltaTakesTheShortWayAcrossTwelve() {
        #expect(abs(DialMath.delta(from: 350, to: 10) - 20) < 0.0001)
        #expect(abs(DialMath.delta(from: 10, to: 350) + 20) < 0.0001)
        #expect(abs(DialMath.delta(from: 90, to: 120) - 30) < 0.0001)
    }

    @Test func draggingPastTwelveStartsTheSecondLap() {
        // 55 min, then a drag from 330° to 30° (60° clockwise = 10 min).
        #expect(abs(DialMath.dragged(minutes: 55, from: 330, to: 30) - 65) < 0.0001)
    }

    @Test func draggingBackPastTwelveReturnsToTheFirstLap() {
        #expect(abs(DialMath.dragged(minutes: 65, from: 30, to: 330) - 55) < 0.0001)
    }

    @Test func theDialStopsAtFiveMinutesAndTwoHours() {
        #expect(DialMath.dragged(minutes: 118, from: 0, to: 90) == 120)
        #expect(DialMath.dragged(minutes: 7, from: 90, to: 0) == 5)
    }

    @Test func valuesSnapToFiveMinutes() {
        #expect(DialMath.snapped(62.4) == 60)
        #expect(DialMath.snapped(63) == 65)
        #expect(DialMath.snapped(2) == 5)
        #expect(DialMath.snapped(200) == 120)
    }

    @Test func ticksFillTheOuterRingThenTheInner() {
        #expect(DialMath.litTicks(minutes: 45) == DialMath.Ticks(outer: 45, inner: 0))
        #expect(DialMath.litTicks(minutes: 85) == DialMath.Ticks(outer: 60, inner: 25))
        #expect(DialMath.litTicks(minutes: 120) == DialMath.Ticks(outer: 60, inner: 60))
    }

    @Test func theHandleSitsOnTheRingOfItsLap() {
        #expect(DialMath.handle(minutes: 45) == DialMath.Handle(angle: 270, lap: 0))
        #expect(DialMath.handle(minutes: 60) == DialMath.Handle(angle: 360, lap: 0))
        #expect(DialMath.handle(minutes: 75) == DialMath.Handle(angle: 90, lap: 1))
        #expect(DialMath.handle(minutes: 120) == DialMath.Handle(angle: 360, lap: 1))
    }
}
```

- [ ] **Step 2: Run to verify they fail.**

- [ ] **Step 3: Implement `DialMath`**

```swift
// Tapout/Effects/DialMath.swift
import Foundation

/// The timer dial's maths: 6° per minute, 60 minutes per lap, two laps (5 min to 2 h), 5-minute steps.
/// Angles are clockwise from 12 o'clock, in degrees, with y pointing down (screen coordinates).
enum DialMath {
    static let step = 5
    static let minimum = 5
    static let maximum = 120

    struct Ticks: Equatable { var outer: Int; var inner: Int }
    /// Where the handle sits: `angle` in 0...360 (360 means a full lap), `lap` 0 (outer) or 1 (inner).
    struct Handle: Equatable { var angle: Double; var lap: Int }

    static func angle(dx: Double, dy: Double) -> Double {
        var a = atan2(dx, -dy) * 180 / .pi
        if a < 0 { a += 360 }
        return a
    }

    /// The shortest signed turn from `a` to `b`, in -180..<180.
    static func delta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d >= 180 { d -= 360 } else if d < -180 { d += 360 }
        return d
    }

    /// Unsnapped minutes after the finger moved from angle `a` to `b`. Relative, so a touch never jumps the value.
    static func dragged(minutes: Double, from a: Double, to b: Double) -> Double {
        min(Double(maximum), max(Double(minimum), minutes + delta(from: a, to: b) / 6))
    }

    static func snapped(_ minutes: Double) -> Int {
        min(maximum, max(minimum, Int((minutes / Double(step)).rounded()) * step))
    }

    static func litTicks(minutes: Int) -> Ticks {
        Ticks(outer: min(60, max(0, minutes)), inner: min(60, max(0, minutes - 60)))
    }

    static func handle(minutes: Int) -> Handle {
        let lap = minutes > 60 ? 1 : 0
        let inLap = minutes - lap * 60
        return Handle(angle: Double(inLap) * 6, lap: lap)
    }
}
```

- [ ] **Step 4: Build `TimerDial`.** A 288 pt square, inside the sheet where the wheel is. Draw with `Canvas` (60 ticks on an outer ring of radius 132 and 60 on an inner ring of radius 108; every fifth tick longer and 2.4 pt wide, the rest 1.6 pt; lit ticks `Color.emberLine`, unlit `Color.track`). The handle: a 22 pt circle in `Color.ember` with a 3 pt `Color.surface1` border at `DialMath.handle`'s angle on its lap's radius. The centre: `Text(TimeFormat.length(seconds))` in `.numberDisplay`, `Color.ink`, `.contentTransition(.numericText())`. The centre shows the length and nothing else.

Gesture: `DragGesture(minimumDistance: 0)` in the dial's local space. On each change, compute the finger's angle with `DialMath.angle(dx:dy:)` around the centre; keep the previous angle and an unsnapped `Double` minutes in `@State`; apply `DialMath.dragged`, then `DialMath.snapped`; when the snapped value changes, write the binding and call `HapticEngine.shared.play(.detent)`. On end, forget the previous angle (the next drag starts fresh from wherever it begins). Ignore touches within 60 pt of the centre (they would spin wildly).

Accessibility: one element, label "Duration", value `TimeFormat.spokenLength(seconds)`, `.accessibilityAdjustableAction` stepping ±5 minutes within 5...120.

Reduce Motion: ticks change without animation (they are drawn from state; do not add implicit animation).

- [ ] **Step 5: Wire the sheet.** In `TimerSheet`, wrap the duration area in `LivingGlassReader { choice in ... }`. Show the dial when `choice == .glass && !typeSize.isAccessibilitySize && !voiceOverOn` (`@Environment(\.accessibilityVoiceOverEnabled)`) and the sheet is not in "longer" mode; otherwise today's big label plus `CountdownWheel`, unchanged. In dial mode, the dial's centre replaces the big label above it (do not show both). The dial binds to `duration` through minutes (`Int(duration / 60)`); a preset chip sets it too. Add a sixth chip, **Longer**, shown only in dial mode: it sets `longer = true` and `duration = 3 * 3600`, which shows the wheel for the rest of the sheet's life. Entering dial mode with a `duration` over 2 h (impossible from the initial 45 min, but guard it) clamps to 120 min. `Start` and every other behaviour are unchanged.

- [ ] **Step 6: Screenshots** (flag on: `xcrun simctl spawn 33A5EBE9-5D77-488C-85C0-FDBC419C7ECE defaults write com.raphymuthu.tapout settings.livingGlass -bool YES`). Open the timer sheet (tap Timer on Home with the simulator control tool, or the Lab's Moments gallery) and save `p10-2-dial-45-dark`, `p10-2-dial-light`, and one with a value over an hour if you can set it with a drag (`p10-2-dial-85-dark`). View each and describe: outer ring lit to 45, inner ring dark; at 85, outer full and inner lit to 25. Then flag off: `p10-2-wheel-off-dark` must match today's sheet. Reset the default afterwards.
- [ ] **Step 7: Run the full suite and both device builds.**
- [ ] **Step 8: Report.** Suggested message: `Phase 10: two-lap timer dial`.

---

### Task 3: Warmth, Home and the covers

**Files:**
- Create: `Tapout/Effects/OrbWarmth.swift`
- Modify: `Tapout/Effects/LivingOrb.swift`, `Tapout/Features/Home/HomeView.swift`, `Tapout/Features/Home/TimerDoneView.swift`, `Tapout/Features/Insights/MilestoneView.swift`
- Test: extend `TapoutTests/LivingOrbTests.swift`

**Interfaces:**
- Consumes: `LivingGlassReader`, `Motion.bloom`, `Motion.resolved`, tokens `Color.emberGlow`, `Color.slateGlow`.
- Produces: `struct OrbWarmth: View` with `init(tone: OrbTone, size: CGFloat)`; `enum OrbWarmthPlan` (pure, below); `LivingOrb` gains `warmth: Bool = false`.

- [ ] **Step 1: Write the failing tests**

```swift
// add to TapoutTests/LivingOrbTests.swift
struct OrbWarmthPlanTests {
    @Test func warmthStartsInTheOtherToneAndSettlesInItsOwn() {
        #expect(OrbWarmthPlan.start(for: .ember) == .slate)
        #expect(OrbWarmthPlan.start(for: .slate) == .ember)
    }

    @Test func warmthIsWiderThanTheOrbsOwnGlow() {
        #expect(OrbWarmthPlan.side(orb: 300) == 780)
    }

    @Test func lightModeIsSofter() {
        #expect(OrbWarmthPlan.strength(dark: true) == 1)
        #expect(OrbWarmthPlan.strength(dark: false) == 0.55)
    }
}
```

(If `OrbTone` is not `Equatable`, add the conformance in `OrbView.swift`; it is a plain enum.)

- [ ] **Step 2: Run to verify they fail.**

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/OrbWarmth.swift
import SwiftUI

/// Pure numbers for the warmth behind the glass orb.
enum OrbWarmthPlan {
    /// The color it fades in from: the state the orb just left.
    static func start(for tone: OrbTone) -> OrbTone { tone == .ember ? .slate : .ember }
    /// 2.6× the orb, past the orb's own 1.44× glow.
    static func side(orb: CGFloat) -> CGFloat { orb * 2.6 }
    /// As the milestone wash: full in dark, 55% in light.
    static func strength(dark: Bool) -> Double { dark ? 1 : 0.55 }
}

/// A soft circle of `ember-glow` or `slate-glow` behind the glass orb (the tokens' rule: a blurred circle,
/// never a full-screen wash). It appears in the previous state's color and settles into its own over `Motion.bloom`.
struct OrbWarmth: View {
    let tone: OrbTone
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        let side = OrbWarmthPlan.side(orb: size)
        let strength = OrbWarmthPlan.strength(dark: colorScheme == .dark)
        let shown = settled ? tone : OrbWarmthPlan.start(for: tone)
        ZStack {
            disc(Color.slateGlow, side: side, strength: strength).opacity(shown == .slate ? 1 : 0)
            disc(Color.emberGlow, side: side, strength: strength).opacity(shown == .ember ? 1 : 0)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(Motion.resolved(Motion.bloom, reduceMotion: reduceMotion)) { settled = true }
        }
    }

    private func disc(_ color: Color, side: CGFloat, strength: Double) -> some View {
        Circle().fill(RadialGradient(stops: [
            .init(color: color.opacity(strength), location: 0),
            .init(color: color.opacity(strength * 0.6), location: 0.35),
            .init(color: color.opacity(strength * 0.18), location: 0.7),
            .init(color: color.opacity(0), location: 1),
        ], center: .center, startRadius: 0, endRadius: side / 2))
    }
}
```

In `LivingOrb`, add `var warmth = false`; in the `.glass` branch only, put `OrbWarmth(tone: tone, size: size)` behind the `GlassOrbView` (`.background { if warmth { OrbWarmth(...) } }`). The classic branch is untouched.

Wire: the three `LivingOrb(` calls in `HomeView` add `warmth: true`. `TimerDoneView`: replace its `OrbView(` with `LivingOrb(` keeping every argument, adding `ripplesOnAppear: true, warmth: true`. `MilestoneView`: replace its `OrbView(` with `LivingOrb(` keeping every argument (no warmth: it has its own wash).

- [ ] **Step 4: Screenshots, flag on:** Home unlocked (`-demoData`) and locked (`-demoTimer`) in dark and light, Time's up (`-demoTimerDone`), and the milestone if a demo argument shows it (check `LockEngine+Debug.swift` and `MomentsGallery`). Name them `p10-3-*`. View each: the warmth should read as a soft glow wider than the orb, never a screen-wide wash. Then flag off: Home and Time's up must match the Phase 9 flag-off shots. Reset the default.
- [ ] **Step 5: Run the full suite and both device builds.**
- [ ] **Step 6: Report.** Suggested message: `Phase 10: warmth behind the glass orb, glass on Time's up and the milestone`.

---

### Task 4: The lock moment with one glass orb

**Files:**
- Modify: `Tapout/Features/Home/LockMomentView.swift`

**Interfaces:**
- Consumes: `LivingGlassReader`, `LivingOrb(tone:ring:size:warmth:)`, `LivingFeedback.lock()`.

- [ ] **Step 1: Restructure the orb.** Wrap `orb` in `LivingGlassReader { choice in ... }`. For `.classic`, keep today's view exactly (ready rings, `Shockwave`, two stacked `LivingOrb`s with opacity). For `.glass`:

```swift
ZStack {
    if frame == 1 { ReadyRings().transition(.opacity) }
    LivingOrb(tone: frame == 1 ? .slate : .ember, ring: ring, size: 280, warmth: frame > 1)
}
.frame(width: 280, height: 280)
.lockMomentMatch(.orb, inOverlay: true)
```

`warmth: frame > 1` makes the warmth appear at frame 2, starting slate and settling ember (`OrbWarmth` starts in the other tone).

The tone change from `.slate` to `.ember` at frame 2 animates through `GlassOrbView`'s `Motion.tone` and sends one shader ripple (Phase 9's `onChange(of: tone)`), which replaces the `Shockwave`. The ring still sweeps through `withAnimation(Motion.lock) { ring = 1 }`. `play()` keeps its timing; it already calls `LivingFeedback.lock()` after Task 1.

- [ ] **Step 2: Verify.** Flag on, trigger the lock moment in the simulator (the Lab's Moments gallery has a lock-moment row; or `MomentsGallery`). Take `p10-4-moment-start` immediately and `p10-4-moment-sealed` about 1 s later; view and describe. Flag off: the classic sequence is unchanged (one screenshot, `p10-4-moment-off`). Reset the default.
- [ ] **Step 3: Run the full suite and both device builds.**
- [ ] **Step 4: Report.** Suggested message: `Phase 10: lock moment with one glass orb`.

---

### Task 5: Checklist and docs

**Files:**
- Modify: `docs/superpowers/verification/iphone-run-checklist.md`, `design/SCREENS.md` (one line)

- [ ] **Step 1: Checklist.** Add section **14. Phase 10: Home and the lock moment** (match the format; the switch must be on for all of these):
  1. **Timer dial.** Open Timer: a dial, not the wheel. Drag clockwise: one detent per 5 minutes, the outer ring fills. Keep going past 12 o'clock: the inner ring starts filling, up to 2 h, then it stops. Drag back: it unwinds.
  2. **Dial precision.** Set exactly 25 min and 1 h 35 min without fighting it.
  3. **Longer.** Tap Longer: the wheel appears at 3 h and reaches 12 h. Start works.
  4. **Wheel at large text and with VoiceOver.** At an accessibility text size, and separately with VoiceOver on, the sheet shows the wheel.
  5. **Lock moment.** Scan a tag: one orb turns from slate to ember while the ring sweeps, one ripple goes out, the background warms. Two taps then a soft swell.
  6. **Unlock haptic.** Unlock with a tag: one soft tap and a fainter echo.
  7. **Warmth.** On Home, locked and unlocked, the glow behind the orb is soft and wider than the orb, never a screen-wide wash, in a dark room and in daylight.
  8. **Time's up and milestone.** Both show the glass orb; Time's up warms in.
  9. **Switch off.** The wheel, the classic lock moment and today's haptics are back.
- [ ] **Step 2: SCREENS.md.** One line under the "disagree" section: with the Living glass switch on (Phase 10), the timer sheet uses a two-lap dial (5 min to 2 h) instead of the wheel, except at accessibility sizes and with VoiceOver.
- [ ] **Step 3: Report.** Suggested message: `Phase 10: device checklist`.
