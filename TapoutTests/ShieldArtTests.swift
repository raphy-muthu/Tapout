#if DEBUG
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct ShieldArtTests {
    @Test func rendersATransparent600Square() throws {
        let image = try #require(ShieldOrbArt.render())
        #expect(image.size.width * image.scale == 600)
        #expect(image.size.height * image.scale == 600)
        let cg = try #require(image.cgImage)
        let alpha = cg.alphaInfo
        #expect(![.none, .noneSkipLast, .noneSkipFirst].contains(alpha))
        // The corner is empty; the middle is the orb.
        #expect(try pixelAlpha(cg, x: 2, y: 2) == 0)
        #expect(try pixelAlpha(cg, x: 300, y: 300) > 200)
        // The middle of an edge is empty too: the glow fades out inside the canvas, nothing is clipped.
        #expect(try pixelAlpha(cg, x: 300, y: 2) == 0)
    }

    /// Writes the PNG into the shield's asset catalog when run with TEST_RUNNER_TAPOUT_EXPORT_SHIELD_ART=1.
    @Test func exportsWhenAsked() throws {
        guard ProcessInfo.processInfo.environment["TAPOUT_EXPORT_SHIELD_ART"] == "1" else { return }
        let data = try #require(ShieldOrbArt.render()?.pngData())
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TapoutShield/Shield.xcassets/SealedOrb.imageset/SealedOrb.png")
        try data.write(to: url)
    }

    private func pixelAlpha(_ image: CGImage, x: Int, y: Int) throws -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel[3]
    }
}
#endif
