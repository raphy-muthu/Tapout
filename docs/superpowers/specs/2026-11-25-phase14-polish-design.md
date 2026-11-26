# Phase 14: polish

The last phase of the UI upgrade. No lock, schedule, timer, pass or history logic changes.

## Owner's choices (2026-11-25)

| Question | Choice |
| --- | --- |
| Ship the new look? | **Not yet.** It stays behind the Debug-only Lab switch. |
| App Store screenshots | **Skipped for now.** |
| Battery and heat | **A meter in the Lab.** |
| Large text | **Fix in both looks** (changes the shipped app at large text sizes only). |

## Large text (both looks)

- Mode cards' schedule and weekly numbers (`numberTile`) scale with Dynamic Type.
- Full-width pill buttons (`PrimaryButton`, Home's Timer, the milestone's Share, "Make default"), Home's mode
  pill and the chips keep padding around their label and grow taller instead of letting the label touch or
  leave the edges. Default size: unchanged.
- The taller buttons must not push words off Home: its subtitle never truncates, and the orb shrinks further
  (to 64) when needed. The emergency-pass orb at accessibility sizes is 96.

## Large text, second pass (owner: "Yes, fix it")

- `numberSmall` and `numberMedium` follow the text size; the timer sheet's length uses the new
  `numberReadout`. The classic widgets keep fixed numbers (`widgetValue`, `widgetTotal`), since a widget's
  frame can't grow. Default size: unchanged.
- The week charts' value label may be wider than its column (capped at xxxLarge) and never widens the chart.
- Settings' passes card and toggle rows, Insights' header, the lock moment's place pill, the editor's Block
  row, onboarding's app count and focus rows make room instead of crowding or breaking words.
- At accessibility sizes the onboarding artwork and the rejected-tag orb shrink so the words fit.
- Left as they are: the system's time wheel, the tab bar's icons, deliberately capped day letters, the hold
  button's countdown inside its circle. Long screens scroll.

## Reduce Motion

With Reduce Motion on, nothing the upgrade added moves, scales or sweeps: opening a Modes drawer, onboarding's
orb changing size, and the pairing ring closing happen at once, with content crossfading where it already did.
Review the other animations added since Phase 9 and fix any that still travel.

## VoiceOver and accessibility audit

Run Xcode's accessibility audit over the app's screens, switch on and off, from a throwaway UI test in a copy
of the project (the project itself gains no test target). Fix real problems the upgrade introduced; list the
rest for the owner. VoiceOver itself can only be judged by listening on the iPhone.

## Lab: battery and heat meter (Debug only)

- Start a run with a short label ("Home, switch on"). It keeps measuring while you leave the Lab and use any
  screen, and keeps the display awake until stopped.
- Every minute while Tapout is on screen it records the battery level, whether the phone is charging, the
  thermal state, Low Power Mode and the switch.
- The report says how long, battery from and to, a rate per hour, the worst heat, and what spoils a run:
  charging, Low Power Mode, time away from the app, the switch changing.
- iOS may report the battery in coarse steps, so the rate is measured between steps and needs at least two
  of them; otherwise the report says the run was too short. Aim for an hour per run.
- "Copy report" puts all saved runs on the clipboard. Runs survive a relaunch.

## Not in this phase

App Store screenshots, shipping the new look, and any new visual design.
