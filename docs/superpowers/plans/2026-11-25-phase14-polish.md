# Phase 14 plan

Spec: `../specs/2026-11-25-phase14-polish-design.md`. No commits (the owner commits).
Test-first for the pure and renderable parts; after the last code change, full suite on iOS 26.5 and Debug and
Release device builds.

1. **Large text** (`TapoutTests/Phase14Tests.swift`): scaling tile numbers; padded pill buttons.
2. **Reduce Motion**: review and fix.
3. **Accessibility audit**: scratch copy + UI test; fix what the upgrade introduced.
4. **Power meter**: `Features/Lab/PowerRun.swift` (pure report), `PowerMeter.swift`, `PowerMeterView.swift`.
5. **Verify**: tests, builds, simulator at large text and with Reduce Motion.
6. **Docs**: checklist section 19, plan page, ledger, memory.
