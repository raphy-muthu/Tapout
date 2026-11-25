# Phase 9: Living Glass Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared effects engine (motion budget, tilt, haptic patterns, motion tokens) and the first Living glass piece, a Metal-shader orb, behind an off-by-default flag, with a Lab page to try it on a device.

**Architecture:** New app-only code in `Tapout/Effects/`. Pure logic (budget, tilt filter, palette, ripples, haptic patterns) is unit tested. `GlassOrb.metal` is a stitchable `colorEffect` shader used by `GlassOrbView` inside a `TimelineView`. `LivingOrb` has `OrbView`'s signature and picks the shader orb only when the flag is on and the motion budget allows, so every existing screen is unchanged with the flag off.

**Tech Stack:** SwiftUI (colorEffect, ShaderLibrary, TimelineView, Animatable), Metal Shading Language, CoreMotion, CoreHaptics, Swift Testing, XcodeGen.

## Global Constraints

See `.superpowers/sdd/p9-constraints.md`. Key lines: iOS 17.0 floor, Swift 6, no packages; flag `settings.livingGlass` off by default and flag-off rendering unchanged; `Shared/` and the extension targets stay free of effect code; never commit, stage or stash; test count starts at the Phase 9 baseline (437 expected).

## File Structure

| File | Responsibility |
| --- | --- |
| `Tapout/Effects/MotionBudget.swift` (new) | `MotionLevel`, pure `MotionBudget.level(...)`, `MotionEnvironment` (low power and thermal, observable). |
| `Tapout/Effects/TiltFilter.swift` (new) | Pure low-pass tilt filter with a slowly following rest pose. |
| `Tapout/Effects/MotionSource.swift` (new) | Shared, reference-counted CoreMotion wrapper publishing `tilt`; synthetic sway without a sensor. |
| `Tapout/Effects/HapticPattern.swift` (new) | Pure haptic event lists and the fallback mapping to `Haptics`. |
| `Tapout/Effects/HapticEngine.swift` (new) | Core Haptics player with fallback. |
| `Tapout/Components/OrbColors.swift` (new, beside `OrbView`, which the widget target also compiles) | Single source of the orb's gradient stops as RGB, with tone mixing. |
| `Tapout/Effects/OrbRipples.swift` (new) | Pure ripple bookkeeping (start times, ages, pruning). |
| `Tapout/Effects/GlassOrb.metal` (new) | The shader. |
| `Tapout/Effects/GlassOrbView.swift` (new) | Animatable SwiftUI view around the shader plus the seal ring. |
| `Tapout/Effects/LivingOrb.swift` (new) | Flag and budget aware host with `OrbView`'s signature. |
| `Tapout/Components/OrbView.swift` (modify) | Extract `OrbSealRing`; build its palette from `OrbColors`. |
| `Tapout/DesignSystem/Motion.swift` (modify) | New tokens and `Motion.resolved`. |
| `Tapout/Model/AppSettings.swift` (modify) | `livingGlassKey`, `livingGlassEnabled`. |
| `Tapout/Features/Home/HomeView.swift`, `LockMomentView.swift` (modify) | Swap `OrbView` for `LivingOrb`; lock haptic through the engine when the flag is on. |
| `Tapout/Features/Lab/EffectsGallery.swift`, `LabView.swift` (new, modify) | DEBUG Effects page and its link. |
| `TapoutTests/*` (new) | One test file per pure unit. |

XcodeGen picks up everything under `Tapout/` automatically, `.metal` included. Run `xcodegen` after adding files.

---

### Task 1: Motion budget, motion tokens and the flag

**Files:**
- Create: `Tapout/Effects/MotionBudget.swift`
- Modify: `Tapout/DesignSystem/Motion.swift`, `Tapout/Model/AppSettings.swift`
- Test: `TapoutTests/MotionBudgetTests.swift`, extend `TapoutTests/AppSettingsTests.swift`

**Interfaces:**
- Produces: `enum MotionLevel { case full, still }`; `MotionBudget.level(reduceMotion:lowPowerMode:thermalState:sceneActive:) -> MotionLevel`; `MotionBudget.frameInterval: TimeInterval` (1/30); `@MainActor @Observable final class MotionEnvironment` with `static let shared`, `private(set) var lowPowerMode: Bool`, `private(set) var thermalState: ProcessInfo.ThermalState`; `Motion.tone`, `Motion.bloom`, `Motion.scrub`, `Motion.detent`, `Motion.resolved(_:reduceMotion:)`; `AppSettings.livingGlassKey`, `AppSettings.livingGlassEnabled(in:) -> Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
// TapoutTests/MotionBudgetTests.swift
import Foundation
import Testing
@testable import Tapout

struct MotionBudgetTests {
    private func level(reduce: Bool = false, lowPower: Bool = false,
                       thermal: ProcessInfo.ThermalState = .nominal, active: Bool = true) -> MotionLevel {
        MotionBudget.level(reduceMotion: reduce, lowPowerMode: lowPower, thermalState: thermal, sceneActive: active)
    }

    @Test func fullWhenNothingObjects() {
        #expect(level() == .full)
        #expect(level(thermal: .fair) == .full)
    }

    @Test func reduceMotionStopsEverything() { #expect(level(reduce: true) == .still) }
    @Test func lowPowerModeStopsEverything() { #expect(level(lowPower: true) == .still) }
    @Test func aBackgroundedAppStops() { #expect(level(active: false) == .still) }
    @Test func seriousHeatStops() {
        #expect(level(thermal: .serious) == .still)
        #expect(level(thermal: .critical) == .still)
    }

    @Test func framesAreCappedAtThirtyPerSecond() {
        #expect(MotionBudget.frameInterval == 1.0 / 30.0)
    }
}
```

