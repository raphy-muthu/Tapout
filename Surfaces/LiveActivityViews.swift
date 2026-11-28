import SwiftUI

/// The Live Activity from design/screens/LiveActivity.dc.html. During a pass (and until its stale date),
/// a slate orb, "Open" and the countdown; otherwise the ember orb and the locked timer, which counts
/// down with "left" while a timer lock runs. Once a timer's end has passed (its stale date), a calm
/// "Time's up": a slate orb without a ring and no timer, until Tapout opens and ends the activity.
private func isOpen(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> Bool {
    state.openUntil != nil && !isStale
}

/// The orb's tone: slate while apps are open (a pass, or a timer that ended), ember while locked.
private func orbTone(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> OrbTone {
    isOpen(state, isStale: isStale) || state.timerIsOver(isStale: isStale) ? .slate : .ember
}

/// No seal ring once a timer has ended: the lock is over.
private func orbRing(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> Double {
    state.timerIsOver(isStale: isStale) ? 0 : 1
}

/// The Lock Screen card. Follows the system appearance.
struct LockScreenCard: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let open = isOpen(state, isStale: isStale)
        HStack(spacing: Space.md) {
            OrbView(tone: orbTone(state, isStale: isStale), ringTone: .ember, ring: orbRing(state, isStale: isStale), size: 80)
            VStack(alignment: .leading, spacing: 2) {
                if state.timerIsOver(isStale: isStale) {
                    Text("Time's up")
                        .font(.tTitle1)
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Label(caption, systemImage: "lock.open").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.inkSecondary)
                } else if open, let until = state.openUntil {
                    Text("Open · Relocks in").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    timer(until, countsDown: true)
                    Text(caption).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                } else if let end = state.timerEnd(isStale: isStale) {
                    if state.showsEndTime(isStale: isStale) {
                        HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                            Text("Ends").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                            Text(end, style: .time)
                                .font(.system(size: 48, weight: .light).monospacedDigit())
                                .foregroundStyle(Color.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    } else {
                        HStack(alignment: .lastTextBaseline, spacing: Space.xs) {
                            timer(end, countsDown: true, range: LockActivityTiming.countdown(to: end))
                            Text("left").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                        }
                    }
                    Label(caption, systemImage: "lock").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                } else {
                    timer(state.lockedFrom)
                    Label(caption, systemImage: "lock").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func timer(_ date: Date, countsDown: Bool = false, range: ClosedRange<Date>? = nil) -> some View {
        Group {
            if countsDown {
                Text(timerInterval: range ?? date.addingTimeInterval(-LockActivityTiming.pass)...date, countsDown: true)
            } else {
                Text(timerInterval: LockActivityTiming.countUp(from: date), countsDown: false)
            }
        }
            .font(.system(size: 48, weight: .light).monospacedDigit())
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var caption: String {
        state.placeName.map { "\(state.modeName) · \($0)" } ?? state.modeName
    }
}

/// The Dynamic Island's orb; the island is always dark.
struct IslandOrb: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    let size: CGFloat

    var body: some View {
        OrbView(tone: orbTone(state, isStale: isStale), ringTone: .ember, ring: orbRing(state, isStale: isStale), size: size)
            .environment(\.colorScheme, .dark)
    }
}

/// The island's timer: the countdown during a pass or a timer lock, the locked timer otherwise. The compact one has a
/// fixed width so the island doesn't jump as digits change; both shrink to fit locks of 10 hours and up.
struct IslandTimer: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    var compact = false

    var body: some View {
        Group {
            if state.timerIsOver(isStale: isStale) {
                Text("Open")
            } else if isOpen(state, isStale: isStale), let until = state.openUntil {
                Text(timerInterval: until.addingTimeInterval(-LockActivityTiming.pass)...until, countsDown: true)
            } else if let end = state.timerEnd(isStale: isStale) {
                if state.showsEndTime(isStale: isStale) {
                    Text(end, style: .time)
                } else {
                    Text(timerInterval: LockActivityTiming.countdown(to: end), countsDown: true)
                }
            } else {
                Text(timerInterval: LockActivityTiming.countUp(from: state.lockedFrom), countsDown: false)
            }
        }
        .font(.system(size: compact ? 16 : 40, weight: compact ? .semibold : .light).monospacedDigit())
        .foregroundStyle(compact ? Color.emberInk : Color.ink)
        .lineLimit(1)
        .minimumScaleFactor(compact ? 0.7 : 0.6)
        .frame(width: compact ? 64 : nil, alignment: .trailing)
        .frame(maxWidth: compact ? nil : 120, alignment: .trailing)
        .environment(\.colorScheme, .dark)
    }
}

/// The expanded island's middle: the mode, then where it was sealed (during a pass, "Relocks in"; during
/// a timer lock, "Time left").
struct IslandTitle: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let open = isOpen(state, isStale: isStale)
        let over = state.timerIsOver(isStale: isStale)
        VStack(alignment: .leading, spacing: 2) {
            Text(over ? "Time's up" : open ? "Open" : state.modeName).font(.tHeadline).foregroundStyle(Color.ink)
            Text(over ? state.modeName : open ? "Relocks in" : subtitle)
                .font(.system(size: 13)).foregroundStyle(Color.inkSecondary)
        }
        .environment(\.colorScheme, .dark)
    }

    private var subtitle: String {
        if state.showsEndTime(isStale: isStale) { return "Ends at" }
        if state.timerEnd(isStale: isStale) != nil { return "Time left" }
        return state.placeName.map { "Sealed at \($0)" } ?? "Sealed"
    }
}

#if DEBUG
extension LockActivityAttributes.ContentState {
    /// A made-up activity for previews and the gallery: locked for `length` (see
    /// `LockSnapshot.sampleLockLengths`), or during a pass with 4:32 left.
    static func sample(lockedFor length: TimeInterval = 2832, open: Bool = false) -> Self {
        Self(lockedFrom: .now - length, openUntil: open ? .now + 272 : nil, modeName: "Deep work", placeName: "Kitchen")
    }

    /// A made-up 45-minute timer lock that ended a minute ago, for the stale "Time's up" look.
    static func sampleTimerDone() -> Self {
        Self(lockedFrom: .now - 46 * 60, openUntil: nil, modeName: "Deep work", placeName: "Kitchen", timerEndsAt: .now - 60)
    }

    /// A made-up timer lock of `length` with `left` to go (see `LockSnapshot.sampleTimers`).
    static func sampleTimer(length: TimeInterval, left: TimeInterval) -> Self {
        Self(lockedFrom: .now - (length - left), openUntil: nil, modeName: "Deep work", placeName: "Kitchen",
             timerEndsAt: .now + left)
    }
}

private let activityPreviewLocked = LockActivityAttributes.ContentState.sample()
private let activityPreviewOpen = LockActivityAttributes.ContentState.sample(open: true)
private let activityPreviewLong = LockActivityAttributes.ContentState.sample(lockedFor: LockSnapshot.sampleLockLengths[1])
private let activityPreviewVeryLong = LockActivityAttributes.ContentState.sample(lockedFor: LockSnapshot.sampleLockLengths[2])
private let activityPreviewTimer = LockActivityAttributes.ContentState.sampleTimer(
    length: LockSnapshot.sampleTimers[0].length, left: LockSnapshot.sampleTimers[0].left)
private let activityPreviewLongTimer = LockActivityAttributes.ContentState.sampleTimer(
    length: LockSnapshot.sampleTimers[1].length, left: LockSnapshot.sampleTimers[1].left)

#Preview("Lock Screen · timer, dark") {
    LockScreenCard(state: activityPreviewTimer, isStale: false)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · 10 h timer, light") {
    LockScreenCard(state: activityPreviewLongTimer, isStale: false)
        .background(Color.surface1).preferredColorScheme(.light)
}

#Preview("Lock Screen · time's up, dark") {
    LockScreenCard(state: .sampleTimerDone(), isStale: true)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · time's up, light") {
    LockScreenCard(state: .sampleTimerDone(), isStale: true)
        .background(Color.surface1).preferredColorScheme(.light)
}

