# Phase 12 plan

Spec: `../specs/2026-11-25-phase12-modes-places-onboarding-design.md`. No commits (the owner commits).
Pure parts test-first; after the last code change, full suite on iOS 26.5 and Debug and Release device builds.

1. **Pure parts + tests** (`TapoutTests/Phase12Tests.swift`): `Model/ModeDrawer.swift` (order, toggle),
   `Effects/CardTilt.swift` (angles, release), `Model/PairingOrb.swift`, `Model/OnboardingOrb.swift`.
2. **Shared glass**: `Effects/GlassPage.swift` (`GlassPageBackground`, `StatusBarFade`), `card()` and
   `CircleIconButton` through `controlSurface`, `LivingOrb(rippleEvery:)`, RootView glow and environments.
3. **Modes**: `Features/Modes/ModeDrawerCard.swift`, glass branch in `ModesView`, editor.
4. **Places**: glass variants in `PlaceCards`, `PlacesView`, `PlaceSheet`, `PairPlaceSheet`.
5. **Onboarding**: shared orb in `OnboardingView`, steps drop their art, Lab preview
   (`Features/Lab/OnboardingPreview.swift`).
6. **Verify**: tests, builds, simulator (switch on and off, dark and light, large text, locked, scrolling,
   drawers, pairing, all six steps), before/after screenshots.
7. **Docs**: checklist section 17, `design/SCREENS.md`, plan page, ledger, memory.
