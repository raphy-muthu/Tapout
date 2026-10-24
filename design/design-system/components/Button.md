# Button

One primary pill per screen, filled in the current state's accent; everything else is a quiet text button.

## Primary

- Height 56pt, full width inside `space-lg` margins, `Capsule(style: .continuous)` (`radius-pill`).
- Label in `headline`. Optional filled SF Symbol at 20pt before the label.
- Locked context: `ember` fill, `on-ember` label. Unlocked context: `slate` fill, `on-slate` label.
- Press: scale 0.97 over `dur-press`. No colour change on press.
- Focus ring: 3pt in the state's `-line` token, 3pt offset.

## Quiet

- Text only, `body` weight 400 in `ink-secondary`, minimum 44pt tall. For secondary actions ("Change mode").
- Never place a quiet "skip", "snooze" or "unlock anyway" next to a locked timer.

## Copy

One to three words, verb first: "Lock", "Tap Buddy to unlock" is the one allowed longer label. No exclamation marks.

## The consumer provides

Label, optional symbol name, the lock state (decides fill), and the action.
