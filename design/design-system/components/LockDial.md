# LockDial

The hero of the lock screen: one huge countdown inside a ring that carries the lock state.

## Anatomy

- **Ring** — 336pt diameter on a 390pt‑wide device (wide enough for five `timer-hero` characters; scale with screen width), 6pt stroke, round caps. Base circle in `track`; progress arc in the state's line token (`ember-line` locked, `slate-line` unlocked), starting at 12 o'clock and running clockwise as time remains.
- **Glow** — a blurred circle behind the ring in `ember-glow` / `slate-glow`. Decorative only.
- **Numerals** — `timer-hero` (SF Pro Rounded, 112pt, ultralight, monospaced digits) in `ink`. Max 5 characters: `mm:ss` under an hour, `h:mm` at or above one hour.
- **State word** — `headline` in `ember-ink` / `slate-ink`, with the `lock` / `lock.open` line symbol, `space-xs` below the numerals.

## States

| State | Arc | Numerals | Word |
| --- | --- | --- | --- |
| Locked | `ember-line`, fraction remaining | time remaining | Locked |
| Unlocked | full circle `slate-line` | time focused this session | Unlocked |
| Ready to lock | `track` only | chosen duration | — (button below says it) |

## Motion

Locking uses `spring-lock` (0.6s, slight overshoot): arc sweeps closed, numerals scale 0.94 → 1, glow warms. Unlocking uses `spring-unlock` (0.8s, no bounce). Reduce Motion: crossfade in place, `dur-crossfade-lock` / `dur-crossfade-unlock`. Haptics `haptic-lock` / `haptic-unlock` fire on the first frame either way.

## Accessibility

Expose as one element: label "Locked, 24 minutes remaining" (`.accessibilityElement(children: .ignore)`), updates announced at most once a minute. At accessibility text sizes, show `h:mm` and move the ring above the numerals.

## The consumer provides

Lock state, remaining or elapsed seconds, and total duration (for the arc fraction).
