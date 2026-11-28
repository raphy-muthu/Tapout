import ActivityKit
import SwiftUI
import WidgetKit

struct LockActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockActivityAttributes.self) { context in
            if context.state.flat == true {
                let tone = FlatPoster.activity(context.state, isStale: context.isStale).tone
                FlatLockScreenCard(state: context.state, isStale: context.isStale)
                    .activityBackgroundTint(tone.field)
                    .activitySystemActionForegroundColor(tone.onField)
            } else {
                LockScreenCard(state: context.state, isStale: context.isStale)
                    .activityBackgroundTint(Color.surface1)
                    .activitySystemActionForegroundColor(Color.ink)
            }
        } dynamicIsland: { context in
            let flat = context.state.flat == true
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if !flat { IslandOrb(state: context.state, isStale: context.isStale, size: 64) }
                }
                DynamicIslandExpandedRegion(.center) {
                    if !flat { IslandTitle(state: context.state, isStale: context.isStale) }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !flat { IslandTimer(state: context.state, isStale: context.isStale) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if flat {
                        FlatIslandBlock(state: context.state, isStale: context.isStale)
                    } else if !context.state.timerIsOver(isStale: context.isStale),
                              !context.state.showsEndTime(isStale: context.isStale) {
                        // Nothing to unlock once a timer has ended.
                        Label("Tap a tag to unlock", systemImage: "wave.3.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.emberInk)
                            .environment(\.colorScheme, .dark)
                    }
                }
            } compactLeading: {
                IslandMark(state: context.state, isStale: context.isStale)
            } compactTrailing: {
                IslandTimer(state: context.state, isStale: context.isStale, compact: true)
            } minimal: {
                IslandMark(state: context.state, isStale: context.isStale)
            }
            .keylineTint(flat ? FlatPoster.activity(context.state, isStale: context.isStale).tone.field : Color.ember)
        }
    }
}

/// The compact island's mark: the flat disc or the orb.
private struct IslandMark: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if state.flat == true {
            FlatIslandDot(state: state, isStale: isStale)
        } else {
            IslandOrb(state: state, isStale: isStale, size: 26)
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
