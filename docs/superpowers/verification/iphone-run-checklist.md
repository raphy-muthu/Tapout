# Tapout iPhone run checklist

One ordered run on a real iPhone, merging the device steps from Phase 4A Task 9, Phase 4B Task 6, Phase 5 Task 6 and its final review, Phase 6, Phase 7 (device feedback) and Phase 8 (timer lock). Each item says what to do and what should happen. The tag in brackets shows where it came from. Plan for about a day: sections 5 and 9 need waiting. Record the result and any Lab lines next to each item.

## Before you start

- [ ] Xcode has profiles for TapoutShield and TapoutWidgets (Signing & Capabilities, your account signed in), and the device build exits 0.
- [ ] The App Group `group.com.raphymuthu.tapout` is ticked on Tapout, TapoutMonitor, TapoutShield and TapoutWidgets. TapoutShield gained it in Phase 13, so open its Signing & Capabilities tab and let Xcode refresh the profile.
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

## 13. Phase 9: living glass

The Metal Toolchain is installed and the shader is in the build (Lab, Effects, Glass shader reads "In this build"). The glass orb has been seen on the simulator only; everything below needs the iPhone.

- [ ] **Flag on.** Lab, Effects: switch "Living glass in the app" on. Home's orb is the glass one, stronger than the classic one, with light moving inside. (9)
- [ ] **Tilt.** Tilt the phone: the highlight moves smoothly with it, with no jitter, and settles when you hold still. (9)
- [ ] **Ripple on lock and unlock.** Lock and unlock: a ripple travels out from the orb each time Home shows the new state. (9)
- [ ] **Lock moment.** With the flag on: two taps, then a soft swell, with the same sequence and no dropped frames. (9)
- [ ] **Haptic patterns.** Lab, Effects, Haptics: lock, unlock, detent, scrub and paired each feel distinct and right. Note any that do not. (9)
- [ ] **Haptics after backgrounding.** Play a haptic, send Tapout to the background for a few seconds, return and play another: nothing crashes and the haptic still plays. (9)
- [ ] **Reduce Motion.** Settings, Accessibility, Reduce Motion on: Home shows the classic orb. Turn it off: the glass orb returns. (9)
- [ ] **Low Power Mode.** Low Power Mode on: classic orb. Off: glass again. (9)
- [ ] **Light appearance.** In light appearance, the glass orb keeps the same slate and ember colors and reads clearly. (9)
- [ ] **Largest Dynamic Type.** At the largest Dynamic Type, the orb shrinks as before and nothing overlaps. (9)
- [ ] **Battery and heat.** Settings → Developer Lab → Battery and heat. Unplugged, at one brightness: Start a run, close the Lab and leave Home open for an hour with the flag on, Stop; then the same with it off. Both reports show a drain figure and the worst heat; compare them. (9, 14)
- [ ] **Flag off.** Switch the flag off: every screen is exactly as before. (9)

## 14. Phase 10: Home and the lock moment

Turn the Living glass switch on (Lab, Effects) for all of these. Seen on the simulator only so far.

- [ ] **Timer dial.** Open Timer: a dial, not the wheel. Drag clockwise: one detent per 5 minutes, the outer ring fills. Keep going past 12 o'clock: the inner ring starts filling, up to 2 h, then it stops. Drag back: it unwinds. (10)
- [ ] **Dial precision.** Set exactly 25 min and 1 h 35 min without fighting it. (10)
- [ ] **Dial versus the sheet.** Drag the dial downward on its lower half: the value changes and the sheet neither moves nor dismisses. (10)
- [ ] **Longer.** Tap Longer: the wheel appears at 3 h and reaches 12 h. Start works. (10)
- [ ] **Wheel at large text and with VoiceOver.** At an accessibility text size, and separately with VoiceOver on, the sheet shows the wheel. (10)
- [ ] **Lock moment.** Scan a tag: one orb turns from slate to ember while the ring sweeps, one ripple goes out, the background warms. Two taps, then a soft swell. (10)
- [ ] **Unlock haptic.** Unlock with a tag: one soft tap and a fainter echo. (10)
- [ ] **Warmth.** On Home, locked and unlocked, the glow is soft and the words stay readable, in a dark room and in daylight. (10)
- [ ] **Time's up and milestone.** Both show the glass orb; Time's up warms in. (10)
- [ ] **Switch off.** The wheel, the classic lock moment and today's haptics are back. (10)

