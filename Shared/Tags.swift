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
