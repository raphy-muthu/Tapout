# Phase 7: Device Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Screen Time page stops flashing at launch, interests get their own onboarding screen, the pair sheet says "Name this Tag", and the Sealed screen and the milestone cover look finished.

**Architecture:** A small pure `ScreenTimeGrace` decides when the Screen Time page may open. Onboarding gains one step. The shield's icon becomes a PNG rendered from `OrbView` by a test and shipped in the shield's own asset catalog. The milestone cover is restyled and animated in place.

**Tech Stack:** Swift 6, SwiftUI, ManagedSettingsUI, Swift Testing, XcodeGen. iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-22-phase7-design.md`. Read it first.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.surface2`, `.ink`, `.inkSecondary`, `.ember`, `.emberInk`, `.emberLine`, `.emberGlow`, `.onEmber`, `.slate`, `.track`). No raw hex in Swift, except the orb's own gradient stops that already live in `OrbView.swift`.
- Fraunces only through `Typography.swift` (add a named style there if none fits; no `.font(.custom…)` elsewhere). SF Pro for other text. Fraunces styles don't take `.bold()` or `.weight()`.
- Copy: very few words, no guilt, emoji or exclamation marks.
- Respect Reduce Motion (crossfade instead of springs). 44pt minimum touch targets. Dark first, every screen works in light.
- DEBUG-only code (Lab pages, art exporters, launch-argument mocks) stays inside `#if DEBUG`. Release must compile: run the Release device build after every task that touches Swift.
- `Shared/` stays free of SwiftUI, ActivityKit and WidgetKit.
- **Never commit, stage or stash.** The user commits manually; each task ends with a suggested commit message. Two untracked Java files in `Tapout/App/` belong to the owner: leave them alone.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`; each implementer uses the derived data path named in its brief):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath build/dd-p7 test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

**Device compile checks** (real exit codes, no pipe):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/device-nosign CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/device-release CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
```

**Test count chain:** 297 → 303 (Task 1) → 304 (Task 2) → 306 (Task 3) → 306 (Task 4). If a count differs, report it; never add or remove tests to hit a number.

## File map

| File | Responsibility |
| --- | --- |
| `Tapout/Engine/ScreenTimeGrace.swift` (new) | When the Screen Time page may open |
| `Tapout/Engine/ScreenTimeAccess.swift`, `Tapout/App/RootView.swift` | Use it; DEBUG mock of the stale read |
| `Tapout/Model/OnboardingDraft.swift`, `Tapout/Features/Onboarding/OnboardingView.swift`, `OnboardingSteps.swift` | Six onboarding steps |
| `Tapout/Features/Places/PairPlaceSheet.swift` | "Name this Tag" |
| `Tapout/DesignSystem/ShieldOrbArt.swift` (new, DEBUG), `TapoutTests/ShieldArtTests.swift` (new) | The shield icon, rendered |
| `TapoutShield/Shield.xcassets/` (new), `TapoutShield/ShieldConfigurationExtension.swift` | The Sealed screen |
| `Tapout/Features/Lab/MomentsGallery.swift` (new, DEBUG), `LabView.swift` | Simulator preview of the Sealed screen and the milestone cover |
| `Tapout/Features/Insights/MilestoneView.swift`, `Tapout/DesignSystem/Typography.swift` | The achievement screen |

---

### Task 1: The Screen Time page stops flashing

**Files:**
- Create: `Tapout/Engine/ScreenTimeGrace.swift`, `TapoutTests/ScreenTimeGraceTests.swift`
- Modify: `Tapout/App/RootView.swift` (`checkScreenTime`, new state), `Tapout/Engine/ScreenTimeAccess.swift` (DEBUG mock)

**Interfaces:**
- Produces: `ScreenTimeGrace` (struct, `static let delay: TimeInterval = 1.5`, `mutating func observe(needed: Bool, now: Date) -> Decision`) and `ScreenTimeGrace.Decision` (`.clear`, `.wait(until: Date)`, `.show`).

The cause: `RootView` subscribes to `AuthorizationCenter.shared.$authorizationStatus` and checks on `.task` and on every foreground. At launch iOS first reports a status that is not `.approved`; `checkScreenTime()` sets `screenTimeNeeded = true`, the Screen Time page opens, then the real `.approved` arrives and it closes.