Append to `AppSettingsTests.swift` (use that file's existing way of making a throwaway `UserDefaults` suite):

```swift
    @Test func livingGlassIsOffUntilTurnedOn() {
        let defaults = UserDefaults(suiteName: "AppSettingsTests.livingGlass")!
        defaults.removePersistentDomain(forName: "AppSettingsTests.livingGlass")
        #expect(AppSettings.livingGlassEnabled(in: defaults) == false)
        defaults.set(true, forKey: AppSettings.livingGlassKey)
        #expect(AppSettings.livingGlassEnabled(in: defaults) == true)
    }
```

Add to a new `MotionTokensTests` struct in `MotionBudgetTests.swift`:

```swift
struct MotionTokensTests {
    @Test func reduceMotionSwapsInTheCrossfade() {
        #expect(Motion.resolved(Motion.bloom, reduceMotion: true) == .easeInOut(duration: 0.25))
        #expect(Motion.resolved(Motion.bloom, reduceMotion: false) == Motion.bloom)
    }
}
```

- [ ] **Step 2: Run to verify they fail** (build errors: `MotionBudget`, `livingGlassEnabled`, `Motion.resolved` undefined). Run the build-and-test command from the constraints file.

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/MotionBudget.swift
import Foundation
import Observation

/// How much the orb may move. `.still` shows the classic, static orb.
enum MotionLevel: Equatable {
    case full, still
}

/// Decides, from the system's own signals, whether continuous effects may run.
enum MotionBudget {
    /// Seconds between frames while the orb runs.
    static let frameInterval: TimeInterval = 1.0 / 30.0

    static func level(reduceMotion: Bool, lowPowerMode: Bool,
                      thermalState: ProcessInfo.ThermalState, sceneActive: Bool) -> MotionLevel {
        if reduceMotion || lowPowerMode || !sceneActive { return .still }
        switch thermalState {
        case .nominal, .fair: return .full
        case .serious, .critical: return .still
        @unknown default: return .still
        }
    }
}

/// Low Power Mode and thermal state, kept current for views that read them in `body`.
@MainActor @Observable
final class MotionEnvironment {
    static let shared = MotionEnvironment()

    private(set) var lowPowerMode: Bool
    private(set) var thermalState: ProcessInfo.ThermalState
    private var observers: [Task<Void, Never>] = []

    init(processInfo: ProcessInfo = .processInfo, center: NotificationCenter = .default) {
        lowPowerMode = processInfo.isLowPowerModeEnabled
        thermalState = processInfo.thermalState
        observers = [
            Task { [weak self] in
                for await _ in center.notifications(named: .NSProcessInfoPowerStateDidChange) {
                    self?.lowPowerMode = processInfo.isLowPowerModeEnabled
                }
            },
            Task { [weak self] in
                for await _ in center.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                    self?.thermalState = processInfo.thermalState
                }
            },
        ]
    }

    deinit { observers.forEach { $0.cancel() } }
}
```

If Swift 6 strict concurrency rejects the `for await` bodies capturing `processInfo` or `self`, keep the behavior and adjust the isolation (for example read `ProcessInfo.processInfo` inside a `@MainActor` closure). Do not weaken the language mode.

In `Motion.swift` add:

```swift
    /// The orb's slate-to-ember change.
    static var tone: Animation { .easeInOut(duration: 0.9) }
    /// Background warmth after a lock.
    static var bloom: Animation { .easeOut(duration: 1.2) }
    /// A chart or dial following a finger.
    static var scrub: Animation { .spring(response: 0.25, dampingFraction: 0.9) }
    /// A step settling into place.
    static var detent: Animation { .spring(response: 0.18, dampingFraction: 0.8) }

    /// The animation to use: `animation`, or a short crossfade when Reduce Motion is on.
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : animation
    }
```

In `AppSettings.swift` add:

```swift
    /// The shader-drawn orb. Off unless the owner turned it on (from the Lab).
    static let livingGlassKey = "settings.livingGlass"

    static func livingGlassEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: livingGlassKey) as? Bool ?? false
    }
```

- [ ] **Step 4: Run the tests to verify they pass**, then run the Debug device build.
- [ ] **Step 5: Report** (do not commit). Suggested message: `Phase 9: motion budget, motion tokens and the living glass flag`.

---

### Task 2: Tilt filter and the shared motion source

**Files:**
- Create: `Tapout/Effects/TiltFilter.swift`, `Tapout/Effects/MotionSource.swift`
- Test: `TapoutTests/TiltFilterTests.swift`, `TapoutTests/MotionSourceTests.swift`

**Interfaces:**
- Produces: `struct TiltFilter` with `init(smoothing: Double = 0.2, restRate: Double = 0.01, gain: Double = 2.4)`, `mutating func update(gravityX: Double, gravityY: Double) -> SIMD2<Double>`, `mutating func reset()`, `private(set) var value: SIMD2<Double>`. Output components are clamped to -1...1. Positive x means the right edge dips; positive y means the top edge tips away from the viewer.
- Produces: `@MainActor @Observable final class MotionSource` with `static let shared`, `private(set) var tilt: SIMD2<Double>`, `func acquire()`, `func release()`, `private(set) var consumers: Int`, `func ingest(gravityX: Double, gravityY: Double)`.

- [ ] **Step 1: Write the failing tests**

```swift
// TapoutTests/TiltFilterTests.swift
import Testing
@testable import Tapout

struct TiltFilterTests {
    @Test func theFirstSampleIsTheRestPose() {
        var filter = TiltFilter()
        #expect(filter.update(gravityX: 0.3, gravityY: -0.7) == .zero)
    }

    @Test func aSteadyPhoneStaysAtZero() {
        var filter = TiltFilter()
        for _ in 0..<100 { _ = filter.update(gravityX: 0.1, gravityY: -0.8) }
        #expect(abs(filter.value.x) < 0.001 && abs(filter.value.y) < 0.001)
    }

    @Test func aTipMovesTheLightButNotAllAtOnce() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        let first = filter.update(gravityX: 0.5, gravityY: -1)
        #expect(first.x > 0)
        #expect(first.x < 0.5 * filter.gain) // low-pass: the first sample after a step is not the full step
    }

    @Test func aHeldTipFadesAsTheRestPoseFollows() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        for _ in 0..<20 { _ = filter.update(gravityX: 0.4, gravityY: -1) }
        let early = filter.value.x
        for _ in 0..<900 { _ = filter.update(gravityX: 0.4, gravityY: -1) }
        #expect(early > 0.3)
        #expect(abs(filter.value.x) < 0.05)
    }

    @Test func outputIsClamped() {
        var filter = TiltFilter(smoothing: 1, restRate: 0, gain: 10)
        _ = filter.update(gravityX: 0, gravityY: 0)
        let out = filter.update(gravityX: 1, gravityY: -1)
        #expect(out.x == 1 && out.y == -1)
    }

    @Test func resetForgetsTheRestPose() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        _ = filter.update(gravityX: 0.5, gravityY: -1)
        filter.reset()
        #expect(filter.value == .zero)
        #expect(filter.update(gravityX: 0.5, gravityY: -1) == .zero)
    }
}
```

```swift
// TapoutTests/MotionSourceTests.swift
import Testing
@testable import Tapout

@MainActor
struct MotionSourceTests {
    @Test func consumersAreCounted() {
        let source = MotionSource()
        source.acquire(); source.acquire()
        #expect(source.consumers == 2)
        source.release()
        #expect(source.consumers == 1)
        source.release(); source.release() // an extra release never goes below zero
        #expect(source.consumers == 0)
    }

