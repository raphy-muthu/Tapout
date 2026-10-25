import Foundation
import Testing
@testable import Tapout

struct TagUIDTests {
    @Test func bytesBecomeUppercaseHex() {
        #expect(TagUID(data: Data([0x04, 0xA2, 0x0F, 0x1B])).hex == "04A20F1B")
    }

    @Test func hexIsNormalisedToUppercase() {
        #expect(TagUID(hex: "04a20f") == TagUID(hex: "04A20F"))
    }

    @Test func displayGroupsBytesWithColons() {
        #expect(TagUID(hex: "04A20F1B").display == "04:A2:0F:1B")
    }
}
