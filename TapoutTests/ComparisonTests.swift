import Foundation
import Testing
@testable import Tapout

struct ComparisonTests {
    private let movie = Comparison.all.first { $0.interest == .movies }!

    @Test func picksTheBiggestComparisonThatFits() {
        #expect(Comparison.best(for: 3 * 3600 + 20 * 60, interests: [.sports, .movies])?.interest == .sports)
        #expect(Comparison.best(for: 50 * 60, interests: [.music, .movies])?.interest == .music)
    }

    @Test func nothingFitsAShortTotal() {
        #expect(Comparison.best(for: 30 * 60, interests: [.movies]) == nil)
    }

    @Test func noInterestsMeansMovies() {
        #expect(Comparison.best(for: 2 * 3600 + 5 * 60, interests: [])?.interest == .movies)
    }

    @Test func wording() {
        #expect(movie.asLongAs(2.5 * 3600) == "As long as a feature film")
        #expect(movie.asLongAs(5 * 3600) == "As long as 2 movies")
        #expect(movie.worth(10 * 3600) == "About 5 movies' worth of time, back.")
        #expect(movie.worth(2 * 3600) == "About as long as a feature film.")
    }
}
