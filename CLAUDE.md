# Tapout — notes for Claude Code

Tapout is an iPhone app (SwiftUI). You tap a paired NFC tag to lock distracting apps, and tap again to unlock. It is as strict as Brick: 5 emergency passes total, ever. The hero is a glowing glass orb that "seals" with a ring when you lock.

## Design source of truth

- `design/design-system/README.md`: colours, type, spacing, radii, motion, haptics, plus Swift snippets. Read it fully first.
- `design/design-system/tokens.json`: exact values, every one with a usage note.
- `design/SCREENS.md`: index of every screen and its source file. Read the "disagree" section; the screens win.
- `design/screens/*.dc.html`: per-screen specs, written as HTML.

## Rules

- Use token names, not raw hex. Every colour is an asset-catalog colour set named after its token, with light and dark appearances.
- Dark-first, but every screen must work in light mode.
- SF Pro for text, SF Pro Rounded (`design: .rounded`) for numbers. `.monospacedDigit()` on anything that ticks.
- 44pt minimum touch targets. Continuous corners. No borders on cards.
- Lock = two rigid haptic taps 90 ms apart. Unlock = one soft tap. Respect Reduce Motion (crossfades instead of springs).
- Very few words on screen. No guilt or shame copy, no emoji.
- Bracketed values like `[3h 12m]` in the specs are placeholders. Wire them to real data or clearly marked mock data.

## Build order

1. Xcode project and tokens: colour assets, `Font`, `Space`, `Radius`, `Motion`, `Haptics`, `Accent` (from the README).
2. `OrbView` (see SCREENS.md) and the floating tab bar.
3. Home in its 3 states, driven by a mock `LockState`, including the lock-moment animation.
4. Onboarding, Modes, Places, Insights, Settings, Emergency pass.
5. Real frameworks: Core NFC (tag pairing/reading), FamilyControls + ManagedSettings (blocking), ManagedSettingsUI (block screen), DeviceActivity (schedules).
6. ActivityKit Live Activity, WidgetKit widgets, weekly recap image export.

## Platform notes (check against current Apple docs before relying on them)

- Family Controls needs the `com.apple.developer.family-controls` entitlement. Distribution requires Apple's approval, so request it early.
- Core NFC needs the NFC capability and an `NFCReaderUsageDescription` in Info.plist. It only works on a physical iPhone, not the simulator.
- The block screen and Screen Time extensions run as separate app-extension targets.
