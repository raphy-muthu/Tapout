import Foundation
import Observation

/// How much the orb may move. `.still` shows the classic, static orb.
enum MotionLevel: Equatable {
    case full, still
}

/// Decides, from the system's own signals, whether continuous effects may run.
enum MotionBudget {
    /// Seconds between frames while the orb runs.
    static let frameInterval: TimeInterval = 1.0 / 30.0

    static func level(reduceMotion: Bool, lowPowerMode: Bool,
                      thermalState: ProcessInfo.ThermalState, sceneActive: Bool) -> MotionLevel {
        if reduceMotion || lowPowerMode || !sceneActive { return .still }
        switch thermalState {
        case .nominal, .fair: return .full
        case .serious, .critical: return .still
        @unknown default: return .still
        }
    }
}

/// Low Power Mode and thermal state, kept current for views that read them in `body`.
@MainActor @Observable
final class MotionEnvironment {
    static let shared = MotionEnvironment()

    private(set) var lowPowerMode: Bool
    private(set) var thermalState: ProcessInfo.ThermalState
    @ObservationIgnored private var observers: [Task<Void, Never>] = []

    init(processInfo: ProcessInfo = .processInfo, center: NotificationCenter = .default) {
        lowPowerMode = processInfo.isLowPowerModeEnabled
        thermalState = processInfo.thermalState
        observers = [
            Task { [weak self] in
                for await _ in center.notifications(named: .NSProcessInfoPowerStateDidChange) {
                    self?.lowPowerMode = processInfo.isLowPowerModeEnabled
                }
            },
            Task { [weak self] in
                for await _ in center.notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                    self?.thermalState = processInfo.thermalState
                }
            },
        ]
    }

    deinit { observers.forEach { $0.cancel() } }
}
