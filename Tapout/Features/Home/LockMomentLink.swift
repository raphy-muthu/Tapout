import SwiftUI

/// Links the lock-moment overlay to Home so the orb, timer and state word glide from
/// the overlay into place while it fades, instead of double-exposing. Nil under Reduce Motion.
struct LockMomentLink {
    let namespace: Namespace.ID
    let overlayShowing: Bool
}

enum LockMomentPart: Hashable {
    case orb, timer, stateWord
}

extension EnvironmentValues {
    @Entry var lockMomentLink: LockMomentLink? = nil
}

private struct LockMomentMatch: ViewModifier {
    let part: LockMomentPart
    let inOverlay: Bool

    @Environment(\.lockMomentLink) private var link

    func body(content: Content) -> some View {
        if let link {
            content.matchedGeometryEffect(id: part, in: link.namespace, properties: .position,
                                          isSource: inOverlay == link.overlayShowing)
        } else {
            content
        }
    }
}

extension View {
    /// Marks a view as one end of the lock-moment glide.
    func lockMomentMatch(_ part: LockMomentPart, inOverlay: Bool = false) -> some View {
        modifier(LockMomentMatch(part: part, inOverlay: inOverlay))
    }
}
