import SwiftUI

extension Font {
    // Numerals: SF Pro Rounded
    static let timerHero = Font.system(size: 112, weight: .ultraLight, design: .rounded).monospacedDigit()
    static let timerLarge = Font.system(size: 72, weight: .light, design: .rounded).monospacedDigit()
    static let numberDisplay = Font.system(size: 48, weight: .light, design: .rounded)
    static let numberMedium = Font.system(size: 28, weight: .regular, design: .rounded)
    static let numberSmall = Font.system(size: 17, weight: .medium, design: .rounded).monospacedDigit()
    // Text: SF Pro, Dynamic Type styles
    static let tLargeTitle = Font.largeTitle.weight(.semibold)
    static let tTitle = Font.title2.weight(.semibold)
    static let tHeadline = Font.headline
    static let tBody = Font.body
    static let tSubhead = Font.subheadline
    static let tFootnote = Font.footnote
    static let tCaption = Font.caption.weight(.medium)
}