    @Test func ingestingASampleMovesTheTilt() {
        let source = MotionSource()
        source.ingest(gravityX: 0, gravityY: -1) // the rest pose
        source.ingest(gravityX: 0.4, gravityY: -1)
        #expect(source.tilt.x > 0)
    }

    @Test func stoppingEasesTheTiltBackToZero() {
        let source = MotionSource()
        source.acquire()
        source.ingest(gravityX: 0, gravityY: -1)
        source.ingest(gravityX: 0.5, gravityY: -1)
        source.release()
        #expect(source.tilt == .zero)
    }
}
```

- [ ] **Step 2: Run to verify they fail.**

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/TiltFilter.swift
import Foundation

/// Turns raw gravity samples into a small, smooth tilt vector.
/// The "rest pose" slowly follows the phone, so the light settles when the phone is held still
/// and only reacts to movement. Positive x: the right edge dips. Positive y: the top edge tips away.
struct TiltFilter {
    var smoothing: Double
    var restRate: Double
    var gain: Double
    private var smoothed: SIMD2<Double>?
    private var rest: SIMD2<Double>?
    private(set) var value: SIMD2<Double> = .zero

    init(smoothing: Double = 0.2, restRate: Double = 0.01, gain: Double = 2.4) {
        self.smoothing = smoothing
        self.restRate = restRate
        self.gain = gain
    }

    @discardableResult
    mutating func update(gravityX: Double, gravityY: Double) -> SIMD2<Double> {
        let sample = SIMD2(gravityX, gravityY)
        let s = smoothed.map { $0 + (sample - $0) * smoothing } ?? sample
        let r = rest.map { $0 + (s - $0) * restRate } ?? s
        smoothed = s
        rest = r
        let raw = (s - r) * gain
        value = SIMD2(min(1, max(-1, raw.x)), min(1, max(-1, raw.y)))
        return value
    }

    mutating func reset() {
        smoothed = nil
        rest = nil
        value = .zero
    }
}
```

`MotionSource`: `acquire()` increments `consumers` and starts on the first one; `release()` decrements (never below zero) and stops on the last, resetting the filter and setting `tilt = .zero`. Start: if `CMMotionManager.isDeviceMotionAvailable`, set `deviceMotionUpdateInterval = MotionBudget.frameInterval` and `startDeviceMotionUpdates(to: .main)`, feeding `ingest(gravityX: motion.gravity.x, gravityY: motion.gravity.y)` on the main actor. Otherwise run a `Task` that, every `MotionBudget.frameInterval`, sets `tilt` to a slow sway: `SIMD2(sin(t * 0.55) * 0.35, cos(t * 0.43) * 0.25)`. Stop cancels that task and stops updates. `ingest` runs the filter and assigns `tilt`. `MotionSource()` must be constructible in tests (a plain `init`), with `static let shared = MotionSource()`. Resolve Swift 6 isolation warnings with `MainActor.assumeIsolated` inside the motion handler or a `Task { @MainActor in }`; do not weaken the language mode.

- [ ] **Step 4: Run the tests to verify they pass**, then the Debug device build.
- [ ] **Step 5: Report.** Suggested message: `Phase 9: tilt filter and shared motion source`.

---

### Task 3: Haptic patterns and the engine

**Files:**
- Create: `Tapout/Effects/HapticPattern.swift`, `Tapout/Effects/HapticEngine.swift`
- Test: `TapoutTests/HapticPatternTests.swift`

**Interfaces:**
- Produces: `struct HapticEvent: Equatable { enum Kind { case transient, continuous }; var kind: Kind; var time: TimeInterval; var duration: TimeInterval; var intensity: Float; var sharpness: Float }`; `enum HapticPattern: CaseIterable { case lock, unlock, detent, scrub, paired }` with `var events: [HapticEvent]` and `var fallback: HapticFallback`; `enum HapticFallback: Equatable { case lock, unlock, select }`; `@MainActor final class HapticEngine` with `static let shared` and `func play(_ pattern: HapticPattern)`.
- Consumes: `Haptics.lock()`, `Haptics.unlock()`, `Haptics.select()`, `AppSettings.hapticsEnabled()` (existing).

- [ ] **Step 1: Write the failing tests**

```swift
// TapoutTests/HapticPatternTests.swift
import Testing
@testable import Tapout

struct HapticPatternTests {
    @Test func lockKeepsTheSpecRule() {
        let events = HapticPattern.lock.events
        let taps = events.filter { $0.kind == .transient }
        #expect(taps.count == 2)
        #expect(taps[0].time == 0)
        #expect(taps[1].time == 0.09)
        #expect(taps.allSatisfy { $0.intensity == 1 })
    }

    @Test func lockEndsWithASoftSwellUnderTheBloom() {
        let swell = HapticPattern.lock.events.last
        #expect(swell?.kind == .continuous)
        #expect((swell?.time ?? 0) > 0.09)
        #expect((swell?.intensity ?? 1) < 0.5)
    }

    @Test func unlockIsOneSoftTapThenAFadingEcho() {
        let events = HapticPattern.unlock.events
        #expect(events.count == 2)
        #expect(events[0].time == 0)
        #expect(events[1].intensity < events[0].intensity)
    }

    @Test func detentAndScrubAreSingleTicks() {
        #expect(HapticPattern.detent.events.count == 1)
        #expect(HapticPattern.scrub.events.count == 1)
        #expect(HapticPattern.scrub.events[0].intensity < HapticPattern.detent.events[0].intensity)
    }

    @Test func pairedIsTheLockPairAtLowerIntensity() {
        let paired = HapticPattern.paired.events
        let lock = HapticPattern.lock.events.filter { $0.kind == .transient }
        #expect(paired.map(\.time) == lock.map(\.time))
        #expect(zip(paired, lock).allSatisfy { $0.intensity < $1.intensity })
    }

    @Test func everyPatternIsWellFormed() {
        for pattern in HapticPattern.allCases {
            let events = pattern.events
            #expect(!events.isEmpty)
            #expect(events.map(\.time) == events.map(\.time).sorted())
            #expect(events.allSatisfy { $0.time >= 0 && (0...1).contains($0.intensity) && (0...1).contains($0.sharpness) })
            #expect(events.filter { $0.kind == .continuous }.allSatisfy { $0.duration > 0 })
        }
    }

    @Test func fallbacksMapToTheExistingHaptics() {
        #expect(HapticPattern.lock.fallback == .lock)
        #expect(HapticPattern.paired.fallback == .lock)
        #expect(HapticPattern.unlock.fallback == .unlock)
        #expect(HapticPattern.detent.fallback == .select)
        #expect(HapticPattern.scrub.fallback == .select)
    }
}
```

