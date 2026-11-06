import Testing
import UIKit
@testable import Tapout

struct FontTests {
    @Test(arguments: FrauncesFace.allCases)
    func cutIsBundledAndRegistered(_ face: FrauncesFace) {
        #expect(UIFont(name: face.rawValue, size: 20) != nil, "missing font \(face.rawValue)")
    }

    private func width(of digit: Character, size: CGFloat) -> CGFloat {
        let font = UIFont(name: FrauncesFace.display.rawValue, size: size)!
        return String(digit).size(withAttributes: [.font: font]).width
    }

    /// Why slots exist. If this ever fails, the font gained even digits and the slots can go.
    @Test func digitsHaveDifferentWidths() {
        #expect(width(of: "1", size: 100) < width(of: "0", size: 100) * 0.8)
    }

    @Test func slotFitsEveryDigitExactlyAtTheWidest() {
        let slot = DigitSlots.digitWidth(face: .display, size: 100)
        let widths = "0123456789".map { width(of: $0, size: 100) }
        #expect(widths.allSatisfy { $0 <= slot })
        #expect(widths.contains(slot))
    }

    @Test func slotScalesWithSize() {
        let small = DigitSlots.digitWidth(face: .display, size: 72)
        let large = DigitSlots.digitWidth(face: .display, size: 144)
        #expect(abs(large - small * 2) < 0.5)
    }

    @Test func onlyDigitsGetSlots() {
        #expect(DigitSlots.width(of: "4", digitWidth: 50) == 50)
        #expect(DigitSlots.width(of: ":", digitWidth: 50) == nil)
    }

    @Test @MainActor func boldTextPicksTheHeavierCut() {
        let pairs: [(FrauncesFace, FrauncesFace)] = [(.display, .displayBold), (.number, .numberBold), (.title, .titleBold)]
        for (regular, bold) in pairs {
            #expect(regular.resolved(boldText: true) == bold)
            #expect(regular.resolved(boldText: false) == regular)
            #expect(bold.resolved(boldText: true) == bold)
            #expect(bold.resolved(boldText: false) == bold)
        }
    }

    /// Bold digits are wider, so a slot measured on the regular cut would clip them.
    @Test func boldCutNeedsAWiderSlot() {
        #expect(DigitSlots.digitWidth(face: .displayBold, size: 100) > DigitSlots.digitWidth(face: .display, size: 100))
    }
}
