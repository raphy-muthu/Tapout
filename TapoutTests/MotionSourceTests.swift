import Foundation
import Observation
import Testing
@testable import Tapout

@MainActor
struct MotionSourceTests {
    @Test func consumersAreCounted() {
        let source = MotionSource()
        source.acquire(); source.acquire()
        #expect(source.consumers == 2)
        source.release()
        #expect(source.consumers == 1)
        source.release(); source.release() // an extra release never goes below zero
        #expect(source.consumers == 0)
    }

    @Test func ingestingASampleMovesTheTilt() {
        let source = MotionSource()
        source.ingest(gravityX: 0, gravityY: -1) // the rest pose
        source.ingest(gravityX: 0.4, gravityY: -1)
        #expect(source.tilt.x > 0)
    }

    @Test func stoppingResetsTheTilt() {
        let source = MotionSource()
        source.acquire()
        source.ingest(gravityX: 0, gravityY: -1)
        source.ingest(gravityX: 0.5, gravityY: -1)
        source.release()
        #expect(source.tilt == .zero)
    }

    /// The orb's timeline pulls the tilt each frame, so a new sample must not re-render anything.
    @Test func aNewSampleDoesNotNotifyObservers() {
        let source = MotionSource()
        source.ingest(gravityX: 0, gravityY: -1)
        let notified = Flag()
        withObservationTracking { _ = source.tilt } onChange: { notified.raise() }
        source.ingest(gravityX: 0.4, gravityY: -1)
        #expect(!notified.isRaised)
    }
}

/// Set from observation's `@Sendable` change handler.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var raised = false
    var isRaised: Bool { lock.withLock { raised } }
    func raise() { lock.withLock { raised = true } }
}
