import Foundation
import SwiftUI
import Testing
@testable import Tapout

struct AppSettingsTests {
    @Test func hapticsAreOnUntilTurnedOff() {
        let defaults = UserDefaults(suiteName: "tapout.tests.\(UUID().uuidString)")!
        #expect(AppSettings.hapticsEnabled(in: defaults))
        defaults.set(false, forKey: AppSettings.hapticsKey)
        #expect(!AppSettings.hapticsEnabled(in: defaults))
    }

    @Test func appearanceMapsToAColorScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.light.colorScheme == .light)
        #expect(Appearance.dark.colorScheme == .dark)
    }
}
