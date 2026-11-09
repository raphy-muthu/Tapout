# Phase 4: real locking and schedules

Handoff build-order step 5: replace the mock lock with Screen Time. Phase 2 proved the risky parts on the owner's iPhone (shields, NFC UIDs, emergency relock through the DeviceActivity `warning` strategy, fired 1 s late). Phase 3 built every screen on `MockLockController`. Phase 4 makes the lock real, in two plans:

- **4A, real locking:** `LockEngine` replaces `MockLockController`; locks shield the active mode's apps minus the always-allowed ones; the lock survives quitting and restarts; passes are counted in the Keychain; pass time stops counting as locked; the Sealed block screen; a Screen Time check on every launch.
- **4B, schedules:** modes with a schedule lock by themselves through the monitor extension. Planned after 4A has run on the iPhone.

## Decisions (2026-11-08)

| | |
| --- | --- |
| Schedule end | **Never auto-unlocks.** A schedule only locks. Every lock, scheduled or not, ends with a tag (or an emergency pass for 5 minutes). A lock you start with a tag during a window stays until you tap again. This replaces the 3B decision "auto-unlock at the end". |
| Tap during a window | Unlocks until the next window starts. |
| Passes | Counted in the App Group **and** a this-device-only Keychain item. The lower count wins, so deleting and reinstalling Tapout doesn't refill passes. A new iPhone starts at five. |
| Pass time | **Doesn't count.** Each pass is recorded on its lock as a time window and left out of every total (Home's timer, Insights, Modes, milestones). Home's timer pauses during a pass and carries on afterwards. |
| Plans | Two: 4A, then 4B. |
| Which tags lock and unlock | Stays in `AppModel.check` (places and modes live there). `LockEngine` owns lock state, shields, passes and relock, and trusts its caller. |
| Lock records | Stay in `AppModel` for 4A (no lock starts outside the app yet). 4B moves record writing into `Shared/` so the monitor can start a scheduled lock's record. |
| Block screen | `ShieldConfiguration` extension, dark only: orb, "Sealed", "Tap a tag to open this app.", and a quiet "Close" button, because iOS shows a button either way. No `ShieldAction` extension unless the device run shows Close doesn't close. |

## 4A behaviour

- **Lock:** `LockEngine.lock()` writes `.locked(since:)` first, then applies `SharedStore.activeShieldPlan`. If Tapout dies in between, the launch sync puts the shields on.
- **Shield plan:** the active mode's apps, categories and sites, minus always-allowed apps and sites. Categories become `.specific(categories, except: allowedApps)`, so an always-allowed app inside a blocked category stays open. The app, the app's relock, and the monitor's relock all read the same `activeShieldPlan`. Mode switching is already off while locked, so the plan can't change mid-lock.
- **Launch:** `syncShields()` makes the shields match the stored lock state (on when locked, off when unlocked, left alone during a pass). Then `AppModel.reconcile(with:)` matches the history to the lock state: unlocked drops open records, as 3B did; locked with no open record adds one; a pass with no open record adds one with its pass window.
- **Emergency pass:** `useEmergencyPass()` returns the relock time; `AppModel.startPass(until:)` records the window. Relock now shortens it (`endPass()`), and unlocking shortens it too (`finishLock`). A relock by the monitor needs no record change, because the window already ends at the relock time.
- **Passes left:** `min(store.passesLeft, 5 − keychain.used)`. Spending writes both.
- **Screen Time revoked:** on launch and every return to the foreground, if onboarding is done and access isn't approved, a full-screen Screen Time page appears (onboarding's step 2 without dots). Allowing again re-applies the shields of a running lock.
- **Simulator:** shields and DeviceActivity don't run there, so `LockEngine.live()` uses stand-ins and the app's clock relocks an expired pass. `-mockScreenTimeRevoked` shows the Screen Time page.
- **Lab (DEBUG):** keeps Screen Time and App Group status, the session, passes with reset, the relock strategy and the log. Pairing, scanning and pass buttons go, because they would bypass `AppModel`.

## 4B outline (planned after 4A)

- One DeviceActivity activity per scheduled mode, repeating daily at the mode's start and end. The monitor checks the weekday in `intervalDidStart`, because one activity per weekday could pass the activity limit (about 20; check the current docs).
- `intervalDidStart`: if unlocked, make the scheduled mode active, start a lock record (shared helper), set `.locked(since:)` and apply the plan. If already locked, do nothing.
- `intervalDidEnd`: nothing, because schedules never unlock.
- Saving or deleting a mode re-registers its activity. Changes while locked apply to the next window.
- Overlapping windows: the first to start wins; later starts find the phone locked and do nothing.

## Not in Phase 4

Live Activity and widgets (Phase 5); lost tag with no passes left (an open PLAN.md decision; today the escape is deleting the app); monetization.
