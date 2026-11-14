import SwiftUI
import Testing
@testable import Tapout

@MainActor
struct RecapImageTests {
    @Test func rendersAStorySizedImage() throws {
        let sample = LockSnapshot.sample(.unlocked)
        let view = RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                             comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        let image = try #require(RecapImage.render(view, colorScheme: .dark))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }

    @Test func darkAndLightImagesDiffer() throws {
        let sample = LockSnapshot.sample(.unlocked)
        let view = RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                             comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        let dark = try #require(RecapImage.render(view, colorScheme: .dark)?.pngData())
        let light = try #require(RecapImage.render(view, colorScheme: .light)?.pngData())
        #expect(dark != light)
    }

    @Test func rendersWithoutAComparison() throws {
        let sample = LockSnapshot.sample(.unlocked)
        let view = RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days, comparison: nil)
        let image = try #require(RecapImage.render(view, colorScheme: .dark))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }

    @Test func shareItemExportsAFullSizePNG() async throws {
        let sample = LockSnapshot.sample(.unlocked)
        let share = RecapShare(weekStart: .now, total: sample.weekTotal, days: sample.days,
                               comparison: nil, colorScheme: .dark)
        let data = try #require(await share.pngData())
        let image = try #require(UIImage(data: data))
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1920)
    }
}
