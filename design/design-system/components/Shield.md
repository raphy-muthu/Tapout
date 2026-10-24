# Shield

What iOS shows when someone opens a blocked app — the one Tapout screen people see outside Tapout, so it must be calm and final.

## Anatomy (ManagedSettingsUI `ShieldConfiguration`)

- Background: `bg` (pass the resolved UIColor for the current appearance; use a solid colour, not a blur, so contrast is predictable).
- Icon: `lock` line symbol rendered in `ember-ink`, on a disc of `ember-glow`.
- Title: "Locked" in `ink`.
- Subtitle: "Tap Buddy to open" in `ink-secondary`.
- Primary button: "Close", `surface-1` background, `ink` label.
- **No secondary button.** No "ignore limit", "one more minute" or similar.

## Notes

The shield is rendered by the system from a configuration, so exact fonts and layout are Apple's; Tapout controls colours, icon and strings. Keep strings to these lengths so they never truncate.

## The consumer provides

The resolved colours for the current appearance and the icon image.