- [ ] **Step 1: Write the failing tests** (`TapoutTests/ScreenTimeGraceTests.swift`)

```swift
import Foundation
import Testing
@testable import Tapout

struct ScreenTimeGraceTests {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func approvedClears() {
        var grace = ScreenTimeGrace()
        #expect(grace.observe(needed: false, now: t0) == .clear)
    }

    @Test func firstMissingReadWaits() {
        var grace = ScreenTimeGrace()
        #expect(grace.observe(needed: true, now: t0) == .wait(until: t0.addingTimeInterval(ScreenTimeGrace.delay)))
    }

    @Test func missingAgainBeforeTheDelayKeepsWaiting() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        let due = t0.addingTimeInterval(ScreenTimeGrace.delay)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(0.4)) == .wait(until: due))
    }

    @Test func missingForTheWholeDelayShowsThePage() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(ScreenTimeGrace.delay)) == .show)
        #expect(grace.observe(needed: true, now: t0.addingTimeInterval(ScreenTimeGrace.delay + 5)) == .show)
    }

    @Test func approvalInTheMeantimeStartsTheWaitAgain() {
        var grace = ScreenTimeGrace()
        _ = grace.observe(needed: true, now: t0)
        #expect(grace.observe(needed: false, now: t0.addingTimeInterval(1)) == .clear)
        let later = t0.addingTimeInterval(2)
        #expect(grace.observe(needed: true, now: later) == .wait(until: later.addingTimeInterval(ScreenTimeGrace.delay)))
    }

    @Test func theDelayIsLongEnoughForAStaleReadAndShortEnoughToNotice() {
        #expect(ScreenTimeGrace.delay >= 1 && ScreenTimeGrace.delay <= 2)
    }
}
```

- [ ] **Step 2:** Run the suite. Expected: compile failure, `ScreenTimeGrace` not found.

- [ ] **Step 3: Implement** `Tapout/Engine/ScreenTimeGrace.swift`:

```swift
import Foundation

/// iOS can report Screen Time as not approved for a moment at launch and when Tapout comes back to
/// the foreground, before it reports the real status. The Screen Time page opens only once access
/// has stayed missing for `delay`, so that moment never flashes the page.
struct ScreenTimeGrace {
    static let delay: TimeInterval = 1.5

    enum Decision: Equatable {
        /// Access is fine, or isn't needed yet: hide the page.
        case clear
        /// Missing, but not for long enough: look again at that time.
        case wait(until: Date)
        /// Missing for the whole delay: open the page.
        case show
    }

    private var missingSince: Date?

    /// `needed` is true when onboarding is done and access is not approved.
    mutating func observe(needed: Bool, now: Date) -> Decision {
        guard needed else {
            missingSince = nil
            return .clear
        }
        let since = missingSince ?? now
        missingSince = since
        let due = since.addingTimeInterval(Self.delay)
        return now >= due ? .show : .wait(until: due)
    }
}
```

In `RootView` add `@State private var screenTimeGrace = ScreenTimeGrace()` and `@State private var screenTimeRecheck: Task<Void, Never>?`, and replace `checkScreenTime()` with:

```swift
    private func checkScreenTime() {
        let status = ScreenTimeAccess.status
        let approved = status == .approved
        model.noteScreenTimeAccess(status)
        let needed = hasOnboarded && !approved
        switch screenTimeGrace.observe(needed: needed, now: .now) {
        case .clear:
            // Approved clears the flag even under a cover or sheet; only showing the page waits.
            screenTimeRecheck?.cancel()
            screenTimeRecheck = nil
            screenTimeNeeded = false
        case .wait(let due):
            screenTimeRecheck?.cancel()
            screenTimeRecheck = Task {
                try? await Task.sleep(for: .seconds(max(0, due.timeIntervalSinceNow) + 0.05))
                guard !Task.isCancelled else { return }
                checkScreenTime()
            }
        case .show:
            // Waits while another cover or sheet is up, so two presentations never fight; their dismissals check again.
            guard cover == nil, intentionCheck == nil, !pairing, !scanning else { return }
            screenTimeNeeded = true
        }
    }
```

Keep the doc comment above the function. In `ScreenTimeAccess.status`, inside the existing `#if targetEnvironment(simulator)` branch, add a DEBUG mock that reproduces the stale read: when launched with `-mockScreenTimeFlash`, return `.notDetermined` for the first 0.8 seconds of the process, then `.approved`:

```swift
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-mockScreenTimeFlash"), Date.now.timeIntervalSince(launchedAt) < 0.8 {
            return .notDetermined
        }
        #endif
```
with `private static let launchedAt = Date.now` (DEBUG only; touch it from `TapoutApp` or read it at first use: a `static let` initialises on first access, so also read it once early by referencing it in `status`'s first call; since `-mockScreenTimeFlash` is only for the simulator it is enough that the first call happens at launch).

- [ ] **Step 4:** Run the suite (303 expected).

- [ ] **Step 5: Reproduce and verify on the simulator** (`iPhone 17 Pro`, your own derived data; the first checks need `-demoData -mockScreenTimeFlash`, which skips onboarding and mocks the stale read):
  1. Stash nothing: to see the old behaviour, temporarily make the `.show` case apply on the first read (or `git stash` is forbidden, so just edit `ScreenTimeGrace.delay` to `0` and rebuild), launch with the arguments and take a screenshot 0.3 s after launch: the "Allow Screen Time" page is showing. Put `delay` back to 1.5.
  2. With `delay` 1.5: launch with the same arguments, screenshot at 0.4 s, 1 s and 3 s. The Home screen shows at every point; the page never appears.
  3. Launch with `-demoData -mockScreenTimeRevoked` (genuinely denied): screenshot at 0.5 s (Home) and at 2.5 s (the Screen Time page is showing).
  Save the three screenshots from steps 2 and 3 under `.superpowers/sdd/shots/p7-1-*.png` and name them in the report.

- [ ] **Step 6:** Both device builds exit 0.

Suggested commit message: `Screen Time page waits out the stale launch read`

---

### Task 2: Interests get their own screen; "Name this Tag"

**Files:**
- Modify: `Tapout/Model/OnboardingDraft.swift`, `Tapout/Features/Onboarding/OnboardingView.swift`, `Tapout/Features/Onboarding/OnboardingSteps.swift`, `Tapout/Features/Places/PairPlaceSheet.swift`, `TapoutTests/OnboardingDraftTests.swift`

**Interfaces:**
- Consumes: `OnboardingDraft.stepCount` and `.cta`; `ChoiceChip(title:isOn:fillsWidth:action:)`; `ScrollsWhenTall`.
- Produces: `InterestsStep(interests: Binding<Set<Interest>>)` (step 5); `PairStep()` (step 6, no parameters).

- [ ] **Step 1: Update the test first.** In `OnboardingDraftTests.buttonTitlesAndStepping`: the loop runs 6 times and the expected titles become `["Get started", "Allow", "Continue", "Continue", "Continue", "Scan tag"]`, and the step count is 6. Add one more test:

```swift
    @Test func interestsComeBeforePairingAndFinishOnPairing() {
        var draft = OnboardingDraft()
        while draft.step < 5 { draft.advance() }
        #expect(draft.cta == "Continue")      // the interests step
        draft.advance()
        #expect(draft.step == OnboardingDraft.stepCount)
        #expect(draft.cta == "Scan tag")      // pairing is last
        draft.advance()
        #expect(draft.step == OnboardingDraft.stepCount)
    }
```

- [ ] **Step 2:** Run the suite. Expected: `buttonTitlesAndStepping` fails (and the new test too).

- [ ] **Step 3: Implement.**
  - `OnboardingDraft.stepCount = 6`; `cta`: `case 3, 4, 5: "Continue"`, default `"Scan tag"`.
  - `OnboardingView` body: `case 5: ScrollsWhenTall { InterestsStep(interests: $draft.interests) }` and `default: ScrollsWhenTall { PairStep() }`.
  - `OnboardingView` footer: "Not now" shows on step 4 (skips the schedule) and on the last step (finishes without a tag), not on step 5: `if draft.step == 4 || draft.step == OnboardingDraft.stepCount { textButton("Not now", action: skip) }`. `skip()` stays as it is (step 4 clears the window and advances, otherwise finishes). Update the file's doc comments: "steps 1–4" becomes the six steps; "Not now on step 5" becomes "on the last step".
  - `OnboardingSteps.swift`: add

```swift
/// Step 5: interests, for Insights' comparisons ("As long as 2 NFL games"). Nothing is required.
struct InterestsStep: View {
    @Binding var interests: Set<Interest>

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Your interests").font(.tLargeTitle).foregroundStyle(Color.ink)
                Text("Insights compares your time to things you enjoy.")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
            }
            // One column at accessibility sizes, so no interest breaks mid-word.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: typeSize.isAccessibilitySize ? 1 : 3),
                      spacing: Space.xs) {
                ForEach(Interest.allCases, id: \.self) { interest in
                    ChoiceChip(title: interest.title, isOn: interests.contains(interest), fillsWidth: true) {
                        if interests.contains(interest) { interests.remove(interest) } else { interests.insert(interest) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
```

  Change `PairStep` to take no parameters: remove the `interests` binding, the "Your interests" section and the grid, and centre what is left (the tag graphic, "Pair your first tag", "Hold the top of your phone to it.") vertically in the step: `.frame(maxWidth: .infinity, maxHeight: .infinity)` with the content in a `VStack(spacing: Space.xl)`; drop the unused `dynamicTypeSize` property. Update the step's doc comment to "Step 6: the first tag." Fix the previews: add "Interests · dark/light" (`InterestsStep(interests: .constant([.sports, .movies])).stepPreview(…)`) and change the Pair previews to `PairStep()`.
  - `PairPlaceSheet.nameField`: `SectionLabel(text: "Name this place")` becomes `SectionLabel(text: "Name this Tag")`. Search `Tapout/` and `TapoutTests/` for the old string and update anything else that shows it.

- [ ] **Step 4:** Run the suite (304 expected). Both device builds exit 0.

- [ ] **Step 5: Look at it** on the simulator (`iPhone 17 Pro`, your own derived data). Onboarding starts when the app has never been onboarded: install and launch without `-demoData` after `xcrun simctl uninstall`. Screenshot step 4, step 5 (Your interests) and step 6 (Pair), dark and light (`xcrun simctl ui <id> appearance light|dark`). Check with the largest Dynamic Type (`xcrun simctl ui <id> content_size accessibility-extra-extra-extra-large`) that step 5 scrolls or fits and Continue stays on screen. Save the shots as `.superpowers/sdd/shots/p7-2-*.png`. Then reset the simulator's content size to `large` and appearance to `dark`.

Suggested commit message: `Interests get their own onboarding screen; Name this Tag`

---

### Task 3: A finished Sealed screen

**Files:**
- Create: `Tapout/DesignSystem/ShieldOrbArt.swift` (DEBUG), `TapoutTests/ShieldArtTests.swift`, `TapoutShield/Shield.xcassets/Contents.json`, `TapoutShield/Shield.xcassets/SealedOrb.imageset/Contents.json`, `TapoutShield/Shield.xcassets/SealedOrb.imageset/SealedOrb.png` (generated), `Tapout/Features/Lab/MomentsGallery.swift` (DEBUG)
- Modify: `TapoutShield/ShieldConfigurationExtension.swift`, `Tapout/Features/Lab/LabView.swift`

**Interfaces:**
- Produces: `ShieldOrbArt` (DEBUG view, 240 × 240 pt, transparent) with `@MainActor static func render() -> UIImage?` (scale 3, so 720 × 720 px, with alpha); `MomentsGallery(model:)` (DEBUG), a Lab page with two rows: "Sealed screen" and "Milestone" (Task 4 uses the second).

iOS draws a shield itself: the icon centred, the title and subtitle under it in the system font, a full-width button at the bottom, on a background colour. The extension only supplies those values, so the polish is the icon and the button.

- [ ] **Step 1: Write the failing tests** (`TapoutTests/ShieldArtTests.swift`, whole file in `#if DEBUG`)

```swift
#if DEBUG
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct ShieldArtTests {
    @Test func rendersATransparent720Square() throws {
        let image = try #require(ShieldOrbArt.render())
        #expect(image.size.width * image.scale == 720)
        #expect(image.size.height * image.scale == 720)
        let cg = try #require(image.cgImage)
        let alpha = cg.alphaInfo
        #expect(![.none, .noneSkipLast, .noneSkipFirst].contains(alpha))
        // The corner is empty; the middle is the orb.
        #expect(try pixelAlpha(cg, x: 2, y: 2) == 0)
        #expect(try pixelAlpha(cg, x: 360, y: 360) > 200)
    }

    /// Writes the PNG into the shield's asset catalog when run with TEST_RUNNER_TAPOUT_EXPORT_SHIELD_ART=1.
    @Test func exportsWhenAsked() throws {
        guard ProcessInfo.processInfo.environment["TAPOUT_EXPORT_SHIELD_ART"] == "1" else { return }
        let data = try #require(ShieldOrbArt.render()?.pngData())
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TapoutShield/Shield.xcassets/SealedOrb.imageset/SealedOrb.png")
        try data.write(to: url)
    }

    private func pixelAlpha(_ image: CGImage, x: Int, y: Int) throws -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel[3]
    }
}
#endif
```

- [ ] **Step 2:** Run the suite. Expected: `ShieldOrbArt` not found.

- [ ] **Step 3: Implement.**
  - `ShieldOrbArt`:

```swift
#if DEBUG
import SwiftUI

/// The Sealed screen's icon: the app's own ember orb with its glow and seal ring, on transparent.
/// Always dark. Exported to the shield's asset catalog by ShieldArtTests, because a shield extension
/// can't render SwiftUI itself.
struct ShieldOrbArt: View {
    static let side: CGFloat = 240

    var body: some View {
        // The orb is 160 pt; its glow reaches 1.44× that, so the canvas keeps it inside.
        OrbView(tone: .ember, ring: 1, size: 160)
            .frame(width: Self.side, height: Self.side)
            .environment(\.colorScheme, .dark)
    }

    @MainActor static func render() -> UIImage? {
        let renderer = ImageRenderer(content: ShieldOrbArt())
        renderer.scale = 3
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return renderer.uiImage
    }
}
#endif
```

  - Asset catalog JSON: `Shield.xcassets/Contents.json` = `{ "info" : { "author" : "xcode", "version" : 1 } }`; `SealedOrb.imageset/Contents.json` = `{ "images" : [ { "filename" : "SealedOrb.png", "idiom" : "universal", "scale" : "3x" } ], "info" : { "author" : "xcode", "version" : 1 } }`. XcodeGen picks the catalog up from the `TapoutShield` folder; run `xcodegen` and confirm.
  - Export the PNG: run the build-and-test command with `TEST_RUNNER_TAPOUT_EXPORT_SHIELD_ART=1` before `xcodebuild`, then check with `sips -g pixelWidth -g pixelHeight -g hasAlpha` (720, 720, yes) and look at it with the Read tool: an ember orb with its ring and a soft glow, nothing clipped at the edges.
  - `ShieldConfigurationExtension.swift`: in `SealedShield.configuration`, set `icon: icon` where

```swift
    /// The app's glass orb, pre-rendered (see ShieldOrbArt). The drawn fallback only shows if the asset is missing.
    private static var icon: UIImage {
        UIImage(named: "SealedOrb", in: .main, compatibleWith: dark)?.withRenderingMode(.alwaysOriginal) ?? fallbackOrb
    }
```

    rename the existing `orb` to `fallbackOrb`. Change the button: `primaryButtonLabel: Label(text: "Close", color: color("on-ember"))` and `primaryButtonBackgroundColor: color("ember")`. Keep the background `color("bg")`, the title ("Sealed", `ink`) and the subtitle ("Tap a tag to open this app.", `ink-secondary`). Update the file's doc comment (the orb is the app's own, the button is ember).
  - `MomentsGallery(model:)` (DEBUG): a plain `List`-style page like `SurfaceGallery`, with two `NavigationLink`s. **Sealed screen** opens a full-screen mock of the shield: `Color.bg`, the `ShieldOrbArt.render()` image at 120 pt wide, "Sealed" (22 pt semibold system font, `ink`), "Tap a tag to open this app." (17 pt system, `inkSecondary`) and a full-width 56 pt capsule button "Close" (ember fill, `onEmber` label) pinned near the bottom, always dark. A comment says it approximates iOS's layout and the real screen is checked on the iPhone. **Milestone** lists the five `Milestone` cases; tapping one presents `MilestoneView(milestone:subtitle:)` full screen using `milestone.subtitle(totalLocked: 36_000, interests: [.sports, .movies])`. Add it to `LabView`'s "Surfaces" section: `NavigationLink("Moments") { MomentsGallery(model: model) }`.