#Preview("Lock Screen · dark") {
    LockScreenCard(state: activityPreviewLocked, isStale: false)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · light, open") {
    LockScreenCard(state: activityPreviewOpen, isStale: false)
        .background(Color.surface1).preferredColorScheme(.light)
}

#Preview("Lock Screen · stale, dark") {
    LockScreenCard(state: activityPreviewOpen, isStale: true)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · 10h 47m, dark") {
    LockScreenCard(state: activityPreviewVeryLong, isStale: false)
        .background(Color.surface1).preferredColorScheme(.dark)
}

#Preview("Lock Screen · 10h 47m, light") {
    LockScreenCard(state: activityPreviewVeryLong, isStale: false)
        .background(Color.surface1).preferredColorScheme(.light)
}

#Preview("Island orb · dark") {
    HStack {
        IslandOrb(state: activityPreviewLocked, isStale: false, size: 64)
        IslandOrb(state: activityPreviewOpen, isStale: false, size: 64)
    }
    .padding().background(Color.black).preferredColorScheme(.dark)
}

#Preview("Island timer · dark") {
    VStack(alignment: .trailing, spacing: Space.sm) {
        IslandTimer(state: activityPreviewLocked, isStale: false)
        IslandTimer(state: activityPreviewOpen, isStale: false)
        IslandTimer(state: activityPreviewLong, isStale: false)
        IslandTimer(state: activityPreviewVeryLong, isStale: false)
        IslandTimer(state: activityPreviewLocked, isStale: false, compact: true)
        IslandTimer(state: activityPreviewOpen, isStale: false, compact: true)
        IslandTimer(state: activityPreviewLong, isStale: false, compact: true)
        IslandTimer(state: activityPreviewVeryLong, isStale: false, compact: true)
        IslandTimer(state: activityPreviewTimer, isStale: false)
        IslandTimer(state: activityPreviewLongTimer, isStale: false, compact: true)
    }
    .padding().background(Color.black).preferredColorScheme(.dark)
}

#Preview("Island title · dark") {
    VStack(alignment: .leading, spacing: Space.sm) {
        IslandTitle(state: activityPreviewLocked, isStale: false)
        IslandTitle(state: activityPreviewOpen, isStale: false)
    }
    .padding().background(Color.black).preferredColorScheme(.dark)
}
#endif

/// `Text(timerInterval:)` ranges for the Live Activity: a count-up runs for a day (the activity
/// ends after 8 hours anyway), a pass counts down over its five minutes, and a timer lock counts down to its end.
enum LockActivityTiming {
    static let span: TimeInterval = 24 * 3600
    static let pass: TimeInterval = 5 * 60

    /// The range for counting down to a timer lock's `end`. Its start is the longest a timer can be before
    /// the end, so the text always shows the time left (never capped) and the range is valid even after the
    /// end has passed, which `now...end` would not be.
    static func countdown(to end: Date) -> ClosedRange<Date> {
        end.addingTimeInterval(-TimerLock.maximum)...end
    }

    /// The range for counting a lock up from `start`. Its end is at least 12 hours after the content was made
    /// (longer than an activity lives), so a lock older than a day, restarted after iOS's 8-hour limit,
    /// never freezes at 24:00:00.
    static func countUp(from start: Date, now: Date = .now) -> ClosedRange<Date> {
        start...max(start.addingTimeInterval(span), now.addingTimeInterval(12 * 3600))
    }
}
