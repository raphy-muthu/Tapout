# Phase 1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A runnable SwiftUI Tapout app with the design tokens, glass orb, floating tab bar, and Home in its unlocked / locked / emergency states (plus the lock moment), driven by mock data.

**Architecture:** XcodeGen generates the Xcode project from `project.yml`. Colour assets are generated from `design/design-system/tokens.json` by a script. A `@MainActor @Observable` `MockLockController` owns a `LockSession` value; views read it, and a 1-second clock task drives auto-relock. No persistence, NFC or Screen Time yet.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, XcodeGen, iOS 17 deployment target, Xcode 27.1, simulator iPhone 17 (iOS 26.5).

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. Bundle ID `com.raphymuthu.tapout`.
- No third-party packages.
- Colours only through asset-catalog tokens (`Color.bg`, `Color.emberInk`, …). The only raw hex lives in `OrbPalette` (orb gradient stops, not tokens).
- SF Pro for text, SF Pro Rounded for numbers, `.monospacedDigit()` on anything that ticks.
- 44pt minimum touch targets, continuous corners, no borders on cards.
- Lock = two rigid taps 90 ms apart; unlock = one soft tap; Reduce Motion swaps springs for crossfades, haptics still play.
- Copy: very few words, no guilt, no emoji, no exclamation marks.
- Mock values live in `MockData` and are named as mock.
- Never commit. The user commits manually; each task ends with a suggested commit message.

## File map

| File | Responsibility |
| --- | --- |
| `project.yml` | XcodeGen project: app + test targets, Info.plist keys |
| `scripts/gen-colors.py` | `tokens.json` → `Colors.xcassets` |
| `Tapout/App/TapoutApp.swift` | App entry; DEBUG launch-argument state |
| `Tapout/App/RootView.swift` | Tab switching, tab bar, lock-moment overlay, clock task |
| `Tapout/DesignSystem/Color+Tokens.swift` | `Color` accessors per token |
| `Tapout/DesignSystem/Accent.swift` | Accent roles by `LockState`, environment entry |
| `Tapout/DesignSystem/Typography.swift` | `Font` styles |
| `Tapout/DesignSystem/Layout.swift` | `Space`, `Radius`, `cardShadow()` |
| `Tapout/DesignSystem/Motion.swift` | Springs and durations |
| `Tapout/DesignSystem/Haptics.swift` | Lock / unlock / mismatch / select |
| `Tapout/Model/LockSession.swift` | `LockState`, `LockSession` + time helpers |
| `Tapout/Model/TimeFormat.swift` | `clock`, `short`, `spoken` |
| `Tapout/Model/MockData.swift` | Placeholder values |
| `Tapout/Model/MockLockController.swift` | Session state machine |
| `Tapout/Components/OrbView.swift` | Glass orb |
| `Tapout/Components/FloatingTabBar.swift` | `AppTab` + capsule tab bar |
| `Tapout/Components/PrimaryButton.swift` | Primary pill + `PressScaleStyle` |
| `Tapout/Components/StateLabel.swift` | State word + glyph |
| `Tapout/Components/TimerText.swift` | Hero numerals with capped Dynamic Type |
| `Tapout/Features/Home/HomeView.swift` | Home's 3 states |
| `Tapout/Features/Home/HomeHeader.swift` | Mode pill + settings button |
| `Tapout/Features/Home/LockMomentView.swift` | 4-frame lock animation |
| `Tapout/Features/Placeholder/PlaceholderView.swift` | Stand-in for later screens |
| `TapoutTests/*.swift` | Colour, time, session and controller tests |