- [ ] **Step 2: Run to verify they fail.**

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/HapticPattern.swift
import Foundation

/// One beat of a haptic pattern. A transient is a tap; a continuous event is a swell.
struct HapticEvent: Equatable {
    enum Kind { case transient, continuous }
    var kind: Kind
    var time: TimeInterval
    var duration: TimeInterval = 0
    var intensity: Float
    var sharpness: Float
}

/// What to use where Core Haptics is not available.
enum HapticFallback: Equatable { case lock, unlock, select }

/// The app's haptic vocabulary. Pure data, so the timing is testable.
enum HapticPattern: CaseIterable {
    /// Two rigid taps 90 ms apart (the spec rule), then a soft swell under the bloom.
    case lock
    /// One soft tap and a fading echo.
    case unlock
    /// A step settling on a dial.
    case detent
    /// A tick as a finger crosses a chart column.
    case scrub
    /// The lock pair at lower intensity, for a tag that just paired.
    case paired

    var events: [HapticEvent] {
        switch self {
        case .lock:
            [HapticEvent(kind: .transient, time: 0, intensity: 1, sharpness: 0.9),
             HapticEvent(kind: .transient, time: 0.09, intensity: 1, sharpness: 0.9),
             HapticEvent(kind: .continuous, time: 0.16, duration: 0.45, intensity: 0.35, sharpness: 0.1)]
        case .unlock:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.6, sharpness: 0.2),
             HapticEvent(kind: .transient, time: 0.18, intensity: 0.25, sharpness: 0.1)]
        case .detent:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.5, sharpness: 0.6)]
        case .scrub:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.3, sharpness: 0.8)]
        case .paired:
            [HapticEvent(kind: .transient, time: 0, intensity: 0.7, sharpness: 0.8),
             HapticEvent(kind: .transient, time: 0.09, intensity: 0.7, sharpness: 0.8)]
        }
    }

    var fallback: HapticFallback {
        switch self {
        case .lock, .paired: .lock
        case .unlock: .unlock
        case .detent, .scrub: .select
        }
    }
}
```

`HapticEngine` (`@MainActor`, `static let shared`): `play(_:)` returns at once when `!AppSettings.hapticsEnabled()`. If `!CHHapticEngine.capabilitiesForHardware().supportsHaptics`, call the matching `Haptics` function from `pattern.fallback` and return. Otherwise lazily create a `CHHapticEngine`, set `resetHandler` (restart it) and `stoppedHandler` (drop the reference so the next play recreates it), start it, build a `CHHapticPattern` from `pattern.events` (`.hapticTransient` or `.hapticContinuous` events with `.hapticIntensity` and `.hapticSharpness` parameters, `relativeTime` from `time`, `duration` for continuous), make an advanced player and `start(atTime: CHHapticTimeImmediate)`. Any error falls back to the `Haptics` function, never throws to the caller. Resolve Swift 6 isolation in the engine handlers without weakening the language mode.

- [ ] **Step 4: Run the tests to verify they pass**, then the Debug device build.
- [ ] **Step 5: Report.** Suggested message: `Phase 9: haptic patterns and Core Haptics engine`.

---

### Task 4: Orb colors, ripples and the shader

**Files:**
- Create: `Tapout/Components/OrbColors.swift`, `Tapout/Effects/OrbRipples.swift`, `Tapout/Effects/GlassOrb.metal`
- Modify: `Tapout/Components/OrbView.swift` (build its private `OrbPalette` from `OrbColors`; nothing else)
- Test: `TapoutTests/OrbColorsTests.swift`, `TapoutTests/OrbRipplesTests.swift`

**Interfaces:**
- Produces: `struct OrbColors: Equatable { var hi, mid, deep, edge, glow, ripple: SIMD3<Float>; var glowAlpha: Float }` with `static func ember(light: Bool) -> OrbColors`, `static func slate(light: Bool) -> OrbColors`, `static func mixed(tone: Double, light: Bool) -> OrbColors` (tone 0 slate, 1 ember, clamped).
- Produces: `struct OrbRipples: Equatable` with `static let lifetime: TimeInterval = 1.5`, `static let capacity = 3`, `mutating func add(at time: TimeInterval)`, `func ages(at time: TimeInterval) -> SIMD3<Float>` (-1 for an empty or finished slot, newest first).
- Produces: Metal function `glassOrb` (signature below), used by Task 5.

- [ ] **Step 1: Write the failing tests**

```swift
// TapoutTests/OrbColorsTests.swift
import Testing
@testable import Tapout

struct OrbColorsTests {
    @Test func theEndsAreTheTwoTones() {
        #expect(OrbColors.mixed(tone: 0, light: false) == .slate(light: false))
        #expect(OrbColors.mixed(tone: 1, light: false) == .ember(light: false))
    }

    @Test func toneIsClamped() {
        #expect(OrbColors.mixed(tone: -3, light: true) == .slate(light: true))
        #expect(OrbColors.mixed(tone: 7, light: true) == .ember(light: true))
    }

    @Test func halfwayIsBetweenTheTones() {
        let mid = OrbColors.mixed(tone: 0.5, light: false)
        let slate = OrbColors.slate(light: false), ember = OrbColors.ember(light: false)
        #expect(mid.mid.x > min(slate.mid.x, ember.mid.x) && mid.mid.x < max(slate.mid.x, ember.mid.x))
        #expect(mid.glowAlpha > min(slate.glowAlpha, ember.glowAlpha) && mid.glowAlpha < max(slate.glowAlpha, ember.glowAlpha))
    }

    @Test func emberMidIsTheEmberToken() {
        // #FF9F43, the orb's body color since Phase 1.
        let c = OrbColors.ember(light: false).mid
        #expect(abs(c.x - 1.0) < 0.001 && abs(c.y - 159.0 / 255) < 0.001 && abs(c.z - 67.0 / 255) < 0.001)
    }

    @Test func lightModeDeepensTheEdgeAndSoftensTheGlow() {
        #expect(OrbColors.ember(light: true).edge != OrbColors.ember(light: false).edge)
        #expect(OrbColors.ember(light: true).glowAlpha < OrbColors.ember(light: false).glowAlpha)
    }
}
```

```swift
// TapoutTests/OrbRipplesTests.swift
import Testing
@testable import Tapout

struct OrbRipplesTests {
    @Test func startsEmpty() {
        #expect(OrbRipples().ages(at: 10) == SIMD3(-1, -1, -1))
    }

    @Test func aRippleAgesFromItsStart() {
        var ripples = OrbRipples()
        ripples.add(at: 10)
        #expect(ripples.ages(at: 10.5) == SIMD3(0.5, -1, -1))
    }

