import Testing
@testable import Tapout

struct TiltFilterTests {
    @Test func theFirstSampleIsTheRestPose() {
        var filter = TiltFilter()
        #expect(filter.update(gravityX: 0.3, gravityY: -0.7) == .zero)
    }

    @Test func aSteadyPhoneStaysAtZero() {
        var filter = TiltFilter()
        for _ in 0..<100 { _ = filter.update(gravityX: 0.1, gravityY: -0.8) }
        #expect(abs(filter.value.x) < 0.001 && abs(filter.value.y) < 0.001)
    }

    @Test func aTipMovesTheLightButNotAllAtOnce() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        let first = filter.update(gravityX: 0.5, gravityY: -1)
        #expect(first.x > 0)
        #expect(first.x < 0.3) // low-pass: the full step would give 0.5 x 2.4, clamped to 1
    }

    @Test func aHeldTipFadesAsTheRestPoseFollows() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        for _ in 0..<20 { _ = filter.update(gravityX: 0.4, gravityY: -1) }
        let early = filter.value.x
        for _ in 0..<900 { _ = filter.update(gravityX: 0.4, gravityY: -1) }
        #expect(early > 0.3)
        #expect(abs(filter.value.x) < 0.05)
    }

    @Test func outputIsClamped() {
        var filter = TiltFilter(smoothing: 1, restRate: 0, gain: 10)
        _ = filter.update(gravityX: 0, gravityY: 0)
        let out = filter.update(gravityX: 1, gravityY: -1)
        #expect(out.x == 1 && out.y == -1)
    }

    @Test func resetForgetsTheRestPose() {
        var filter = TiltFilter()
        _ = filter.update(gravityX: 0, gravityY: -1)
        _ = filter.update(gravityX: 0.5, gravityY: -1)
        filter.reset()
        #expect(filter.value == .zero)
        #expect(filter.update(gravityX: 0.5, gravityY: -1) == .zero)
    }
}
