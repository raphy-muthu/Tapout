# Phase 6: Release Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapout gets everything an App Store submission needs (app icon, privacy manifests, export compliance, listing, privacy policy, screenshots), plus the Phase 5 leftovers: no Keychain read every second, the recap rendered on demand, and tinted Home Screen widgets. It also gets one combined iPhone checklist.

**Architecture:**
- The icon is a SwiftUI view rendered with `ImageRenderer` by a test that writes the PNG into a new asset catalog.
- Privacy manifests are plain plist resources, one per bundle.
- The engine fix stays inside `LockEngine`.
- The recap share becomes a `Transferable` that renders when the share sheet asks for it.
- Widget faces take a `tinted` flag that the widget entry views derive from `widgetRenderingMode`.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Swift Testing, XcodeGen. iOS 17+.

**Design:** `docs/superpowers/specs/2026-11-13-phase6-design.md`. Read it first.

## Global Constraints

- Minimum iOS 17.0, iPhone only, portrait. No third-party packages. Swift 6 language mode.
- Colours only through asset-catalog tokens (`Color.bg`, `.surface1`, `.ink`, `.ember`, `.emberInk`, `.slate`, `.track`, …). No raw hex in Swift.
- Fraunces only through `Typography.swift`; timers in SF Pro with `.monospacedDigit()`.
- Copy: very few words, no guilt, emoji or exclamation marks.
- `Shared/` stays free of SwiftUI, ActivityKit and WidgetKit.
- DEBUG-only code (gallery, Lab, icon art, demo data) stays inside `#if DEBUG`. Release must compile: run the Release device build at the end of every task that touches Swift.
- **Never commit, stage or stash.** The user commits manually; each task ends with a suggested commit message.

**Build and test** (from `/Users/puneetmuthu/Documents/tapout`; each implementer uses its own derived data path, named in its brief):

```bash
xcodegen && xcodebuild -project Tapout.xcodeproj -scheme Tapout -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath build/dd-p6 test 2>&1 | grep -E "error:|warning:|Test run with|TEST (SUCCEEDED|FAILED)" | grep -v "\[store\]\|appintents"
```

**Device compile checks** (real exit codes, no pipe):

```bash
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/device-nosign CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
xcodebuild -project Tapout.xcodeproj -scheme Tapout -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/device-release CODE_SIGNING_ALLOWED=NO build -quiet; echo "exit $?"
```

**Test count chain:** 288 → 290 (Task 1) → 292 (Task 2) → 295 (Task 3) → 296 (Task 4) → 296 (Task 5). If a count differs, report it; never add or remove tests to hit a number.

## File map

| File | Responsibility |
| --- | --- |
| `Tapout/DesignSystem/AppIconArt.swift` (new, DEBUG) | The icon as a view |
| `Tapout/Assets.xcassets/` (new) | `AppIcon.appiconset` with the exported 1024 PNG |
| `TapoutTests/AppIconTests.swift` (new) | Renders the icon, checks it, exports on request |
| `Tapout/PrivacyInfo.xcprivacy`, `TapoutMonitor/PrivacyInfo.xcprivacy`, `TapoutWidgets/PrivacyInfo.xcprivacy`, `TapoutShield/PrivacyInfo.xcprivacy` (new) | Privacy manifests |
| `TapoutTests/ReleaseConfigTests.swift` (new) | Manifest and export-compliance checks |
| `Tapout/Engine/LockEngine.swift` | Tick without the Keychain; assign only on change |
| `Tapout/Features/Insights/RecapView.swift`, `InsightsView.swift` | Render on demand |
| `Surfaces/WidgetFaces.swift`, `TapoutWidgets/Widgets.swift`, `Tapout/Features/Lab/SurfaceGallery.swift` | Tinted faces |
| `docs/appstore/listing.md`, `docs/appstore/privacy-policy.md`, `docs/superpowers/verification/iphone-run-checklist.md` (new) | Submission copy and the device run |
| `project.yml` | Icon name, export compliance key |

---

