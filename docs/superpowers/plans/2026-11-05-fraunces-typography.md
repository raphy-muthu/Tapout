# Fraunces Typography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapout's large numbers and titles use Fraunces; small text and small numbers use SF Pro; SF Pro Rounded goes away. The ticking timers must not jitter.

**Architecture:** A script cuts three static fonts from Fraunces' variable source and commits them to the app, the same way `scripts/gen-colors.py` generates colours. Almost every screen already goes through named styles in `Typography.swift`, so changing those styles moves the app. Because Fraunces has no tabular figures, ticking numbers use a new `FixedDigitText` view that gives each digit an equal-width slot.

**Tech Stack:** SwiftUI `Font.custom`, UIKit `UIFont` for measuring, Python + fontTools (build-time only, not shipped), Swift Testing, XcodeGen, Xcode 27.1, iPhone 17 simulator (iOS 26.5).

**Run this before Phase 3B.** Task 3 updates the 3B plan to match, so 3B builds on the new fonts instead of adding more SF Pro Rounded.

## Findings behind this plan (checked 2026-11-05)

- **No tabular figures.** The full Fraunces font's only OpenType substitution features are `case`, `liga`, `rvrn` and `ss01`. At 100pt its digits range from 33.5 (`1`) to 56.7 (`0`) wide. `.monospacedDigit()` would do nothing, and a timer would shift every second.
- **Fixed slots look right.** A browser test of `47:14`, `1:11` and `0:08` with equal-width digit slots held steady and read well. The softer `SOFT 100` cut suits the orb better than `SOFT 0`.
- **Lining digits.** Digits sit at one height by default, so `47:14` doesn't bounce the way true old-style figures would.
- **License.** SIL Open Font License 1.1 with no Reserved Font Name, so renamed cuts may ship in a paid app. `OFL.txt` must ship with them.

## Decisions

| Style | Before | After |
| --- | --- | --- |
| `timerHero` (112), `timerLarge` (72), `numberDisplay` (48) | SF Pro Rounded | Fraunces **Display**: opsz 144, wght 300, SOFT 100, WONK 0 |
| new `numberHero` (96), for Insights in 3B | inline SF Pro Rounded | Fraunces **Display** |
| `numberMedium` (28), new `numberTile` (20) | SF Pro Rounded | Fraunces **Number**: opsz 36, wght 400, SOFT 100, WONK 0 |
| `numberSmall` (17) and other numbers under 20pt | SF Pro Rounded | SF Pro, `.monospacedDigit()` where they tick |
| `tLargeTitle` (34), `tTitle1` (28), `tTitle` (22) | SF Pro semibold | Fraunces **Title**: opsz 36, wght 600, SOFT 100, WONK 0, scaling with Dynamic Type |
| `tHeadline`, `tBody`, `tSubhead`, `tFootnote`, `tCaption` | SF Pro | Unchanged |

- **20pt is the line.** Numbers of 20pt and up are Fraunces, below that SF Pro. That follows "SF Pro for small text" and avoids Fraunces' thin strokes at small sizes.
- **WONK 0:** Fraunces' "wonky" leaning letters stay off, keeping names like "Kitchen" tidy.
- **Static cuts, not the variable font.** SwiftUI can't easily set `opsz` or `SOFT`, and the variable font's default instance is 9pt Black. Three static files are simple, and Phase 5's widgets can reuse them.

## Known limits (for later phases)

- **Live Activity and widgets (Phase 5):** `Text(timerInterval:)` is drawn by the system as one string, so it can't use slots and Fraunces would jitter. Those ticking timers should use SF Pro with `.monospacedDigit()`.
- **Block screen (Phase 4):** `ShieldConfiguration` takes colours, an icon and text, so it's expected to stay in the system font. Check against Apple's docs then.
- **Other scripts:** Fraunces covers Latin and Vietnamese. A place named in another script falls back to the system font automatically.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party Swift packages. Swift 6 language mode. fontTools is a build-time tool only and is never linked into the app.
- `Shared/` stays free of SwiftUI; the monitor extension draws nothing and gets no fonts.
- Colours only through asset-catalog tokens. 44pt minimum touch targets.
- `OFL.txt` ships in the app bundle alongside the fonts.
- Never commit. The user commits manually; each task ends with a suggested commit message.

