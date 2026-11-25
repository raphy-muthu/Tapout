import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct GlassOrbRenderTests {
    @Test func theShaderIsInTheBuild() {
        #expect(GlassOrbShader.isAvailable)
    }

    @Test func theShaderDrawsASphereWithTransparentCorners() throws {
        let renderer = ImageRenderer(content: GlassOrbView(tone: 1, size: 200).frame(width: 288, height: 288))
        renderer.scale = 1
        let image = try #require(renderer.uiImage?.cgImage)
        let corner = try pixel(image, x: 2, y: 2)
        let centre = try pixel(image, x: 144, y: 160)
        #expect(corner.alpha < 0.05)
        #expect(centre.alpha > 0.95)
        #expect(centre.red > centre.blue) // ember, not slate
    }

    @Test func slateIsBluerThanEmber() throws {
        func centre(tone: Double) throws -> (red: Double, green: Double, blue: Double, alpha: Double) {
            let renderer = ImageRenderer(content: GlassOrbView(tone: tone, size: 200).frame(width: 288, height: 288))
            renderer.scale = 1
            return try pixel(try #require(renderer.uiImage?.cgImage), x: 144, y: 160)
        }
        let slate = try centre(tone: 0), ember = try centre(tone: 1)
        #expect(slate.blue / max(slate.red, 0.001) > ember.blue / max(ember.red, 0.001))
    }

    /// One pixel, premultiplied, read by drawing the image offset into a 1x1 context.
    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> (red: Double, green: Double, blue: Double, alpha: Double) {
        var data = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (Double(data[0]) / 255, Double(data[1]) / 255, Double(data[2]) / 255, Double(data[3]) / 255)
    }
}
