import SwiftUI

/// One accessor per colour set in Colors.xcassets, which is generated from
/// design/design-system/tokens.json by scripts/gen-colors.py.
extension Color {
    static let bg = Color("bg")
    static let surface1 = Color("surface-1")
    static let surface2 = Color("surface-2")
    static let ink = Color("ink")
    static let inkSecondary = Color("ink-secondary")
    static let inkTertiary = Color("ink-tertiary")
    static let ember = Color("ember")
    static let emberInk = Color("ember-ink")
    static let emberLine = Color("ember-line")
    static let emberGlow = Color("ember-glow")
    static let onEmber = Color("on-ember")
    static let slate = Color("slate")
    static let slateInk = Color("slate-ink")
    static let slateLine = Color("slate-line")
    static let slateGlow = Color("slate-glow")
    static let onSlate = Color("on-slate")
    static let track = Color("track")
    static let danger = Color("danger")
    static let scrim = Color("scrim")
}
