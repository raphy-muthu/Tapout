# Tapout

**Calm, tactile, a little bit magic.** Tapout blocks distracting apps until you tap a paired NFC tag — Buddy, a small 3D‑printed "screen time buddy" that sits on your desk or by the door. The app is the remote control for a physical object, so it should feel like one: dark‑first, quiet, heavy in the hand, almost wordless.

This README is the source of truth. It is written so a developer (or Claude Code) can build the SwiftUI app from it without opening any other file. Token values live in `tokens.json`; every token there carries a usage note.

---

## 1. Principles

1. **One object per screen.** The lock screen holds the timer and nothing competing with it. If a screen needs a paragraph, the flow is wrong.
2. **State is colour, not words.** Ember (amber) means locked. Slate (cool grey‑blue) means unlocked. The whole UI shifts accent with state; the word "Locked" is a label, not an alert.
3. **Tactile, not flat.** Depth comes from tone steps between `bg`, `surface-1` and `surface-2`, from continuous corners and from springs and haptics — never from borders, outlines or gradient washes.
4. **Strict and kind.** Tapout is as strict as a hardware lock: no "skip" button sits next to the timer. It never guilts. No streak shaming, no "you failed", no sad faces, no emoji.
5. **Earn the magic.** The two moments that matter — lock and unlock — get the spring, the glow and the haptics. Everything else is quick and quiet so those two stay special.

## 2. Voice and copy

Very few words. Prefer a number or an icon to a sentence; prefer two words to five.

| Do | Don't |
| --- | --- |
| Locked | Focus mode is now active! |
| Tap Buddy to unlock | You must scan your NFC tag to regain access |
| 24:05 | 24 minutes and 5 seconds remaining |
| Back at 17:00 | Don't give up now! |
| That's not your Buddy | Error: invalid tag |
| 3h 12m focused | You wasted only 2 hours today |

- Sentence case everywhere except `caption` section labels (uppercase).
- No exclamation marks. No emoji. No guilt, shame, streak‑loss warnings or moralising.
- Buddy is a proper noun ("Tap Buddy", "Buddy's away"). The product name is Tapout, one word, capital T.
- Errors say what happened and the next step, in one line, in `danger`.

## 3. Colour

Dark is the primary theme; light is complete, not an afterthought. Both are in `tokens.json` (`dark` first).

### Neutrals

| Token | Dark | Light | Use |
| --- | --- | --- | --- |
| `bg` | #0B0D10 | #F6F4EF | Screen background |
| `surface-1` | #15181D | #FFFDF9 | Cards, groups, tab bar |
| `surface-2` | #1E222A | #ECE8E0 | Wells, tracks, sheets, pressed |
| `ink` | #F3F1EC | #15171B | Primary text, timer |
| `ink-secondary` | #A4ABB6 | #565C66 | Subtitles, counts |
| `ink-tertiary` | #8A919C | #5F656F | Captions, labels (floor) |

### The accent has two states

The accent is chosen by **lock state**, then by theme. Each state has four roles, because one hex cannot be a fill, a text colour and a stroke in both themes and still pass contrast:

| Role | Locked (ember) | Unlocked (slate) | Use |
| --- | --- | --- | --- |
| Fill | `ember` #FF9F43 | `slate` #8A94A6 | Primary button, ring fill, Buddy light |
| On fill | `on-ember` | `on-slate` | Text/icon on the fill |
| Text | `ember-ink` (dark #FF9F43 / light #96490A) | `slate-ink` (dark #8A94A6 / light #535C6C) | The state word, small glyphs |
| Line | `ember-line` (dark #FF9F43 / light #C2650F) | `slate-line` (dark #8A94A6 / light #6B7487) | Progress arc, focus ring, indicators |
| Glow | `ember-glow` | `slate-glow` | Halo behind ring / Buddy (decorative) |

Rules:

- Never use the fill hex (`ember`, `slate`) for text on a light background — it fails contrast. Use the `-ink` token.
- Never show both accents at full strength on one screen. The current state owns the accent; the other state appears only as a preview (e.g. the unlocked colour on a "what happens when you unlock" sheet).
- Glows are radial, blurred, centred behind one object, at most ~1.5× its size. No full‑screen gradients.
- `danger` is the only other hue, used rarely and never to scold.
- `track` is the unfilled ring path. Progress is always also shown as numerals, so the track can be faint.

### Contrast (WCAG 2.x, measured)

Every text token passes 4.5:1 on `bg`, `surface-1` and `surface-2` in both themes. Lowest pair per token:

| Token | Dark (worst surface) | Light (worst surface) |
| --- | --- | --- |
| `ink` | 14.1:1 | 14.7:1 |
| `ink-secondary` | 6.9:1 | 5.5:1 |
| `ink-tertiary` | 5.0:1 | 4.8:1 |
| `ember-ink` | 7.8:1 | 5.3:1 |
| `slate-ink` | 5.2:1 | 5.5:1 |
| `danger` | 6.3:1 | 5.4:1 |
| `on-ember` on `ember` | 9.5:1 | 8.8:1 |
| `on-slate` on `slate` | 6.4:1 | 5.9:1 |

Non‑text strokes (`ember-line`, `slate-line`) are at least 3.3:1 against every surface. The fills `ember` and `slate` are under 3:1 against the light background, so a light‑theme filled shape must never be the only cue: pair it with a label or an `-ink`/`-line` element.

## 4. Typography

Two families, both system:

- **SF Pro Rounded** (`rounded`) — every number and timer. Large, light weight, always `.monospacedDigit()` when the value changes so digits don't jitter.
- **SF Pro** (`text`) — every word.

```swift
extension Font {
    // Numerals — SF Pro Rounded
    static let timerHero     = Font.system(size: 112, weight: .ultraLight, design: .rounded).monospacedDigit()
    static let timerLarge    = Font.system(size: 72,  weight: .light,      design: .rounded).monospacedDigit()
    static let numberDisplay = Font.system(size: 48,  weight: .light,      design: .rounded)
    static let numberMedium  = Font.system(size: 28,  weight: .regular,    design: .rounded)
    static let numberSmall   = Font.system(size: 17,  weight: .medium,     design: .rounded).monospacedDigit()
    // Text — SF Pro (Dynamic Type styles)
    static let tLargeTitle = Font.largeTitle.weight(.semibold)   // 34/41
    static let tTitle      = Font.title2.weight(.semibold)       // 22/28
    static let tHeadline   = Font.headline                       // 17/22 semibold
    static let tBody       = Font.body                           // 17/22
    static let tSubhead    = Font.subheadline                    // 15/20
    static let tFootnote   = Font.footnote                       // 13/18
    static let tCaption    = Font.caption.weight(.medium)        // 12/16, uppercase
}
```

| Style | Size / line | Weight | Use |
| --- | --- | --- | --- |
| `timer-hero` | 112 / 112 | 200 | The lock‑screen countdown. One per screen. Max 5 characters: `mm:ss` under an hour, `h:mm` above |
| `timer-large` | 72 / 76 | 300 | Duration picker, timers in sheets |
| `number-display` | 48 / 52 | 300 | Headline stats |
| `number-medium` | 28 / 32 | 400 | Counts in cards |
| `number-small` | 17 / 22 | 500 | Numbers inline with body text |
| `large-title` | 34 / 41 | 600 | Screen title, one or two words |
| `title` | 22 / 28 | 600 | Card and sheet titles |
| `headline` | 17 / 22 | 600 | State words, buttons, row titles |
| `body` | 17 / 22 | 400 | Rare sentences |
| `subhead` | 15 / 20 | 400 | Subtitles (ink-secondary) |
| `footnote` | 13 / 18 | 400 | Footers (ink-tertiary) |
| `caption` | 12 / 16 | 500 | Uppercase section labels (ink-tertiary) |

**Dynamic Type.** Text styles use the system text styles so they scale. Numeral styles use fixed sizes for layout but must scale with `@ScaledMetric(relativeTo: .largeTitle)` capped at 1.3× for `timer-hero` (it already fills the width). At accessibility sizes, `timer-hero` drops to `h:mm` and the ring moves above the numerals.

## 5. Spacing and shape

Spacing is a 4‑point base with generous defaults:

| Token | pt | Typical use |
| --- | --- | --- |
| `space-2xs` | 4 | Icon ↔ label in a chip |
| `space-xs` | 8 | Title ↔ subtitle |
| `space-sm` | 12 | Between cards in a group |
| `space-md` | 16 | Compact control padding, stacked buttons |
| `space-lg` | 24 | **Card padding and screen side margin** |
| `space-xl` | 32 | Between groups |
| `space-2xl` | 48 | Timer ↔ primary action |
| `space-3xl` | 64 | Above the hero timer |
| `space-4xl` | 96 | Full‑screen lock/unlock moments |

Radii, always `style: .continuous`:

| Token | pt | Use |
| --- | --- | --- |
| `radius-sm` | 12 | Chips, app tiles |
| `radius-inner` | 16 | Elements inset 8pt inside a card (concentric) |
| `radius-card` | 24 | Every card / group |
| `radius-sheet` | 32 | Sheet top corners, Buddy panel |
| `radius-pill` | 999 | Buttons, toggles, status pill (`Capsule`) |

**No borders.** Separation is the tone step from `bg` to `surface-1`. Inside a card, separate rows with `space-sm` gaps or a `surface-2` well — not hairlines. In light theme a card may carry one very soft shadow (`black 6%, y 2, blur 12`) to sit on `bg`; dark theme has none.

**Touch targets** are at least 44×44pt. The primary button is 56pt tall, full width minus `space-lg` margins.

## 6. Iconography

SF Symbols, **line (non‑fill) variants**, weight matched to adjacent text (`.regular` beside body, `.light` beside numerals), rendering mode `.monochrome` in `ink`, `ink-secondary` or the state's `-ink` token. Never multicolour, never emoji.

| Meaning | Symbol |
| --- | --- |
| Locked | `lock` |
| Unlocked | `lock.open` |
| Tap / NFC | `wave.3.right` |
| Timer / duration | `timer` |
| Blocked apps | `square.grid.2x2` |
| Schedule | `calendar` |
| Buddy (the tag) | `circle.dotted` |
| Settings | `gearshape` |
| Add | `plus` |

Fill variants are allowed only for the one icon inside a filled ember/slate button, where the line weight would disappear.

## 7. Motion

Two springs carry the brand; everything else stays out of the way. Read `@Environment(\.accessibilityReduceMotion)` everywhere something moves.

```swift
enum Motion {
    static let lock   = Animation.spring(response: 0.6, dampingFraction: 0.72) // spring-lock, ~600ms, small overshoot
    static let unlock = Animation.spring(response: 0.8, dampingFraction: 0.9)  // spring-unlock, ~800ms, no bounce
    static let ui     = Animation.spring(response: 0.4, dampingFraction: 0.85) // spring-ui
    static let press  = Animation.easeOut(duration: 0.15)                      // dur-press, scale 0.97
    static let reveal = Animation.easeInOut(duration: 0.4)                     // dur-reveal
    // Reduce Motion replacements: crossfade in place, no scale/travel
    static let lockReduced   = Animation.easeInOut(duration: 0.25)             // dur-crossfade-lock
    static let unlockReduced = Animation.easeInOut(duration: 0.35)             // dur-crossfade-unlock
    static let readyPulse    = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true) // dur-ready-pulse
}
```

**Lock (≈0.6s).** On a successful tag read: the ring's arc sweeps closed from the top and turns `ember-line`; numerals scale 0.94 → 1.0; `ember-glow` fades up behind the ring; accent across the screen swaps slate → ember. Haptic fires on the first frame.

**Unlock (≈0.8s, slower on purpose).** The arc fades to `track`, the glow cools to `slate-glow`, numerals settle to the elapsed summary. No bounce — unlocking is a release, not a reward.

**Reduce Motion.** Replace both with a crossfade of the whole state in place (0.25s lock, 0.35s unlock). No scale, no sweep, no pulse; the tag‑ready pulse becomes a static outline. Haptics still play.

## 8. Haptics

| Token | Pattern | Implementation |
| --- | --- | --- |
| `haptic-lock` | **Two firm taps**, 90ms apart | `.rigid`, intensity 1.0, ×2 |
| `haptic-unlock` | **One soft tap** | `.soft`, intensity 0.6, ×1 |
| `haptic-tag-mismatch` | Warning | `UINotificationFeedbackGenerator` `.warning` |
| `haptic-select` | Detent tick | `UISelectionFeedbackGenerator` |

```swift
enum Haptics {
    static func lock() {
        let g = UIImpactFeedbackGenerator(style: .rigid); g.prepare()
        g.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { g.impactOccurred(intensity: 1.0) }
    }
    static func unlock() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
    static func mismatch() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}
```

Call `prepare()` when the NFC session starts so the first tap lands on time. Haptics are the one feedback channel that survives Reduce Motion, so never skip them.

## 9. Components

Each has a live preview and guidelines in this system.

- **LockDial** — the hero: `timer-hero` numerals centred inside a 336pt ring (27pt side margins on a 390pt‑wide iPhone) (`track` + state `-line` arc, 6pt stroke, round caps), state word in `headline` + state `-ink` below, glow behind.
- **TapTarget** — the "hold near Buddy" moment: a 160pt circle in `surface-2`, `wave.3.right` icon, `slate-line` pulse outline while the NFC session is open.
- **ModeCard** — a saved blocking mode: `title`, `subhead` summary ("6 apps · weekdays"), `number-medium` duration, on `surface-1`, `radius-card`, `space-lg` padding.
- **Button** — primary pill (56pt, state fill + `on-` colour, `headline`), quiet button (text only, `ink-secondary`). Never more than one primary per screen.
- **Shield** — the screen iOS shows when a blocked app is opened (ManagedSettingsUI `ShieldConfiguration`): `bg` background, lock glyph in `ember`, title "Locked", subtitle "Tap Buddy to open", one button "Close". No secondary "ignore" action.
- **StatusPill** (spec only, no preview yet) — compact state chip for the home screen and widgets: `surface-2` capsule, 8pt dot in the state fill, `headline` label.

## 10. Building it in SwiftUI

**Colours.** Create one Asset Catalog colour set per colour token, named exactly as the token (`bg`, `surface-1`, `ember-ink`, …), with *Any Appearance* = light value and *Dark* = dark value. Fills `ember` and `slate` use the same hex in both. Then:

```swift
extension Color {
    static let bg = Color("bg"), surface1 = Color("surface-1"), surface2 = Color("surface-2")
    static let ink = Color("ink"), inkSecondary = Color("ink-secondary"), inkTertiary = Color("ink-tertiary")
    static let danger = Color("danger"), track = Color("track"), scrim = Color("scrim")
}

enum LockState { case locked, unlocked }

struct Accent {
    let fill, onFill, ink, line, glow: Color
    static func `for`(_ s: LockState) -> Accent {
        switch s {
        case .locked:   Accent(fill: Color("ember"), onFill: Color("on-ember"), ink: Color("ember-ink"), line: Color("ember-line"), glow: Color("ember-glow"))
        case .unlocked: Accent(fill: Color("slate"), onFill: Color("on-slate"), ink: Color("slate-ink"), line: Color("slate-line"), glow: Color("slate-glow"))
        }
    }
}
// Inject once at the root: .environment(\.accent, Accent.for(state)) and .tint(accent.line)
```

**Spacing & radius.**

```swift
enum Space { static let xxs: CGFloat = 4, xs = 8.0, sm = 12.0, md = 16.0, lg = 24.0, xl = 32.0, xxl = 48.0, xxxl = 64.0, xxxxl = 96.0 }
enum Radius { static let sm: CGFloat = 12, inner = 16.0, card = 24.0, sheet = 32.0 }

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
```

**Themes.** Dark‑first: default `preferredColorScheme` to `nil` (follow the system) but design and test dark first. Every screen must be checked in both.

**App structure (suggested).** Three tabs at most: *Lock* (LockDial + primary button), *Modes* (ModeCards), *Buddy* (pairing, tag status). Onboarding: four screens — what Tapout does, Screen Time permission, pair Buddy (TapTarget), choose apps.

**Platform notes (for the developer, verify against current Apple docs).** Blocking uses Apple's Screen Time APIs — FamilyControls (authorization and `FamilyActivityPicker`), ManagedSettings (`ManagedSettingsStore` shields) and ManagedSettingsUI (custom shield appearance); DeviceActivity for schedules. Tag reads use Core NFC. The Family Controls entitlement needs Apple's approval before App Store distribution. The Core NFC scan sheet is drawn by iOS, so Tapout's own lock/unlock animation and haptics play right after the sheet reports a successful read.

**Strictness.** No skip, snooze or "5 more minutes" control appears next to the timer or on the Shield. If an emergency exit exists, it lives in Buddy settings behind a deliberate, multi‑step action, styled as a quiet button — never as a primary action.

## 11. Don'ts

- No borders or hairline dividers on cards.
- No gradient washes, mesh backgrounds or neon glows beyond the token glows.
- No emoji, mascots drawn in the UI, confetti, or celebratory animation on unlock.
- No guilt, shame, streak‑loss or "are you sure you want to waste time?" copy.
- No text in `ember` or `slate` fill colours on light backgrounds.
- No more than one accent state visible at full strength.