- [ ] **Step 4:** Run the suite without the export variable (306 expected). Both device builds exit 0. Confirm the Release product holds the icon: `assetutil --info build/device-release/Build/Products/Release-iphoneos/Tapout.app/PlugIns/TapoutShield.appex/Assets.car | grep -c SealedOrb` is above 0.

- [ ] **Step 5: Look at it.** Launch on the `iPhone 17 Pro` simulator with `-demoData`, open Settings → Developer Lab → Moments → Sealed screen, and screenshot it. Judge it against `design/screens/Block.dc.html` (near-black, sealed ember orb, "Sealed", "Tap a tag to open this app."): is the orb crisp, the glow soft, the button clearly the one action? Save as `.superpowers/sdd/shots/p7-3-sealed.png`.

Suggested commit message: `Sealed screen: the real orb as its icon, an ember Close button`

---

### Task 4: A finished achievement screen

**Files:**
- Modify: `Tapout/Features/Insights/MilestoneView.swift`, `Tapout/DesignSystem/Typography.swift` (only if no existing style fits)

**Interfaces:**
- Consumes: `MilestoneView(milestone:subtitle:)` (signature unchanged); `OrbView(tone:ring:size:)`; `Motion`, `Haptics.select()`; `MomentsGallery` from Task 3 for previewing.