    @Test func aFinishedRippleDisappears() {
        var ripples = OrbRipples()
        ripples.add(at: 10)
        #expect(ripples.ages(at: 10 + OrbRipples.lifetime + 0.01) == SIMD3(-1, -1, -1))
    }

    @Test func newestComesFirstAndTheOldestIsDroppedAtCapacity() {
        var ripples = OrbRipples()
        for t in [1.0, 1.1, 1.2, 1.3] { ripples.add(at: t) }
        let ages = ripples.ages(at: 1.4)
        #expect(abs(ages.x - 0.1) < 0.0001 && abs(ages.y - 0.2) < 0.0001 && abs(ages.z - 0.3) < 0.0001)
    }
}
```

- [ ] **Step 2: Run to verify they fail.**

- [ ] **Step 3: Implement the pure parts**

```swift
// Tapout/Components/OrbColors.swift
import simd

/// The orb's gradient stops as RGB (0...1), the single source for `OrbView` and the shader.
/// Ported from Orb.dc.html; these are not design tokens, nothing else uses them.
struct OrbColors: Equatable {
    var hi, mid, deep, edge, glow, ripple: SIMD3<Float>
    var glowAlpha: Float

    private static func rgb(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(Float((hex >> 16) & 0xFF), Float((hex >> 8) & 0xFF), Float(hex & 0xFF)) / 255
    }

    static func ember(light: Bool) -> OrbColors {
        OrbColors(hi: rgb(0xFFE3C4), mid: rgb(0xFF9F43), deep: rgb(0xC0600F),
                  edge: rgb(light ? 0x8A3F06 : 0x3D1702), glow: rgb(0xFF9F43), ripple: rgb(0xFF9F43),
                  glowAlpha: light ? 0.42 : 0.5)
    }

    static func slate(light: Bool) -> OrbColors {
        OrbColors(hi: rgb(0xEEF1F6), mid: rgb(0x9AA3B4), deep: rgb(0x555E70),
                  edge: rgb(light ? 0x4A5263 : 0x141820), glow: rgb(0x8A94A6), ripple: rgb(0xC8D2E2),
                  glowAlpha: light ? 0.32 : 0.34)
    }

    /// 0 is slate, 1 is ember.
    static func mixed(tone: Double, light: Bool) -> OrbColors {
        let t = Float(min(1, max(0, tone)))
        let a = slate(light: light), b = ember(light: light)
        func mix(_ x: SIMD3<Float>, _ y: SIMD3<Float>) -> SIMD3<Float> { x + (y - x) * t }
        return OrbColors(hi: mix(a.hi, b.hi), mid: mix(a.mid, b.mid), deep: mix(a.deep, b.deep),
                         edge: mix(a.edge, b.edge), glow: mix(a.glow, b.glow), ripple: mix(a.ripple, b.ripple),
                         glowAlpha: a.glowAlpha + (b.glowAlpha - a.glowAlpha) * t)
    }
}
```

`mixed(tone: 0)` must equal `slate` exactly and `mixed(tone: 1)` must equal `ember` exactly; with `t` of 0 or 1 the arithmetic above is exact. If floating point makes the equality tests fail, return `a` or `b` directly for the two ends.

Then in `OrbView.swift`, rebuild the private `OrbPalette` from `OrbColors` (convert each `SIMD3<Float>` to `Color(.sRGB, red:green:blue:)`; `glowAlpha` and `dropShadow` as before). Remove the now-duplicated hex literals and the `Color(rgb:)` helper if nothing else uses it. The rendered orb must not change.

```swift
// Tapout/Effects/OrbRipples.swift
import simd

/// The start times of the orb's last few ripples. Pure bookkeeping; the shader draws them.
struct OrbRipples: Equatable {
    static let lifetime: TimeInterval = 1.5
    static let capacity = 3
    private var starts: [TimeInterval] = []

    mutating func add(at time: TimeInterval) {
        starts.append(time)
        if starts.count > Self.capacity { starts.removeFirst(starts.count - Self.capacity) }
    }

    /// Ages in seconds, newest first. -1 marks an empty or finished slot.
    func ages(at time: TimeInterval) -> SIMD3<Float> {
        var out = SIMD3<Float>(repeating: -1)
        for (slot, start) in starts.reversed().enumerated() where slot < Self.capacity {
            let age = time - start
            if age >= 0 && age < Self.lifetime { out[slot] = Float(age) }
        }
        return out
    }
}
```

Add `import Foundation` for `TimeInterval`.

- [ ] **Step 4: Write the shader**

```metal
// Tapout/Effects/GlassOrb.metal
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Straight-alpha colour `rgb` with alpha `a`, composited over premultiplied `dst`.
static half4 over(half4 dst, float3 rgb, float a) {
    half ha = half(clamp(a, 0.0, 1.0));
    return half4(half3(rgb) * ha + dst.rgb * (1.0h - ha), ha + dst.a * (1.0h - ha));
}

// Distance from an ellipse's centre, 1 at its edge.
static float ellipse(float2 p, float2 c, float2 radii) {
    return length((p - c) / radii);
}