### Task 1: App icon

**Files:**
- Create: `Tapout/DesignSystem/AppIconArt.swift`
- Create: `Tapout/Assets.xcassets/Contents.json`, `Tapout/Assets.xcassets/AppIcon.appiconset/Contents.json`, `Tapout/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (generated)
- Create: `TapoutTests/AppIconTests.swift`
- Modify: `project.yml` (the `Tapout` target's `ASSETCATALOG_COMPILER_APPICON_NAME: ""` becomes `AppIcon`; delete the comment after it)

**Interfaces:**
- Produces: `AppIconArt` (DEBUG view, 1024 × 1024 points) and `AppIconArt.render() -> UIImage?` (opaque, scale 1, 1024 × 1024 px).

- [ ] **Step 1: Write the failing tests** (`TapoutTests/AppIconTests.swift`)

```swift
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct AppIconTests {
    @Test func rendersAnOpaque1024Square() throws {
        let image = try #require(AppIconArt.render())
        #expect(image.size == CGSize(width: 1024, height: 1024))
        #expect(image.scale == 1)
        let alpha = try #require(image.cgImage?.alphaInfo)
        #expect([.none, .noneSkipLast, .noneSkipFirst].contains(alpha))
    }

    /// Writes the PNG into the asset catalog when run with TEST_RUNNER_TAPOUT_EXPORT_ICON=1 (see Step 4).
    @Test func exportsWhenAsked() throws {
        guard ProcessInfo.processInfo.environment["TAPOUT_EXPORT_ICON"] == "1" else { return }
        let data = try #require(AppIconArt.render()?.pngData())
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tapout/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        try data.write(to: url)
    }
}
```

- [ ] **Step 2:** Run the suite. Expected: compile failure, `AppIconArt` not found.

- [ ] **Step 3: Implement** `Tapout/DesignSystem/AppIconArt.swift`:

```swift
#if DEBUG
import SwiftUI

/// The App Store icon, as designed in design/screens/AppIcon.dc.html: the sealed ember orb on a
/// surface disc on near-black. Always dark. Exported to the asset catalog by AppIconTests.
struct AppIconArt: View {
    static let side: CGFloat = 1024

    var body: some View {
        ZStack {
            Color.bg
            Circle().fill(Color.surface1).frame(width: 800, height: 800)
            OrbView(tone: .ember, ring: 1, size: 720)
        }
        .frame(width: Self.side, height: Self.side)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    @MainActor static func render() -> UIImage? {
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return renderer.uiImage
    }
}

#Preview { AppIconArt().scaleEffect(0.3).frame(width: 320, height: 320) }
#endif
```

`Tapout/Assets.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`Tapout/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [ { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Set `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`.

- [ ] **Step 4: Export the PNG:** run the build-and-test command with `TEST_RUNNER_TAPOUT_EXPORT_ICON=1` set in the environment of `xcodebuild`. Then check it:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha Tapout/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Expected: 1024, 1024, `hasAlpha: no`. Look at the PNG with the Read tool. It should match the design: an ember orb with a ring, on a dark disc, on near-black.

- [ ] **Step 5:** Run the suite again without the variable (290 tests), then both device builds. Confirm the built app has the icon: `ls build/device-nosign/Build/Products/Debug-iphoneos/Tapout.app | grep -i AppIcon` lists `AppIcon60x60@2x.png` or `Assets.car` contains it (`assetutil --info .../Assets.car | grep -c AppIcon` > 0).

Suggested commit message: `App icon from the design, rendered from OrbView`

---

### Task 2: Privacy manifests and export compliance

**Files:**
- Create: `Tapout/PrivacyInfo.xcprivacy`, `TapoutMonitor/PrivacyInfo.xcprivacy`, `TapoutWidgets/PrivacyInfo.xcprivacy`, `TapoutShield/PrivacyInfo.xcprivacy`
- Create: `TapoutTests/ReleaseConfigTests.swift`
- Modify: `project.yml` (the `Tapout` target's `info.properties` gains `ITSAppUsesNonExemptEncryption: false`)

- [ ] **Step 1: Write the failing tests** (`TapoutTests/ReleaseConfigTests.swift`; `Bundle.main` is the host app in unit tests):

```swift
import Foundation
import Testing

struct ReleaseConfigTests {
    @Test func appDeclaresNoEncryption() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }

