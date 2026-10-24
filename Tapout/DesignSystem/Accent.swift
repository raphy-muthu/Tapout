import SwiftUI

/// The state accent's five roles. One hex can't be a fill, a text colour and a stroke
/// in both themes and still pass contrast, so each role is its own token.
struct Accent {
    let fill, onFill, ink, line, glow: Color

    static func `for`(_ state: LockState) -> Accent {
        switch state {
        case .locked:
            Accent(fill: .ember, onFill: .onEmber, ink: .emberInk, line: .emberLine, glow: .emberGlow)
        case .unlocked:
            Accent(fill: .slate, onFill: .onSlate, ink: .slateInk, line: .slateLine, glow: .slateGlow)
        }
    }
}

extension EnvironmentValues {
    @Entry var accent: Accent = .for(.unlocked)
}