Build/test command used throughout (run from `~/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -quiet test
```

---

### Task 1: Project scaffold and colour tokens

**Files:**
- Create: `project.yml`, `scripts/gen-colors.py`, `Tapout/App/TapoutApp.swift` (temporary), `Tapout/DesignSystem/Color+Tokens.swift`, `Tapout/DesignSystem/Colors.xcassets/**` (generated)
- Modify: `.gitignore` (add `Tapout.xcodeproj/`)
- Test: `TapoutTests/ColorTokenTests.swift`

**Interfaces:**
- Produces: `Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.inkTertiary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.onEmber`, `.slate`, `.slateInk`, `.slateLine`, `.slateGlow`, `.onSlate`, `.track`, `.danger`, `.scrim`.

- [ ] **Step 1: Install XcodeGen** — `brew install xcodegen`

- [ ] **Step 2: Write the project file**

<!-- file: project.yml -->
```yaml
name: Tapout
options:
  bundleIdPrefix: com.raphymuthu
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS: NO
    ENABLE_USER_SCRIPT_SANDBOXING: YES
targets:
  Tapout:
    type: application
    platform: iOS
    sources:
      - path: Tapout
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
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: ""
        ASSETCATALOG_COMPILER_APPICON_NAME: "" # app icon arrives with the AppIcon screen
  TapoutTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: TapoutTests
    dependencies:
      - target: Tapout
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.raphymuthu.tapout.tests
        GENERATE_INFOPLIST_FILE: YES
schemes:
  Tapout:
    build:
      targets:
        Tapout: all
        TapoutTests: [test]
    test:
      targets:
        - TapoutTests
```

- [ ] **Step 3: Write the colour generator**

<!-- file: scripts/gen-colors.py -->
```python
#!/usr/bin/env python3
"""Generate Colors.xcassets colour sets from design/design-system/tokens.json.

Run from anywhere: python3 scripts/gen-colors.py
Each token becomes one colour set named exactly like the token,
with Any = light value and Dark = dark value.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design/design-system/tokens.json"
OUT = ROOT / "Tapout/DesignSystem/Colors.xcassets"
INFO = {"author": "xcode", "version": 1}


def components(hex_value):
    h = hex_value.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    return {"red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}", "alpha": f"{a:.3f}"}


def colour(hex_value):
    return {"color-space": "srgb", "components": components(hex_value)}


def main():
    tokens = json.loads(TOKENS.read_text(encoding="utf-8"))["color"]["tokens"]
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    (OUT / "Contents.json").write_text(json.dumps({"info": INFO}, indent=2) + "\n")
    for token in tokens:
        light, dark = token["value"]["light"], token["value"]["dark"]
        folder = OUT / f"{token['name']}.colorset"
        folder.mkdir()
        contents = {
            "colors": [
                {"idiom": "universal", "color": colour(light)},
                {
                    "idiom": "universal",
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "color": colour(dark),
                },
            ],
            "info": INFO,
        }
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print(f"Wrote {len(tokens)} colour sets to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Write a temporary app entry so the project builds**

<!-- file: Tapout/App/TapoutApp.swift -->
```swift
import SwiftUI

@main
struct TapoutApp: App {
    var body: some Scene {
        WindowGroup {
            Color.bg.ignoresSafeArea()
        }
    }
}
```

- [ ] **Step 5: Write the failing colour test**

<!-- file: TapoutTests/ColorTokenTests.swift -->
```swift
import Testing
import UIKit
@testable import Tapout

struct ColorTokenTests {
    static let names = [
        "bg", "surface-1", "surface-2", "ink", "ink-secondary", "ink-tertiary",
        "ember", "ember-ink", "ember-line", "ember-glow", "on-ember",
        "slate", "slate-ink", "slate-line", "slate-glow", "on-slate",
        "track", "danger", "scrim",
    ]

    @Test(arguments: names)
    func colourSetExists(_ name: String) {
        #expect(UIColor(named: name) != nil, "missing colour set \(name)")
    }

    @Test func backgroundDiffersByAppearance() throws {
        let bg = try #require(UIColor(named: "bg"))
        let dark = bg.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = bg.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        #expect(dark != light)
    }
}
```

- [ ] **Step 6: Run tests — expect failure** (no colour sets yet). Run the build/test command. Expected: `colourSetExists` fails for all 19 names.

- [ ] **Step 7: Generate colours and write accessors**

Run: `python3 -I scripts/gen-colors.py` → `Wrote 19 colour sets to Tapout/DesignSystem/Colors.xcassets`

<!-- file: Tapout/DesignSystem/Color+Tokens.swift -->
```swift
import SwiftUI

/// One accessor per colour set in Colors.xcassets, which is generated from
/// design/design-system/tokens.json by scripts/gen-colors.py.
extension Color {
    static let bg = Color("bg")
    static let surface1 = Color("surface-1")
    static let surface2 = Color("surface-2")
    static let ink = Color("ink")
    static let inkSecondary = Color("ink-secondary")
    static let inkTertiary = Color("ink-tertiary")
    static let ember = Color("ember")
    static let emberInk = Color("ember-ink")
    static let emberLine = Color("ember-line")
    static let emberGlow = Color("ember-glow")
    static let onEmber = Color("on-ember")
    static let slate = Color("slate")
    static let slateInk = Color("slate-ink")
    static let slateLine = Color("slate-line")
    static let slateGlow = Color("slate-glow")
    static let onSlate = Color("on-slate")
    static let track = Color("track")
    static let danger = Color("danger")
    static let scrim = Color("scrim")
}
```

Append `Tapout.xcodeproj/` to `.gitignore`.

- [ ] **Step 8: Run tests — expect pass** (20 passing).

- [ ] **Step 9: Leave uncommitted.** Suggested message: `Add XcodeGen project and generated colour tokens`

---

### Task 2: Design system and lock model

**Files:**
- Create: `Tapout/DesignSystem/{Accent,Typography,Layout,Motion,Haptics}.swift`, `Tapout/Model/{LockSession,TimeFormat,MockData,MockLockController}.swift`
- Test: `TapoutTests/{TimeFormatTests,LockSessionTests,MockLockControllerTests}.swift`

**Interfaces:**
- Consumes: `Color` tokens (Task 1).
- Produces:
  - `enum LockState { case locked, unlocked }`
  - `enum LockSession: Equatable { case unlocked; case locked(since: Date); case emergency(relockAt: Date, duration: TimeInterval) }` with `lockState`, `elapsed(at:) -> TimeInterval`, `remaining(at:) -> TimeInterval`, `remainingFraction(at:) -> Double`
  - `struct Accent { fill, onFill, ink, line, glow: Color; static func for(_: LockState) -> Accent }`, `EnvironmentValues.accent`
  - `enum TimeFormat { static func clock(_:) -> String; static func short(_:) -> String; static func spoken(_:) -> String }`
  - `enum MockData { modeName, placeName, phoneFreeToday }`
  - `@MainActor @Observable final class MockLockController` — `init(session:passesLeft:now:)`, `session`, `passesLeft`, `simulateTagRead()`, `useEmergencyPass()`, `relockNow()`, `tick()`, `static let emergencyDuration`, `static let totalPasses`
  - `Font.timerHero … .tCaption`, `Space.*`, `Radius.*`, `View.cardShadow()`, `Motion.*`, `Haptics.prepare/lock/unlock/mismatch/select`

- [ ] **Step 1: Write the failing tests**

<!-- file: TapoutTests/TimeFormatTests.swift -->
```swift
import Testing
@testable import Tapout

struct TimeFormatTests {
    @Test func underAnHourShowsMinutesAndSeconds() {
        #expect(TimeFormat.clock(0) == "0:00")
        #expect(TimeFormat.clock(47 * 60 + 12) == "47:12")
        #expect(TimeFormat.clock(59 * 60 + 59) == "59:59")
    }

    @Test func fromAnHourShowsHoursAndMinutes() {
        #expect(TimeFormat.clock(3600) == "1:00")
        #expect(TimeFormat.clock(3600 + 5 * 60 + 59) == "1:05")
    }

    @Test func clockRoundsDownAndNeverGoesNegative() {
        #expect(TimeFormat.clock(59.9) == "0:59")
        #expect(TimeFormat.clock(-5) == "0:00")
    }

    @Test func shortForm() {
        #expect(TimeFormat.short(2 * 3600 + 40 * 60) == "2h 40m")
        #expect(TimeFormat.short(40 * 60) == "40m")
        #expect(TimeFormat.short(3600) == "1h")
        #expect(TimeFormat.short(0) == "0m")
    }

    @Test func spokenForm() {
        #expect(TimeFormat.spoken(47 * 60 + 12) == "47 minutes")
        #expect(TimeFormat.spoken(3600 + 5 * 60) == "1 hour, 5 minutes")
        #expect(TimeFormat.spoken(30) == "30 seconds")
    }
}
```

<!-- file: TapoutTests/LockSessionTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

struct LockSessionTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func elapsedCountsUpWhileLocked() {
        #expect(LockSession.locked(since: t0).elapsed(at: t0 + 2832) == 2832)
        #expect(LockSession.locked(since: t0).elapsed(at: t0 - 5) == 0)
        #expect(LockSession.unlocked.elapsed(at: t0) == 0)
    }

    @Test func remainingCountsDownDuringEmergency() {
        let session = LockSession.emergency(relockAt: t0 + 300, duration: 300)
        #expect(session.remaining(at: t0 + 28) == 272)
        #expect(session.remainingFraction(at: t0 + 150) == 0.5)
        #expect(session.remaining(at: t0 + 400) == 0)
        #expect(session.remainingFraction(at: t0 + 400) == 0)
    }

    @Test func lockStatePicksTheAccent() {
        #expect(LockSession.unlocked.lockState == .unlocked)
        #expect(LockSession.locked(since: t0).lockState == .locked)
        #expect(LockSession.emergency(relockAt: t0, duration: 300).lockState == .locked)
    }
}
```

<!-- file: TapoutTests/MockLockControllerTests.swift -->
```swift
import Foundation
import Testing
@testable import Tapout

@MainActor
struct MockLockControllerTests {
    private final class Clock {
        var now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    }

    private let clock = Clock()

    private func makeController(session: LockSession = .unlocked, passesLeft: Int = 3) -> MockLockController {
        MockLockController(session: session, passesLeft: passesLeft, now: { [clock] in clock.now })
    }

    @Test func startsUnlockedWithThreePasses() {
        let controller = makeController()
        #expect(controller.session == .unlocked)
        #expect(controller.passesLeft == 3)
    }

    @Test func tagReadLocksAtTheCurrentTime() {
        let controller = makeController()
        controller.simulateTagRead()
        #expect(controller.session == .locked(since: clock.now))
    }

    @Test func tagReadWhileLockedUnlocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.simulateTagRead()
        #expect(controller.session == .unlocked)
    }

    @Test func emergencyPassSpendsOneAndOpensForFiveMinutes() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        #expect(controller.passesLeft == 2)
        #expect(controller.session == .emergency(relockAt: clock.now + 300, duration: 300))
    }

    @Test func emergencyPassNeedsALockAndAPass() {
        let unlocked = makeController()
        unlocked.useEmergencyPass()
        #expect(unlocked.session == .unlocked)
        #expect(unlocked.passesLeft == 3)

        let since = clock.now
        let empty = makeController(session: .locked(since: since), passesLeft: 0)
        empty.useEmergencyPass()
        #expect(empty.session == .locked(since: since))
        #expect(empty.passesLeft == 0)
    }

    @Test func tickBeforeExpiryKeepsAppsOpen() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        clock.now += 299
        controller.tick()
        #expect(controller.session.lockState == .locked)
        #expect(controller.session != .locked(since: clock.now))
        if case .emergency = controller.session {} else { Issue.record("expected emergency") }
    }

    @Test func tickAtExpiryRelocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        let relockAt = clock.now + 300
        clock.now += 300
        controller.tick()
        #expect(controller.session == .locked(since: relockAt))
    }

    @Test func relockNowLocksImmediately() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        clock.now += 60
        controller.relockNow()
        #expect(controller.session == .locked(since: clock.now))
        #expect(controller.passesLeft == 2)
    }

    @Test func tagReadDuringEmergencyUnlocks() {
        let controller = makeController(session: .locked(since: clock.now))
        controller.useEmergencyPass()
        controller.simulateTagRead()
        #expect(controller.session == .unlocked)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure** (`TimeFormat`, `LockSession`, `MockLockController` undefined).

- [ ] **Step 3: Write the model**

<!-- file: Tapout/Model/LockSession.swift -->
```swift
import Foundation

/// The two accent states from the design system: ember owns locked, slate owns unlocked.
enum LockState {
    case locked, unlocked
}

/// What the phone is doing right now.
enum LockSession: Equatable {
    case unlocked
    case locked(since: Date)
    /// An emergency pass is open; apps relock at `relockAt`.
    case emergency(relockAt: Date, duration: TimeInterval)

    /// An emergency pass is part of a lock, so ember keeps the accent.
    var lockState: LockState {
        switch self {
        case .unlocked: .unlocked
        case .locked, .emergency: .locked
        }
    }

    /// Time locked so far. Zero when not locked.
    func elapsed(at date: Date) -> TimeInterval {
        guard case .locked(let since) = self else { return 0 }
        return max(0, date.timeIntervalSince(since))
    }

    /// Time until an emergency pass relocks. Zero otherwise.
    func remaining(at date: Date) -> TimeInterval {
        guard case .emergency(let relockAt, _) = self else { return 0 }
        return max(0, relockAt.timeIntervalSince(date))
    }

    /// Share of the emergency pass still left, 0...1; drives the orb ring.
    func remainingFraction(at date: Date) -> Double {
        guard case .emergency(_, let duration) = self, duration > 0 else { return 0 }
        return min(1, remaining(at: date) / duration)
    }
}
```

<!-- file: Tapout/Model/TimeFormat.swift -->
```swift
import Foundation

enum TimeFormat {
    /// Hero timer text: `m:ss` under an hour, `h:mm` from one hour. At most 5 characters.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total >= 3600 {
            return "\(total / 3600):" + String(format: "%02d", total % 3600 / 60)
        }
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// Compact duration for stats: "2h 40m", "40m", "1h".
    static func short(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds)) / 60
        let hours = minutes / 60
        switch (hours, minutes % 60) {
        case (0, let m): return "\(m)m"
        case (let h, 0): return "\(h)h"
        case (let h, let m): return "\(h)h \(m)m"
        }
    }

    /// VoiceOver form: "47 minutes", "1 hour, 5 minutes", "30 seconds".
    static func spoken(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds < 60 ? [.second] : [.hour, .minute]
        return formatter.string(from: max(0, seconds.rounded(.down))) ?? ""
    }
}
```

<!-- file: Tapout/Model/MockData.swift -->
```swift
import Foundation