    @Test func appPrivacyManifestDeclaresUserDefaultsReasons() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try #require(types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        #expect(Set(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []) == ["CA92.1", "1C8F.1"])
    }
}
```

- [ ] **Step 2:** Run. Expected: both fail.

- [ ] **Step 3: Write the manifests.** App (`Tapout/PrivacyInfo.xcprivacy`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
				<string>1C8F.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

Monitor and widgets: the same, with only `1C8F.1`. Shield: the same keys with an empty `NSPrivacyAccessedAPITypes` array. First grep `TapoutShield/` for `UserDefaults`, `systemUptime`, file timestamps and disk-space APIs, and if any appear, declare them. Also grep the whole repo for other required-reason APIs: `systemUptime`, `mach_absolute_time`, `creationDate`, `modificationDate`, `.contentModificationDateKey`, `volumeAvailableCapacity`, `activeInputModes`. Declare any you find in the bundle that compiles them.

Add `ITSAppUsesNonExemptEncryption: false` to the app's `info.properties` in `project.yml`.

- [ ] **Step 4:** Run `plutil -lint` on all four manifests, then the suite (292). Then run both device builds and check that each bundle carries its manifest:

```bash
find build/device-release/Build/Products/Release-iphoneos/Tapout.app -name PrivacyInfo.xcprivacy
```

Expected: four paths: the app, `PlugIns/TapoutMonitor.appex`, `TapoutShield.appex` and `TapoutWidgets.appex`.

Suggested commit message: `Privacy manifests for every bundle, and export compliance`

---

### Task 3: No Keychain read every second

**Files:**
- Modify: `Tapout/Engine/LockEngine.swift`
- Test: `TapoutTests/LockEngineTests.swift`

**Interfaces:**
- Unchanged public API. `reload()` keeps its meaning (a full re-read, including the vault). `tick()` stops calling the vault.

The problem: `tick()` runs every second while Tapout is open and calls `reload()`, which reads `passesLeft` through `currentPassesLeft` → `passes.used()` → `SecItemCopyMatching`. The vault only changes through the engine (`useEmergencyPass`, `resetPasses`), and both of those already call `reload()`. `reload()` also assigns all four observed properties on every tick, so SwiftUI re-evaluates every view that reads them once a second.

- [ ] **Step 1: Write the failing tests** in `LockEngineTests.swift`. Use a counting vault:

```swift
private final class CountingVault: PassCounting, @unchecked Sendable {
    private(set) var reads = 0
    private var count = 0
    func used() -> Int { reads += 1; return count }
    @discardableResult func setUsed(_ count: Int) -> Bool { self.count = count; return true }
}
```

Tests (adapt the setup to the file's existing helpers: `store`, `shields`, `relock`, `clock`):
1. `tickDoesNotReadTheVault`: build an engine with a `CountingVault`, note `reads` after init, call `tick()` 10 times while locked, and expect `reads` unchanged.
2. `passesLeftStillDropsAfterAPass`: lock, use an emergency pass, then `tick()`. `passesLeft == totalPasses - 1` (this guards that the cached count is updated by the full reload in `useEmergencyPass`).
3. `quietTickChangesNothingObservable`: lock, then wrap a read of `session`, `passesLeft`, `relockStrategy` and `log` in `withObservationTracking`, with an `onChange` that sets a flag. Call `tick()` with nothing changed in the store, and expect the flag to stay false. Then write a new session to the store as the monitor would (`store.session = .unlocked`, or whatever the existing monitor-relock test writes), track again, `tick()`, and expect the flag to be true.

- [ ] **Step 2:** Run. Expected: tests 1 and 3 fail.

- [ ] **Step 3: Implement.** In `LockEngine`:

```swift
    /// Passes spent, as last read from the vault. Only the engine changes the vault, and every
    /// change ends in `reload()`, so `tick()` can skip the Keychain.
    @ObservationIgnored private var vaultUsed = 0

    /// Re-reads the store and the pass vault.
    func reload() {
        vaultUsed = passes.used()
        refresh()
    }

    /// Re-reads the store only. Assigns only what changed, so a quiet tick redraws nothing.
    private func refresh() {
        let newSession = store.session
        if newSession != session { session = newSession }
        let newPasses = max(0, min(store.passesLeft, SharedStore.totalPasses - vaultUsed))
        if newPasses != passesLeft { passesLeft = newPasses }
        let newStrategy = store.relockStrategy
        if newStrategy != relockStrategy { relockStrategy = newStrategy }
        let newLog = store.log
        if newLog != log { log = newLog }
    }
