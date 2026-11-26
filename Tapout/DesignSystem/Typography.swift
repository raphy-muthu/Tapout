import SwiftUI

extension Font {
    // Numbers of 20pt and up: Fraunces. It has no tabular digits, so anything that ticks uses FixedDigitText.
    // Computed so each read picks the cut for the current Bold Text setting.
    @MainActor static var numberHero: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 96) }
    @MainActor static var numberDisplay: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 48) }
    // A still number as large as numberDisplay that follows the text size: the timer sheet's length.
    @MainActor static var numberReadout: Font { Font.custom(FrauncesFace.display.resolved().rawValue, size: 48, relativeTo: .largeTitle) }
    @MainActor static var numberMedium: Font { Font.custom(FrauncesFace.number.resolved().rawValue, size: 28, relativeTo: .title) }
    // The classic widgets' numbers: fixed, because a widget's frame can't grow with the text.
    @MainActor static var widgetValue: Font { Font.custom(FrauncesFace.number.resolved().rawValue, fixedSize: 28) }
    @MainActor static var widgetTotal: Font { .numberDisplay }
    // Scales with the text size, like the words beside it in a stat tile.
    @MainActor static var numberTile: Font { Font.custom(FrauncesFace.number.resolved().rawValue, size: 20, relativeTo: .title3) }
    // The flat widgets' still totals: fixed, because a widget's frame can't grow with the text.
    @MainActor static var numberPoster: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 46) }
    // For the 1080 × 1920 recap image only, fixed so Dynamic Type can't change it.
    @MainActor static var recapWordmark: Font { Font.custom(FrauncesFace.title.resolved().rawValue, fixedSize: 20) }
    @MainActor static var recapTotal: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 67) }
    // The milestone cover's hero title: a step above tLargeTitle, still scaling with Dynamic Type.
    @MainActor static var milestoneTitle: Font { Font.custom(FrauncesFace.title.resolved().rawValue, size: 44, relativeTo: .largeTitle) }
    // Small numbers: SF Pro.
    static let numberSmall = Font.system(.body, weight: .medium).monospacedDigit() // 17pt at the default size
    // Titles: Fraunces, scaling with Dynamic Type.
    @MainActor static var tLargeTitle: Font { Font.custom(FrauncesFace.title.resolved().rawValue, size: 34, relativeTo: .largeTitle) }
    @MainActor static var tTitle1: Font { Font.custom(FrauncesFace.title.resolved().rawValue, size: 28, relativeTo: .title) } // card heroes in the screen specs
    @MainActor static var tTitle: Font { Font.custom(FrauncesFace.title.resolved().rawValue, size: 22, relativeTo: .title2) }
    // Text: SF Pro, Dynamic Type styles
    static let tHeadline = Font.headline
    static let tBody = Font.body
    static let tSubhead = Font.subheadline
    static let tFootnote = Font.footnote
    static let tCaption = Font.caption.weight(.medium)
}
