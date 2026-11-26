# Phase 12: Modes, Places and onboarding in living glass

Everything here sits behind the Debug-only Lab switch (`settings.livingGlass`). With the switch off, and in
every Release build, the screens are unchanged. No lock, schedule, timer, pass or history logic changes.

## Owner's choices (2026-11-25)

| Question | Choice |
| --- | --- |
| Modes | **Drawer cards.** One column; tapping a card opens it; editing is one tap further, on Edit. |
| Places hero | **A live glass orb** on the default place's card. Pairing gets the sample's moment. |
| Onboarding | **One orb throughout:** moves and resizes, a sixth of the ring per step, ember on the first tag. |

## Shared

- The breathing glow now sits behind all four tabs: full on Home, `BackdropPlan.readingStrength` elsewhere.
  `GlassPageBackground` draws the same glow behind sheets and onboarding.
- `card()` and `CircleIconButton` go through `controlSurface`: identical with the switch off, glass with it on.
- Modes and Places fade out under the status bar (`StatusBarFade`, moved out of Insights).
- Sheets and covers get `\.glassControls` explicitly.

## Modes

- One column of cards, the active mode first on arrival. The order holds while the screen is up, so a card
  doesn't jump when it becomes active.
- Card header: an orb gem (ember for the active mode, slate for the rest; ringed while locked), name, the
  existing subtitle, "Selected" or "Active now" on the active mode.
- One drawer open at a time; the active mode's is open on arrival. Tap the open header to close it.
- Drawer: app icons, the seven days (lit when scheduled), the three tiles (Schedule, Unlocks at, This week),
  "Use this mode" (not on the active mode; off while locked) and "Edit" ("View" while locked).
- A card tilts toward a finger resting on it and lets go once the finger moves (so scrolling is untouched).
  iOS 18 and later; none with Reduce Motion.
- On iOS 18 and later the editor zooms out of its card.
- The editor gets the glow, glass cards and a larger glass orb.

## Places

- Default place card: a glass orb (slate; ember and ringed while locked). Tapping the orb ripples it; tapping
  the name opens the place. Tiles get a small orb in place of the flat dot. Cards tilt.
- Place sheet: glow and glass.
- Pairing sheet: the status disc becomes the orb. Scanning ripples every 1.1 s; a read turns it ember, closes
  the ring and plays the `paired` haptic; then the name field, as today. A failure is a still slate orb with
  the message. Words are unchanged.

## Onboarding

- One orb above the steps, never recreated.

| Step | Orb size (large text) | Ring |
| --- | --- | --- |
| 1 welcome | 260 (180) | 1/6 |
| 2 Screen Time, hourglass on the orb | 190 (120) | 2/6 |
| 3 apps, 4 focus time, 5 interests | 96 (hidden) | 3/6, 4/6, 5/6 |
| 6 pair, rippling | 230 (150) | 5/6 |
| 6 paired | 230 (150), ember | full |

- When the first tag pairs, the answers are saved at once, the orb turns ember with "Paired", and onboarding
  closes 1.6 s later. "Not now" closes at once, as today.
- Steps drop their own artwork (welcome orb, hourglass tile, pairing rings) while the shared orb is there.

## Lab: preview onboarding (Debug only)

Replaying real onboarding on a set-up phone would overwrite the active mode's apps and schedule. The Lab gets
"Preview onboarding": the same screens over a scratch store, with a stand-in tag scan. No Screen Time request,
no notification request, nothing written to the real store. It has a close button.

## Limits

- Glass orb, ripples and tilt fall back to the classic orb under Reduce Motion, Low Power Mode or heat.
- iOS 17 gets no finger tilt and no zoom.
- NFC pairing and haptics can only be judged on an iPhone.
