#if DEBUG
import SwiftUI
import WidgetKit

/// DEBUG-only: the widget faces at their real sizes, for the live store and sample states (including
/// long locks), so the simulator can show and screenshot them without adding widgets by hand.
struct SurfaceGallery: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    row("Now", model.lockSnapshot(at: context.date), date: context.date)
                }
                row("Locked", .sample(.locked(countingFrom: .now - 2832)))
                row("Locked · 1h 47m", .sampleLocked(for: LockSnapshot.sampleLockLengths[1]))
                row("Locked · 10h 47m", .sampleLocked(for: LockSnapshot.sampleLockLengths[2]))
                row("Timer · 45 min, 31 min left", timerSample(0))
                row("Timer · 10 h", timerSample(1))
                row("Open", .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
                row("Unlocked", .sample(.unlocked))
                tintedSection
                liveActivityRow
            }
            .padding(Space.md)
        }
        .background(Color.bg)
        .navigationTitle("Widgets")
    }

    private func timerSample(_ index: Int) -> LockSnapshot {
        let timer = LockSnapshot.sampleTimers[index]
        return .sampleTimer(length: timer.length, left: timer.left)
    }

    private func row(_ title: String, _ snapshot: LockSnapshot, date: Date = .now) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title).font(.tHeadline)
            HStack(alignment: .top, spacing: Space.sm) {
                tile(SmallFace(snapshot: snapshot, date: date), width: 170, height: 170)
                VStack(spacing: Space.sm) {
                    tile(CircularFace(snapshot: snapshot, date: date), width: 76, height: 76, radius: 38)
                    tile(RectangularFace(snapshot: snapshot, date: date), width: 172, height: 76, radius: 16)
                }
            }
            tile(MediumFace(snapshot: snapshot, date: date), width: 364, height: 170)
        }
    }

    /// The flat-orb faces iOS draws in tinted and clear modes, on a slate wash standing in for a tinted Home Screen.
    private var tintedSection: some View {
        let small: [(String, LockSnapshot)] = [
            ("Locked", .sample(.locked(countingFrom: .now - 2832))),
            ("Open", .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832))),
            ("Timer", timerSample(0)),
            ("Unlocked", .sample(.unlocked)),
        ]
        return VStack(alignment: .leading, spacing: Space.xs) {
            Text("Tinted").font(.tHeadline)
            ForEach(small, id: \.0) { _, snapshot in
                tintedTile(SmallFace(snapshot: snapshot, tinted: true), width: 170, height: 170)
            }
            tintedTile(MediumFace(snapshot: small[0].1, tinted: true), width: 364, height: 170)
        }
    }

    private func tintedTile(_ face: some View, width: CGFloat, height: CGFloat) -> some View {
        face
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.slate.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var liveActivityRow: some View {
        // The last one is stale: a timer that ended with Tapout closed.
        let states: [(String, LockActivityAttributes.ContentState, Bool)] = [
            ("47m", .sample(), false),
            ("1h 47m", .sample(lockedFor: LockSnapshot.sampleLockLengths[1]), false),
            ("10h 47m", .sample(lockedFor: LockSnapshot.sampleLockLengths[2]), false),
            ("Open", .sample(open: true), false),
            ("Timer 31m left", .sampleTimer(length: LockSnapshot.sampleTimers[0].length, left: LockSnapshot.sampleTimers[0].left), false),
            ("Timer 10 h", .sampleTimer(length: LockSnapshot.sampleTimers[1].length, left: LockSnapshot.sampleTimers[1].left), false),
            ("Time's up", .sampleTimerDone(), true),
        ]
        return VStack(alignment: .leading, spacing: Space.xs) {
            Text("Live Activity").font(.tHeadline)
            ForEach(states, id: \.0) { _, state, stale in
                LockScreenCard(state: state, isStale: stale)
                    .frame(width: 364)
                    .background(Color.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            ForEach(states, id: \.0) { _, state, stale in
                HStack(spacing: Space.xs) {
                    IslandOrb(state: state, isStale: stale, size: 26)
                    Spacer(minLength: 0)
                    IslandTimer(state: state, isStale: stale, compact: true)
                }
                .padding(.horizontal, 10)
                .frame(width: 250, height: 37)
                .background(Color.black, in: Capsule())
            }
            ForEach(states, id: \.0) { _, state, stale in
                HStack(spacing: Space.sm) {
                    IslandOrb(state: state, isStale: stale, size: 64)
                    IslandTitle(state: state, isStale: stale)
                    Spacer(minLength: 0)
                    IslandTimer(state: state, isStale: stale)
                }
                .padding(Space.md)
                .frame(width: 364)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
            }
        }
    }

    private func tile(_ face: some View, width: CGFloat, height: CGFloat, radius: CGFloat = 22) -> some View {
        face
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

#Preview("Surface gallery · dark") {
    NavigationStack { SurfaceGallery(model: DemoData.previewModel()) }.preferredColorScheme(.dark)
}

#Preview("Surface gallery · light") {
    NavigationStack { SurfaceGallery(model: DemoData.previewModel()) }.preferredColorScheme(.light)
}
#endif
