# Phase 9: living glass foundation

Part of the UI/UX upgrade (`docs/superpowers/plans/2026-11-24-ui-ux-upgrade.md`, which holds the three directions and the samples page). This phase builds the shared engine and the first visible piece of the chosen direction.

## Owner's decisions (2026-11-24)

| Question | Answer |
| --- | --- |
| Direction | **Blend A, C, B.** Living glass for Home, the lock moment, Modes and Places. Field instrument's heatmap and scrub for Insights, and its dial for the timer. Bold poster's flat color for widgets and the Live Activity. |
| Technology ceiling | Metal shaders, CoreMotion, Core Haptics. iOS 17 floor. |
| Scope this phase | The foundation and the first Living glass orb. No other screen changes. |

The owner asked for plans to proceed without a stop. The rest are my calls and can be changed.

## What Phase 9 delivers

| Piece | Decision |
| --- | --- |
| Feature flag | `AppSettings.livingGlassKey` (`settings.livingGlass`), **off by default**, switched on from the Lab's new Effects page (Lab is DEBUG-only, so Release is always off). Off means today's `OrbView`, pixel for pixel. |
| Motion budget | `MotionBudget.level(...)` returns `.full` or `.still`. `.still` when Reduce Motion, Low Power Mode, thermal state serious or critical, or the app is not active. `.still` shows the classic `OrbView`. Frames are capped at 30 per second. |
| Tilt | `TiltFilter` (pure low-pass plus a slowly following rest pose, output clamped to -1...1) fed by `MotionSource`, a shared reference-counted wrapper around one `CMMotionManager` at 30 Hz. Without a motion sensor (the Simulator) it sways slowly on its own. |
| Haptics | `HapticPattern` (pure event lists: lock, unlock, detent, scrub, paired) and `HapticEngine` (Core Haptics, falls back to today's `Haptics` where unsupported). The lock pattern keeps the spec rule: two rigid taps 90 ms apart, then a soft swell. Only the lock moment (with the flag on) and the Lab use the engine this phase. |
| Motion tokens | `Motion` gains `tone`, `bloom`, `scrub`, `detent`, and `Motion.resolved(_:reduceMotion:)` so every new animation has a Reduce Motion twin. |
| Orb shader | `GlassOrb.metal`, a stitchable `colorEffect` function. It draws the glow, drop shadow, glass body, caustics, gloss, rim light and up to three ripples. The seal ring stays in SwiftUI (`OrbSealRing`, extracted from `OrbView`). Colors come from one shared `OrbColors` table so the shader and `OrbView` cannot drift. |
| Orb host | `LivingOrb` has `OrbView`'s signature. It chooses the shader orb or the classic one. Home (unlocked, locked, emergency) and the lock moment use it. Nothing else changes. |
| Lab | An **Effects** page: flag toggle, motion readouts, the shader orb beside the classic one with tone and ring sliders, tap for a ripple, live tilt values, one button per haptic pattern. |

## Not in Phase 9

- Insights, Modes, Places, onboarding, the timer dial, widgets, Live Activity, shield changes (later phases).
- Wiring the new haptic patterns anywhere except the lock moment.
- A Settings switch for the owner. The flag lives in the Lab until the look is chosen.
- Any change to lock, schedule, timer, pass or history logic.

## Known limits

- The shader cannot be checked for feel without an iPhone. The simulator renders it, but tilt, battery and haptics are device-only.
- `ImageRenderer` may not draw Metal shaders in unit tests. If it does not, the render test is dropped and the Lab screenshots stand in.
- Several orbs on screen at once (the lock moment has two layers) each run a timeline. Both share one motion sensor.
- Building the shader needs Xcode's Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`, about 840 MB). It was installed on 2026-11-24 with the owner's approval; a Mac without it fails every build with "missing Metal Toolchain". `GlassOrbShader.isAvailable` still guards the flag, so a build without the shader falls back to the classic orb.

## Unverified until the iPhone run

- How the glass looks and moves compared with the classic orb.
- Tilt feel, rest-pose drift, and whether 30 fps is smooth.
- The lock haptic pattern and the other four.
- Battery and heat after 30 minutes on Home with the flag on.
