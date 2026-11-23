# Phase 8: timer lock

The owner's request: set how long to lock for, as a timer ("lock my phone for 45 minutes to do this task"). No tag to start, apps open again by themselves at the end.

## Owner's answers (2026-11-22)

| Question | Answer |
| --- | --- |
| How does a timer lock start? | **No tag needed.** Pick a duration on Home, tap Start. |
| Can it end early? | **A paired tag, or an emergency pass**, with the same rules as a normal lock. |
| What happens at zero? | **Apps open by themselves**, even with Tapout closed, with a short "Time's up" moment. |

The owner asked for plans to proceed without a stop, so the rest are my calls. Each can be changed.

## Decisions

| Topic | Decision |
| --- | --- |
| Where it lives | Home, unlocked state: a **Timer** button next to Scan opens a sheet. The sheet has a countdown wheel (hours and minutes), preset chips (15 m, 30 m, 45 m, 1 h, 2 h), the "What's it for?" field (the same draft as Home's), the mode whose apps will lock ("Locks Study's 6 apps"), and a **Start** button. |
| Range | 5 minutes to 12 hours, in 1-minute steps on the wheel. |
| Which apps | The active mode's apps, like a tag lock. Start is off, with "Choose apps in Modes first", when the mode has none. |
| No paired tag | Allowed. The sheet says "No tag is paired. Only the timer or an emergency pass will open your apps." |
| What the lock is | An ordinary `.locked(since:)` session plus a **`TimerLock`** (`start`, `duration`) kept beside it in the App Group store. Everything that reads the session (shields, schedules, widgets, history) keeps working unchanged. |
| Clock | Wall-clock. An emergency pass does not pause it. If the timer ends during a pass, the pass ends with it and the apps stay open. |
| Early exit | A paired tag unlocks it (the active mode's unlock places still apply); passes work as in any lock. Unlocking early drops the timer. |
| Home while locked | The orb ring shows the time left (it empties as time passes), the big number counts **down** to zero, the label reads "Locked · timer", with "Ends at 3:45 PM" beneath. Tap the orb, then a tag, to unlock early, as now. The pass link stays. |
| When it ends in the app | One shared "finish" step: shields off, session unlocked, the `lastUnlockAt` stamp, the record closed at the timer's end time. The app plays the unlock haptic and shows a **Time's up** cover ("45 min locked", Done); an intention gets the "Did you do it?" sheet after it. |
| When it ends with Tapout closed | The monitor extension runs the same finish step at the timer's end, and posts a notification ("Time's up. 45 min locked. Your apps are open."). The next time Tapout opens, it closes the record at the timer's end time and shows the Time's up cover once. |
| DeviceActivity | One more activity, `tapout.timer`, scheduled with the same `RelockPlan` strategies as the emergency relock (DeviceActivity refuses intervals under 15 minutes, so a short timer aims a warning callback at its end). The Lab's relock-strategy setting applies to both. |
| Activity limit | DeviceActivity allows 20 activities per app. Modes had 19 and the emergency relock 1. Modes now get **18**, so the timer fits. |
| Due rule | Same as an emergency pass: due when `now >= endsAt - early`, or when the clock was set back so far that `endsAt` is further away than the duration. The app waits for the exact time; the monitor accepts 60 s early. |
| Notifications | Asked for when the first timer starts (as schedules do). Without permission the timer still ends; only the notice is missing. |
| Widgets and Live Activity | While a timer lock runs they show **time left** counting down instead of time locked counting up. After the end they read unlocked. |
| History and Insights | A timer lock is an ordinary lock record (no place). Its end is the timer's end time, even when the app noticed later. |

## Hand-over to a schedule (owner's call)

When a timer ends and a mode's scheduled window is running at that moment, the lock does not open: it carries on as that mode's scheduled lock, as if the schedule had started on time.

- **Rule:** the same eligibility as a schedule start (`ScheduledLock.decide`): a window containing now on a scheduled day, Screen Time access on (the app's last check when the process can't see it), the mode has apps, a tag is paired, the schedule was not saved during this window, and the owner has not unlocked since the window began. The one difference: "already locked" is ignored, because the timer is the lock being replaced. `lastUnlockAt` is read as it was **before** the timer's finish, so the timer's own end never counts as an unlock. If more than one mode qualifies, the one whose window started latest wins, then mode order.
- **What happens:** the timer's record closes at its end time (as today); the session stays locked, `since` = now; the scheduled mode becomes the active mode (name published for widgets); its shields replace the timer mode's; no unlock stamp is written; the timer moves to `finishedTimer`. History then opens the scheduled lock's record through the usual `reconcile`.
- **Where:** one shared function in `Shared/`, used by the app's finish and the monitor's finish, so they agree. Access: the app and the monitor pass what they can see, as for schedule starts.
- **Notification (Tapout closed):** the title is the mode name, the body is "Timer done. Locked until you tap a tag."
- **Time's up cover:** shows with a **handed over** look: the orb is ember with a full ring, the title is still "Time's up", the line is "<length> done. <Mode> is locked until you tap a tag." (spoken form likewise). No claim that apps are open.
- **Widgets and Live Activity:** read the store, so they show the scheduled lock once the finish step has run. The timeline entry at the timer's end still reads unlocked until the finish step reloads them (the app and the monitor already reload after it).
- **Not handed over:** an early unlock by tag or pass; a timer that ends outside every window; a window the owner already unlocked in.

## Known limits (from the final review, kept on purpose)

- **The clock is wall-clock.** Setting the phone's clock forward or back moves the end with it, as it does for emergency passes.
- **Short timers lean on the emergency-relock trick.** For 15 minutes or more the monitor's end callback comes at the end time; under 15 minutes it relies on a warning callback. If that callback never comes, the timer still ends when Tapout is next opened (the record closes at the timer's end time either way).
- **Time's up is skipped for one case:** a finished timer still waiting to be closed when the next timer starts (its record is kept, closed at its own end).
- **The lock moment** for a timer counts up from 0:00 for a second before Home's countdown takes over.

## Not in Phase 8

- Pausing or extending a running timer.
- Choosing apps per timer (the active mode decides).
- Timer templates, repeating timers, or a timer inside a mode's schedule.
- A timer started from a widget, the Lock Screen or Shortcuts.

## Unverified until the iPhone run

- The monitor ending a timer while Tapout is closed (same mechanism as the emergency relock, which is itself still waiting for a device check, so a 5 to 14 minute timer leans on the same unconfirmed trick).
- The notification at the end.
- The Time's up cover after reopening following a closed-app end.
