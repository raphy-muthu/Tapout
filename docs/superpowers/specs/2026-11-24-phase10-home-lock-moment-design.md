# Phase 10: Home and the lock moment, living glass

Part of the UI/UX upgrade (`docs/superpowers/plans/2026-11-24-ui-ux-upgrade.md`). Builds on Phase 9 (the glass orb, motion budget, tilt, haptic patterns, Lab switch). Phase 9 is not yet committed; Phase 10 sits on top of it in the same working tree.

## Owner's answers (2026-11-24)

| Question | Answer |
| --- | --- |
| Timer input | **The dial replaces the wheel, with a second rotation for 2 hours.** The wheel comes back at accessibility text sizes and with VoiceOver. |
| Rollout | **Everything behind the Lab switch** (Debug-only `settings.livingGlass`). Release looks exactly as today. |
| Lock haptic | **The new pattern only with the switch on.** Today's two taps stay the default. |

The owner asked for plans to proceed without a stop. The rest are my calls and can be changed.

## Decisions

| Topic | Decision |
| --- | --- |
| Switch | Everything below happens only with the Lab switch on. With it off, every screen, sheet and haptic is exactly as before Phase 10. |
| One reader | `LivingGlassReader` decides glass or classic once (switch, motion budget, shader present) and hands the answer to its content. `LivingOrb` and the lock moment use it, so they always agree. The timer dial is not a motion effect, so it depends only on the switch, the text size, VoiceOver and the Longer chip (final review I4): Reduce Motion, Low Power Mode or heat never swap it for the wheel. |
| Haptics | `LivingFeedback.lock()` and `.unlock()` play the Core Haptics patterns with the switch on and today's `Haptics.lock()`/`.unlock()` with it off. Every lock and unlock haptic in the app goes through them (lock moment, Relock now, relock after a pass, tag unlock, timer end, emergency pass). |
| Warmth | With the glass orb, a soft circle of glow sits behind it, 2.6× the orb, using the `ember-glow` and `slate-glow` tokens (the tokens say: a blurred circle, never a full-screen wash). When the orb appears in a new state it starts in the old state's color and warms or cools over `Motion.bloom` (1.2 s). Light mode at 55% strength, as the milestone wash. |
| Home | The three Home orbs get warmth. Warmth and the appear-ripple swing only when the orb's tone changed since it was last shown (`OrbToneMemory`), so a tab return, coming back from the background or the keyboard resizing the orb never replays them (final review I3). |
| Lock moment | With the glass orb: one orb instead of two stacked ones. It starts slate with the ready rings, turns ember while the ring sweeps (the tone change sends a shader ripple, which replaces the three-ring shockwave), and warms the background. Timing is unchanged: tap at 0 ms, sweep at 90 ms, seal at about 450 ms, settled at 600 ms. Classic orb: today's sequence, untouched. |
| Timer dial | Shown in the timer sheet with the switch on, unless the text size is an accessibility size or VoiceOver is on (then the wheel). 60 ticks around an outer ring for the first hour and 60 on an inner ring for the second hour. Drag the ring clockwise to add time: crossing 12 o'clock continues onto the inner ring. Steps of 5 minutes, from 5 minutes to 2 hours, with a detent haptic per step. The length is shown in the dial's centre. The drag is relative (it moves from where the value is), so a touch never jumps the value. VoiceOver can still adjust it in 5-minute steps (it shows the wheel by default, but the dial is adjustable too). |
| Longer than 2 hours | The preset chips stay (15 m, 30 m, 45 m, 1 h, 2 h). In dial mode a sixth chip, **Longer**, switches the sheet to the wheel at 3 h, so 12 h stays reachable. |
| Covers | Time's up and the milestone cover use `LivingOrb`, so they show the glass orb with the switch on. Time's up gets warmth and a ripple, cooling from ember, when the apps opened; after a hand-over to a schedule the orb stays ember, so it appears settled with no ripple. The milestone keeps its own wash and rings. |
| Reduce Motion | The glass orb already falls back to the classic one. Warmth then does not draw. The dial does not animate its ticks (they snap). |

## Not in Phase 10

- Insights, Modes, Places, onboarding, widgets, Live Activity, shield.
- A Settings switch for the owner, or shipping any of this in Release.
- Any change to lock, timer, schedule, pass or history logic. `TimerLock` keeps its 5 min to 12 h range.

## Unverified until the iPhone run

- The dial's feel: drag precision, the detent haptic per step, crossing into the second lap.
- The lock moment's single-orb sequence at full speed, and the new unlock haptic.
- Warmth in a dark room and in daylight.