## File map

| File | Responsibility |
| --- | --- |
| `scripts/gen-fonts.py` | Variable Fraunces → three static TTFs + `OFL.txt` |
| `Tapout/DesignSystem/Fonts/*.ttf`, `OFL.txt` | Generated, committed |
| `Tapout/DesignSystem/FrauncesFace.swift` | Names of the three cuts |
| `Tapout/DesignSystem/Typography.swift` | The styles |
| `Tapout/Components/FixedDigitText.swift` | `DigitSlots`, `FixedDigitText` |
| `Tapout/Components/TimerText.swift` | Uses fixed slots |
| `Tapout/Features/Home/LockMomentView.swift` | Taller caption for Fraunces' line height |
| `Tapout/Features/Modes/ModeCards.swift`, `Tapout/Features/Settings/SettingsView.swift` | The two remaining inline Rounded uses |
| `project.yml` | `UIAppFonts` |
| `TapoutTests/FontTests.swift` | Fonts load; slots behave |
| `CLAUDE.md`, `design/design-system/README.md`, `PLAN.md`, the Phase 3B plan | Keep the docs true |

Build/test command used throughout (run from `~/Documents/tapout`):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build/dd test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)"
```

The suite has 95 tests before this plan and 100 after it.

---

### Task 1: Cut and bundle the fonts

**Files:**
- Create: `scripts/gen-fonts.py`, `Tapout/DesignSystem/FrauncesFace.swift`, `TapoutTests/FontTests.swift`, `Tapout/DesignSystem/Fonts/` (generated)
- Modify: `project.yml`

**Interfaces:**
- Produces: `FrauncesFace` (`.display`, `.number`, `.title`; raw values are PostScript names); bundled files `Fraunces-TapoutDisplay.ttf`, `Fraunces-TapoutNumber.ttf`, `Fraunces-TapoutTitle.ttf`.

- [x] **Step 1: Write the failing test**

<!-- file: TapoutTests/FontTests.swift -->
```swift
import Testing
import UIKit
@testable import Tapout

struct FontTests {
    @Test(arguments: FrauncesFace.allCases)
    func cutIsBundledAndRegistered(_ face: FrauncesFace) {
        #expect(UIFont(name: face.rawValue, size: 20) != nil, "missing font \(face.rawValue)")
    }
}
```

<!-- file: Tapout/DesignSystem/FrauncesFace.swift -->
```swift
/// The three Fraunces cuts Tapout ships, made by scripts/gen-fonts.py. Raw values are PostScript names.
enum FrauncesFace: String, CaseIterable, Sendable {
    /// Optical size 144, light: timers and big stats.
    case display = "Fraunces-TapoutDisplay"
    /// Optical size 36, regular: numbers of 20–28pt in cards.
    case number = "Fraunces-TapoutNumber"
    /// Optical size 36, semibold: titles.
    case title = "Fraunces-TapoutTitle"
}
```

- [x] **Step 2: Run the build/test command** — expect `cutIsBundledAndRegistered` to fail for all three cuts.

- [x] **Step 3: Write the script**

<!-- file: scripts/gen-fonts.py -->
```python
#!/usr/bin/env python3
"""Cut Tapout's static Fraunces fonts from the variable source and copy its license.

Fraunces is licensed under the SIL OFL 1.1 with no Reserved Font Name. The source is pinned to a
google/fonts commit, so re-running gives the same fonts. Needs fontTools; see the plan for the venv.
"""
import pathlib
import urllib.request

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

