import Foundation

/// What the owner enjoys, picked in onboarding. Insights compares locked time with these.
enum Interest: String, Codable, CaseIterable, Sendable {
    case sports, movies, reading, music, travel, fitness

    var title: String { rawValue.capitalized }
}
