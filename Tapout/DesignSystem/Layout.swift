import SwiftUI

/// 4-point spacing scale.
enum Space {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let xxxxl: CGFloat = 96
}

/// Corner radii; always used with `style: .continuous`.
enum Radius {
    static let sm: CGFloat = 12
    static let inner: CGFloat = 16
    static let card: CGFloat = 24
    static let sheet: CGFloat = 32
}

/// The one soft shadow a card may carry in light theme (black 6%, y 2, blur 12). Dark has none.
private struct CardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.shadow(color: colorScheme == .light ? .black.opacity(0.06) : .clear, radius: 6, y: 2)
    }
}

extension View {
    func cardShadow() -> some View { modifier(CardShadow()) }
}
