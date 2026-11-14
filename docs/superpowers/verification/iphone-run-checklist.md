# Tapout iPhone run checklist

One ordered run on a real iPhone, merging the device steps from Phase 4A Task 9, Phase 4B Task 6, Phase 5 Task 6 and its final review, and Phase 6. Each item says what to do and what should happen. The tag in brackets shows where it came from. Plan for about a day: sections 5 and 9 need waiting. Record the result and any Lab lines next to each item.

## Before you start

- [ ] Xcode has profiles for TapoutShield and TapoutWidgets (Signing & Capabilities, your account signed in), and the device build exits 0.
- [ ] The App Group `group.com.raphymuthu.tapout` is ticked on every target: Tapout, TapoutMonitor, TapoutShield and TapoutWidgets.
- [ ] Two NFC tags (NTAG213/215/216) are to hand: one to pair, one to be rejected as unknown.
- [ ] The Family Controls (Development) entitlement is already granted.
- [ ] Signing is set for a Release build too, so a signing problem shows early (the Release check is in section 10).
- [ ] A second iPhone without a Dynamic Island is available, if you own one (optional).

## 1. Setup and signing

- [ ] **Note existing schedules.** Before installing, check which modes already have schedules, since they start on install. (4B)
- [ ] **Install a Debug build.** `xcrun devicectl device install app --device 00008140-000A28340E29401C build/device/Build/Products/Debug-iphoneos/Tapout.app`. It installs and launches. (4A)
- [ ] **Widgets signing.** Add a Tapout widget to the Home Screen. It shows "Unlocked" with a real time, not "Unlocked 0m" (0m means the App Group is not ticked for TapoutWidgets). (5)
- [ ] **Reset passes.** In Settings → Lab, tap Reset passes. The count shows 5. (4A)
- [ ] **App icon.** Check the icon on the Home Screen, in iOS Settings → Tapout and in Spotlight. It is the ember orb with a full ring on near-black, crisp, with no transparent corners or odd edges. (6)

## 2. First launch and onboarding

- [ ] **Fresh onboarding.** Delete Tapout, reinstall, and go through onboarding to the end. Screen Time permission is asked, the app picker opens, the tag pairs, interests save. (4A, 6)
- [ ] **No Screen Time flash.** With access on, a cold launch never flashes the Screen Time page. (4A)
- [ ] **Notifications.** The notification permission is asked at launch; allow it. (4B)
- [ ] **Unknown tag.** Scan the second, unpaired tag. You see "That's not one of your tags." with a warning haptic. (4A, 6)

## 3. Pairing and locking

- [ ] **Set up a mode.** In Modes, give the active mode a whole category (for example Social) and one single app (for example a game). In Always allowed, add one app inside that category (for example Messages). (4A)
- [ ] **Lock.** Tap your tag. Two rigid haptic taps 90 ms apart, the orb seals, the timer starts at 0:00. Note how the lock moment feels against the NFC sheet. (4A)
- [ ] **Sealed screen.** Open an app from the blocked category and the single app. Both show Sealed (orb, "Sealed", "Tap a tag to open this app.", Close). Note whether the orb looks crisp and what Close does. (4A)
- [ ] **Always allowed.** The always-allowed app opens. (4A)
- [ ] **Force quit.** Force quit Tapout, then open a blocked app: still Sealed. Reopen Tapout: still locked, and the timer kept counting. (4A)
- [ ] **Read-only while locked.** Settings shows the locked banner and lock glyphs, with controls disabled. (4A)
- [ ] **Unlock.** Tap your tag: one soft haptic, blocked apps open. Note the milestone cover against the unlock. (4A)
- [ ] **Screen Time access off.** Turn off Tapout's Screen Time access in iOS Settings and switch back to Tapout without quitting: the Screen Time page appears. Note whether blocked apps opened while access was off. Tap Allow (or Open Settings): Home returns and blocked apps are Sealed again. Repeat with a force quit instead of switching back. (4A)

## 4. Emergency passes