## 15. Phase 10b: Home boost

Living glass switch on. Seen on the simulator only so far.

- [ ] **Look.** Home has the stronger glass orb with light moving inside, a breathing glow filling the screen, and frosted controls and tab bar. (10b)
- [ ] **Tap the orb.** Unlocked: a ripple, a bounce and a tick. Locked: tapping it still starts a scan. (10b)
- [ ] **Lock bloom.** Scan a tag: ember light spreads from the orb across the screen and settles into the locked glow with no jump. (10b)
- [ ] **Smooth and legible.** Scrolling intentions, switching tabs and the countdown stay smooth; small text is readable on the glow in light and dark, indoors and in daylight. (10b)
- [ ] **Battery and heat with the boost.** The runs in section 13 cover this build, which includes the glow and frosted controls. If you ran them on an earlier build, run them again. (10b)
- [ ] **Switch off.** Home looks exactly as it did before. (10b)

## 16. Phase 11: Insights

Living glass switch on. Seen on the simulator only so far.

- [ ] **Look.** Insights has the glow behind it, frosted cards, seven glass columns, a five-week heatmap and a streak tile. (11)
- [ ] **Scrub the chart.** Drag sideways across the columns: one column lifts and glows under your thumb, the big number and title follow, one light tick per day. It stays on release; tapping it again returns to the week. Days after today don't select. (11)
- [ ] **Scroll over the charts.** Swipe up and down starting on the columns, then on the heatmap: the page scrolls every time and no day is picked by accident. (11)
- [ ] **Heatmap.** Tap days and drag along a week: the outline and the line underneath follow. Days before your first lock and after today are faint and don't select. The colors match how much you locked. (11)
- [ ] **Streak and tiles.** The streak and the other tiles match your real history. (11)
- [ ] **Share.** Share the week: the image has the glass columns and looks right in Photos and in Instagram Stories. (11)
- [ ] **VoiceOver.** The chart reads as one adjustable item and swiping up or down moves a day; on the heatmap only days with time are read. (11)
- [ ] **Reduce Motion.** Columns appear without rising or lifting; the glow holds still. (11)
- [ ] **Light, large text, daylight.** Everything reads in light appearance, at your largest text size, and outdoors. (11)
- [ ] **Smooth.** Scrolling and scrubbing stay smooth on the phone. (11)
- [ ] **Switch off.** Insights looks exactly as it did before. (11)

## 17. Phase 12: Modes, Places and onboarding

Living glass switch on. Seen on the simulator only so far.

- [ ] **Modes drawers.** Modes is one column of glass cards with the selected mode first and open. Tapping another card opens it and closes the last; tapping the open one closes it, with one light tick each time. (12)
- [ ] **Use this mode.** It moves the ember orb and "Selected" to that card without the cards jumping, and Home shows the new mode. While locked it is dimmed and Edit reads View. (12)
- [ ] **Tilt and scroll.** Rest a finger on a card: it leans under your finger and settles when you lift. Swipe up and down starting on cards: the page scrolls every time and nothing opens by accident. Quick and slow taps both work. (12)
- [ ] **Editor.** Edit grows out of its card and goes back into it on Cancel, Save and swipe down. Delete a mode you don't need: the screen closes cleanly. Scroll straight after closing the editor. (12)
- [ ] **Places.** The default place has a live orb that tilts with the phone and ripples when tapped; tapping the name opens the place. The other tiles open their places. (12)
- [ ] **Pair a real tag.** The orb ripples while waiting and stays visible above the system's scan sheet; on a read it turns ember, the ring closes, you feel two taps, and Name this Tag appears. Try an already paired tag: a still slate orb with the message. (12)
- [ ] **Preview onboarding.** Settings → Developer Lab → Preview onboarding: one orb moves through all six steps, the ring grows a sixth each step, and after Save place it turns ember with "Paired" and closes. Your own modes, apps, places and schedules are unchanged afterwards. (12)
- [ ] **VoiceOver.** A mode card says its name and Open or Closed; Edit says which mode; the days read as one item. The default place reads as one button. (12)
- [ ] **Reduce Motion.** The orbs are the classic still ones, drawers open at once, onboarding's steps crossfade, and nothing tilts, slides or resizes. (12, 14)
- [ ] **Light, large text, daylight.** Modes, Places, pairing and onboarding read in light appearance, at your largest text size, and outdoors. (12)
- [ ] **Smooth and cool.** Opening drawers, scrolling and onboarding stay smooth, and the phone doesn't warm up with Places left open for a few minutes. (12)
- [ ] **Switch off.** Modes, Places and pairing look exactly as they did before. (12)