/// Placeholder content for Phase 1. Every value here stands in for real data from later phases.
enum MockData {
    static let modeName = "Deep work"
    static let placeName = "Kitchen"
    static let phoneFreeToday: TimeInterval = 2 * 3600 + 40 * 60
}
```

<!-- file: Tapout/Model/MockLockController.swift -->
```swift
import Foundation
import Observation

/// Stands in for the real NFC + Screen Time controller until Phase 4. Nothing is persisted.
@MainActor
@Observable
final class MockLockController {
    /// An emergency pass opens apps for five minutes.
    static let emergencyDuration: TimeInterval = 5 * 60
    /// Five passes total, ever. They never refill.
    static let totalPasses = 5

    private(set) var session: LockSession
    private(set) var passesLeft: Int
    @ObservationIgnored private let now: () -> Date

    init(session: LockSession = .unlocked, passesLeft: Int = 3, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.passesLeft = passesLeft
        self.now = now
    }

    /// A paired tag was read: lock when unlocked, otherwise unlock.
    func simulateTagRead() {
        switch session {
        case .unlocked: session = .locked(since: now())
        case .locked, .emergency: session = .unlocked
        }
    }

    /// Spends one pass. Only works while locked with passes left.
    func useEmergencyPass() {
        guard case .locked = session, passesLeft > 0 else { return }
        passesLeft -= 1
        session = .emergency(relockAt: now() + Self.emergencyDuration, duration: Self.emergencyDuration)
    }

