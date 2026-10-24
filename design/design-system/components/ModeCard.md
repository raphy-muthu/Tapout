# ModeCard

A saved blocking mode: which apps, when, and for how long, in one borderless card.

## Anatomy

- `surface-1` background, `radius-card` (24pt continuous), `space-lg` padding, no border or shadow in dark (one soft shadow allowed in light).
- Left: name in `title` / `ink`; summary in `subhead` / `ink-secondary` ("6 apps · weekdays"), `space-xs` below.
- Right: duration in `number-medium` (SF Pro Rounded) / `ink`, unit in `footnote` / `ink-tertiary`.
- Cards stack with `space-sm` gaps under an uppercase `caption` label.

## States

- **Active (locked now):** summary turns `ember-ink` with the `lock` symbol. No coloured background or border — the accent is a word and a glyph, not a fill.
- **Pressed:** background `surface-2`, scale 0.98 over `dur-press`.

## The consumer provides

Mode name, app count, schedule text, duration, and whether it is the active mode. Tapping opens the mode sheet (`radius-sheet`).
