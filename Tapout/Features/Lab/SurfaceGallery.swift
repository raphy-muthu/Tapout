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
                row("Open", .sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832)))
                row("Unlocked", .sample(.unlocked))
                liveActivityRow
            }
            .padding(Space.md)
        }
        .background(Color.bg)
        .navigationTitle("Widgets")
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

    private var liveActivityRow: some View {
        let states: [(String, LockActivityAttributes.ContentState)] = [
            ("47m", .sample()),
            ("1h 47m", .sample(lockedFor: LockSnapshot.sampleLockLengths[1])),
            ("10h 47m", .sample(lockedFor: LockSnapshot.sampleLockLengths[2])),
            ("Open", .sample(open: true)),
        ]
        return VStack(alignment: .leading, spacing: Space.xs) {
            Text("Live Activity").font(.tHeadline)
            ForEach(states, id: \.0) { _, state in
                LockScreenCard(state: state, isStale: false)
                    .frame(width: 364)
                    .background(Color.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            ForEach(states, id: \.0) { _, state in
                HStack(spacing: Space.xs) {
                    IslandOrb(state: state, isStale: false, size: 26)
                    Spacer(minLength: 0)
                    IslandTimer(state: state, isStale: false, compact: true)
                }
                .padding(.horizontal, 10)
                .frame(width: 250, height: 37)
                .background(Color.black, in: Capsule())
            }
            ForEach(states, id: \.0) { _, state in
                HStack(spacing: Space.sm) {
                    IslandOrb(state: state, isStale: false, size: 64)
                    IslandTitle(state: state, isStale: false)
                    Spacer(minLength: 0)
                    IslandTimer(state: state, isStale: false)
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