```

Delete `currentPassesLeft`, or reduce it to the expression above if something else uses it. In `tick()`, replace `reload()` with `refresh()`. If `LockSession`, `RelockStrategy` or `LogEntry` aren't `Equatable`, add the conformance (they are plain value types; check `Shared/`).

- [ ] **Step 4:** Run the suite (295) and both device builds.

Suggested commit message: `Lock clock no longer reads the Keychain every second`

---

### Task 4: Recap rendered on demand

**Files:**
- Modify: `Tapout/Features/Insights/RecapView.swift` (`RecapImage`), `Tapout/Features/Insights/InsightsView.swift`
- Test: `TapoutTests/RecapImageTests.swift`

**Interfaces:**
- `RecapImage.render(_:colorScheme:scale:)`: `scale` defaults to 3, so existing callers and tests are unchanged.
- New `RecapShare: Transferable, Sendable`, holding `weekStart`, `total`, `days`, `comparison` and `colorScheme`. It exports `.png` by rendering at 3× on the main actor.
- New `RecapShare.pngData() async -> Data?`, the function its `DataRepresentation` calls. It is a separate function so it can be tested.

- [ ] **Step 1: Write the failing test** in `RecapImageTests.swift`:

```swift
    @Test func shareItemExportsAFullSizePNG() async throws {
        let sample = LockSnapshot.sample(.unlocked)
        let share = RecapShare(weekStart: .now, total: sample.weekTotal, days: sample.days,
                               comparison: nil, colorScheme: .dark)
        let data = try #require(await share.pngData())
        let image = try #require(UIImage(data: data))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }
```

- [ ] **Step 2:** Run. Expected: `RecapShare` not found.

- [ ] **Step 3: Implement** in `RecapView.swift`:

```swift
enum RecapImage {
    /// The recap at `scale`× (3× is the shared 1080 × 1920 image; 1× is the share sheet thumbnail).
    @MainActor static func render(_ view: RecapView, colorScheme: ColorScheme, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, colorScheme))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(RecapView.size)
        return renderer.uiImage
    }
}

/// The shared recap. The full image is rendered only when the share sheet asks for it.
struct RecapShare: Transferable, Sendable {
    let weekStart: Date
    let total: TimeInterval
    let days: [Insights.Day]
    let comparison: Comparison?
    let colorScheme: ColorScheme

