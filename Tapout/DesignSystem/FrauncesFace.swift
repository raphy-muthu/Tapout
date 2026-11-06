import UIKit

/// The six Fraunces cuts Tapout ships, made by scripts/gen-fonts.py. Raw values are PostScript names.
enum FrauncesFace: String, CaseIterable, Sendable {
    /// Optical size 144, light: timers and big stats.
    case display = "Fraunces-TapoutDisplay"
    /// Optical size 36, regular: numbers of 20–28pt in cards.
    case number = "Fraunces-TapoutNumber"
    /// Optical size 36, semibold: titles.
    case title = "Fraunces-TapoutTitle"
    /// Display for Bold Text.
    case displayBold = "Fraunces-TapoutDisplayBold"
    /// Number for Bold Text.
    case numberBold = "Fraunces-TapoutNumberBold"
    /// Title for Bold Text.
    case titleBold = "Fraunces-TapoutTitleBold"

    /// Each cut is a single static face, so `.bold()`, `.weight()` and `legibilityWeight` do nothing to it.
    /// To honour iOS's Bold Text setting, pick the heavier cut by name. A bold cut resolves to itself.
    @MainActor func resolved(boldText: Bool = UIAccessibility.isBoldTextEnabled) -> FrauncesFace {
        guard boldText else { return self }
        switch self {
        case .display, .displayBold: return .displayBold
        case .number, .numberBold: return .numberBold
        case .title, .titleBold: return .titleBold
        }
    }
}