// Draws the glass orb. The canvas is `canvas` pixels square (the orb is `orbSize` wide, centred,
// so the glow and ripples have room). Units below: 1.0 is half the orb's width.
[[ stitchable ]] half4 glassOrb(
    float2 position, half4 currentColor,
    float canvas, float orbSize,
    float tiltX, float tiltY, float time, float lightMode,
    float3 hi, float3 mid, float3 deep, float3 edge,
    float3 glow, float glowAlpha,
    float3 rippleColor, float3 rippleAges, float amplitude)
{
    const float unit = orbSize * 0.5;
    float2 p = (position - float2(canvas * 0.5)) / unit;
    float r = length(p);
    const float R = 0.74;                 // sphere radius: the orb is inset 13% each side
    const float aa = 1.5 / unit;          // 1.5 px
    float2 tilt = float2(tiltX, tiltY);
    half4 out = half4(0);

    // Glow: a radial halo, 1.44x the orb (see OrbView.glow).
    float t = r * 0.5 / 1.018;
    float g = t < 0.38 ? mix(1.0, 0.35, t / 0.38) : mix(0.35, 0.0, saturate((t - 0.38) / 0.30));
    out = over(out, glow, g * glowAlpha);

    // Drop shadow under the sphere.
    float shadow = 1.0 - smoothstep(R * 0.80, R * 1.32, length(p - float2(0.0, 0.16 * R)));
    bool light = lightMode > 0.5;
    out = over(out, light ? float3(0.082, 0.09, 0.106) : float3(0.0), shadow * (light ? 0.18 : 0.5));

    // Glass body.
    float inside = 1.0 - smoothstep(R - aa, R + aa, r);
    if (inside > 0.0) {
        float2 pn = p / R;                                       // -1...1 across the sphere
        float2 centre = float2(tilt.x * 0.24, 0.16 + tilt.y * 0.24);
        float bt = length(pn - centre) / 1.532;
        float3 c = mix(hi, mid, saturate(bt / 0.34));
        c = mix(c, deep, saturate((bt - 0.34) / 0.38));
        c = mix(c, edge, saturate((bt - 0.72) / 0.28));

        // Inner shading: a little dark at the bottom, a little light at the top.
        c = mix(c, float3(0.0), 0.26 * smoothstep(0.7, 1.0, length(pn - float2(0.0, -0.12))) * smoothstep(-0.1, 0.8, pn.y));
        c = mix(c, float3(1.0), 0.14 * smoothstep(0.75, 1.0, length(pn - float2(0.0, 0.10))) * smoothstep(0.1, -0.8, pn.y));

        // Light pooling at the bottom of the glass.
        float pool = 1.0 - saturate(ellipse(pn, float2(-tilt.x * 0.16, 0.84 - tilt.y * 0.10), float2(1.4, 0.68)) / 0.7);
        c = mix(c, float3(1.0), 0.32 * pool);

        // A slow caustic drifting through the glass.
        float a = time * 0.5 * amplitude;
        float caustic = 1.0 - saturate(ellipse(pn, float2(cos(a) * 0.38 + tilt.x * 0.2, sin(a * 1.3) * 0.30), float2(0.6, 0.4)));
        c = mix(c, float3(1.0), 0.17 * caustic);

        // Main gloss, follows the tilt.
        float ge = ellipse(pn, float2(-0.30 + tilt.x * 0.36, -0.52 + tilt.y * 0.36), float2(0.6, 0.4));
        float gloss = ge < 0.45 ? mix(0.92, 0.35, ge / 0.45) : mix(0.35, 0.0, saturate((ge - 0.45) / 0.55));
        c = mix(c, float3(1.0), gloss);

        // Small secondary gloss.
        float se = 1.0 - saturate(ellipse(pn, float2(0.32 - tilt.x * 0.1, 0.56 - tilt.y * 0.1), float2(0.24, 0.14)));
        c = mix(c, float3(1.0), 0.4 * se);

        // Fresnel rim.
        c = mix(c, float3(1.0), 0.2 * saturate((length(pn - tilt * 0.1) - 0.74) / 0.26));

        out = over(out, c, inside);
    }

    // Hairline rim.
    float rim = 1.0 - smoothstep(0.0, aa * 1.4, abs(r - (R - aa * 0.7)));
    out = over(out, float3(1.0), 0.22 * rim);

    // Ripples travelling outward from the sphere.
    for (int i = 0; i < 3; i++) {
        float age = rippleAges[i];
        if (age >= 0.0 && age < 1.5) {
            float q = age / 1.5;
            float e = 1.0 - pow(1.0 - q, 2.2);
            float radius = R * 1.04 + e * R * 0.95;
            float width = (1.0 + 3.0 * (1.0 - q)) / unit;
            float line = 1.0 - smoothstep(0.0, width, abs(r - radius));
            out = over(out, rippleColor, pow(1.0 - q, 1.6) * 0.6 * line * amplitude);
        }
    }
    return out;
}
```

- [ ] **Step 5: Run `xcodegen` and the full test build.** The tests must pass and the shader must compile into the app's default metallib (a Metal compile error fails the build). Run the Debug and Release device builds too.
- [ ] **Step 6: Report.** Suggested message: `Phase 9: orb colors, ripples and the glass shader`.

---

### Task 5: The glass orb view

**Files:**
- Create: `Tapout/Effects/GlassOrbView.swift`
- Modify: `Tapout/Components/OrbView.swift` (extract `OrbSealRing`)
- Test: `TapoutTests/GlassOrbRenderTests.swift` (best effort, see Step 4)

**Interfaces:**
- Consumes: `OrbColors.mixed(tone:light:)`, `OrbRipples`, `MotionBudget.frameInterval`, Metal function `glassOrb` (Task 4), `OrbTone`.
- Produces: `struct OrbSealRing: View` with `init(tone: OrbTone, ring: Double, size: CGFloat)`; `struct GlassOrbView: View, Animatable` with `init(tone: Double, ringTone: OrbTone? = nil, ring: Double = 0, size: CGFloat = 300, tilt: SIMD2<Double> = .zero, ripples: OrbRipples = OrbRipples(), amplitude: Double = 1)`.

- [ ] **Step 1: Extract the ring.** Move `OrbView.sealRing`'s body into `struct OrbSealRing: View` (same file, internal access) taking `tone`, `ring` and `size`, with the identical drawing (track circle only while 0 < progress < 1, trimmed stroke, `Color.emberLine`/`Color.slateLine`, shadow). `OrbView` uses `OrbSealRing(tone: ringTone ?? tone, ring: ring, size: size)`. Run the existing tests: nothing about the classic orb may change.

- [ ] **Step 2: Write `GlassOrbView`.**

```swift
// Tapout/Effects/GlassOrbView.swift
import SwiftUI

/// The shader-drawn orb. Same layout contract as `OrbView` (a `size` square, the glow spills outside it),
/// with live tilt, ripples and a slate-to-ember mix that animates under `withAnimation`.
struct GlassOrbView: View, Animatable {
    /// 0 is slate, 1 is ember.
    var tone: Double
    var ringTone: OrbTone?
    var ring: Double
    var size: CGFloat
    var tilt: SIMD2<Double>
    var ripples: OrbRipples
    /// 0 freezes the sway and ripples (the picture still draws).
    var amplitude: Double

    @Environment(\.colorScheme) private var colorScheme

