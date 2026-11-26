import SwiftUI

extension View {
    /// A surface-1 card: continuous corners, no border, the light-theme soft shadow. Frosted glass where the
    /// Living glass switch is on (`\.glassControls`).
    func card(radius: CGFloat = Radius.card, padding: CGFloat = Space.lg) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSurface(.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
