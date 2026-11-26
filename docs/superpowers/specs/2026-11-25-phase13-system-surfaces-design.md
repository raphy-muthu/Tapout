# Phase 13: widgets, Live Activity and shield

Follows the Debug-only Lab switch (`settings.livingGlass`). With the switch off, and in every Release build,
all system surfaces are unchanged. No lock, schedule, timer, pass or history logic changes.

## Owner's choices (2026-11-25)

| Question | Choice |
| --- | --- |
| Widgets and Live Activity | **Pure flat color:** ember when locked, slate when unlocked, near-black text, big numbers, no orb. |
| Shield | **Glass orb on dark:** today's layout with the shader-drawn orb. |
| How the shield turns on | **Follows the Lab switch.** TapoutShield gets the App Group entitlement. |

## The switch outside the app

`Shared/LivingGlassMirror.swift` copies the switch into the App Group (`livingGlass.surfaces`). The app writes
it on launch and whenever the switch changes, then reloads widget timelines and updates the Live Activity.
Readers return false in Release builds, whatever is stored. The shield compiles only this file from `Shared/`.

TapoutShield gains `com.apple.security.application-groups` and declares UserDefaults access (reason 1C8F.1) in
its privacy manifest. **Owner step:** Xcode must refresh the shield's signing profile before the next install.

## Colors and type

- Locked: `ember` field, `on-ember` text. Unlocked, open (pass) and Time's up: `slate` field, `on-slate` text.
  Text is full strength; hierarchy comes from size and weight, because faded near-black fails contrast on slate.
- Ticking numbers: SF Pro, heavy, monospaced digits. (`Text(timerInterval:)` can't use `FixedDigitText`, so it
  can't be Fraunces; the classic faces already use SF Pro here.)
- Still numbers: Fraunces, large; "1h 45m" stacks on two lines in the small widget.

## Home Screen widgets

| State | Small: top, number, bottom |
| --- | --- |
| Locked | Locked · count-up · mode |
| Timer lock | Time left · countdown · mode |
| Pass | Relocks in · countdown · Open |
| Unlocked | Today · stacked total · phone-free |

Medium: "This week" and the total in large Fraunces ("Time left" and the countdown during a timer lock), over
seven bars in the text color, today solid and the others faint.

Where iOS removes the widget's background (StandBy, tinted and clear Home Screens), near-black text would
vanish: the text becomes the state color in full color, and the system's primary color otherwise.

## Lock Screen widgets

iOS tints them, so there is no color. With the switch on the numbers are larger and heavier.

## Live Activity

- The content state carries `flat` (absent when off, so running activities from older builds decode).
- Lock Screen: a state-colored card: a caption (mode and "Locked", or "Time left", "Open · Relocks in",
  "Time's up"), a 60pt number, the place.
- Dynamic Island: its background is always black. Expanded: a state-colored block across the bottom with the
  caption and a large number. Compact and minimal: a flat state-colored disc with a lock or open-lock symbol in
  place of the orb; the timer as today.

## Shield

`SealedOrbGlass` in the shield's catalog: the glass orb, ember, ringed, rendered from the app's shader by
`ShieldArtTests` (export on request). The shield picks it when the mirror is on. Colors, words and button are
unchanged. iOS may keep showing the earlier look until it next asks the shield for its configuration.

## Lab

The widget gallery and the "Sealed screen" mock follow the switch.

## Not in this phase

Pre-rendered orb art for widgets (no orb was chosen), StandBy-specific layouts, and polish (Phase 14).