    init(tone: Double, ringTone: OrbTone? = nil, ring: Double = 0, size: CGFloat = 300,
         tilt: SIMD2<Double> = .zero, ripples: OrbRipples = OrbRipples(), amplitude: Double = 1) {
        self.tone = tone
        self.ringTone = ringTone
        self.ring = ring
        self.size = size
        self.tilt = tilt
        self.ripples = ripples
        self.amplitude = amplitude
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(tone, ring) }
        set { tone = newValue.first; ring = newValue.second }
    }

    /// The shader's square: the orb plus room for the glow and ripples.
    private var canvas: CGFloat { size * 1.44 }

    var body: some View {
        let light = colorScheme == .light
        let colors = OrbColors.mixed(tone: tone, light: light)
        ZStack {
            TimelineView(.animation(minimumInterval: MotionBudget.frameInterval)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                Rectangle()
                    .fill(Color.white)
                    .frame(width: canvas, height: canvas)
                    .colorEffect(ShaderLibrary.glassOrb(
                        .float(canvas), .float(size),
                        .float(tilt.x * amplitude), .float(tilt.y * amplitude),
                        .float(now.truncatingRemainder(dividingBy: 3600)), .float(light ? 1 : 0),
                        .float3(Double(colors.hi.x), Double(colors.hi.y), Double(colors.hi.z)),
                        .float3(Double(colors.mid.x), Double(colors.mid.y), Double(colors.mid.z)),
                        .float3(Double(colors.deep.x), Double(colors.deep.y), Double(colors.deep.z)),
                        .float3(Double(colors.edge.x), Double(colors.edge.y), Double(colors.edge.z)),
                        .float3(Double(colors.glow.x), Double(colors.glow.y), Double(colors.glow.z)),
                        .float(Double(colors.glowAlpha)),
                        .float3(Double(colors.ripple.x), Double(colors.ripple.y), Double(colors.ripple.z)),
                        .float3(Double(ripples.ages(at: now).x), Double(ripples.ages(at: now).y), Double(ripples.ages(at: now).z)),
                        .float(amplitude)))
            }
            OrbSealRing(tone: ringTone ?? (tone >= 0.5 ? .ember : .slate), ring: ring, size: size)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone >= 0.5 ? (ring >= 1 ? "Sealed ember orb" : "Ember orb") : "Slate orb")
    }
}
```

The `Shader.Argument` overloads (`float`, `float3`) take `Double`/`CGFloat` here; if the SDK offers a `SIMD3<Float>` overload or wants `Float`, use whichever compiles. Argument order must match the Metal signature exactly: canvas, orbSize, tiltX, tiltY, time, lightMode, hi, mid, deep, edge, glow, glowAlpha, rippleColor, rippleAges (a float3), amplitude. `allowsHitTesting(false)` keeps the orb from swallowing taps meant for a wrapping `Button`.

- [ ] **Step 3: Add a `#Preview`** that shows the slate and ember orbs side by side in dark mode, to compare with `OrbView`.

- [ ] **Step 4: Render test (best effort).**

```swift
// TapoutTests/GlassOrbRenderTests.swift
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct GlassOrbRenderTests {
    @Test func theShaderDrawsASphereWithTransparentCorners() throws {
        let renderer = ImageRenderer(content: GlassOrbView(tone: 1, size: 200).frame(width: 288, height: 288))
        renderer.scale = 1
        let image = try #require(renderer.uiImage?.cgImage)
        // Corner: outside the glow's reach. Centre: inside the sphere.
        let corner = try pixel(image, x: 2, y: 2)
        let centre = try pixel(image, x: 144, y: 160)
        #expect(corner.alpha < 0.05)
        #expect(centre.alpha > 0.95)
        #expect(centre.red > centre.blue) // ember, not slate
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var data = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        let a = Double(data[3]) / 255
        return (Double(data[0]) / 255, Double(data[1]) / 255, Double(data[2]) / 255, a)
    }
}
```

`ImageRenderer` may not run Metal shaders or `TimelineView` content. If the test cannot be made to pass for that reason (the image is blank or only the ring renders), delete this test file, say so in the report, and instead render the Lab screenshot in Task 7. Do not keep a test that passes by asserting less. Note the first-frame time: a `TimelineView` renders at once in `ImageRenderer`.

- [ ] **Step 5: Run the full suite and both device builds.**
- [ ] **Step 6: Report.** Suggested message: `Phase 9: glass orb view and seal ring`.

---

### Task 6: LivingOrb host and the first two screens

**Files:**
- Create: `Tapout/Effects/LivingOrb.swift`
- Modify: `Tapout/Features/Home/HomeView.swift` (three `OrbView` calls), `Tapout/Features/Home/LockMomentView.swift` (two `OrbView` calls and the haptic)
- Test: `TapoutTests/LivingOrbTests.swift`

**Interfaces:**
- Consumes: `AppSettings.livingGlassKey`, `MotionBudget.level`, `MotionEnvironment.shared`, `MotionSource.shared`, `GlassOrbView`, `OrbView`, `HapticEngine.shared`.
- Produces: `struct LivingOrb: View` with `init(tone: OrbTone, ringTone: OrbTone? = nil, ring: Double = 0, size: CGFloat = 300, ripplesOnAppear: Bool = false)`; `enum LivingOrbChoice { case classic, glass }` with `static func choose(flag: Bool, level: MotionLevel) -> LivingOrbChoice`.

- [ ] **Step 1: Write the failing test**

```swift
// TapoutTests/LivingOrbTests.swift
import Testing
@testable import Tapout

struct LivingOrbTests {
    @Test func glassNeedsTheFlagAndFullMotion() {
        #expect(LivingOrbChoice.choose(flag: true, level: .full) == .glass)
        #expect(LivingOrbChoice.choose(flag: false, level: .full) == .classic)
        #expect(LivingOrbChoice.choose(flag: true, level: .still) == .classic)
        #expect(LivingOrbChoice.choose(flag: false, level: .still) == .classic)
    }
}
```

- [ ] **Step 2: Run to verify it fails.**

- [ ] **Step 3: Implement**

```swift
// Tapout/Effects/LivingOrb.swift
import SwiftUI

/// Which orb to draw.
enum LivingOrbChoice: Equatable {
    case classic, glass

    static func choose(flag: Bool, level: MotionLevel) -> LivingOrbChoice {
        flag && level == .full ? .glass : .classic
    }
}

/// `OrbView`'s signature. Draws the shader orb when the flag is on and the motion budget allows,
/// otherwise exactly the classic orb.
struct LivingOrb: View {
    var tone: OrbTone
    var ringTone: OrbTone? = nil
    var ring: Double = 0
    var size: CGFloat = 300
    /// A ripple when the orb appears, which is how a lock or unlock shows on Home.
    var ripplesOnAppear = false

    @AppStorage(AppSettings.livingGlassKey) private var flag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var ripples = OrbRipples()
    private let environment = MotionEnvironment.shared
    private let motion = MotionSource.shared

    private var choice: LivingOrbChoice {
        LivingOrbChoice.choose(
            flag: flag,
            level: MotionBudget.level(reduceMotion: reduceMotion, lowPowerMode: environment.lowPowerMode,
                                      thermalState: environment.thermalState, sceneActive: scenePhase == .active))
    }

    var body: some View {
        switch choice {
        case .classic:
            OrbView(tone: tone, ringTone: ringTone, ring: ring, size: size)
        case .glass:
            GlassOrbView(tone: tone == .ember ? 1 : 0, ringTone: ringTone, ring: ring, size: size,
                         tilt: motion.tilt, ripples: ripples)
                .animation(Motion.tone, value: tone)
                .onAppear {
                    motion.acquire()
                    if ripplesOnAppear { ripples.add(at: Date.timeIntervalSinceReferenceDate) }
                }
                .onDisappear { motion.release() }
                .onChange(of: tone) { ripples.add(at: Date.timeIntervalSinceReferenceDate) }
        }
    }
}
```

