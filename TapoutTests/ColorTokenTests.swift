import Testing
import UIKit
@testable import Tapout

struct ColorTokenTests {
    static let names = [
        "bg", "surface-1", "surface-2", "ink", "ink-secondary", "ink-tertiary",
        "ember", "ember-ink", "ember-line", "ember-glow", "on-ember",
        "slate", "slate-ink", "slate-line", "slate-glow", "on-slate",
        "track", "danger", "scrim",
    ]

    @Test(arguments: names)
    func colourSetExists(_ name: String) {
        #expect(UIColor(named: name) != nil, "missing colour set \(name)")
    }

    @Test func backgroundDiffersByAppearance() throws {
        let bg = try #require(UIColor(named: "bg"))
        let dark = bg.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = bg.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        #expect(dark != light)
    }
}
