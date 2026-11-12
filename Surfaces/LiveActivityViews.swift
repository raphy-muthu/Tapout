import SwiftUI

/// The Live Activity from design/screens/LiveActivity.dc.html. During a pass (and until its stale date),
/// a slate orb, "Open" and the countdown; otherwise the ember orb and the locked timer.
private func isOpen(_ state: LockActivityAttributes.ContentState, isStale: Bool) -> Bool {
    state.openUntil != nil && !isStale
}

/// The Lock Screen card. Follows the system appearance.
struct LockScreenCard: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let open = isOpen(state, isStale: isStale)
        HStack(spacing: Space.md) {
            OrbView(tone: open ? .slate : .ember, ringTone: .ember, ring: 1, size: 80)
            VStack(alignment: .leading, spacing: 2) {
                if open, let until = state.openUntil {
                    Text("Open · Relocks in").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    timer(until, countsDown: true)
                    Text(caption).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                } else {
                    timer(state.lockedFrom)
                    Label(caption, systemImage: "lock").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.emberInk)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func timer(_ date: Date, countsDown: Bool = false) -> some View {
        Group {
            if countsDown {
                Text(timerInterval: date.addingTimeInterval(-LockActivityTiming.pass)...date, countsDown: true)
            } else {
                Text(timerInterval: date...date.addingTimeInterval(LockActivityTiming.span), countsDown: false)
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
        OrbView(tone: isOpen(state, isStale: isStale) ? .slate : .ember, ringTone: .ember, ring: 1, size: size)
            .environment(\.colorScheme, .dark)
    }
}

/// The island's timer: the countdown during a pass, the locked timer otherwise. The compact one has a
/// fixed width so the island doesn't jump as digits change; both shrink to fit locks of 10 hours and up.
struct IslandTimer: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool
    var compact = false

    var body: some View {
        Group {
            if isOpen(state, isStale: isStale), let until = state.openUntil {
                Text(timerInterval: until.addingTimeInterval(-LockActivityTiming.pass)...until, countsDown: true)
            } else {
                Text(timerInterval: state.lockedFrom...state.lockedFrom.addingTimeInterval(LockActivityTiming.span), countsDown: false)
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

/// The expanded island's middle: the mode, then where it was sealed (or, during a pass, "Relocks in").
struct IslandTitle: View {
    let state: LockActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let open = isOpen(state, isStale: isStale)
        VStack(alignment: .leading, spacing: 2) {
            Text(open ? "Open" : state.modeName).font(.tHeadline).foregroundStyle(Color.ink)
            Text(open ? "Relocks in" : (state.placeName.map { "Sealed at \($0)" } ?? "Sealed"))
                .font(.system(size: 13)).foregroundStyle(Color.inkSecondary)
        }
        .environment(\.colorScheme, .dark)
    }
}

#if DEBUG
extension LockActivityAttributes.ContentState {
    /// A made-up activity for previews and the gallery: locked for `length` (see
    /// `LockSnapshot.sampleLockLengths`), or during a pass with 4:32 left.
    static func sample(lockedFor length: TimeInterval = 2832, open: Bool = false) -> Self {
        Self(lockedFrom: .now - length, openUntil: open ? .now + 272 : nil, modeName: "Deep work", placeName: "Kitchen")
    }
}

private let activityPreviewLocked = LockActivityAttributes.ContentState.sample()
private let activityPreviewOpen = LockActivityAttributes.ContentState.sample(open: true)
private let activityPreviewLong = LockActivityAttributes.ContentState.sample(lockedFor: LockSnapshot.sampleLockLengths[1])
private let activityPreviewVeryLong = LockActivityAttributes.ContentState.sample(lockedFor: LockSnapshot.sampleLockLengths[2])

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
/// ends after 8 hours anyway), and a pass counts down over its five minutes.
enum LockActivityTiming {
    static let span: TimeInterval = 24 * 3600
    static let pass: TimeInterval = 5 * 60
}
