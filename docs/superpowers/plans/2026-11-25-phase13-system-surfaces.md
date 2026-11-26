# Phase 13 plan

Spec: `../specs/2026-11-25-phase13-system-surfaces-design.md`. No commits (the owner commits).
Pure parts test-first; after the last code change, full suite on iOS 26.5 and Debug and Release device builds.

1. **Switch mirror + tests** (`TapoutTests/Phase13Tests.swift`): `Shared/LivingGlassMirror.swift`; app writes it
   (`RootView`); shield entitlement, sources and privacy manifest.
2. **Poster model**: `Surfaces/FlatPoster.swift` (words and tone per state, stacked totals).
3. **Faces**: `Surfaces/FlatFaces.swift`, widget configurations, `SnapshotEntry.flat`.
4. **Live Activity**: `ContentState.flat`, `Surfaces/FlatActivityViews.swift`, widget configuration.
5. **Shield**: glass art export, asset, `ShieldConfigurationExtension`, Lab mock and gallery.
6. **Verify**: tests, builds, built entitlements and manifests, gallery and real widgets / Live Activity /
   shield on the simulator where it can show them.
7. **Docs**: checklist section 18 and the setup item about the shield's App Group, `design/SCREENS.md`, plan
   page, ledger, memory.