    func pngData() async -> Data? {
        await MainActor.run {
            let view = RecapView(weekStart: weekStart, total: total, days: days, comparison: comparison)
            return RecapImage.render(view, colorScheme: colorScheme)?.pngData()
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { share in
            guard let data = await share.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
    }
}
```

If `Comparison` isn't `Sendable`, add the conformance (it's a value type in `Tapout/Model`). Add `import UniformTypeIdentifiers` if `.png` isn't found.

In `InsightsView`: keep the `.task(id: recapKey)`, but render the thumbnail at `scale: 1` into `recap`. Share with:

```swift
ShareLink(item: RecapShare(weekStart: weekStart, total: total, days: days, comparison: comparison, colorScheme: colorScheme),
          message: Text(text),
          preview: SharePreview("Your week", image: recap)) { shareIcon }
```

`header(total:)` needs `weekStart`, `days` and `comparison` passed in. While `recap` (the thumbnail) is nil, keep the text-only `ShareLink`. Update the comment above `.task` to say it renders the thumbnail.

- [ ] **Step 4:** Run the suite (296) and both device builds.

Suggested commit message: `Recap image rendered only when shared`

---

### Task 5: Tinted Home Screen widgets

**Files:**
- Modify: `Surfaces/WidgetFaces.swift`, `TapoutWidgets/Widgets.swift`, `Tapout/Features/Lab/SurfaceGallery.swift`

**Interfaces:**
- `SmallFace(snapshot:date:tinted:)` and `MediumFace(snapshot:tinted:)`: `tinted: Bool = false` is added after the existing parameters (keep the existing labels; check the current initialisers).
- New `FlatOrb(tone: OrbTone, ring: Bool, size: CGFloat)` in `WidgetFaces.swift`.

- [ ] **Step 1: Implement `FlatOrb`** in `WidgetFaces.swift`. It is the orb for tinted and clear widgets, which can't show gradients or glow:

```swift
/// The orb for tinted and clear Home Screen widgets, where iOS flattens colour: a soft disc, and
/// the seal ring drawn in the accent group so it takes the tint.
struct FlatOrb: View {
    var ring: Bool
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.18)).frame(width: size * 0.74, height: size * 0.74)
            if ring {
                Circle().stroke(lineWidth: size * 0.05).widgetAccentable()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
```

`.widgetAccentable()` is in WidgetKit, so add `import WidgetKit` to `WidgetFaces.swift` if it's missing. It's fine in the app too.

- [ ] **Step 2:** In `SmallFace` and `MediumFace`, when `tinted` is true, use `FlatOrb(ring: <same as the ring the glass orb shows>, size: <same size>)` in place of `OrbView`. In `MediumFace`, mark today's bar `.widgetAccentable()` when tinted. Text stays as it is (iOS tints it).

- [ ] **Step 3:** In `TapoutWidgets/Widgets.swift`, the entry views for the small and medium families read `@Environment(\.widgetRenderingMode) var renderingMode` and pass `tinted: renderingMode != .fullColor`. Accessory faces are unchanged.

- [ ] **Step 4:** In `SurfaceGallery`, add a "Tinted" section: the small face in each of the three states and the medium face, all with `tinted: true`, shown on `Color.slate.opacity(0.35)` to stand in for a tinted Home Screen. Add `#Preview`s for the tinted faces in `WidgetFaces.swift`.

- [ ] **Step 5:** Run the suite (296, unchanged) and both device builds.

Suggested commit message: `Flat orb for tinted and clear Home Screen widgets`

---

### Task 6: Submission copy and the iPhone checklist

**Files:**
- Create: `docs/appstore/listing.md`, `docs/appstore/privacy-policy.md`, `docs/superpowers/verification/iphone-run-checklist.md`

No code. Read `CLAUDE.md` (voice), `design/SCREENS.md`, the Phase 4A, 4B and 5 plans in `docs/superpowers/plans/`, and the Phase 5 final review notes in `.superpowers/sdd/progress.md`.

- [ ] **Step 1: `docs/appstore/listing.md`**, each field with its character limit:
  - **Name:** "Tapout" (30).
  - **Subtitle:** 30 max, for example "Tap a tag. Put the phone down." Offer two alternatives.
  - **Promotional text:** 170.
  - **Description:** 4000 max, aim for about 1200. Cover how it works (pair NFC tags to places, tap to lock chosen apps, tap again to unlock), modes, schedules, five emergency passes for life, Insights and the weekly recap, the Live Activity and widgets, and privacy (everything stays on the phone, no account). Tags are bought separately: any NTAG213/215/216 sticker works. Use the app's voice: plain, calm, no guilt, no emoji, no exclamation marks.
  - **Keywords:** 100 characters, comma-separated, no spaces after commas, not repeating the name.
  - **Category:** Productivity (secondary: Health & Fitness).
  - **Age rating answers:** all None; 4+.
  - **App Privacy:** Data Not Collected. Explain why: no servers, App Group and Keychain only.
  - **Review notes:**
    - Tapout needs a physical NFC tag, which reviewers won't have.
    - A screen recording of the full flow is attached; mark this as **OWNER: record and attach**.
    - The Family Controls entitlement is used to shield apps; explain how.
    - There is no login.
    - Steps a reviewer can take without a tag: onboarding up to pairing, and Modes, Places, Insights and Settings, which are viewable.
  - **What's New:** "First release."
  - **Support URL / Privacy policy URL / Marketing URL:** **OWNER** placeholders, clearly marked.
- [ ] **Step 2: `docs/appstore/privacy-policy.md`**, a short policy in plain language:
  - no data collected or shared;
  - everything stored on the device (App Group storage, the Keychain for pass counts);
  - Screen Time data is handled by iOS, and Tapout never sees which apps you use;
  - NFC is used only to read the tag's ID;
  - no analytics or ads;
  - a contact line marked **OWNER**;
  - an effective date of 2026-11-13.
- [ ] **Step 3: `docs/superpowers/verification/iphone-run-checklist.md`**, one ordered run on a real iPhone. Merge:
  - every device step of Phase 4A Task 9 Step 3, Phase 4B Task 6 Step 3 and Phase 5 Task 6 Step 3;
  - the Phase 5 final review's extra device checks (in `progress.md`, and in the review summary: signing with the App Group checked, a signed Release build, tinted and clear Home Screen modes, StandBy, Lock Screen light and dark and Always-On, a device without a Dynamic Island if available, 1h+ and 10h+ timers, a relock with Tapout closed while watching the widgets, the largest Dynamic Type and Bold Text on the card, swiping the Live Activity away, the iOS per-app Live Activity switch, a lock over 8 hours, midnight rollover, the reboot and first-unlock widget state, and the recap saved to Photos at 1080 × 1920);
  - the Phase 6 items: the icon on the Home Screen, in Settings and in Spotlight; the tinted widgets.

  Group them into sections, in an order that is efficient on one phone over about a day:
  1. Setup and signing
  2. First launch and onboarding
  3. Pairing and locking
  4. Emergency passes
  5. Schedules (some need waiting)
  6. Live Activity
  7. Widgets
  8. Recap
  9. Long-running and overnight checks
  10. Reset

  Each item is a checkbox with what to do and what should happen, and "(from 4A/4B/5/6)". Deduplicate overlapping items. Start with a short "before you start" list: Xcode profiles for TapoutShield and TapoutWidgets, the App Group on every target, two NFC tags, and the Family Controls (Development) entitlement already granted.

Suggested commit message: `App Store listing, privacy policy and the combined iPhone checklist`

---

### Task 7: Screenshots, verification and final review (controller)

- [ ] **Step 1:** Run the build-and-test command (296) and both device builds; all exit 0 with no warnings from project sources.
- [ ] **Step 2:** On the `iPhone 17 Pro Max` simulator (1320 × 2868), set the status bar with `xcrun simctl status_bar <id> override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4`, then launch with `-demoData`. Capture App Store screenshots into `docs/appstore/screenshots/`:
  1. `1-home-locked.png`
  2. `2-home-unlocked.png`
  3. `3-insights.png`
  4. `4-modes.png`
  5. `5-places.png`
  6. `6-emergency-pass.png`

  Check each is 1320 × 2868 and shows no DEBUG UI.
- [ ] **Step 3:** In the gallery, check the tinted faces. Check the Home Screen icon in the simulator, after pressing Home.
- [ ] **Step 4:** Final whole-phase review, fixes, then save a contact sheet as `docs/superpowers/verification/phase6-*.png`.
- [ ] **Step 5:** Report with the suggested commit message `Phase 6: release prep — icon, privacy manifests, listing, and Phase 5 follow-ups`.
