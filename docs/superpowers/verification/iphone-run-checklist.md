# Tapout iPhone run checklist

One ordered run on a real iPhone, merging the device steps from Phase 4A Task 9, Phase 4B Task 6, Phase 5 Task 6 and its final review, Phase 6, Phase 7 (device feedback) and Phase 8 (timer lock). Each item says what to do and what should happen. The tag in brackets shows where it came from. Plan for about a day: sections 5 and 9 need waiting. Record the result and any Lab lines next to each item.

## Before you start

- [ ] Xcode has profiles for TapoutShield and TapoutWidgets (Signing & Capabilities, your account signed in), and the device build exits 0.
- [ ] The App Group `group.com.raphymuthu.tapout` is ticked on Tapout, TapoutMonitor and TapoutWidgets. TapoutShield doesn't use it.
- [ ] Two NFC tags (NTAG213/215/216) are to hand: one to pair, one to be rejected as unknown.
- [ ] The Family Controls (Development) entitlement is already granted.
- [ ] Signing is set for a Release build too, so a signing problem shows early (the Release check is in section 10).
- [ ] A second iPhone without a Dynamic Island is available, if you own one (optional).

## 1. Setup and signing

- [ ] **Note existing schedules.** Before installing, check which modes already have schedules, since they start on install. (4B)
- [ ] **Install a Debug build.** `xcrun devicectl device install app --device 00008140-000A28340E29401C build/device/Build/Products/Debug-iphoneos/Tapout.app`. It installs and launches. (4A)
- [ ] **Widget installed.** Press and hold the Home Screen, tap +, search Tapout and add the small widget. It shows "Unlocked". "0m" today is normal on a fresh install. The real test that the widgets share the App Group is the first lock in section 3: the widget must change to Locked. (5)
- [ ] **Reset passes.** In Settings → Lab, tap Reset passes. The count shows 5. (4A)
- [ ] **App icon.** Check the icon on the Home Screen, in iOS Settings → Tapout and in Spotlight. It is the ember orb with a full ring on near-black, crisp, with no transparent corners or odd edges. (6)

## 2. First launch and onboarding

- [ ] **Fresh onboarding.** Delete Tapout, reinstall, and go through all six steps: Welcome, Screen Time (permission is asked), Apps (the picker opens), Focus time, **Your interests on a screen of their own** (Continue works with nothing picked), then Pair your first tag. When the tag is found, the name field is labelled **"Name this Tag"**. Interests you picked show up in Insights later. (4A, 6, 7)
- [ ] **No Screen Time flash.** With access on, open Tapout a dozen times (cold launches after force quitting, and returning from the Home Screen). The "Allow Screen Time" page never appears, not even for a moment. (4A, 7)
- [ ] **Notifications.** The notification permission is asked at launch; allow it. (4B)
- [ ] **Unknown tag.** Scan the second, unpaired tag. You see "That's not one of your tags." with a warning haptic. (4A, 6)

## 3. Pairing and locking

- [ ] **Set up a mode.** In Modes, give the active mode a whole category (for example Social) and one single app (for example a game). In Always allowed, add one app inside that category (for example Messages). (4A)
- [ ] **Lock.** Tap your tag. Two rigid haptic taps 90 ms apart, the orb seals, the timer starts at 0:00. Note how the lock moment feels against the NFC sheet. Then look at the Home Screen widget: it shows Locked. If it still says Unlocked, the App Group is not ticked for TapoutWidgets. (4A, 5)
- [ ] **Sealed screen.** Open an app from the blocked category and the single app. Both show Sealed: the glass orb in an ember ring with a soft glow, "Sealed", "Tap a tag to open this app.", and an **ember Close button**. Note how big the orb looks, whether its edges are crisp and its glow soft (no visible square or hard edge), and what Close does. (4A, 7)
- [ ] **Always allowed.** The always-allowed app opens. (4A)
- [ ] **Force quit.** Force quit Tapout, then open a blocked app: still Sealed. Reopen Tapout: still locked, and the timer kept counting. (4A)
- [ ] **Read-only while locked.** Settings shows the locked banner and lock glyphs, with controls disabled. (4A)
- [ ] **Unlock.** Tap your tag: one soft haptic, blocked apps open. Your first finished lock earns the **First lock** milestone cover: three rings appear from the outside in and the orb fades up; the seal ring sweeps closed as the ember glow rises; the title and the line under it fade up; one light tap and a faint ripple as the seal closes. Share and Done work. Tap Done within the first second: no tap is felt after the cover closes. Try it once with Reduce Motion on (iOS Settings → Accessibility → Motion): it simply fades in. (4A, 7)
- [ ] **Screen Time access off.** Turn off Tapout's Screen Time access in iOS Settings and switch back to Tapout without quitting: after about 1.5 seconds (Home shows briefly first), the Screen Time page appears. Note whether blocked apps opened while access was off. Tap Allow (or Open Settings): Home returns and blocked apps are Sealed again. Then switch away and back twice: the page does not come back. Repeat with a force quit instead of switching back. (4A, 7)

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

## 11. Phase 7 extras

Added after your first run. Each is a check for something Phase 7 changed.

