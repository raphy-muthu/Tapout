#if DEBUG
import SwiftUI

/// The Sealed screen's icon: the app's own ember orb with its glow and seal ring, on transparent.
/// Always dark. Exported to the shield's asset catalog by ShieldArtTests, because a shield extension
/// can't render SwiftUI itself.
struct ShieldOrbArt: View {
    static let side: CGFloat = 200

    var body: some View {
        // iOS draws the shield icon at its own fixed size, so the image has to be filled: at 200 pt the
        // seal ring (about 76 pt radius) spans about 76% of it. The orb's glow reaches 1.44x its 160 pt,
        // wider than the canvas, so a radial alpha mask fades the halo out before the edge instead of
        // leaving a hard clip. The mask stays fully opaque to 80% of the radius (past the ring).
        OrbView(tone: .ember, ring: 1, size: 160)
            .frame(width: Self.side, height: Self.side)
            .mask(RadialGradient(stops: [.init(color: .black, location: 0),
                                         .init(color: .black, location: 0.8),
                                         .init(color: .clear, location: 1)],
                                 center: .center, startRadius: 0, endRadius: Self.side / 2))
            .environment(\.colorScheme, .dark)
    }

    @MainActor static func render() -> UIImage? {
        let renderer = ImageRenderer(content: ShieldOrbArt())
        renderer.scale = 3
        renderer.isOpaque = false
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return renderer.uiImage
    }
}

#Preview { ShieldOrbArt().background(Color.bg) }
#endif