## 18. Phase 13: widgets, Live Activity and shield

Living glass switch on. Widgets and the Live Activity seen on the simulator only; the shield has not been seen on any device.

- [ ] **Signing.** The signed install succeeds with TapoutShield's new App Group, and the blocked-app screen still appears. (13)
- [ ] **Turn the switch on, then look.** After toggling the switch in the Lab, Home Screen widgets turn flat ember (locked) or slate (unlocked) within a few seconds, and a running Live Activity changes with them. (13)
- [ ] **Widgets through a day.** Locked counts up, a timer counts down under "Time left", a pass reads "Relocks in" on slate, unlocked shows today's total; the medium widget's week matches Insights. (13)
- [ ] **Closed-app changes.** A schedule or timer that locks or unlocks while Tapout is closed repaints the widgets. (13)
- [ ] **Lock Screen widgets.** The circular and rectangular widgets are bolder and nothing is cut off, including a lock of more than ten hours. (13)
- [ ] **Live Activity.** The Lock Screen card is flat ember with a big number and fits without clipping, through lock, pass and Time's up. (13)
- [ ] **Dynamic Island.** Compact shows the flat lock disc and the time; long press shows the ember block; a second app's activity shows the minimal disc. (13)
- [ ] **StandBy and tinted.** In StandBy and with a tinted or clear Home Screen, every number is readable. (13)
- [ ] **Shield.** A blocked app shows the glass orb. With the switch off it shows the classic orb again (iOS may take a new lock, or a few minutes, to ask again). (13)
- [ ] **Daylight.** Near-black text on ember and slate reads outdoors. (13)
- [ ] **Switch off.** Widgets, the Live Activity and the shield look exactly as they did before. (13)

## 19. Phase 14: polish

- [ ] **Battery runs.** Besides Home (section 13), do an hour each, switch on, of Places left open and a locked Home. Tap Copy report and send the text. (14)
- [ ] **Battery meter.** A run keeps the screen awake, continues after you close the Lab, and the report says if you charged, used Low Power Mode, switched the look or left Tapout. Saved runs are still there after closing Tapout. (14)
- [ ] **Largest text.** At your largest text size, the numbers on mode cards grow with the words, and the mode pill, suggestion chips, Scan, Timer, Save place, Share and Make default keep space around their labels. Home's "phone-free today" line is complete (the orb gets smaller). Timer length, onboarding's time ranges, Insights tiles and chart labels, and Settings grow too; the week chart stays on screen; "Emergency passes", "Afternoons" and "0 apps" don't break mid-word; onboarding's first, Screen Time and pairing steps and the rejected-tag screen show their words without scrolling. Switch off too: this change ships. (14)
- [ ] **VoiceOver walk.** With VoiceOver on, switch on, swipe through Home, lock and unlock, every tab, a mode's drawer and editor, pairing and the onboarding preview: everything is announced in a sensible order and every control can be activated. (14)
- [ ] **Reduce Motion walk.** The same tour with Reduce Motion on: nothing slides, grows or sweeps; the glow and orbs hold still. (14)