    /// Ends an emergency pass early.
    func relockNow() {
        guard case .emergency = session else { return }
        session = .locked(since: now())
    }

    /// Called every second; relocks when an emergency pass runs out.
    func tick() {
        if case .emergency(let relockAt, _) = session, now() >= relockAt {
            session = .locked(since: relockAt)
        }
    }
}

#if DEBUG
extension MockLockController {
    /// `-mockState locked|emergency` starts in that state, for screenshots.
    static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> MockLockController {
        guard let index = arguments.firstIndex(of: "-mockState"), index + 1 < arguments.count else {
            return MockLockController()
        }
        let now = Date()
        switch arguments[index + 1] {
        case "locked":
            return MockLockController(session: .locked(since: now - (47 * 60 + 12)))
        case "emergency":
            return MockLockController(session: .emergency(relockAt: now + (4 * 60 + 32), duration: emergencyDuration), passesLeft: 2)
        default:
            return MockLockController()
        }
    }
}
#endif
```

- [ ] **Step 4: Write the design-system files** (straight from README §4, §5, §7, §8, §10)

<!-- file: Tapout/DesignSystem/Accent.swift -->
```swift
import SwiftUI

/// The state accent's five roles. One hex can't be a fill, a text colour and a stroke
/// in both themes and still pass contrast, so each role is its own token.
struct Accent {
    let fill, onFill, ink, line, glow: Color

    static func `for`(_ state: LockState) -> Accent {
        switch state {
        case .locked:
            Accent(fill: .ember, onFill: .onEmber, ink: .emberInk, line: .emberLine, glow: .emberGlow)
        case .unlocked:
            Accent(fill: .slate, onFill: .onSlate, ink: .slateInk, line: .slateLine, glow: .slateGlow)
        }
    }
}

extension EnvironmentValues {
    @Entry var accent: Accent = .for(.unlocked)
}
```

<!-- file: Tapout/DesignSystem/Typography.swift -->
```swift
import SwiftUI

extension Font {
    // Numerals: SF Pro Rounded
    static let timerHero = Font.system(size: 112, weight: .ultraLight, design: .rounded).monospacedDigit()
    static let timerLarge = Font.system(size: 72, weight: .light, design: .rounded).monospacedDigit()
    static let numberDisplay = Font.system(size: 48, weight: .light, design: .rounded)
    static let numberMedium = Font.system(size: 28, weight: .regular, design: .rounded)
    static let numberSmall = Font.system(size: 17, weight: .medium, design: .rounded).monospacedDigit()
    // Text: SF Pro, Dynamic Type styles
    static let tLargeTitle = Font.largeTitle.weight(.semibold)
    static let tTitle = Font.title2.weight(.semibold)
    static let tHeadline = Font.headline
    static let tBody = Font.body
    static let tSubhead = Font.subheadline
    static let tFootnote = Font.footnote
    static let tCaption = Font.caption.weight(.medium)
}
```

<!-- file: Tapout/DesignSystem/Layout.swift -->
```swift
import SwiftUI

/// 4-point spacing scale.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let xxxxl: CGFloat = 96
}

/// Corner radii; always used with `style: .continuous`.
enum Radius {
    static let sm: CGFloat = 12
    static let inner: CGFloat = 16
    static let card: CGFloat = 24
    static let sheet: CGFloat = 32
}

/// The one soft shadow a card may carry in light theme (black 6%, y 2, blur 12). Dark has none.
private struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 6, y: 2)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
}
```

<!-- file: Tapout/DesignSystem/Motion.swift -->
```swift
import SwiftUI