- [ ] **Cold launch after a restart.** Restart the iPhone, unlock it, wait 10 seconds, then open Tapout; repeat after a force quit. The Allow Screen Time page never appears, not even briefly. If it flashes only here, report it with the time since the restart. (7)
- [ ] **A dozen ordinary launches.** Force quit and relaunch, and come back from the Home Screen, Control Center and a notification, twelve times in all. No flash. (7)
- [ ] **Revoke, then scan at once.** Turn Tapout's Screen Time access off, switch back, and within a second tap your tag. When the NFC sheet closes, the Screen Time page appears within about 2 seconds. (7)
- [ ] **Cancel the tag sheet in onboarding.** On Pair your first tag, start a scan and cancel the sheet. You stay on that step, Scan tag works again, and Not now still finishes onboarding. (7)
- [ ] **Places pairing label.** Places → add a tag. The field above the name reads "Name this Tag". (7)
- [ ] **Sealed in light and dark.** Open a blocked app with the iPhone in light appearance and again in dark. Always the dark screen. If a mode blocks a website, Safari shows the same screen. (7)
- [ ] **Milestone Close.** Tap the top-right Close quickly on a fresh cover a few times: it closes every time. Open Share and cancel it: the sequence doesn't replay. Turn on Reduce Motion from Control Center while the cover is open: the orb and words stay visible. At the largest text size Share and Done stay on screen. In light mode the glow is gentle, not a flat disc. (7)
- [ ] **Release or TestFlight look.** The Sealed screen shows the glass orb, not flat circles (flat circles mean the image didn't load in the signed build), and Settings has no Lab. (7)

## 12. Phase 8: timer lock

Needs a mode with apps chosen. Allow notifications when asked. The first three are the important ones: they are the parts only an iPhone can prove.

- [ ] **Start a timer.** On Home, tap **Timer**. The sheet shows a duration, a wheel, five chips and "Locks <mode>'s apps". Pick 15 min, tap Start: two rigid haptics, the orb seals, the big number counts **down** from 15:00, the label reads "Locked · timer" and "Ends at" shows the right clock time. No tag was needed. Blocked apps are Sealed. (8)
- [ ] **Timer ends with Tapout open.** Start a 5 minute timer and stay in Tapout. At 0:00: one soft haptic, the **Time's up** cover appears ("5 min locked. Your apps are open."), blocked apps open. Done closes it. If you wrote "What's it for?", "Did you do it?" follows. (8)
- [ ] **Timer ends with Tapout closed.** Start a 15 minute timer, force quit Tapout and lock the phone. At 15 minutes: a "Time's up" notification arrives, and a blocked app opens. Open Tapout: the Time's up cover shows once, Home is unlocked, and Insights counts 15 minutes. Lab shows the monitor's "timer: finished" line. This leans on the same DeviceActivity trick as the emergency relock, so also note how late the unlock was. (8)
- [ ] **Short timer with Tapout closed.** Repeat with 5 minutes, Tapout force quit. Note whether apps open on time, a few minutes late, or only when you open Tapout. Report which. (8)
- [ ] **Early exit with a tag.** Start a 30 minute timer, then tap your tag: it unlocks (one soft haptic) and the timer is gone. Home shows Unlocked, no Time's up cover, and 30 minutes later nothing changes. (8)
- [ ] **Early exit with a pass.** Start a timer and use an emergency pass: apps open for 5 minutes, then relock with the timer still counting down in real time (the pass does not pause it). (8)
- [ ] **Timer ends during a pass.** Start a 5 minute timer and wait about 4 minutes, then use a pass, so the pass is still open when the timer ends. At the timer's end apps stay open and Home is unlocked. (8)
- [ ] **Quit and restart.** Start a 15 minute timer, force quit Tapout, then restart the iPhone. Blocked apps are still Sealed after the restart. Reopen Tapout before the end: the countdown is right. After the end it unlocks. (8)
- [ ] **No apps chosen.** On a mode with no apps, the sheet shows "Choose apps in Modes first" and Start is off. (8)
- [ ] **No tag paired.** With no paired places (only for this test), the sheet says only the timer or an emergency pass will open the apps. Start works. (8)
- [ ] **Widgets and Live Activity.** During a timer lock: the Live Activity (Lock Screen, island, compact and minimal), the Home Screen widgets and the Lock Screen widgets count **down** with "left", not up. At the end they return to Unlocked. At 10 hours or more they still fit. (8)
- [ ] **Schedule during a timer.** Let a scheduled window start while a timer lock is running (say a mode scheduled from 18:00 and a 1 h timer started at 17:30). Nothing changes at the window's start (Lab shows "Schedule skipped: already locked"). When the timer ends inside the window, the apps stay Sealed, now under the scheduled mode; with Tapout closed the notification's title is the mode's name and its text is "Timer done. Locked until you tap a tag." (Lab: "timer: finished, handed over to <mode>"); the Time's up cover shows an ember orb with a full ring and "<length> done. <Mode> is locked until you tap a tag."; there is no unlock haptic; Home shows the scheduled mode locked, and a tag tap opens it. Insights keep the timer's lock and the scheduled lock as two records, the second starting at the timer's end. If you already unlocked with your tag earlier in that window, or the window has already ended when the timer does, the apps open instead. (8)
- [ ] **Timer ends outside every window.** Start a timer that ends when no mode's scheduled window is running: the apps open as usual, with "Time's up", "<length> locked. Your apps are open." and the unlock haptic (or the "Time's up" notification with Tapout closed). (8)
- [ ] **Notifications denied.** With notifications off, the timer still ends on time; only the notice is missing. (8)
- [ ] **Wheel and sheet.** The wheel stops at 5 minutes and 12 hours. Chips move the wheel. The sheet is usable in light mode and at the largest text size. (8)
