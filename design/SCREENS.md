# Tapout — screen index

Every screen from the "Tapout App Screens" canvas, mapped to its source file in `screens/`.

## How to read the source files

- Each `.dc.html` file is one screen written as HTML with inline styles. **Read them as specs, not code to port.** Take layout, sizes (px = pt), copy, colours and states from them and rebuild in SwiftUI.
- Most files cover several artboards through a prop. Example: `Home.dc.html` has `state` = `unlocked | locked | emergency` and `theme` = `dark | light`. The `<sc-if value="{{locked}}">` blocks show what appears in each state.
- `{{t.bg}}`, `{{t.ink}}` etc. are design-system colour tokens. The palette in each file's `<script>` block maps them to hex values that match `design-system/tokens.json`. In SwiftUI, use the asset-catalog colour of the same token name, never the raw hex.
- `<dc-import name="Orb" …>` = use the shared `OrbView`. `<dc-import name="TabBar" …>` = use the shared tab bar.
- Text in square brackets, like `[3h 12m]`, is a placeholder for real data.
- Fonts in the files fall back to Inter/Nunito for the browser. In the app, use SF Pro and SF Pro Rounded as `design-system/README.md` says.
- Ignore `support.js`, `<helmet>`, `<x-dc>` and `data-props`. They belong to the design tool.
- `canvas.json` lists all 60 artboards with titles, in case you need the full picture.

## Shared components (build these first)

| Component | File | Props |
| --- | --- | --- |
| Glass orb (the hero) | `Orb.dc.html` | `tone` ember/slate, `size`, `ring` 0–1 (how much of the seal ring is drawn), `ringTone`, `theme` |
| Tab bar | `TabBar.dc.html` | `active` home/modes/places/insights, `theme` |

**The orb** is layered radial gradients (glow, glass body, specular gloss) plus an SVG ring with a drop-shadow glow. In SwiftUI: a `ZStack` of `Circle()`s with `RadialGradient` fills, a `.blur` glow and a trimmed `Circle().trim(from:0,to:ring)` stroke. Copy the exact colour stops and proportions from the file's `renderVals()`: sphere inset 13% of size, ring stroke 1.6% of size, glow 1.44× size. A Metal or SceneKit version can come later; match this look first.

## Screens

| # | Screen | File | Variants (prop values) | Notes |
| --- | --- | --- | --- | --- |
| 1 | Onboarding: welcome, Screen Time, pick apps, pair tag + interests | `Main.dc.html` | `step` 1–4 × `theme` | Interest chips are multi-select. Step 3 app tiles stand in for `FamilyActivityPicker`. |
| 2 | Home | `Home.dc.html` | `state` unlocked / locked / emergency × `theme` | Locked timer counts **up**. Emergency counts **down** to relock, and the orb ring shows the time left. |
| 3 | Lock moment storyboard | `LockFrame.dc.html` | `frame` 1–4 × `theme` | Timing: 0 ms tag read + first rigid tap; 90 ms second tap and ring sweep (spring 0.6 s, damping 0.72); ~450 ms seal + one shockwave ripple; 600 ms settled, timer at 0:00. Reduce Motion: frame 1 → 4 as a 250 ms crossfade, haptics unchanged. |
| 4 | Unknown tag rejected | `Rejected.dc.html` | `theme` | Copy: "That's not one of your tags." Warning haptic. |
| 5 | Modes list + edit mode | `Modes.dc.html` | `view` list / edit × `theme` | Day and place chips toggle. |
| 6 | Places list + pairing sheet | `Places.dc.html` | `view` list / pair × `theme` | Each paired NFC tag is a named place ("Kitchen"). |
| 7 | Insights week + milestone | `Insights.dc.html` | `view` week / milestone × `theme` | Hero comparison, e.g. "As long as an entire NFL game". Comparisons come from the interests picked in onboarding. |
| 8 | Weekly recap story (1080 × 1920) | `Recap.dc.html` | `theme` | Rendered to an image for Instagram Stories sharing. |
| 9 | Emergency pass | `EmergencyPass.dc.html` | `theme` | Hold 10 s to confirm, releasing resets it. 5 passes total, ever. They never refill. |
| 10 | Settings + read-only while locked | `Settings.dc.html` | `locked` true/false × `theme` | Locked: banner and lock glyphs, controls disabled. |
| 11 | Block screen (dark only) | `Block.dc.html` | — | ShieldConfiguration: only colours, icon, title, subtitle. |
| 12 | Live Activity + Dynamic Island | `LiveActivity.dc.html` | `theme` | Compact, minimal, expanded, Lock Screen. ActivityKit + WidgetKit. |
| 13 | Widgets small + medium | `Widgets.dc.html` | `theme` | WidgetKit. |
| 14 | App icon 1024 | `AppIcon.dc.html` | — | Full square, iOS applies the mask. Export as PNG. |
| 15 | Buddy concepts (pick one later) | `Buddy.dc.html` | `concept` pebble / lantern / stack / peek × `theme` | Exploration only. Don't build until one is chosen. |

## Where the screens and the design-system README disagree

The screens came later and are the newer decision. **When they conflict, follow the screens**:

- **Tabs:** the README suggests Lock / Modes / Buddy. The screens use **Home / Modes / Places / Insights**, with Settings opened from the gear on Home.
- **Naming:** the README calls the tag "Buddy". The screens call paired tags **places** ("Kitchen", "Desk") and keep "Buddy" for the optional character concept.
- **Shield copy:** the README says "Locked / Tap Buddy to open / Close". The screen says **"Sealed / Tap a tag to open this app."** with no button. iOS may still require a button; check ManagedSettingsUI.
- **Emergency exit:** the README puts it in settings. The locked Home screen shows a quiet "Emergency pass · [3] left" link. The owner may remove this link; ask before shipping it.
- **Mascots:** the README says no mascots. Buddy concepts are a deliberate, still-undecided exception.