The cover today is a flat page: the orb in three static rings, a "Milestone" label, a title, a subtitle, Share and Done. Make it feel earned without adding words or changing the buttons.

Requirements:
1. **Glow wash.** Behind the orb, a soft radial wash from the `emberGlow` token that fades into `bg` (stronger in dark, gentler in light), so the page isn't flat.
2. **Sealing sequence on appear.** The three outer rings fade in from the outside in, about 0.12 s apart, each scaling from about 0.9 to 1; the orb's seal ring sweeps from 0 to 1 (its `ring` value animates) over about 0.9 s; when it completes, play `Haptics.select()` once. The title and subtitle fade up slightly after the ring starts. Under Reduce Motion everything is simply there, with a `Motion.reveal` crossfade of the whole block and no haptic delay.
3. **Hierarchy.** The title is the hero: a larger Fraunces style from `Typography.swift` (add a named style such as `milestoneTitle` there if none of the existing ones is big enough, following how `recapTotal` is defined; no raw fonts in the view). "Milestone" stays as the small label above it. The subtitle keeps `tBody` in `inkSecondary`, centred, with a readable width (about 300 pt, no limit at accessibility sizes).
4. **Spacing and buttons.** Keep the existing Close, Share (ember capsule) and Done, with more even spacing between the hero block and the buttons. Keep the `ViewThatFits` fallbacks so the largest text sizes still show everything, with Share on screen.
5. Dark and light both look right; the existing previews stay (add `.sevenDayStreak`).

