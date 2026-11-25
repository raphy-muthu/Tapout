# UI/UX upgrade plan: intricate, interactive, technically advanced

Owner's request (2026-11-24): the interface can be more intricate, more interactive, more technically advanced and more visually appealing. Plan it, with sample designs.

Sample designs (interactive, three directions, six screens each): https://claude.ai/artifact/T9EeCaRPf6qp1W61zJUVfg

## Owner's answers

| Question | Answer |
| --- | --- |
| Direction | **A sample of each**: Living glass, Bold poster, Field instrument. Pick or blend after trying them. |
| Technology ceiling | **Metal shaders and motion sensors** (SwiftUI shaders, CoreMotion, Core Haptics, keyframes). Floor stays iOS 17. |
| Scope | **All four areas**: Home and lock moment, Insights, Modes / Places / onboarding, system surfaces. |
| Samples | **Interactive page plus this plan.** Nothing in the app changes yet. |

## Where the app is today

- The orb is layered static gradients (`Tapout/Components/OrbView.swift`). It does not respond to touch or motion.
- Motion is two springs plus a few crossfades (`Tapout/DesignSystem/Motion.swift`). The lock moment (`LockMomentView`) is the only choreographed sequence.
- Haptics are single impacts (`Haptics.swift`): two rigid taps for lock, one soft tap for unlock, selection, mismatch.
- Insights, Modes, Places, onboarding and Settings are static cards and lists. No Charts framework, no Canvas, no TimelineView, no shaders, no CoreMotion.
- Deployment target iOS 17.0, Swift 6.

The visual identity is good (ember and slate, Fraunces numerals, the glass orb). The gap is that almost nothing responds to the person holding the phone.

## The three directions

All three keep the token system, the orb as the hero, the two haptic signatures and the "very few words" rule. They differ in what the interface is made of.

| | **A. Living glass** | **B. Bold poster** | **C. Field instrument** |
| --- | --- | --- | --- |
| Idea | The orb is a physical object: it tilts, refracts and ripples. | The number is the screen. Color floods the whole display. | The interface is a measuring device: dials, ticks, readouts. |
| Home | Shader orb, background warms slate to ember, ring empties as time runs. | 218 pt countdown, ember flood from the tap point, orb as a rising moon. | 60-tick dial you drag to set the timer, second hand, readout strip. |
| Lock moment | Two haptics, ripple, ring sweep, ember bloom spreading from the orb. | Ember rises from the bottom, "SEALED." sets letter by letter. | Radar sweep, tag read printed line by line, ring seals. |
| Insights | Glass columns you scrub with a thumb. | 200 pt headline, seven full-width bars, tap to switch day. | Five-week heatmap, seven-day line, stat strip. |
| Modes | Cards tilt toward the finger and open like drawers. | Color blocks that grow and compress. | Every schedule on one 24 hour bar, day chips toggle in place. |
| Pair a tag | Ripples until a tag answers, orb warms, ring closes. | Rings pulse, ember flood, black seal with a check. | Radar and a log of what was read. |
| Strengths | Most premium, closest to today's look, least new design to learn. | Most readable at a glance, strongest on small widgets, least battery. | Most "technically advanced" feel, shows history well. |
| Costs | Shader work, highest battery use, needs tuning on a real device. | Two extra accent tones, loudest, farthest from the current look. | Needs a monospaced face (SF Mono, system) that the design system does not list, densest. |
| Fit with the rules | Strong. | Strains "calm". Needs an owner call on tone. | Strains "very few words". Needs an owner call on density. |

**Recommendation:** build the shared foundation and the Living glass orb first (they serve every direction), then decide. A blend is likely best: A for Home, lock moment, Modes and Places; C's heatmap and scrub for Insights; B's flat color for widgets and the Live Activity, where shaders cannot run. The decision gate is after Phase 2, once the orb is on the owner's iPhone.

## Shared foundation (all directions)

1. **Shader pipeline.** One Metal file in `Tapout/Shaders/` with `[[stitchable]]` functions used through `colorEffect` and `layerEffect` (iOS 17). First function: the glass orb (body, rim light, caustics, tone mix). Later: ripple distortion, the bloom, a grain layer. The current `OrbView` stays as the fallback path, selected at runtime.
2. **Motion input.** A `MotionSource` wrapping `CMMotionManager` at 30 Hz with a low-pass filter and a calibrated rest pose, exposed as an `@Observable` tilt vector. Started only by views that need it, stopped when they leave the screen or the app backgrounds. Simulator and Reduce Motion: a slow synthetic sway or a fixed light.
3. **Haptic language.** A `HapticEngine` over Core Haptics with named patterns: `lock` (rigid, rigid at 90 ms, now with a soft swell under the bloom), `unlock` (one soft tap, then a fading echo), `detent` (dial steps), `scrub` (light tick per chart column), `paired` (the lock pattern at lower intensity). Falls back to the current `Haptics` on devices without Core Haptics. The spec rule stays: lock is two rigid taps 90 ms apart.
4. **Motion tokens.** Extend `Motion.swift` from two springs to a small vocabulary (settle, bloom, ripple, scrub, detent) with Reduce Motion equivalents for each. Every new animation must have a crossfade twin.
5. **Motion budget.** 30 fps cap for the orb, `TimelineView(.animation(minimumInterval:))`. Pause on Low Power Mode, `ProcessInfo.thermalState >= .serious`, and when the app is inactive. Target: under 5% extra battery per hour of an unlocked Home on screen, measured on device.
6. **Lab screen.** The existing Lab tab gets an "Effects" page so each effect can be tried, toggled and measured on the iPhone before it reaches a real screen.

