import Foundation
import Testing

struct ReleaseConfigTests {
    @Test func appDeclaresNoEncryption() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }

    @Test func appPrivacyManifestDeclaresUserDefaultsReasons() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        #expect(plist["NSPrivacyTracking"] as? Bool == false)
        #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let types = try #require(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try #require(types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        #expect(Set(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []) == ["CA92.1", "1C8F.1"])
    }

    @Test func appExplainsSavingToPhotos() {
        let text = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String
        #expect(text?.isEmpty == false)
    }
}