/// Two springs carry the brand; everything else stays out of the way.
enum Motion {
    static var lock: Animation { .spring(response: 0.6, dampingFraction: 0.72) }
    static var unlock: Animation { .spring(response: 0.8, dampingFraction: 0.9) }
    static var ui: Animation { .spring(response: 0.4, dampingFraction: 0.85) }
    static var press: Animation { .easeOut(duration: 0.15) }
    static var reveal: Animation { .easeInOut(duration: 0.4) }
    // Reduce Motion: crossfade in place, no scale or travel
    static var lockReduced: Animation { .easeInOut(duration: 0.25) }
    static var unlockReduced: Animation { .easeInOut(duration: 0.35) }
    static var readyPulse: Animation { .easeInOut(duration: 1.6).repeatForever(autoreverses: true) }
}
```

<!-- file: Tapout/DesignSystem/Haptics.swift -->
```swift
import UIKit

/// Haptics are the one feedback channel that survives Reduce Motion, so never skip them.
@MainActor
enum Haptics {
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    /// Call when a tag session starts so the first lock tap lands on time.
    static func prepare() { rigid.prepare() }

    /// Two firm taps, 90 ms apart.
    static func lock() {
        rigid.prepare()
        rigid.impactOccurred(intensity: 1.0)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            rigid.impactOccurred(intensity: 1.0)
        }
    }

    /// One soft tap.
    static func unlock() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }

    static func mismatch() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}
```

- [ ] **Step 5: Run tests — expect pass.**

- [ ] **Step 6: Leave uncommitted.** Suggested message: `Add design system and mock lock model`

---

### Task 3: Shared components

**Files:**
- Create: `Tapout/Components/{OrbView,FloatingTabBar,PrimaryButton,StateLabel,TimerText}.swift`

**Interfaces:**
- Consumes: tokens, `Space`, `Motion`, `Haptics`, `EnvironmentValues.accent`, `cardShadow()`.
- Produces:
  - `enum OrbTone { case ember, slate }`; `OrbView(tone:ringTone:ring:size:)` (`ringTone: OrbTone? = nil`, `ring: Double = 0`, `size: CGFloat = 300`)
  - `enum AppTab: CaseIterable { home, modes, places, insights }` with `title`; `FloatingTabBar(active: Binding<AppTab>)`
  - `PrimaryButton(title:systemImage:action:)` reading `\.accent`; `PressScaleStyle`
  - `StateLabel(text:systemImage:color:)`; `TimerText(text:)`

These are views; they're verified by building, by `#Preview`, and by the simulator screenshots in Task 5 rather than unit tests.

- [ ] **Step 1: Write the orb**

<!-- file: Tapout/Components/OrbView.swift -->
```swift
import SwiftUI

enum OrbTone {
    case ember, slate
}

/// The glass orb hero, ported from `renderVals()` in design/screens/Orb.dc.html:
/// a glow, a glass body, a specular gloss and an optional seal ring.
struct OrbView: View {
    var tone: OrbTone
    /// Colour of the seal ring; defaults to the orb's own tone.
    var ringTone: OrbTone? = nil
    /// How much of the seal ring is drawn, 0...1.
    var ring: Double = 0
    var size: CGFloat = 300

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = OrbPalette(tone: tone, light: colorScheme == .light)
        let sphere = size * (1 - 2 * 0.13)
        ZStack {
            glow(palette)
            glassBody(palette, sphere: sphere)
            gloss(sphere: sphere)
            sealRing
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// Radial halo, 1.44× the orb, centred behind it.
    private func glow(_ palette: OrbPalette) -> some View {
        let side = size * 1.44
        return Circle()
            .fill(RadialGradient(stops: [
                .init(color: palette.glow.opacity(palette.glowAlpha), location: 0),
                .init(color: palette.glow.opacity(palette.glowAlpha * 0.35), location: 0.38),
                .init(color: palette.glow.opacity(0), location: 0.68),
            ], center: .center, startRadius: 0, endRadius: side / 2 * 1.4142)) // CSS farthest-corner
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }

    private func glassBody(_ palette: OrbPalette, sphere: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(stops: [
                    .init(color: palette.hi, location: 0),
                    .init(color: palette.mid, location: 0.34),
                    .init(color: palette.deep, location: 0.72),
                    .init(color: palette.edge, location: 1),
                ], center: UnitPoint(x: 0.5, y: 0.58), startRadius: 0, endRadius: sphere * 0.766)
                .shadow(.inner(color: .white.opacity(0.14), radius: sphere * 0.05, y: -sphere * 0.05))
                .shadow(.inner(color: .black.opacity(0.28), radius: sphere * 0.06, y: sphere * 0.06))
            )
            .overlay {
                // Light pooling at the bottom of the glass
                EllipseHighlight(rx: 0.7, ry: 0.34, cx: 0.5, cy: 0.92, side: sphere, stops: [
                    .init(color: .white.opacity(0.32), location: 0),
                    .init(color: .white.opacity(0), location: 0.7),
                ])
                .clipShape(Circle())
            }
            .overlay { Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
            .frame(width: sphere, height: sphere)
            .shadow(color: palette.dropShadow, radius: sphere * 0.09, y: sphere * 0.08)
    }

    private func gloss(sphere: CGFloat) -> some View {
        ZStack {
            EllipseHighlight(rx: 0.30, ry: 0.20, cx: 0.35, cy: 0.24, side: sphere, stops: [
                .init(color: .white.opacity(0.92), location: 0),
                .init(color: .white.opacity(0.35), location: 0.45),
                .init(color: .white.opacity(0), location: 1),
            ])
            EllipseHighlight(rx: 0.12, ry: 0.07, cx: 0.66, cy: 0.78, side: sphere, stops: [
                .init(color: .white.opacity(0.4), location: 0),
                .init(color: .white.opacity(0), location: 1),
            ])
        }
        .frame(width: sphere, height: sphere)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }

    /// Always in the tree (an empty trim draws nothing) so the ring can sweep in when animated.
    private var sealRing: some View {
        let progress = min(max(ring, 0), 1)
        let stroke = max(2.5, size * 0.016)
        let ember = (ringTone ?? tone) == .ember
        return ZStack {
            Circle()
                .stroke(Color.track, lineWidth: stroke)
                .opacity(progress > 0 && progress < 1 ? 1 : 0)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ember ? Color.emberLine : Color.slateLine,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size - stroke * 3, height: size - stroke * 3)
        .shadow(color: (ember ? Color.ember : Color.slate).opacity(0.7), radius: size * 0.025)
        .allowsHitTesting(false)
    }

    private var label: String {
        switch tone {
        case .ember: ring >= 1 ? "Sealed ember orb" : "Ember orb"
        case .slate: "Slate orb"
        }
    }
}

/// CSS `radial-gradient(ellipse rx% ry% at cx% cy%, …)` drawn in a `side` × `side` box.
private struct EllipseHighlight: View {
    let rx: CGFloat, ry: CGFloat, cx: CGFloat, cy: CGFloat
    let side: CGFloat
    let stops: [Gradient.Stop]

    var body: some View {
        let radius = side * rx
        Circle()
            .fill(RadialGradient(stops: stops, center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(x: 1, y: ry / rx)
            .position(x: side * cx, y: side * cy)
            .frame(width: side, height: side)
    }
}

/// Orb-only gradient stops from Orb.dc.html. Not design tokens: nothing else uses them.
private struct OrbPalette {
    let hi, mid, deep, edge, glow, dropShadow: Color
    let glowAlpha: Double

    init(tone: OrbTone, light: Bool) {
        switch tone {
        case .ember:
            hi = Color(rgb: 0xFFE3C4)
            mid = Color(rgb: 0xFF9F43)
            deep = Color(rgb: 0xC0600F)
            edge = Color(rgb: light ? 0x8A3F06 : 0x3D1702)
            glow = .ember
            glowAlpha = light ? 0.42 : 0.5
        case .slate:
            hi = Color(rgb: 0xEEF1F6)
            mid = Color(rgb: 0x9AA3B4)
            deep = Color(rgb: 0x555E70)
            edge = Color(rgb: light ? 0x4A5263 : 0x141820)
            glow = .slate
            glowAlpha = light ? 0.32 : 0.34
        }
        dropShadow = light ? Color(rgb: 0x15171B).opacity(0.18) : .black.opacity(0.5)
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB,
                  red: Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255)
    }
}

#Preview("Orbs") {
    VStack(spacing: 60) {
        OrbView(tone: .slate, size: 200)
        OrbView(tone: .ember, ring: 1, size: 200)
        OrbView(tone: .slate, ringTone: .ember, ring: 0.6, size: 200)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.bg)
}
```