## Area plans

### Home and lock moment
- Orb states: ready (slate, breathing), reading (ripples), sealed (ember, ring), timer (ring shows time left), emergency pass (ring counts down), unlocked-after (soft settle).
- Tap on the orb: ripple. Hold near a tag: ready rings.
- Background warmth: glow color follows orb tone over about 1.2 s.
- Timer sheet: replace the wheel with the dial from Direction C, or keep the wheel in A and B. Owner's call after trying it.
- Time's up and milestone covers reuse the orb states.

### Insights
- Swift Charts with `chartXSelection` for scrub (iOS 17), selection haptic per column.
- Streak and milestone get a quiet glass card (A) or a heatmap (C).
- Recap image render uses the same column material so the shared image matches the app.

### Modes, Places and onboarding
- Mode cards: pointer-like tilt from touch position (`rotation3DEffect`), open-in-place detail, matched geometry into the editor.
- Pairing: orb state machine driven by the Core NFC session callbacks.
- Onboarding (six steps): shared orb persists across steps and changes state, so progress feels like one object changing.

### System surfaces
These cannot run shaders or free animation. They take the look through:
- Pre-rendered orb art per state, generated by the same shader into the asset catalog at build time (extends `ShieldOrbArt`).
- `Text(timerInterval:)` and `contentTransition(.numericText)` for countdowns.
- Direction B's flat color fields are the most robust here, so widgets and the Live Activity lean on them in any blend.
- The Sealed shield stays within ManagedSettingsUI limits (color, icon, title, subtitle).

## Phases

Each phase ships alone, ends with the full suite green and Debug and Release device builds passing, and waits for an iPhone check before the next.

| # | Phase | Output | Verified by |
| --- | --- | --- | --- |
| 1 | Foundation | Shader pipeline, `MotionSource`, `HapticEngine`, motion tokens, Lab "Effects" page, battery and thermal gates | Unit tests for pure parts (low-pass filter, pattern builders, motion-budget decisions); Lab on device |
| 2 | The orb | Shader orb behind a feature flag, tilt, ripple, tone transition, fallback to `OrbView` | Snapshot tests of fallback; device check of look and battery; **decision gate** |
| 3 | Home and lock moment | New Home states, lock moment sequence, timer sheet, Time's up | Existing lock tests unchanged; new tests for state mapping; device run |
| 4 | Insights | Scrubbable chart, streak, milestone, recap match | Chart data tests; Dynamic Type and light/dark screenshots |
| 5 | Modes, Places, onboarding | Card physics, pairing moment, onboarding orb | Accessibility sizes, Reduce Motion pass |
| 6 | System surfaces | Pre-rendered orb art, Live Activity, widgets, shield | Surface galleries in Lab; device check |
| 7 | Polish and device pass | Battery and thermal measurement, Reduce Motion and VoiceOver review, App Store screenshots | iPhone checklist section for this work |

Effort is large: phases 1 and 2 are the riskiest and most valuable. Phases 3 to 6 are independent once the foundation exists and can be reordered.

## Risks and rules

- **Battery and heat.** Continuous shading is the main cost. Mitigations above. If the measured cost is too high, the orb animates only on interaction and for a few seconds after, and rests as a still frame.
- **Accessibility.** Reduce Motion replaces every effect with a crossfade. Haptics stay. Every interactive element keeps a 44 pt target and a VoiceOver label. Dynamic Type must work on every redesigned screen (the app already tests accessibility sizes).
- **Correctness first.** The lock engine, schedules, timer lock and monitor are untouched. This work only changes presentation. A regression in lock behavior would be worse than any visual gain, so no phase edits `Shared/` logic.
- **Design-system rules.** Keep token names and no raw hex outside the shader, no borders on cards, Fraunces for large numerals (use `FixedDigitText` for anything that ticks). Direction C needs a monospaced face: use SF Mono through `.monospaced()`, not a bundled font. Direction B needs two extra accent tones, to be added as tokens.
- **Unproven on device.** Shader look, tilt feel, Core Haptics patterns and battery cost are all unverified until the iPhone run. The samples are web approximations of motion and layout, not of the shader.
- **Swift 6.** `MotionSource` and `HapticEngine` are main-actor types, matching `Haptics`.
- **Copy.** Words stay few. The sample screens use only copy the app already has, plus the one-line captions in the pairing and lock screens, which are examples to review.

## Decisions needed from the owner

1. After trying the samples: one direction, or a blend (the recommendation above)?
2. Timer sheet: keep the wheel or move to the dial?
3. Is Direction B's louder tone acceptable for any screen, or should it be limited to widgets and the Live Activity?
4. Should Insights show five weeks of history (Direction C's heatmap), or stay at one week?

## Out of scope

- Any change to lock, schedule, timer, pass or history logic.
- A 3D or particle layer (SceneKit, RealityKit). Offered, not chosen.
- New features. This plan changes how existing screens look and respond.
- iPad, Apple Watch and Mac layouts.
