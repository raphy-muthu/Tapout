import SwiftUI

/// The Living glass switch's Live Activity: flat state color on the Lock Screen, and in the expanded island a
/// block of it across the bottom (the island's own background is always black). No orb.

/// The activity's one big number: the countdown during a pass or a timer lock, the count-up otherwise, and
/// "Open" once a timer has ended.
private struct FlatActivityNumber: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    let size: CGFloat

    var body: some View {
        Group {
            if state.timerIsOver(isStale: isStale) {
                Text("Open")
            } else if !isStale, let until = state.openUntil {
                Text(timerInterval: until.addingTimeInterval(-LockActivityTiming.pass)...until, countsDown: true)
            } else if let end = state.timerEndsAt {
                Text(timerInterval: LockActivityTiming.countdown(to: end), countsDown: true)
            } else {
                Text(timerInterval: state.lockedFrom...state.lockedFrom.addingTimeInterval(LockActivityTiming.span),
                     countsDown: false)
            }
        }
        .flatTimer(size)
    }
}

/// The Lock Screen card. Its background is the activity's tint, `tone.field`.
struct FlatLockScreenCard: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let poster = FlatPoster.activity(state, isStale: isStale)
        VStack(alignment: .leading, spacing: 0) {
            FlatHeading(text: poster.heading)
            FlatActivityNumber(state: state, isStale: isStale, size: 60)
            if let footer = poster.footer {
                Text(footer).font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(poster.tone.onField)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, Space.md)
    }
}

/// The expanded island's bottom block.
struct FlatIslandBlock: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let poster = FlatPoster.activity(state, isStale: isStale)
        VStack(alignment: .leading, spacing: 0) {
            FlatHeading(text: poster.heading)
            FlatActivityNumber(state: state, isStale: isStale, size: 52)
            // Nothing to unlock once a timer has ended.
            if !state.timerIsOver(isStale: isStale) {
                Label("Tap a tag to unlock", systemImage: "wave.3.right")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(poster.tone.onField)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .background(poster.tone.field, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The compact and minimal island: a flat disc of the state's color with a lock, in place of the orb.
struct FlatIslandDot: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    var size: CGFloat = 24

    var body: some View {
        let tone = FlatPoster.activity(state, isStale: isStale).tone
        Circle()
            .fill(tone.field)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: tone == .ember ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(tone.onField)
            }
            .accessibilityLabel(tone == .ember ? "Locked" : "Open")
    }
}