- [ ] **Use a pass.** Lock, then use a pass (hold 10 s; releasing early resets it). Blocked apps open. (4A)
- [ ] **Relock with Tapout closed.** Leave Tapout closed for 5 minutes, then open a blocked app: Sealed again. Open Tapout: the timer is about 5 minutes behind the time since you locked. Lab shows the monitor's relock lines. (4A)
- [ ] **Second pass within 10 minutes.** Use a second pass within 10 minutes of the first: apps stay open for the full 5 minutes, not closed at once. (4A)
- [ ] **Relock now.** During a pass, tap Relock now: locked again, and the timer carries on. (5)
- [ ] **Pass count survives reinstall.** Note the pass count. Unlock first, then delete Tapout and reinstall it. Finish onboarding: the same count. Deleting the app removes the Home Screen widget from section 1; section 7 adds it again. (4A)
- [ ] **Restart the iPhone while locked.** Re-lock with your tag first, then restart. Blocked apps are still Sealed after the restart. The widget state before first unlock is checked in section 9. (4A)

## 5. Schedules (some need waiting)

Do 4A's checks first. Open Settings → Lab to watch the log.

- [ ] **Create a schedule.** Give a mode at least one app and a schedule for today starting about 3 minutes from now, at least 15 minutes long, on days that include tomorrow. Allow notifications when asked. Force quit Tapout and let the phone sleep. (4B)
- [ ] **Start time.** A notification names the mode with "Locked until you tap a tag."; a blocked app shows Sealed. Open Tapout: Locked, the mode pill shows that mode, the timer counts from the start time. Lab shows the "Scheduled lock" line and its access readout. (4B)
- [ ] **Unlock inside the window.** Unlock with your tag during the window. Force quit and reopen after 2 minutes: still unlocked, and no restart line in Lab. (4B)
- [ ] **Window end while locked.** Lock with your tag before the window ends and let the end time pass: still locked, and Lab shows "Schedule window ended". Unlock with your tag. (4B)
- [ ] **Open at window start.** With Tapout open at a window start, Home flips to Locked within about a second with the scheduled mode. (4B)
- [ ] **Unscheduled day.** On a day the schedule does not include, nothing happens at the start time and Lab shows "Schedule skipped: not a scheduled day". (4B)
- [ ] **No apps, no tag.** A second mode with a schedule but no apps: "Didn't lock: no apps chosen." Remove all paired places (only for this test, then re-pair): "Didn't lock: no tag paired." (4B)
- [ ] **Edit into a running window.** Edit a schedule so its window is already running: Lab shows "Schedule started" and then "Schedule skipped: saved during this window"; nothing locks until the next window. (4B)
- [ ] **Screen Time off at a window.** Turn Tapout's Screen Time access off before a window: "Didn't lock: Screen Time is off." (note Lab's access readout). Allow access again from Tapout's page without force quitting; the next window still locks. (4B)
- [ ] **Pass during a scheduled lock.** An emergency pass during a scheduled lock with Tapout closed relocks after 5 minutes in the same mode. (4B)
- [ ] **Notifications denied.** With notifications denied in iOS Settings, a window still locks, silently. (4B)
- [ ] **Deleted mode.** Delete a scheduled mode before its window: nothing happens at its start time. (4B)
- [ ] **Repeat tomorrow.** Tomorrow at the same time it locks again with a notice. (4B)
- [ ] **Scheduled lock with Tapout closed, widgets.** Let a schedule lock while Tapout is closed: widgets update within a minute or so. Tap the notification to open Tapout: the Live Activity starts. (5)

## 6. Live Activity

