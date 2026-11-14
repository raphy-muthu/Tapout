#if DEBUG
import SwiftUI

/// The App Store icon, as designed in design/screens/AppIcon.dc.html: the sealed ember orb on a
/// surface disc on near-black. Always dark. Exported to the asset catalog by AppIconTests.
struct AppIconArt: View {
    static let side: CGFloat = 1024

    var body: some View {
        ZStack {
            Color.bg
            Circle().fill(Color.surface1).frame(width: 800, height: 800)
            OrbView(tone: .ember, ring: 1, size: 720)
        }
        .frame(width: Self.side, height: Self.side)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    @MainActor static func render() -> UIImage? {
        let renderer = ImageRenderer(content: AppIconArt())
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return renderer.uiImage
    }
}

#Preview { AppIconArt().scaleEffect(0.3).frame(width: 320, height: 320) }
#endif
