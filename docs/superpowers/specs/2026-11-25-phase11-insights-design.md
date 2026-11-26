# Phase 11: Insights in living glass

Phase 4 of the upgrade plan (`docs/superpowers/plans/2026-11-24-ui-ux-upgrade.md`). The owner accepted the boosted Home and asked for Insights next.

## Owner's answers

| Question | Answer |
| --- | --- |
| What the screen holds | **Add to today's.** Nothing leaves. The chart becomes scrubbable; a streak and a five-week heatmap are added. |
| Week chart | **Glass columns** that lift and glow under the thumb. |

Everything is behind the Living glass switch (Debug only). With it off, and in Release, Insights is unchanged.

## Screen, top to bottom (switch on)

1. Header "This week" and the share button, frosted.
2. Hero total, "phone-free this week". With a day selected, the header names the day and the hero shows that day.
3. Week chart: seven glass columns.
4. Last five weeks: a heatmap with a readout line under it.
5. Comparison card (always the week's, whatever is selected).
6. Tiles: day streak and locks, longest and best time, goals done.

The breathing glow from Home sits behind the screen at lower strength. The cards are frosted.

## Week chart

- Today is lit until a day is selected.
- Tap a column to select it; tap it again to return to the week. Drag sideways to move the selection; it stays on release.
- Days after today can't be selected.
- A vertical drag scrolls the page.
- A scrub haptic per change.
- Columns rise in turn on first appearance, and the selected one lifts. Reduce Motion: no rise, no lift.
- VoiceOver: one adjustable element. Swipe up or down moves a day.

## Heatmap

- Five rows, the current week last, seven days each, in the calendar's week order.
- A day's color strength follows its phone-free time against the busiest day shown (at least one hour, so one short lock isn't full strength).
- Days after today, and days before the first lock, are faint and can't be selected. A new owner never sees a field of misses.
- Tap a day, or drag across a row. The readout shows the day and its time. Today is selected at first.
- Cells are at least 44 points apart both ways on a 375-point screen.
- Weekday letters and the readout use SF Mono through `.monospaced()`.
- VoiceOver: only days with time on them are read, so empty days aren't read out as misses.

## Streak

`Insights.streak` as it already is (alive until midnight). Before the first one, the tile shows progress ("0 of 1, lock to a streak").

## Shared image

With the switch on, the recap's bars use the same glass column.

## Not changing

Lock, schedule, history and Insights calculations. The milestone cover (already on the glass orb). Modes, Places, onboarding.

## Known limits

- The heatmap is only as full as the history on that iPhone.
- Look, drag feel and haptics need the owner's iPhone.
