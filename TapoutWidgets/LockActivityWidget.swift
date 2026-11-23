import ActivityKit
import SwiftUI
import WidgetKit

struct LockActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockActivityAttributes.self) { context in
            LockScreenCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.surface1)
                .activitySystemActionForegroundColor(Color.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    IslandOrb(state: context.state, isStale: context.isStale, size: 64)
                }
                DynamicIslandExpandedRegion(.center) {
                    IslandTitle(state: context.state, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandTimer(state: context.state, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Nothing to unlock once a timer has ended.
                    if !context.state.timerIsOver(isStale: context.isStale) {
                        Label("Tap a tag to unlock", systemImage: "wave.3.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.emberInk)
                            .environment(\.colorScheme, .dark)
                    }
                }
            } compactLeading: {
                IslandOrb(state: context.state, isStale: context.isStale, size: 26)
            } compactTrailing: {
                IslandTimer(state: context.state, isStale: context.isStale, compact: true)
            } minimal: {
                IslandOrb(state: context.state, isStale: context.isStale, size: 26)
            }
            .keylineTint(Color.ember)
        }
    }
}

#if DEBUG
private extension LockActivityAttributes.ContentState {
    static let locked = LockActivityAttributes.ContentState(lockedFrom: .now - 2832, openUntil: nil, modeName: "Deep work", placeName: "Kitchen")
    static let open = LockActivityAttributes.ContentState(lockedFrom: .now - 2832, openUntil: .now + 272, modeName: "Deep work", placeName: "Kitchen")
    static let veryLong = LockActivityAttributes.ContentState.sample(lockedFor: LockSnapshot.sampleLockLengths[2])
    static let timer = LockActivityAttributes.ContentState.sampleTimer(
        length: LockSnapshot.sampleTimers[0].length, left: LockSnapshot.sampleTimers[0].left)
}

#Preview("Island", as: .dynamicIsland(.expanded), using: LockActivityAttributes()) {
    LockActivityWidget()
} contentStates: {
    LockActivityAttributes.ContentState.locked
    LockActivityAttributes.ContentState.open
    LockActivityAttributes.ContentState.veryLong
    LockActivityAttributes.ContentState.timer
}

#Preview("Compact", as: .dynamicIsland(.compact), using: LockActivityAttributes()) {
    LockActivityWidget()
} contentStates: {
    LockActivityAttributes.ContentState.locked
    LockActivityAttributes.ContentState.open
    LockActivityAttributes.ContentState.veryLong
    LockActivityAttributes.ContentState.timer
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: LockActivityAttributes()) {
    LockActivityWidget()
} contentStates: {
    LockActivityAttributes.ContentState.locked
    LockActivityAttributes.ContentState.open
    LockActivityAttributes.ContentState.veryLong
    LockActivityAttributes.ContentState.timer
}

#Preview("Lock Screen", as: .content, using: LockActivityAttributes()) {
    LockActivityWidget()
} contentStates: {
    LockActivityAttributes.ContentState.locked
    LockActivityAttributes.ContentState.open
    LockActivityAttributes.ContentState.veryLong
    LockActivityAttributes.ContentState.timer
}
#endif
