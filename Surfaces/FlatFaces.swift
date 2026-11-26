import SwiftUI
import WidgetKit

/// The Living glass switch's Home Screen widgets: a flat field of the state's color, near-black text and
/// big numbers, no orb. Words and color come from `FlatPoster`. The field is the widget's container background,
/// so these faces draw only what sits on it.

extension OrbTone {
    var field: Color { self == .ember ? .ember : .slate }
    var onField: Color { self == .ember ? .onEmber : .onSlate }

    /// The text color on a flat widget. Where iOS has taken the background away (StandBy, tinted and clear
    /// Home Screens), near-black would vanish: the state color in full color, the system's own otherwise.
    func flatInk(hasBackground: Bool, fullColor: Bool) -> Color {
        guard fullColor else { return .primary }
        return hasBackground ? onField : field
    }
}

/// A flat surface's small uppercase words.
struct FlatHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy))
            .textCase(.uppercase)
            .tracking(0.6)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

extension View {
    /// A number that ticks: SF Pro, heavy, one line that shrinks for long times.
    /// (`Text(timerInterval:)` can't use `FixedDigitText`, so it can't be Fraunces.)
    func flatTimer(_ size: CGFloat) -> some View {
        font(.system(size: size, weight: .heavy).monospacedDigit())
            .multilineTextAlignment(.leading)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
    }
}

/// Small: the state on top, one big number, a few words below.
struct FlatSmallFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now

    @Environment(\.showsWidgetContainerBackground) private var hasBackground
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let poster = FlatPoster.home(snapshot, date: date)
        VStack(alignment: .leading, spacing: 0) {
            FlatHeading(text: poster.heading).widgetAccentable()
            Spacer(minLength: 2)
            number
            Spacer(minLength: 2)
            if let footer = poster.footer {
                Text(footer).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(poster.tone.flatInk(hasBackground: hasBackground, fullColor: renderingMode == .fullColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private var number: some View {
        switch snapshot.state(at: date) {
        case .locked(let from):
            if let end = snapshot.timerEndsAt {
                Text(timerInterval: LockActivityTiming.countdown(to: end), countsDown: true).flatTimer(48)
            } else {
                Text(from, style: .timer).flatTimer(48)
            }
        case .open(let relockAt, _):
            Text(timerInterval: date...relockAt, countsDown: true).flatTimer(48)
        case .unlocked:
            VStack(alignment: .leading, spacing: -6) {
                ForEach(FlatPoster.stacked(snapshot.today), id: \.self) { line in
                    Text(line).font(.numberPoster).lineLimit(1).minimumScaleFactor(0.6)
                }
            }
        }
    }
}

/// Medium: this week's total (the time left during a timer lock) over seven bars, today solid.
struct FlatMediumFace: View {
    let snapshot: LockSnapshot
    var date: Date = .now

    @Environment(\.showsWidgetContainerBackground) private var hasBackground
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// The timer's end while a timer lock is on screen.
    private var countingTo: Date? {
        if case .locked = snapshot.state(at: date) { snapshot.timerEndsAt } else { nil }
    }

    var body: some View {
        let ink = FlatPoster.home(snapshot, date: date).tone
            .flatInk(hasBackground: hasBackground, fullColor: renderingMode == .fullColor)
        VStack(alignment: .leading, spacing: 4) {
            FlatHeading(text: countingTo == nil ? "Phone-free this week" : "Time left").widgetAccentable()
            if let countingTo {
                Text(timerInterval: LockActivityTiming.countdown(to: countingTo), countsDown: true).flatTimer(48)
            } else {
                Text(TimeFormat.short(snapshot.weekTotal)).font(.numberPoster).lineLimit(1).minimumScaleFactor(0.5)
            }
            Spacer(minLength: 0)
            bars(ink)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func bars(_ ink: Color) -> some View {
        let peak = max(snapshot.days.map(\.lockedTime).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(snapshot.days, id: \.start) { day in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(ink.opacity(day.isToday ? 1 : 0.32))
                    .frame(maxWidth: .infinity)
                    .frame(height: 8 + 36 * day.lockedTime / peak)
                    .widgetAccentable(day.isToday)
            }
        }
        .frame(height: 44, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

#if DEBUG
private struct FlatPreview<Face: View>: View {
    let width: CGFloat
    let snapshot: LockSnapshot
    @ViewBuilder let face: Face

    var body: some View {
        face
            .padding(16)
            .frame(width: width, height: 170)
            .background(FlatPoster.home(snapshot, date: .now).tone.field,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview("Flat · small and medium") {
    let locked = LockSnapshot.sample(.locked(countingFrom: .now - 2832))
    let unlocked = LockSnapshot.sample(.unlocked)
    return VStack {
        HStack {
            FlatPreview(width: 170, snapshot: locked) { FlatSmallFace(snapshot: locked) }
            FlatPreview(width: 170, snapshot: unlocked) { FlatSmallFace(snapshot: unlocked) }
        }
        FlatPreview(width: 364, snapshot: unlocked) { FlatMediumFace(snapshot: unlocked) }
    }
}
#endif