- [ ] **Step 1:** Implement the above. This task is visual: no logic tests are needed, but the suite must stay green (306).
- [ ] **Step 2: Look at it.** On the `iPhone 17 Pro` simulator with `-demoData`: Settings → Developer Lab → Moments → Milestone → each case. Screenshot dark and light for `.firstLock`, `.tenHours` and `.sevenDayStreak` (the title lengths differ), then once with the largest Dynamic Type (`xcrun simctl ui <id> content_size accessibility-extra-extra-extra-large`; reset to `large` after) and once with Reduce Motion on (`xcrun simctl spawn <id> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true`, undo it afterwards, and say so in the report if the setting can't be toggled this way). Also capture a frame about 0.5 s after the cover opens to show the sequence part-way. Save as `.superpowers/sdd/shots/p7-4-*.png`. If something looks unfinished, iterate before reporting; say what you changed.
- [ ] **Step 3:** The suite passes (306) and both device builds exit 0.

Suggested commit message: `Milestone screen: glow, sealing sequence, bigger title`

---

### Task 5: Checklist and notes (controller)

- [ ] Update `docs/superpowers/verification/iphone-run-checklist.md` and the published plan page: the onboarding check now has six steps, with interests on their own; add a check for the milestone cover (earn "First lock" and look at it) and update the Sealed screen check (the orb is the app's real orb, the Close button is ember).
- [ ] Final whole-phase review, fixes, verification (suite, both device builds), a contact sheet as `docs/superpowers/verification/phase7-*.png`, and the report with the commit message `Phase 7: device feedback`.
