import Foundation

/// A tag's hardware serial number, as uppercase hex. Tapout recognises tags by this alone.
struct TagUID: Codable, Hashable, Sendable {
    let hex: String

    init(hex: String) {
        self.hex = hex.uppercased()
    }

    init(data: Data) {
        self.hex = data.map { String(format: "%02X", $0) }.joined()
    }

    /// Whether this ID stays the same every time the tag is read. An empty ID can't tell tags apart, and a 4-byte
    /// ID starting 08 is an ISO 14443-3 random ID (many bank, office and transit cards): it changes each time,
    /// so a place paired with it could never unlock again.
    var isStable: Bool {
        guard !hex.isEmpty else { return false }
        return !(hex.count == 8 && hex.hasPrefix("08"))
    }

    /// "04:A2:0F", for the Lab and the log.
    var display: String {
        var pairs: [Substring] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            pairs.append(hex[index..<next])
            index = next
        }
        return pairs.joined(separator: ":")
    }
}

/// A tag the owner has paired. Only paired tags lock and unlock.
struct PairedTag: Codable, Hashable, Identifiable, Sendable {
    let uid: TagUID
    var name: String
    let pairedAt: Date

    var id: TagUID { uid }
}
