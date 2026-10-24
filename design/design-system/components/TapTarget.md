# TapTarget

The moment you reach for Buddy: a single round target that says "hold your phone here" without a paragraph.

## Anatomy

- 160pt circle in `surface-2`, `wave.3.right` line symbol at 48pt in `ink`.
- Pulse outline 12pt outside the circle, 2pt `slate-line`, breathing over `dur-ready-pulse` (opacity 0.4 ↔ 1, scale 1 ↔ 1.04) with `ease-standard`. Under Reduce Motion it is static at full opacity.
- Label in `headline` / `ink` ("Tap Buddy to unlock" or "Tap Buddy to lock"); optional hint in `subhead` / `ink-secondary`.

## Behaviour

Shown while the Core NFC session is open. iOS draws its own scan sheet on top; the TapTarget is what sits behind it and what the user returns to on cancel. On a successful read, hand off to LockDial with `spring-lock` or `spring-unlock` and the matching haptic. On a tag that is not the paired Buddy: `haptic-tag-mismatch` and one line in `danger` — "That's not your Buddy".

## The consumer provides

The action (lock or unlock) for the label, and the NFC session state.
