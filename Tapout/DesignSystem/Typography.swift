import SwiftUI

extension Font {
    // Numbers of 20pt and up: Fraunces. It has no tabular digits, so anything that ticks uses FixedDigitText.
    // Computed so each read picks the cut for the current Bold Text setting.
    @MainActor static var numberHero: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 96) }
    @MainActor static var numberDisplay: Font { Font.custom(FrauncesFace.display.resolved().rawValue, fixedSize: 48) }
    @MainActor static var numberMedium: Font { Font.custom(FrauncesFace.number.resolved().rawValue, fixedSize: 28) }
    @MainActor static var numberTile: Font { Font.custom(FrauncesFace.number.resolved().rawValue, fixedSize: 20) }
    // Small numbers: SF Pro.
    static let numberSmall = Font.system(size: 17, weight: .medium).monospacedDigit()
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
