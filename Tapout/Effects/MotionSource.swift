import CoreMotion
import Foundation
import Observation

/// One shared, reference-counted source of device tilt. Views `acquire()` while they are
/// showing the orb and `release()` when they leave; the sensor only runs while someone needs it.
/// Without a motion sensor (the Simulator) the tilt sways slowly on its own.
@MainActor @Observable
final class MotionSource {
    static let shared = MotionSource()

    /// Smoothed tilt, each component in -1...1. See `TiltFilter` for the axes.
    /// Not observed: views pull it from a `TimelineView` each frame, so a sensor sample never
    /// re-renders anything on its own (that would double the 30 fps budget).
    @ObservationIgnored private(set) var tilt: SIMD2<Double> = .zero
    private(set) var consumers = 0

    @ObservationIgnored private var filter = TiltFilter()
    @ObservationIgnored private var manager: CMMotionManager?
    @ObservationIgnored private var sway: Task<Void, Never>?

    init() {}

    func acquire() {
        consumers += 1
        if consumers == 1 { start() }
    }

    func release() {
        guard consumers > 0 else { return }
        consumers -= 1
        if consumers == 0 { stop() }
    }

    func ingest(gravityX: Double, gravityY: Double) {
        tilt = filter.update(gravityX: gravityX, gravityY: gravityY)
    }

    private func start() {
        let manager = CMMotionManager()
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = MotionBudget.frameInterval
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let motion else { return }
                let x = motion.gravity.x, y = motion.gravity.y
                MainActor.assumeIsolated { self?.ingest(gravityX: x, gravityY: y) }
            }
            self.manager = manager
        } else {
            let start = Date()
            sway = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    // Stops once the source is freed; the strong reference lasts one step only.
                    guard let self else { return }
                    let t = Date().timeIntervalSince(start)
                    self.tilt = SIMD2(sin(t * 0.55) * 0.35, cos(t * 0.43) * 0.25)
                    try? await Task.sleep(for: .seconds(MotionBudget.frameInterval))
                }
            }
        }
    }

    private func stop() {
        manager?.stopDeviceMotionUpdates()
        manager = nil
        sway?.cancel()
        sway = nil
        filter.reset()
        tilt = .zero
    }
}
