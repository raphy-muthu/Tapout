# Phase 3B: onboarding, emergency pass, rejected tag, insights

Covers the second half of handoff build-order step 4, plus three ideas adopted from Uncoil (a friends' app, reviewed 2026-10-27): **lock intention**, **focus-time onboarding** and **honest insights**. Builds on Phase 3A (data models, `AppModel`, shared components, Settings, Places, Modes). Lock state still comes from `MockLockController`; Phase 4 swaps in `LockEngine`.

## Decisions (2026-10-27)

| | |
| --- | --- |
| Schedules | Auto-lock at the start, auto-unlock at the end (Phase 4 implements; 3B only saves schedules) |
| Pass link | Stays on locked Home; opens the hold-for-10-seconds screen |
| New tags | Pairing only while unlocked; the Rejected screen hides "Pair as a new place" while locked |
| Lock history | 3B starts writing `LockRecord`s from the mock lock flow, so Insights shows real numbers in the simulator. Phase 4 moves the writing into `LockEngine` |
| Copy | Very few words, no guilt, no shame counters (nothing ever counts misses or failed goals) |

## 1. Lock intention (new)

Why: planning *what* a session is for roughly doubles follow-through (Gollwitzer & Brandstätter 1997: 71% vs 32%). It must stay optional and cost at most one tap.

- **Before locking (unlocked Home):** one quiet field above Scan, placeholder `What's it for?`, max 40 characters, plus up to 3 recent intentions as chips (tap to reuse). Scan works with the field empty. The field clears after each lock.
- **While locked:** the intention shows under the state word on the lock moment (frame 4) and on locked Home, `tSubhead` in `ink-secondary`, one line, truncated.
- **On unlock** (tag, or a schedule ending): if the lock had an intention, a small sheet asks `Did you do it?` with the intention text and two equal buttons, `Done` and `Not yet`. Swiping the sheet away records nothing. One selection haptic. No follow-up, no score.
- **Emergency pass:** no question; the lock is still running.
- **Data:** `LockRecord.intention: String?` and `LockRecord.intentionDone: Bool?` (nil = no intention, or the question was skipped). The current lock's intention is kept in the store (`currentIntention`) so a Phase 5 Live Activity can show it.
- **Insights:** a `Goals done` tile (see §3), shown only after enough answers.

## 2. Focus-time onboarding (new step)

Why: Uncoil asks for the user's best time of day. Tapout's schedules auto-lock, so the answer can create a useful scheduled mode on day one.

Onboarding grows from 4 to 5 steps (dots update):

1. Tap to lock (welcome)
2. Allow Screen Time
3. What should wait? (apps)
4. **When should it lock?** (new)
5. Pair your first tag + interests

Step 4 layout follows the step 3 card style:
- Title `When should it lock?` (`tLargeTitle`), subtitle `It locks on its own. Tap a tag to open early.` (`ink-secondary`).
- One card of single-select rows, 56pt each: `Mornings` 9–12, `Afternoons` 13–17, `Evenings` 18–21, each with its time range on the right in `numberSmall`.
- Day chips `M T W T F S S` (weekdays on by default), the same chips as the Modes editor.
- CTA `Continue`; secondary text button `Not now` (skips; the first mode stays manual).
- Result: the first mode (named `Focus`) gets the apps from step 3 and this schedule.

## 3. Honest insights (rules for Insights and milestones)

Why: a number built from three data points misleads, and a streak that reads zero every morning feels like a punishment.

- **Minimum samples.** Every derived value has a minimum and returns nil below it. The tile then shows progress in `ink-tertiary` (`2 of 5 locks`) instead of a number. Sums and counts (`3h` this week, `12 locks`) are always shown, since they are facts.

  | Value | Needs |
  | --- | --- |
  | Longest | 1 lock this week |
  | Comparison card | Week total ≥ the shortest comparison for the user's interests; otherwise the card is hidden |
  | Best time (`Afternoons`) | 8 locks in the last 28 days, and the winning time block has ≥ 3 of them |
  | Goals done (`4 of 6`) | 3 answered intentions in the last 28 days |
- **Streaks stay alive until midnight.** A streak counts consecutive days with at least one finished lock. If today has none yet, count back from yesterday.
- **No miss counters.** Nothing shows missed days, broken streaks, `Not yet` answers or unused schedules.
- **Comparisons** come from a bundled table keyed by the onboarding interests (e.g. Sports → an NFL game ≈ 3h 12m, Movies → a feature film ≈ 2h, Music → an album ≈ 45m). Pick the largest comparison that fits the total; with no interests, use Movies.
- **Milestones** (full-screen, `Insights.dc.html` milestone view): first lock, first 10 hours, first 7-day streak, 50 hours, 100 hours. Each shows once, right after the unlock that crossed it. The subtitle uses a comparison (`About 5 movies' worth of time, back.`). Share uses a plain-text share link until the Phase 5 recap image.

Insights becomes a `ScrollView`: the spec's hero, comparison card, 7-day bar chart and `locks` / `longest` tiles, then a second tile row for `Best time` and `Goals done`, each gated as above.

## 4. Spec screens without changes in intent

- **Emergency pass** (`EmergencyPass.dc.html`): 5 pips, `N of 5 left. Passes never refill.`, a 204pt hold button inside a 248pt ember ring that fills over 10 s. Releasing resets it. Completing calls the controller's emergency pass and dismisses. Haptics: a light tick each second, the unlock tap on completion. VoiceOver: an accessibility action uses the pass after confirming, since a 10 s hold is hard with assistive tech.
- **Rejected tag** (`Rejected.dc.html`): a 220pt slate orb inside a dashed `danger` ring, `That's not one of your tags.`, `Try Kitchen or Desk.` (the first two paired place names), `Try again` (scans again) and, **only while unlocked**, `Pair as a new place` (opens the 3A pair sheet). Warning haptic on appear.
- **Scan path:** Home's Scan (and the locked orb, as the unlock stand-in) now reads a tag through 3A's `TagScanning`. A paired tag allowed by the active mode locks or unlocks; anything else shows Rejected. In the simulator, the mock scanner returns the default place, or an unknown tag with `-mockUnknownTag`.
- **Onboarding** shows on first launch only (a stored `hasOnboarded` flag). Step 2 calls the real Screen Time authorization on device; in the simulator it continues regardless. Step 3 opens `FamilyActivityPicker`. Step 5's `Scan tag` pairs through the 3A pair sheet.

## Out of scope

Recap image (Phase 5), Live Activity and widgets (Phase 5), real auto-lock schedules and `LockEngine` wiring (Phase 4), Buddy.
