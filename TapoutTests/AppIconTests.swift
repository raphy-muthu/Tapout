#if DEBUG
import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct AppIconTests {
    @Test func rendersAnOpaque1024Square() throws {
        let image = try #require(AppIconArt.render())
        #expect(image.size == CGSize(width: 1024, height: 1024))
        #expect(image.scale == 1)
        let alpha = try #require(image.cgImage?.alphaInfo)
        #expect([.none, .noneSkipLast, .noneSkipFirst].contains(alpha))
    }

    /// Writes the PNG into the asset catalog when run with TEST_RUNNER_TAPOUT_EXPORT_ICON=1 (see Step 4).
    @Test func exportsWhenAsked() throws {
        guard ProcessInfo.processInfo.environment["TAPOUT_EXPORT_ICON"] == "1" else { return }
        let data = try #require(AppIconArt.render()?.pngData())
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Tapout/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
        try data.write(to: url)
    }
}
#endif