`@State` mutation inside `onAppear` of a conditionally shown branch is fine. If `@AppStorage` plus the `private let` observable properties produce Swift 6 isolation errors, adjust isolation, not the language mode.

- [ ] **Step 4: Wire the screens.** In `HomeView.swift` replace the three `OrbView(` calls (unlocked, locked, emergency) with `LivingOrb(` keeping every argument, and add `ripplesOnAppear: true` to each. The `.lockMomentMatch(.orb)` modifiers and the `Button` wrapper stay as they are. In `LockMomentView.swift` replace the two `OrbView(` calls with `LivingOrb(`. In `LockMomentView.play()` replace `Haptics.lock()` with:

```swift
        if AppSettings.livingGlassEnabled() {
            HapticEngine.shared.play(.lock)
        } else {
            Haptics.lock()
        }
```

(`LockMomentView` is a view; if `play()` is not main-actor isolated, call through `await MainActor.run { }` or match how `Haptics.lock()` is already called.)

- [ ] **Step 5: Verify with the flag off (must be unchanged).** Run the full suite. Then on the iPhone 17 simulator, `bin/relaunch` with the flag unset and take `p9-6-home-off-dark` and `p9-6-home-off-light` screenshots (Home unlocked); compare with a `p8-4-home-dark.png` style capture: the orb must look identical to before.

- [ ] **Step 6: Verify with the flag on.** `xcrun simctl spawn 33A5EBE9-5D77-488C-85C0-FDBC419C7ECE defaults write com.raphymuthu.tapout settings.livingGlass -bool YES`, relaunch, take `p9-6-home-on-dark`, `p9-6-home-on-light` and a locked state (`-demoLock` or the existing demo argument that shows a locked Home; check `LockEngine+Debug.swift`). View each screenshot and describe what you see in the report: the glass orb should read as the same orb, with a visible gloss and glow, and the ring on the locked one. Reset the default afterwards (`defaults delete`).

- [ ] **Step 7: Run both device builds.**
- [ ] **Step 8: Report.** Suggested message: `Phase 9: living orb on Home and the lock moment`.

---

### Task 7: Lab Effects page, checklist and docs

**Files:**
- Create: `Tapout/Features/Lab/EffectsGallery.swift`
- Modify: `Tapout/Features/Lab/LabView.swift`, `docs/superpowers/verification/iphone-run-checklist.md`, `docs/superpowers/specs/2026-11-24-phase9-living-glass-design.md` (only if reality differed), `design/SCREENS.md` (one line)

**Interfaces:**
- Consumes: everything above.
- Produces: `EffectsGallery` (DEBUG only), linked from the Lab.

- [ ] **Step 1: Build `EffectsGallery`** (whole file inside `#if DEBUG`, plain system list styling like the rest of the Lab). Sections:
  1. **Flag**: `Toggle("Living glass in the app", isOn: $flag)` with `@AppStorage(AppSettings.livingGlassKey)`.
  2. **Motion**: `LabeledContent` rows for Reduce Motion (`@Environment(\.accessibilityReduceMotion)`), Low Power Mode and thermal state (from `MotionEnvironment.shared`), scene phase, and the resulting `MotionLevel`.
  3. **Orb**: a `GlassOrbView` at 220 pt in the section, with `@State` tone and ring sliders (0...1), a ripple on tap (`OrbRipples` kept in `@State`, `add(at: Date.timeIntervalSinceReferenceDate)`), tilt from `MotionSource.shared` (acquire in `.onAppear`, release in `.onDisappear`), and animated changes through `withAnimation(Motion.tone)` when the tone slider ends. Beside it, the classic `OrbView` at 160 pt with the same tone (slate when tone < 0.5, else ember) and ring, for comparison.
  4. **Tilt**: x and y as monospaced digits.
  5. **Haptics**: one `Button` per `HapticPattern.allCases` that calls `HapticEngine.shared.play(pattern)`, labelled with the case name.
  Add `NavigationLink("Effects") { EffectsGallery() }` to a new "Living glass" section in `LabView` (keep it inside the existing `#if DEBUG`).

- [ ] **Step 2: Screenshots.** Launch the Lab effects page on the simulator and save `p9-7-effects-dark`, `p9-7-effects-light` (and, if a way to open it directly is easy, a screenshot of the orb with the ember tone at ring 0.7). View them and describe the glass orb next to the classic one in the report. If the page is only reachable by tapping, use `mcp__Claude_Code_iOS_Simulator__control` taps.

- [ ] **Step 3: Checklist.** Append to `docs/superpowers/verification/iphone-run-checklist.md` a new section **13. Phase 9: living glass** with these checks (match the file's existing format, and update its item count in the header and any total):
  1. Lab, Effects: switch "Living glass in the app" on. Home's orb is the glass one and looks like the same orb, only livelier.
  2. Tilt the phone: the highlight moves smoothly with it, with no jitter, and settles when you hold still.
  3. Lock and unlock: a ripple travels out from the orb each time Home shows the new state.
  4. Lock moment with the flag on: two taps, then a soft swell, with the same sequence and no dropped frames.
  5. Lab, Effects, Haptics: lock, unlock, detent, scrub and paired each feel distinct and right. Note any that do not.
  6. Settings, Accessibility, Reduce Motion on: Home shows the classic orb. Turn it off: the glass orb returns.
  7. Low Power Mode on: classic orb. Off: glass again.
  8. Light appearance: the glass orb matches the classic one's colors in both modes.
  9. Largest Dynamic Type: the orb shrinks as before and nothing overlaps.
  10. Leave Home open on a charger-free phone for 30 minutes with the flag on, then off for 30 minutes: note the battery drop for each and whether the phone gets warm.
  11. Switch the flag off: every screen is exactly as before.

- [ ] **Step 4: One line in `design/SCREENS.md`** under "Where the screens and the design-system README disagree": the Home orb can be the shader-drawn glass orb (Phase 9, behind a flag); the classic layered-gradient orb stays the reference and the fallback.

- [ ] **Step 5: Run the full suite and both device builds.**
- [ ] **Step 6: Report.** Suggested message: `Phase 9: Lab effects page and device checklist`.