- [ ] **Step 2: Write the tab bar, button, state label and timer**

<!-- file: Tapout/Components/FloatingTabBar.swift -->
```swift
import SwiftUI

/// Named `AppTab` because SwiftUI already has a `Tab` type.
enum AppTab: CaseIterable {
    case home, modes, places, insights

    var title: String {
        switch self {
        case .home: "Home"
        case .modes: "Modes"
        case .places: "Places"
        case .insights: "Insights"
        }
    }
}

/// The floating capsule tab bar from design/screens/TabBar.dc.html.
struct FloatingTabBar: View {
    @Binding var active: AppTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let light = colorScheme == .light
        HStack(spacing: Space.xxs) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    guard tab != active else { return }
                    Haptics.select()
                    active = tab
                } label: {
                    icon(for: tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(tab == active ? Color.ink : Color.inkTertiary)
                        .background {
                            if tab == active { Capsule(style: .continuous).fill(Color.surface2) }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == active ? .isSelected : [])
            }
        }
        .padding(Space.xs)
        .frame(height: 64)
        .background(Color.surface1, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(light ? 0.10 : 0.4), radius: light ? 10 : 12, y: light ? 4 : 8)
        .padding(.horizontal, Space.lg)
    }

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeGlyph()
        case .modes: Image(systemName: "slider.horizontal.3").font(.system(size: 20))
        case .places: Image(systemName: "mappin").font(.system(size: 20))
        case .insights: Image(systemName: "chart.bar").font(.system(size: 20))
        }
    }
}

/// The spec's custom Home icon: a ring inside a dashed ring.
private struct HomeGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(lineWidth: 1.6).frame(width: 14, height: 14)
            Circle().stroke(style: StrokeStyle(lineWidth: 1.6, dash: [3, 3])).frame(width: 20, height: 20)
        }
        .frame(width: 24, height: 24)
    }
}

#Preview {
    @Previewable @State var tab = AppTab.home
    VStack { Spacer(); FloatingTabBar(active: $tab) }
        .background(Color.bg)
}
```

<!-- file: Tapout/Components/PrimaryButton.swift -->
```swift
import SwiftUI

/// The one primary pill per screen, filled in the current state's accent.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.accent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
                }
                Text(title).font(.tHeadline)
            }
            .foregroundStyle(accent.onFill)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(accent.fill, in: Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Press feedback from the design system: scale 0.97, no colour change.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}
```

<!-- file: Tapout/Components/StateLabel.swift -->
```swift
import SwiftUI

/// The state word with its line glyph, e.g. "Locked" in ember-ink.
struct StateLabel: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
            Text(text).font(.tHeadline)
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }
}
```

<!-- file: Tapout/Components/TimerText.swift -->
```swift
import SwiftUI

/// Hero numerals. Scales with Dynamic Type but caps at 1.3× because it already fills the width.
struct TimerText: View {
    let text: String

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 112

    var body: some View {
        Text(text)
            .font(.system(size: min(size, 112 * 1.3), weight: .ultraLight, design: .rounded).monospacedDigit())
            .kerning(-3)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
```