- [ ] **Starts on lock.** Lock with your tag: the Dynamic Island (compact, minimal, expanded) and the Lock Screen show the Live Activity with a ticking timer. (5)
- [ ] **Timers tick.** With the screen lit, the digits tick. On the dimmed Lock Screen, the timer shows dashes; that is iOS behaviour, not a bug. (5)
- [ ] **Pass state.** Use a pass: the card shows "Open · Relocks in" with the countdown on one line. After the relock, the card shows the locked timer again, without the 5 minutes. (5)
- [ ] **Unlock ends it.** Unlock: the Live Activity ends. (5)
- [ ] **Settings toggle.** Settings → Live Activity off and on while locked: it ends, then comes back. (5)
- [ ] **iOS per-app switch.** Turn the iOS per-app Live Activity switch (iOS Settings → Tapout) off and on while locked. Tapout does not crash; the activity returns after you open Tapout. (5)
- [ ] **Swipe away.** Swipe the Live Activity away, then open Tapout: it comes back. This is by design. (5)
- [ ] **Largest Dynamic Type and Bold Text.** Set the largest Dynamic Type size and turn on Bold Text. The Lock Screen card still fits, with nothing clipped or overlapping. (5)
- [ ] **Lock Screen wallpapers.** Check the card on a light and a dark wallpaper: text stays readable. (5)
- [ ] **Always-On.** On an Always-On display (iPhone 14 Pro or later), the card is readable and dimmed correctly. (5)
- [ ] **No Dynamic Island.** On a device without a Dynamic Island, if available, the Lock Screen card and banner look right. (5)
- [ ] **StandBy.** Lay the phone sideways on a charger: the Live Activity shows in StandBy, and in night mode it is not glaring. (5)
- [ ] **1h+ and 10h+ timers.** After the lock passes 1 hour (and later 10 hours, see section 9), the timer fits on the card, the island and the widgets. (5)

## 7. Widgets

- [ ] **Add the widgets.** Add the small and medium widgets to the Home Screen and the circular and rectangular widgets to the Lock Screen. (5)
- [ ] **Locked.** Lock with your tag: every widget shows Locked with a ticking timer. (5)
- [ ] **Pass.** Use a pass: "Open" with the countdown everywhere. Close Tapout and wait for the relock: widgets show the locked timer again, without the 5 minutes. Watch the widgets at the relock time. (5)
- [ ] **Unlocked.** Unlock: widgets show today's time. (5)
- [ ] **Tinted.** Set the Home Screen to tinted mode: the small and medium faces show a flat orb with an accented ring and today's bar in the tint. Nothing is unreadable. (6)
- [ ] **Clear.** Set the Home Screen to clear mode: same flat orb, readable on the clear background. Also try light and dark Home Screen appearance in full colour: glass orb unchanged. (6)
- [ ] **StandBy small widget.** In StandBy the small widget reads clearly, in night mode too. (5)
- [ ] **Lock Screen widgets.** On light and dark wallpapers, and in Always-On, the circular and rectangular widgets are legible. (5)

## 8. Recap

- [ ] **Share.** In Insights, tap Share. The sheet shows the "Your week" recap thumbnail. Share to Instagram Stories or Photos. (5)
- [ ] **Resolution.** Save it to Photos and open Info: the image is 1080 × 1920. (5, 6)
- [ ] **Look.** The saved image matches the thumbnail, with correct fonts and no clipping. (5)

## 9. Long-running and overnight checks

- [ ] **Lock over 8 hours.** Lock, keep it locked for over 8 hours (overnight is fine), then reopen Tapout. Blocked apps stayed Sealed, the timer is right, and the Live Activity (which iOS ends at 8 hours) returns after you open Tapout. (5)
- [ ] **Overnight schedule.** Run this overnight, with the 8-hour check. An overnight schedule (for example 11 PM to 6 AM) locks at the start and stays locked past the end. (4B)
- [ ] **10h+ timer.** At 10 hours or more, the timer fits everywhere (card, island, widgets). (5)
- [ ] **Midnight rollover.** Across midnight, "today" in widgets and Insights rolls over to the new day, and the lock time is split correctly. (5)
- [ ] **Reboot, then widgets before first unlock.** Restart the iPhone while locked. Before the first unlock, check the Lock Screen widgets: they show a sensible state (no crash, no stale "Open"). After unlocking, they update. (5)

## 10. Reset

- [ ] **Unlock and tidy.** Unlock, and remove the test schedules and any test places you added. (4B)
- [ ] **Reset passes.** Lab's Reset passes (Debug builds only) is the only reset. The count survives reinstall by design. For a clean start before release, reset in Debug, then install the Release build. (4A)
- [ ] **Release or TestFlight build.** Install a signed Release or TestFlight build and repeat sections 3 (lock, Sealed, unlock), 6 and 7 quickly. It works the same, and Settings has no Lab. (5, 6)
- [ ] **Report.** Report each result, plus anything that looked or felt wrong (haptics, the lock moment, the milestone cover). (4A, 4B, 5, 6)
