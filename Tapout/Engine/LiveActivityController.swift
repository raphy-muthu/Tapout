import ActivityKit
import Foundation
import os

/// Starts, updates and ends the lock's Live Activity to match `LiveActivityPlan`. ActivityKit lets the
/// app start one only while it's in the foreground, so a lock a schedule started appears the next time
/// Tapout opens. Never more than one.
@MainActor
enum LiveActivityController {
    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "liveActivity")

    static func sync(_ snapshot: LockSnapshot, enabled: Bool) {
        let all = Activity<LockActivityAttributes>.activities
        let activities = all.filter { LiveActivityPlan.countsAsCurrent($0.activityState.phase) }
        let finished = all.filter { !LiveActivityPlan.countsAsCurrent($0.activityState.phase) }
        let allowed = enabled && ActivityAuthorizationInfo().areActivitiesEnabled
        let action = LiveActivityPlan.decide(snapshot: snapshot, enabled: allowed, current: activities.first?.content.state)
        let extras = Array(activities.dropFirst()) + finished
        switch action {
        case .none:
            end(extras)
        case .end:
            end(activities + finished)
        case .start(let state):
            end(extras)
            do {
                _ = try Activity.request(attributes: LockActivityAttributes(),
                                         content: ActivityContent(state: state, staleDate: state.openUntil),
                                         pushType: nil)
            } catch {
                logger.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
            }
        case .update(let state):
            end(extras)
            guard let id = activities.first?.id else { return }
            Task { await update(id: id, to: state) }
        }
    }

    private static func end(_ activities: [Activity<LockActivityAttributes>]) {
        let ids = activities.map(\.id)
        guard !ids.isEmpty else { return }
        Task { await end(ids: ids) }
    }

    // Nonisolated, so the activities they look up never cross from the main actor (Swift 6 region isolation).
    private nonisolated static func update(id: String, to state: LockActivityAttributes.ContentState) async {
        let activity = Activity<LockActivityAttributes>.activities.first { $0.id == id }
        await activity?.update(ActivityContent(state: state, staleDate: state.openUntil))
    }

    private nonisolated static func end(ids: [String]) async {
        for activity in Activity<LockActivityAttributes>.activities where ids.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

private extension ActivityState {
    var phase: LiveActivityPlan.Phase {
        switch self {
        case .active: .active
        case .stale: .stale
        default: .over
        }
    }
}