- [ ] **Step 3: Build** (the build/test command) — expect success, all tests still pass.

- [ ] **Step 4: Leave uncommitted.** Suggested message: `Add orb, tab bar and shared components`

---

### Task 4: Home, lock moment and app shell

**Files:**
- Create: `Tapout/Features/Home/{HomeView,HomeHeader,LockMomentView}.swift`, `Tapout/Features/Placeholder/PlaceholderView.swift`, `Tapout/App/RootView.swift`
- Modify: `Tapout/App/TapoutApp.swift` (replace temporary body)

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: `RootView(controller:)`, `HomeView(controller:onScan:onOpenSettings:)`, `LockMomentView(placeName:onFinished:)`, `PlaceholderView(title:)`.

- [ ] **Step 1: Write Home**

<!-- file: Tapout/Features/Home/HomeHeader.swift -->
```swift
import SwiftUI

/// Mode pill (picker arrives with Modes in Phase 3) and the settings button.
struct HomeHeader: View {
    let modeName: String
    let isLocked: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if isLocked {
                    Image(systemName: "lock").font(.system(size: 14, weight: .semibold))
                }
                Text(modeName).font(.tSubhead.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isLocked ? Color.emberInk : Color.ink)
            .padding(.leading, 14)
            .padding(.trailing, Space.md)
            .frame(height: 44)
            .background(Color.surface1, in: Capsule(style: .continuous))
            .cardShadow()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mode: \(modeName)")

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
}
```

<!-- file: Tapout/Features/Home/HomeView.swift -->
```swift
import SwiftUI

/// Home in its three states, matching design/screens/Home.dc.html.
struct HomeView: View {
    let controller: MockLockController
    let onScan: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(modeName: MockData.modeName, isLocked: isLocked, onOpenSettings: onOpenSettings)
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
            VStack(spacing: Space.xl) {
                OrbView(tone: .slate, size: 300)
                VStack(spacing: Space.xxs) {
                    StateLabel(text: "Unlocked", systemImage: "lock.open", color: .slateInk)
                    Text("\(TimeFormat.short(MockData.phoneFreeToday)) phone-free today")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Scan", systemImage: "wave.3.right", action: onScan)
        }
    }

    private func locked(at date: Date) -> some View {
        let elapsed = controller.session.elapsed(at: date)
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 20) {
                // Stand-in for tapping a tag until Core NFC arrives in Phase 4.
                Button(action: unlock) {
                    OrbView(tone: .ember, ring: 1, size: 244)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock")
                .accessibilityHint("Stands in for tapping your tag")

                VStack(spacing: Space.xs) {
                    TimerText(text: TimeFormat.clock(elapsed))
                        .accessibilityLabel("Locked for \(TimeFormat.spoken(elapsed))")
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                }
            }
            Spacer(minLength: 0)
            if controller.passesLeft > 0 {
                Button(action: useEmergencyPass) {
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

    private func unlock() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.unlock) { controller.simulateTagRead() }
    }

    private func useEmergencyPass() {
        Haptics.unlock()
        withAnimation(reduceMotion ? Motion.unlockReduced : Motion.ui) { controller.useEmergencyPass() }
    }

    private func relockNow() {
        Haptics.lock()
        withAnimation(reduceMotion ? Motion.lockReduced : Motion.lock) { controller.relockNow() }
    }
}

#Preview("Unlocked · dark") {
    RootView().preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))))
        .preferredColorScheme(.dark)
}

#Preview("Emergency · dark") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2))
        .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    RootView().preferredColorScheme(.light)
}

#Preview("Locked · light") {
    RootView(controller: MockLockController(session: .locked(since: .now - (47 * 60 + 12))))
        .preferredColorScheme(.light)
}

#Preview("Emergency · light") {
    RootView(controller: MockLockController(session: .emergency(relockAt: .now + 272, duration: 300), passesLeft: 2))
        .preferredColorScheme(.light)
}
```

- [ ] **Step 2: Write the lock moment**

<!-- file: Tapout/Features/Home/LockMomentView.swift -->
```swift
import SwiftUI

/// The lock storyboard from design/screens/LockFrame.dc.html:
/// 0 ms tag read + first rigid tap · 90 ms second tap and ring sweep ·
/// ~450 ms seal shockwave · 600 ms settled at 0:00.
struct LockMomentView: View {
    let placeName: String
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Storyboard frame, 1...4.
    @State private var frame = 1
    @State private var ring = 0.0

    var body: some View {
        VStack(spacing: 0) {
            placePill
            VStack(spacing: Space.lg) {
                orb
                caption
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        .task { await play() }
    }

    private var placePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin").font(.system(size: 14, weight: .semibold))
            Text(placeName).font(.tSubhead.weight(.semibold))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(Color.surface1, in: Capsule(style: .continuous))
        .cardShadow()
        .frame(height: 44)
    }

    private var orb: some View {
        ZStack {
            if frame == 1 {
                ReadyRings().transition(.opacity)
            }
            if frame >= 3 && !reduceMotion {
                Shockwave(from: 280)
            }
            OrbView(tone: .slate, size: 280).opacity(frame == 1 ? 1 : 0)
            OrbView(tone: .ember, ring: ring, size: 280).opacity(frame == 1 ? 0 : 1)
        }
        .frame(width: 280, height: 280)
    }

    private var caption: some View {
        VStack(spacing: Space.xs) {
            if frame == 4 {
                Group {
                    TimerText(text: "0:00")
                    StateLabel(text: "Locked", systemImage: "lock", color: .emberInk)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
            } else if frame == 1 {
                Text("Hold still")
                    .font(.tTitle)
                    .foregroundStyle(Color.ink)
            }
        }
        .frame(height: 150, alignment: .top)
    }

    private func play() async {
        Haptics.lock() // two rigid taps: now and at 90 ms
        if reduceMotion {
            withAnimation(Motion.lockReduced) {
                frame = 4
                ring = 1
            }
        } else {
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(Motion.lock) {
                frame = 2
                ring = 1
            }
            try? await Task.sleep(for: .milliseconds(360))
            frame = 3
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(Motion.ui) { frame = 4 }
        }
        try? await Task.sleep(for: .milliseconds(700))
        onFinished()
    }
}

/// Frame 1: the tag-ready outline around the orb.
private struct ReadyRings: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.slateLine, lineWidth: 2)
                .frame(width: 312, height: 312)
                .opacity(0.7)
            Circle().strokeBorder(Color.slateLine, lineWidth: 1.5)
                .frame(width: 364, height: 364)
                .opacity(0.3)
        }
    }
}

/// Frame 3: one ripple of three ember rings expanding out from the orb and fading.
private struct Shockwave: View {
    let from: CGFloat
    @State private var expanded = false

    var body: some View {
        ZStack {
            ring(size: 380, width: 3, opacity: 0.55)
            ring(size: 540, width: 2, opacity: 0.3)
            ring(size: 740, width: 1.5, opacity: 0.14)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { expanded = true }
        }
    }

    private func ring(size: CGFloat, width: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(Color.emberLine, lineWidth: width)
            .frame(width: size, height: size)
            .scaleEffect(expanded ? 1 : from / size)
            .opacity(expanded ? 0 : opacity)
    }
}

#Preview {
    LockMomentView(placeName: MockData.placeName) {}
}
```

