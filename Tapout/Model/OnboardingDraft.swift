import FamilyControls
import Foundation

/// The "When should it lock?" choices.
enum FocusWindow: String, CaseIterable, Identifiable {
    case mornings, afternoons, evenings

    var id: Self { self }
    var title: String { rawValue.capitalized }

    /// Minutes after midnight.
    var start: Int {
        switch self {
        case .mornings: 9 * 60
        case .afternoons: 13 * 60
        case .evenings: 18 * 60
        }
    }

    var end: Int {
        switch self {
        case .mornings: 12 * 60
        case .afternoons: 17 * 60
        case .evenings: 21 * 60
        }
    }
}

/// Onboarding's answers, saved together on the last step.
struct OnboardingDraft {
    static let stepCount = 5

    var step = 1
    var selection = FamilyActivitySelection()
    var alwaysAllowed = FamilyActivitySelection()
    var window: FocusWindow?
    var days: Set<Int> = ModeSchedule.weekdays
    var interests: Set<Interest> = []

    /// nil without a window or days; the starter mode then stays manual.
    var schedule: ModeSchedule? {
        guard let window, !days.isEmpty else { return nil }
        return ModeSchedule(days: days, start: window.start, end: window.end)
    }

    var cta: String {
        switch step {
        case 1: "Get started"
        case 2: "Allow"
        case 3, 4: "Continue"
        default: "Scan tag"
        }
    }

    mutating func advance() {
        step = min(step + 1, Self.stepCount)
    }
}
