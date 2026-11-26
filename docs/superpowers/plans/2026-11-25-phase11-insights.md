# Phase 11 plan: Insights in living glass

Spec: `docs/superpowers/specs/2026-11-25-phase11-insights-design.md`. Baseline: 508 tests.

| # | Task | Files | Done when |
| --- | --- | --- | --- |
| 1 | Pure logic, test first | `Model/InsightsHeatmap.swift`, `Model/ChartScrub.swift`, `TapoutTests/InsightsGlassTests.swift` | Heatmap days and intensity, column hit testing, axis decision, selection rules pass |
| 2 | Columns and scrub gesture | `Features/Insights/GlassColumns.swift`, `ScrubGesture.swift` | Tap and sideways drag select; vertical drag scrolls |
| 3 | Heatmap | `Features/Insights/Heatmap.swift` | Five weeks, readout, VoiceOver |
| 4 | Screen, backdrop, recap | `InsightsView.swift`, `InsightsParts.swift`, `RecapView.swift`, `Effects/LivingBackdrop.swift`, `App/RootView.swift` | Switch on matches the spec; switch off unchanged |
| 5 | Demo month, verify, review, docs | `Model/DemoData.swift` (`-demoMonth`, Debug), checklist section 16, `design/SCREENS.md` | Full suite, Debug and Release device builds, simulator screenshots on and off, drag and scroll tried |

Rules: no logic changes in `Shared/`; token colors only; no commits.
