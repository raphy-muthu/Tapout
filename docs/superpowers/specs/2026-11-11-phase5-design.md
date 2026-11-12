# Phase 5: system surfaces

Handoff build-order step 6: a Live Activity and Dynamic Island for a running lock, Home Screen and Lock Screen widgets, and the weekly recap image. Specs: `design/screens/LiveActivity.dc.html`, `Widgets.dc.html`, `Recap.dc.html` (sizes there are CSS points; Recap is 1080 × 1920 px). Builds on Phase 4: the lock state, history and modes live in the App Group store.

## Decisions (2026-11-11)

| | |
| --- | --- |
| Live Activity during a pass | Slate orb with an ember ring, "Open", and "Relocks in 4:32" counting down; afterwards it shows the locked timer again (pass time left out). |
| Live Activity on/off | Starts with every lock, on by default; Settings → Live Activity turns it off (the switch already exists and is stored). iOS's own per-app switch also applies. |
| Widgets | Home Screen small (locked / open / unlocked) and medium (this week), as designed, plus Lock Screen circular and rectangular widgets (my design, below). |
| Recap | Insights' Share button shares the recap image, with the text line as the message. |
| Timers | Live Activity and widget timers use `Text(date, style: .timer)` in SF Pro with monospaced digits (Fraunces can't tick there). Static numbers of 20pt and up stay Fraunces, so the widget extension carries the fonts and `OFL.txt`. |
| Scheduled locks | ActivityKit only lets the app start a Live Activity while it's in the foreground (no push server in v1). A lock a schedule starts gets its Live Activity the next time Tapout opens (for example from the lock notification). Widgets refresh from the monitor too. |

## How it fits together

- **`Surfaces/`** (new folder, compiled into the app and the widget extension, not the monitor): `LockSnapshot` (what every surface shows, computed from the store at one moment), the widget faces, the Live Activity views, `LockActivityAttributes` and `LiveActivityPlan`. Faces live here so the app's DEBUG gallery can show them in the simulator.
- **`LockSnapshot.state`**: `.unlocked`, `.locked(countingFrom:)` or `.open(relockAt:resumesFrom:)`. `countingFrom` is a date such that a timer counting up from it shows the lock's time without pass time; `resumesFrom` is the same for after the pass.
- **`TapoutWidgets`** (new extension, `com.raphymuthu.tapout.widgets`, App Group): the widget bundle, the timeline provider and the `ActivityConfiguration`.
- **App:** on every lock-state change, foreground and launch, `RootView` reloads widget timelines and syncs the Live Activity (`LiveActivityController`, driven by the pure `LiveActivityPlan`). The monitor reloads widget timelines after a scheduled lock or a relock.
- **Live Activity during a pass:** its content has `openUntil = relockAt` and `staleDate = relockAt`. Once stale, the view shows the locked timer from `lockedFrom`, so it's right even if Tapout stays closed through the relock.

## Lock Screen widgets (not in the designs)

Rendered by iOS in its own tint, so no token colours apply.

- **Circular:** a lock (or open-lock) symbol over the timer while locked, the countdown while open, or today's phone-free time ("2h 40m") while unlocked, on the standard accessory background.
- **Rectangular:** the state word with its symbol ("Locked", "Open", "Unlocked"), then the timer, the countdown ("Relocks in 4:32") or "2h 40m today", then the mode's name while locked or open.

## Not in Phase 5

Push-started Live Activities (needs a server), interactive widgets, StandBy-specific layouts, Apple Watch.
