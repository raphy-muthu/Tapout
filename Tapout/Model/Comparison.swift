import Foundation

/// An everyday length of time to compare locked time with, keyed by interest. Approximate on purpose.
struct Comparison: Equatable {
    let interest: Interest
    /// "an entire NFL game"
    let phrase: String
    /// "NFL games"
    let plural: String
    /// SF Symbol for the Insights card.
    let symbol: String
    let length: TimeInterval

    static let all: [Comparison] = [
        Comparison(interest: .sports, phrase: "an entire NFL game", plural: "NFL games", symbol: "football", length: 3 * 3600 + 12 * 60),
        Comparison(interest: .movies, phrase: "a feature film", plural: "movies", symbol: "film", length: 2 * 3600),
        Comparison(interest: .reading, phrase: "a 300-page novel", plural: "novels", symbol: "book", length: 6 * 3600),
        Comparison(interest: .music, phrase: "a full album", plural: "albums", symbol: "music.note", length: 45 * 60),
        Comparison(interest: .travel, phrase: "a flight across the US", plural: "cross-country flights", symbol: "airplane", length: 5 * 3600 + 30 * 60),
        Comparison(interest: .fitness, phrase: "a marathon", plural: "marathons", symbol: "figure.run", length: 4 * 3600 + 30 * 60),
    ]

    /// The longest comparison that `time` covers, from the owner's interests (Movies when none were picked).
    /// nil when even the shortest is longer than `time`; screens then hide the comparison.
    static func best(for time: TimeInterval, interests: [Interest]) -> Comparison? {
        let picked = interests.isEmpty ? [.movies] : interests
        return all.filter { picked.contains($0.interest) && $0.length <= time }.max { $0.length < $1.length }
    }

    /// Insights card: "As long as an entire NFL game", "As long as 2 NFL games".
    func asLongAs(_ time: TimeInterval) -> String {
        let count = Int(time / length)
        return count >= 2 ? "As long as \(count) \(plural)" : "As long as \(phrase)"
    }

    /// Milestone line: "About 5 movies' worth of time, back.", "About as long as a feature film."
    func worth(_ time: TimeInterval) -> String {
        let count = Int(time / length)
        return count >= 2 ? "About \(count) \(plural)' worth of time, back." : "About as long as \(phrase)."
    }
}
