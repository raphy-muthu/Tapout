import SwiftUI

extension View {
    /// A surface-1 card: continuous corners, no border, the light-theme soft shadow.
    func card(radius: CGFloat = Radius.card, padding: CGFloat = Space.lg) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .cardShadow()
    }
}