- [ ] **Step 3: Write the shell**

<!-- file: Tapout/Features/Placeholder/PlaceholderView.swift -->
```swift
import SwiftUI

/// Stand-in for screens that arrive in Phase 3.
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
            Text("Coming in Phase 3")
                .font(.tSubhead)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Space.lg)
        .background(Color.bg.ignoresSafeArea())
    }
}
```

<!-- file: Tapout/App/RootView.swift -->
```swift
import SwiftUI

/// Tabs, the floating tab bar, the lock-moment overlay and the clock that drives auto-relock.
struct RootView: View {
    @State private var controller: MockLockController
    @State private var tab = AppTab.home
    @State private var showingSettings = false
    @State private var showingLockMoment = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(controller: MockLockController = MockLockController()) {
        _controller = State(initialValue: controller)
    }

    var body: some View {
        let accent = Accent.for(controller.session.lockState)
        ZStack {
            screen
                .safeAreaInset(edge: .bottom, spacing: Space.md) {
                    FloatingTabBar(active: $tab)
                }
            if showingLockMoment {
                LockMomentView(placeName: MockData.placeName) {
                    withAnimation(Motion.reveal) { showingLockMoment = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .environment(\.accent, accent)
        .tint(accent.line)
        .sheet(isPresented: $showingSettings) {
            PlaceholderView(title: "Settings")
        }
        .task { await runClock() }
    }

    @ViewBuilder
    private var screen: some View {
        switch tab {
        case .home:
            HomeView(controller: controller, onScan: scan, onOpenSettings: { showingSettings = true })
        case .modes:
            PlaceholderView(title: "Modes")
        case .places:
            PlaceholderView(title: "Places")
        case .insights:
            PlaceholderView(title: "Insights")
        }
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

<!-- file: Tapout/App/TapoutApp.swift -->
```swift
import SwiftUI

@main
struct TapoutApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            RootView(controller: .fromLaunchArguments())
            #else
            RootView()
            #endif
        }
    }
}
```

- [ ] **Step 4: Build and run tests** — expect success.

- [ ] **Step 5: Leave uncommitted.** Suggested message: `Add Home states, lock moment and app shell`

---

### Task 5: Verify in the simulator

- [ ] **Step 1:** Run the build/test command; all tests pass, no warnings from `Tapout/`.
- [ ] **Step 2:** Boot iPhone 17 (iOS 26.5), install the built app, and for each of `unlocked` (no argument), `-mockState locked`, `-mockState emergency`, launch in dark and light (`xcrun simctl ui booted appearance dark|light`) and screenshot.
- [ ] **Step 3:** Compare each screenshot against `Home.dc.html`: orb sizes (300 / 244), header pill colour, state word colours, button fill (slate Scan, ember Relock now), tab bar active cell.
- [ ] **Step 4:** From unlocked, tap Scan and capture the lock moment; confirm it settles into Locked at 0:00 and counts up. Tap the orb to unlock. Lock again, tap Emergency pass, confirm the countdown and the ring shrinking, then Relock now.
- [ ] **Step 5:** Report results with screenshots. Leave all changes uncommitted with a suggested commit message.

---

## Verification results (2026-10-24)

- 19 tests pass (`ColorTokenTests`, `TimeFormatTests`, `LockSessionTests`, `MockLockControllerTests`); no warnings from `Tapout/`.
- iPhone 17 simulator, iOS 26.5: all three Home states checked in dark and light (`docs/superpowers/verification/phase1-home-states.png`).
- Tapped through: Scan → lock moment → Locked counting up; Emergency pass → countdown with shrinking ring and pass count 3 → 2; Relock now; orb tap → Unlocked.
- Lock moment recorded frame by frame (`docs/superpowers/verification/phase1-lock-moment.png`): slate + ready rings + "Hold still", clockwise ring sweep with slate → ember, shockwave, timer scale-in, handoff into Home.

Changes made during verification:
- `project.yml`: `ASSETCATALOG_COMPILER_APPICON_NAME: ""` until the app icon exists.
- The overlay double-exposed with Home as it faded. Added `Features/Home/LockMomentLink.swift` (matched-geometry link, off under Reduce Motion) so the orb, timer and "Locked" glide from the overlay into place, and the overlay timer now runs live from the session.
- Places icon: SF `mappin` replaced by `Components/PinGlyph.swift`, drawn from the spec's SVG path (tab bar and place pill).

Not verifiable in the simulator: haptics, and Reduce Motion behaviour (not toggled during this run).