COMMIT = "4024282d9b0cffcdb8e3024560862746178d741f"
BASE = f"https://raw.githubusercontent.com/google/fonts/{COMMIT}/ofl/fraunces"
SOURCE_URL = f"{BASE}/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
LICENSE_URL = f"{BASE}/OFL.txt"

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Tapout" / "DesignSystem" / "Fonts"
CACHE = ROOT / "build" / "fonts"

# name: (weight class, axis locations)
FACES = {
    "Display": (300, {"opsz": 144, "wght": 300, "SOFT": 100, "WONK": 0}),
    "Number": (400, {"opsz": 36, "wght": 400, "SOFT": 100, "WONK": 0}),
    "Title": (600, {"opsz": 36, "wght": 600, "SOFT": 100, "WONK": 0}),
}


def rename(font, face):
    family = f"Fraunces Tapout {face}"
    postscript = f"Fraunces-Tapout{face}"
    name = font["name"]
    # Drop typographic and variation names left over from the variable font.
    name.names = [record for record in name.names if record.nameID not in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25)]
    for name_id, value in {1: family, 2: "Regular", 3: postscript, 4: family, 6: postscript}.items():
        name.setName(value, name_id, 3, 1, 0x409)
        name.setName(value, name_id, 1, 0, 0)


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    source = CACHE / "Fraunces-variable.ttf"
    if not source.exists():
        urllib.request.urlretrieve(SOURCE_URL, source)
    urllib.request.urlretrieve(LICENSE_URL, OUTPUT / "OFL.txt")

    for face, (weight, axes) in FACES.items():
        font = instancer.instantiateVariableFont(TTFont(source), axes)
        rename(font, face)
        font["OS/2"].usWeightClass = weight
        if "STAT" in font:
            del font["STAT"]
        path = OUTPUT / f"Fraunces-Tapout{face}.ttf"
        font.save(path)
        print(f"{path.name}: {path.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
```

- [x] **Step 4: Generate the fonts.** `build/` is git-ignored, so the tool stays out of the repo:

```bash
python3 -m venv build/fonts-venv && build/fonts-venv/bin/pip install --quiet fonttools && build/fonts-venv/bin/python scripts/gen-fonts.py
```

Expected: three lines of output, each file roughly 100–250 KB, and `Tapout/DesignSystem/Fonts/` holding the three TTFs and `OFL.txt`. Check `OFL.txt` starts with the copyright line and has no "Reserved Font Name". If a file is over 400 KB, say so in the report rather than subsetting it.

- [x] **Step 5: Register the fonts.** In `project.yml`, add to the `Tapout` target's `info.properties`, after `UIApplicationSceneManifest`:

```yaml
        UIAppFonts:
          - Fraunces-TapoutDisplay.ttf
          - Fraunces-TapoutNumber.ttf
          - Fraunces-TapoutTitle.ttf
```

XcodeGen copies `.ttf` and `.txt` files under `Tapout/` into the bundle because `Tapout` is a source path.

- [x] **Step 6: Run the build/test command** — 96 tests pass. Also confirm `ls build/dd/Build/Products/Debug-iphonesimulator/Tapout.app | grep -E "Fraunces|OFL"` lists all four files.

- [x] **Step 7: Leave uncommitted.** Suggested message: `Bundle three static Fraunces cuts`

---

### Task 2: Styles and fixed digit slots

**Files:**
- Create: `Tapout/Components/FixedDigitText.swift`
- Modify: `Tapout/DesignSystem/Typography.swift`, `Tapout/Components/TimerText.swift`, `Tapout/Features/Home/LockMomentView.swift`, `Tapout/Features/Modes/ModeCards.swift`, `Tapout/Features/Settings/SettingsView.swift`, `TapoutTests/FontTests.swift`

**Interfaces:**
- Consumes: `FrauncesFace` (Task 1).
- Produces: `Font.numberHero`, `Font.numberTile`; `DigitSlots.digitWidth(face:size:)`, `DigitSlots.width(of:digitWidth:)`; `FixedDigitText(text:face:size:)`; `StatTile(value:caption:isNumber:)` (renamed from `rounded:`).

- [x] **Step 1: Write the failing tests.** Add inside `FontTests`:

```swift
    private func width(of digit: Character, size: CGFloat) -> CGFloat {
        let font = UIFont(name: FrauncesFace.display.rawValue, size: size)!
        return String(digit).size(withAttributes: [.font: font]).width
    }

    /// Why slots exist. If this ever fails, the font gained even digits and the slots can go.
    @Test func digitsHaveDifferentWidths() {
        #expect(width(of: "1", size: 100) < width(of: "0", size: 100) * 0.8)
    }

    @Test func slotFitsEveryDigitExactlyAtTheWidest() {
        let slot = DigitSlots.digitWidth(face: .display, size: 100)
        let widths = "0123456789".map { width(of: $0, size: 100) }
        #expect(widths.allSatisfy { $0 <= slot })
        #expect(widths.contains(slot))
    }

    @Test func slotScalesWithSize() {
        let small = DigitSlots.digitWidth(face: .display, size: 72)
        let large = DigitSlots.digitWidth(face: .display, size: 144)
        #expect(abs(large - small * 2) < 0.5)
    }

    @Test func onlyDigitsGetSlots() {
        #expect(DigitSlots.width(of: "4", digitWidth: 50) == 50)
        #expect(DigitSlots.width(of: ":", digitWidth: 50) == nil)
    }
```

- [x] **Step 2: Run the tests to see them fail** — expect `DigitSlots` not found.

- [x] **Step 3: Write the slots**

<!-- file: Tapout/Components/FixedDigitText.swift -->
```swift
import SwiftUI
import UIKit

/// Fraunces has no tabular figures, so `.monospacedDigit()` does nothing and a `1` is far narrower
/// than a `0`. Anything that ticks gives each digit a slot as wide as the widest digit.
enum DigitSlots {
    static func digitWidth(face: FrauncesFace, size: CGFloat) -> CGFloat {
        let font = UIFont(name: face.rawValue, size: size) ?? .systemFont(ofSize: size)
        return "0123456789".map { String($0).size(withAttributes: [.font: font]).width }.max() ?? size
    }

    /// nil leaves anything else, such as the colon, at its natural width.
    static func width(of character: Character, digitWidth: CGFloat) -> CGFloat? {
        character.isNumber ? digitWidth : nil
    }
}

/// Numbers in Fraunces that don't shift as they change.
struct FixedDigitText: View {
    let text: String
    var face = FrauncesFace.display
    let size: CGFloat

    var body: some View {
        let digitWidth = DigitSlots.digitWidth(face: face, size: size)
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                Text(String(character))
                    .font(.custom(face.rawValue, fixedSize: size))
                    .fixedSize()
                    .frame(width: DigitSlots.width(of: character, digitWidth: digitWidth))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}
```

- [x] **Step 4: Change the styles.** Replace `Tapout/DesignSystem/Typography.swift`:

<!-- file: Tapout/DesignSystem/Typography.swift -->
```swift
import SwiftUI

extension Font {
    // Numbers of 20pt and up: Fraunces. It has no tabular digits, so anything that ticks uses FixedDigitText.
    static let timerHero = Font.custom(FrauncesFace.display.rawValue, fixedSize: 112)
    static let numberHero = Font.custom(FrauncesFace.display.rawValue, fixedSize: 96)
    static let timerLarge = Font.custom(FrauncesFace.display.rawValue, fixedSize: 72)
    static let numberDisplay = Font.custom(FrauncesFace.display.rawValue, fixedSize: 48)
    static let numberMedium = Font.custom(FrauncesFace.number.rawValue, fixedSize: 28)
    static let numberTile = Font.custom(FrauncesFace.number.rawValue, fixedSize: 20)
    // Small numbers: SF Pro.
    static let numberSmall = Font.system(size: 17, weight: .medium).monospacedDigit()
    // Titles: Fraunces, scaling with Dynamic Type.
    static let tLargeTitle = Font.custom(FrauncesFace.title.rawValue, size: 34, relativeTo: .largeTitle)
    static let tTitle1 = Font.custom(FrauncesFace.title.rawValue, size: 28, relativeTo: .title) // card heroes in the screen specs
    static let tTitle = Font.custom(FrauncesFace.title.rawValue, size: 22, relativeTo: .title2)
    // Text: SF Pro, Dynamic Type styles
    static let tHeadline = Font.headline
    static let tBody = Font.body
    static let tSubhead = Font.subheadline
    static let tFootnote = Font.footnote
    static let tCaption = Font.caption.weight(.medium)
}
```

- [x] **Step 5: Use the slots in the timer.** Replace `Tapout/Components/TimerText.swift`:

<!-- file: Tapout/Components/TimerText.swift -->
```swift
import SwiftUI

/// Hero numerals. Scales with Dynamic Type but caps at 1.3× because it already fills the width,
/// and steps down if a long time still wouldn't fit.
struct TimerText: View {
    let text: String

    @ScaledMetric(relativeTo: .largeTitle) private var scaledSize: CGFloat = 112

    var body: some View {
        let size = min(scaledSize, 112 * 1.3)
        ViewThatFits(in: .horizontal) {
            FixedDigitText(text: text, size: size)
            FixedDigitText(text: text, size: size * 0.85)
            FixedDigitText(text: text, size: size * 0.7)
        }
        .foregroundStyle(Color.ink)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
```

- [x] **Step 6: Fix the remaining inline uses**
  - `Tapout/Features/Settings/SettingsView.swift`, the `/5` after the pass count: change `.font(.system(size: 17, design: .rounded))` to `.font(.system(size: 17))`.
  - `Tapout/Features/Modes/ModeCards.swift`, in `StatTile`: rename `rounded` to `isNumber`, update its doc comment to `/// Numbers use Fraunces; words use SF Pro.`, change the font line to `.font(isNumber ? .numberTile : .tHeadline)`, and update the three `StatTile(...)` calls in `ActiveModeCard` from `rounded:` to `isNumber:`.
  - `Tapout/Features/Home/LockMomentView.swift`, in `caption`: change `.frame(height: 150, alignment: .top)` to `.frame(height: 176, alignment: .top)`. Fraunces' line height is taller than SF Pro Rounded's, so the timer and "Locked" need more room.

  Then check nothing is left: `grep -rn "design: .rounded" Tapout` must print nothing.

- [x] **Step 7: Run the build/test command** — 100 tests pass, no warnings from `Tapout/`, `Shared/`, `TapoutTests/` or `TapoutMonitor/`.

- [x] **Step 8: Leave uncommitted.** Suggested message: `Switch numbers and titles to Fraunces with fixed digit slots`

---

### Task 3: Keep the docs and the 3B plan true

**Files:**
- Modify: `CLAUDE.md`, `design/design-system/README.md`, `PLAN.md`, `docs/superpowers/plans/2026-10-28-phase3b-onboarding-pass-insights.md`

**Interfaces:**
- Consumes: the styles from Task 2. No code changes; this task has no tests.

- [x] **Step 1: `CLAUDE.md`.** Replace the rule `- SF Pro for text, SF Pro Rounded (`design: .rounded`) for numbers. `.monospacedDigit()` on anything that ticks.` with:

```markdown
- Fraunces for titles and numbers of 20pt and up, through the styles in `Typography.swift`. SF Pro for all other text and small numbers. Fraunces has no tabular digits: anything in Fraunces that ticks uses `FixedDigitText`; SF Pro numbers that tick use `.monospacedDigit()`.
```

- [x] **Step 2: `design/design-system/README.md`.** Directly under the heading `## 4. Typography`, add:

```markdown
> **Updated 2026-11-05: Fraunces replaces SF Pro Rounded.** Titles and numbers of 20pt and up use Fraunces; everything smaller uses SF Pro. This overrides the families and the Swift below, and the matching `tokens.json` usage notes. Sizes and roles are unchanged. `Tapout/DesignSystem/Typography.swift` is the source of truth, and `docs/superpowers/plans/2026-11-05-fraunces-typography.md` explains why.
```

- [x] **Step 3: `PLAN.md`.**
  - Under "What you do **not** need", delete the line `- **Custom fonts**: SF Pro and SF Pro Rounded ship with iOS.`
  - Under **Phase 5**, add the bullet: `- Live Activity and widget timers use SF Pro with `.monospacedDigit()`: `Text(timerInterval:)` can't use Fraunces' fixed digit slots. Widgets that show titles or static numbers need the Fraunces files added to their target.`
  - Under **Phase 6**, add the bullet: `- Credit Fraunces (SIL OFL 1.1) in the app's licenses; `OFL.txt` already ships in the bundle.`

- [x] **Step 4: Update the Phase 3B plan.** Make these exact replacements in `docs/superpowers/plans/2026-10-28-phase3b-onboarding-pass-insights.md`:

| Find | Replace with |
| --- | --- |
| `.font(.system(size: 15, weight: .semibold, design: .rounded))` | `.font(.system(size: 15, weight: .semibold))` |
| `.font(.system(size: 12, design: .rounded))` | `.font(.system(size: 12))` |
| `.font(.system(size: 96, weight: .ultraLight, design: .rounded))` and the `.kerning(-2)` line after it | `.font(.numberHero)` |
| `Text("\(countdown.secondsLeft)")` with its `.font(.timerLarge)` and `.foregroundStyle(Color.ink)` lines | `FixedDigitText(text: "\(countdown.secondsLeft)", size: 72)` and `.foregroundStyle(Color.ink)` |
| `Font.timerLarge` in Task 4's Consumes line | `FixedDigitText(text:face:size:)` |
| `change `.frame(height: 150, alignment: .top)` on `caption` to `.frame(height: 176, alignment: .top)`` | `change `.frame(height: 176, alignment: .top)` on `caption` to `.frame(height: 204, alignment: .top)`` |
| `SF Pro for words, SF Pro Rounded for numbers; `.monospacedDigit()` on anything that ticks.` | `Fraunces for titles and numbers of 20pt and up, through the styles in `Typography.swift`; SF Pro for everything else. Fraunces has no tabular digits: anything in Fraunces that ticks uses `FixedDigitText`.` |
| `The suite has 95 tests after Phase 3A (as built; its plan predicted 84).` | `The suite has 100 tests after Phase 3A and the Fraunces switch.` |

Then raise the test counts by five: `95 + 13 = 108` → `100 + 13 = 113`; `108 + 19 = 127` → `113 + 19 = 132`; `127 + 4 = 131` → `132 + 4 = 136`; `131 + 4 = 135` → `136 + 4 = 140`; `135 + 5 = 140` → `140 + 5 = 145`; `140 + 1 = 141` → `145 + 1 = 146`; `check: 141 tests pass` → `check: 146 tests pass`.

Check: `grep -n "design: .rounded\|\.kerning(-2)" docs/superpowers/plans/2026-10-28-phase3b-onboarding-pass-insights.md` prints nothing.

- [x] **Step 5: Leave uncommitted.** Suggested message: `Update design docs and the 3B plan for Fraunces`

---

### Task 4: Verify in the simulator and on the iPhone

Simulator: iPhone 17, iOS 26.5, id `33A5EBE9-5D77-488C-85C0-FDBC419C7ECE`. Tab bar: Modes (158, 807), Places (243, 807). Home's gear (356, 92).

- [x] **Step 1:** Run the build/test command: 100 tests pass, no warnings.
- [x] **Step 2: The timer must not jitter.** Install the app and launch with `-demoData -mockState locked`. Record 12 seconds with `xcrun simctl io <id> recordVideo`, extract one frame per second with `ffmpeg`, crop to the timer and tile them into a contact sheet. Expected: the colon and every digit slot stay in the same place across all frames while the seconds change. Repeat with `-mockState emergency` for the countdown.
- [x] **Step 3: Screens.** Launch with `-demoData`, in dark then light. Screenshot Home unlocked (Scan), Home locked, the lock moment, Modes (large title, mode name, `9–5` tile), a mode editor (large name field), Places (large title, default place), the pair sheet, and Settings (`3/5`). Check: titles and large numbers are Fraunces; buttons, state words, chips and captions are SF Pro; nothing is clipped; the lock moment hands over to Home without the timer jumping.
- [x] **Step 4: Thin strokes.** Look at the timer at full size in **light** theme, which has less contrast than dark. Fraunces Display's hairlines must stay clearly visible. If they don't, change `Display`'s `wght` in `scripts/gen-fonts.py` from 300 to 350, re-run it, and repeat this step. Say in the report if that happened.
- [x] **Step 5: Dynamic Type.** `xcrun simctl ui <id> content_size accessibility-extra-extra-extra-large`, relaunch, and screenshot Home locked, Modes, Places and Settings. Titles must scale and wrap or shrink without being cut off, and the timer must fit on one line. Restore with `xcrun simctl ui <id> content_size large`.
- [ ] **Step 6: Check on the iPhone,** because simulator text rendering can differ. This needs the phone connected:

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'generic/platform=iOS' -derivedDataPath build/device -allowProvisioningUpdates build -quiet
```

```bash
xcrun devicectl device install app --device 00008140-000A28340E29401C build/device/Build/Products/Debug-iphoneos/Tapout.app
```

If the phone isn't connected, finish the other steps and list this one as still open.

- [x] **Step 7:** Report the app's size change, the timer contact sheet and screenshots, saved in `docs/superpowers/verification/fraunces-*.png`. Leave all changes uncommitted with the suggested message `Fraunces verification results`.

## Additions from the final review

- A. Bold Text: three heavier cuts (`DisplayBold`, `NumberBold`, `TitleBold`), so six cuts now. `FrauncesFace.resolved(boldText:)` picks the cut; Typography styles are computed, `FixedDigitText` resolves once, and `RootView` re-renders the `NavigationStack` when `legibilityWeight` changes.
- B. `design/SCREENS.md` and the 3B plan's comparison step say fonts follow `Typography.swift`.
- C. `FixedDigitText` forces left-to-right layout so digits aren't reversed in RTL.
- D. `StatTile` captions bottom-align with a `Spacer`.
- E. `timerHero` and `timerLarge` removed: unused, and they bring jitter back on a ticking number.

## Verification results (2026-11-06)

- 102 tests pass; no warnings from project sources. The signed device build succeeds with all six cuts and `OFL.txt` in the bundle.
- Timer: recorded at 1 fps for 12 s, locked and emergency. The colon and every digit hold still (`docs/superpowers/verification/fraunces-timer-*.png`).
- Dark, light, lock moment and largest text size checked in the simulator (`fraunces-*.png`). The Display cut's fine strokes stay clear in light theme, so it stays at wght 300.
- Bold Text seen working in the simulator (`fraunces-bold-text-and-modes.png`).
- VoiceOver's accessibility tree checked in a test harness on iOS 18.6 and 26.5: the caller's "Locked for ..." label wins and there is one element.
- **Still open:** install on the iPhone (not connected) and listen to VoiceOver on locked Home; iOS 17 is untested because this Mac has no iOS 17 runtime.
- **Not from the font:** at the largest accessibility text sizes the Modes stat tiles wrap letter by letter and the Places tiles cramp. Fraunces titles are slightly wider, so `lineLimit(1)` on the active mode's name truncates a little sooner.
