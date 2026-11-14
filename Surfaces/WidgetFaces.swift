import SwiftUI
import WidgetKit

/// The widgets' faces, from design/screens/Widgets.dc.html. In `Surfaces/` so the app's DEBUG gallery
/// can show them too. Timers tick on their own: the lock counts up with `Text(date, style: .timer)`,
/// and a pass counts down from the entry's date to its relock time and stops at 0:00. Each face takes
/// the entry's date and draws `snapshot.state(at: date)`, so a pass whose time has come shows the lock.

/// Small: the lock with its timer, a pass with its countdown, or today's phone-free time.
struct SmallFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now
    var tinted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            orb
            Spacer(minLength: 0)
            value
            label
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private var orb: some View {
        if tinted {
            if case .unlocked = snapshot.state(at: date) {
                FlatOrb(ring: false, size: 64)
            } else {
                FlatOrb(ring: true, size: 64)
            }
        } else {
            glassOrb
        }
    }

    @ViewBuilder private var glassOrb: some View {
        switch snapshot.state(at: date) {
        case .locked: OrbView(tone: .ember, ring: 1, size: 64)
        case .open: OrbView(tone: .slate, ringTone: .ember, ring: 1, size: 64)
        case .unlocked: OrbView(tone: .slate, size: 64)
        }
    }

    @ViewBuilder private var value: some View {
        switch snapshot.state(at: date) {
        case .locked(let from):
            Text(from, style: .timer).font(.system(size: 34, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .open(let relockAt, _):
            Text(timerInterval: date...relockAt, countsDown: true)
                .font(.system(size: 34, weight: .light).monospacedDigit()).foregroundStyle(Color.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .unlocked:
            Text(TimeFormat.short(snapshot.today)).font(.numberMedium).foregroundStyle(Color.ink)
        }
    }

    @ViewBuilder private var label: some View {
        switch snapshot.state(at: date) {
        case .locked: Text("Locked").font(.tCaption).foregroundStyle(Color.emberInk)
        case .open: Text("Open").font(.tCaption).foregroundStyle(Color.emberInk)
        case .unlocked: Text("today").font(.tCaption).foregroundStyle(Color.slateInk)
        }
    }
}

/// Medium: this week's phone-free time and a bar per day, today in ember.
struct MediumFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now
    var tinted: Bool = false

    var body: some View {
        HStack(spacing: 20) {
            orb
            VStack(alignment: .leading, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeFormat.short(snapshot.weekTotal)).font(.numberDisplay).foregroundStyle(Color.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("phone-free this week").font(.tCaption).foregroundStyle(Color.inkSecondary)
                }
                bars
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var orb: some View {
        let unlocked: Bool = if case .unlocked = snapshot.state(at: date) { true } else { false }
        if tinted {
            FlatOrb(ring: !unlocked, size: 112)
        } else if unlocked {
            OrbView(tone: .slate, size: 112)
        } else {
            OrbView(tone: .ember, ring: 1, size: 112)
        }
    }

    private var bars: some View {
        let peak = max(snapshot.days.map(\.lockedTime).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(snapshot.days, id: \.start) { day in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(day.isToday ? Color.ember : Color.surface2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 6 + 34 * day.lockedTime / peak)
                    .widgetAccentable(tinted && day.isToday)
            }
        }
        .frame(height: 40, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// The orb for tinted and clear Home Screen widgets, where iOS flattens colour: a soft disc, and
/// the seal ring drawn in the accent group so it takes the tint.
struct FlatOrb: View {
    var ring: Bool
    var size: CGFloat

    var body: some View {
        ZStack {
            // The one non-token colour: in tinted mode iOS replaces colour, so a neutral is correct.
            Circle().fill(.white.opacity(0.18)).frame(width: size * 0.74, height: size * 0.74)
            if ring {
                Circle().stroke(lineWidth: size * 0.05).widgetAccentable()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Lock Screen circular: iOS tints it, so it uses no token colours.
struct CircularFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).widgetAccentable()
                Group {
                    switch snapshot.state(at: date) {
                    case .locked(let from): Text(from, style: .timer)
                    case .open(let relockAt, _): Text(timerInterval: date...relockAt, countsDown: true)
                    case .unlocked: Text(TimeFormat.short(snapshot.today))
                    }
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            .padding(4)
        }
    }

    private var symbol: String {
        if case .unlocked = snapshot.state(at: date) { "lock.open" } else { "lock.fill" }
    }
}

/// Lock Screen rectangular: the state, the time, and the mode while locked.
struct RectangularFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(title, systemImage: symbol).font(.headline).widgetAccentable()
            Group {
                switch snapshot.state(at: date) {
                case .locked(let from): Text(from, style: .timer)
                case .open(let relockAt, _): Text("Relocks in \(Text(timerInterval: date...relockAt, countsDown: true))")
                case .unlocked: Text("\(TimeFormat.short(snapshot.today)) today")
                }
            }
            .font(.body.monospacedDigit())
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            if case .unlocked = snapshot.state(at: date) {} else {
                Text(snapshot.modeName).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        switch snapshot.state(at: date) {
        case .locked: "Locked"
        case .open: "Open"
        case .unlocked: "Unlocked"
        }
    }

    private var symbol: String {
        if case .unlocked = snapshot.state(at: date) { "lock.open" } else { "lock.fill" }
    }
}

// MARK: Previews

private let previewLocked = LockSnapshot.sample(.locked(countingFrom: .now - 2832))
private let previewLockedLong = LockSnapshot.sampleLocked(for: LockSnapshot.sampleLockLengths[1])
private let previewLockedVeryLong = LockSnapshot.sampleLocked(for: LockSnapshot.sampleLockLengths[2])
private let previewOpen = LockSnapshot.sample(.open(relockAt: .now + 272, resumesFrom: .now - 2832))
private let previewUnlocked = LockSnapshot.sample(.unlocked)

private struct FacePreview<Face: View>: View {
    let width: CGFloat
    let height: CGFloat
    let scheme: ColorScheme
    @ViewBuilder let face: Face

    var body: some View {
        face
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.surface1, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
            .background(Color.bg)
            .environment(\.colorScheme, scheme)
    }
}

#Preview("Small · locked · dark") { FacePreview(width: 170, height: 170, scheme: .dark) { SmallFace(snapshot: previewLocked) } }
#Preview("Small · locked · light") { FacePreview(width: 170, height: 170, scheme: .light) { SmallFace(snapshot: previewLocked) } }
#Preview("Small · open · dark") { FacePreview(width: 170, height: 170, scheme: .dark) { SmallFace(snapshot: previewOpen) } }
#Preview("Small · open · light") { FacePreview(width: 170, height: 170, scheme: .light) { SmallFace(snapshot: previewOpen) } }
#Preview("Small · unlocked · dark") { FacePreview(width: 170, height: 170, scheme: .dark) { SmallFace(snapshot: previewUnlocked) } }
#Preview("Small · unlocked · light") { FacePreview(width: 170, height: 170, scheme: .light) { SmallFace(snapshot: previewUnlocked) } }
#Preview("Medium · dark") { FacePreview(width: 364, height: 170, scheme: .dark) { MediumFace(snapshot: previewLocked) } }
#Preview("Medium · light") { FacePreview(width: 364, height: 170, scheme: .light) { MediumFace(snapshot: previewLocked) } }
#Preview("Circular · dark") { FacePreview(width: 76, height: 76, scheme: .dark) { CircularFace(snapshot: previewLocked) } }
#Preview("Circular · light") { FacePreview(width: 76, height: 76, scheme: .light) { CircularFace(snapshot: previewLocked) } }
#Preview("Rectangular · dark") { FacePreview(width: 172, height: 76, scheme: .dark) { RectangularFace(snapshot: previewOpen) } }
#Preview("Rectangular · light") { FacePreview(width: 172, height: 76, scheme: .light) { RectangularFace(snapshot: previewOpen) } }
#Preview("Small · 1h 47m · dark") { FacePreview(width: 170, height: 170, scheme: .dark) { SmallFace(snapshot: previewLockedLong) } }
#Preview("Small · 10h 47m · light") { FacePreview(width: 170, height: 170, scheme: .light) { SmallFace(snapshot: previewLockedVeryLong) } }
#Preview("Small · 10h 47m · dark") { FacePreview(width: 170, height: 170, scheme: .dark) { SmallFace(snapshot: previewLockedVeryLong) } }
#Preview("Circular · 10h 47m · dark") { FacePreview(width: 76, height: 76, scheme: .dark) { CircularFace(snapshot: previewLockedVeryLong) } }
#Preview("Circular · 10h 47m · light") { FacePreview(width: 76, height: 76, scheme: .light) { CircularFace(snapshot: previewLockedVeryLong) } }
#Preview("Rectangular · 10h 47m · dark") { FacePreview(width: 172, height: 76, scheme: .dark) { RectangularFace(snapshot: previewLockedVeryLong) } }
#Preview("Rectangular · 10h 47m · light") { FacePreview(width: 172, height: 76, scheme: .light) { RectangularFace(snapshot: previewLockedVeryLong) } }

private struct TintedPreview<Face: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder let face: Face

    var body: some View {
        face
            .padding(16)
            .frame(width: width, height: height)
            .background(Color.slate.opacity(0.35), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
            .background(Color.bg)
            .environment(\.colorScheme, .dark)
    }
}

#Preview("Small · locked · tinted") { TintedPreview(width: 170, height: 170) { SmallFace(snapshot: previewLocked, tinted: true) } }
#Preview("Small · open · tinted") { TintedPreview(width: 170, height: 170) { SmallFace(snapshot: previewOpen, tinted: true) } }
#Preview("Small · unlocked · tinted") { TintedPreview(width: 170, height: 170) { SmallFace(snapshot: previewUnlocked, tinted: true) } }
#Preview("Medium · tinted") { TintedPreview(width: 364, height: 170) { MediumFace(snapshot: previewLocked, tinted: true) } }
