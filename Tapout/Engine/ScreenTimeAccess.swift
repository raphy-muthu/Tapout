import FamilyControls
import Foundation

/// Asks for Screen Time access for this iPhone's own user.
enum ScreenTimeAccess {
    enum Outcome: Equatable {
        case granted, declined, noConnection, unavailable

        /// The line under the step's text. nil once access is granted.
        var message: String? {
            switch self {
            case .granted: nil
            case .declined: "Screen Time is off. Turn it on in Settings, then tap Allow."
            case .noConnection: "No connection. Try again."
            case .unavailable: "Screen Time isn't available on this iPhone."
            }
        }

        /// Only a decline can be fixed in Settings.
        var offersSettings: Bool { self == .declined }
    }

    /// What Screen Time access is right now; it can be turned off in Settings at any time.
    /// The simulator counts as approved, unless launched with -mockScreenTimeRevoked.
    @MainActor static var status: ScheduledLock.LiveAccess {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-mockScreenTimeRevoked") ? .denied : .approved
        #else
        let status = AuthorizationCenter.shared.authorizationStatus
        if status == .approved { return .approved }
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return .approved }
        return status == .denied ? .denied : .notDetermined
        #endif
    }

    /// Whether Tapout may shield apps right now. Not yet asked counts as no.
    @MainActor static var isApproved: Bool { status == .approved }

    /// The simulator can't grant access, so there it continues, unless launched with -mockScreenTimeDenied.
    @MainActor static func request() async -> Outcome {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-mockScreenTimeDenied") ? .declined : .granted
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return .granted
        } catch {
            return outcome(for: error)
        }
        #endif
    }

    static func outcome(for error: any Error) -> Outcome {
        switch error as? FamilyControlsError {
        case .authorizationCanceled: .declined
        case .networkError: .noConnection
        default: .unavailable
        }
    }
}
