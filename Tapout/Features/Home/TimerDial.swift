import SwiftUI

/// The timer sheet's two-lap dial (living glass only): 60 ticks on an outer ring for the first hour,
/// 60 on an inner ring for the second. Dragging around the ring moves the value relative to where it is,
/// in 5-minute steps from 5 min to 2 h, with a detent haptic per step. The length sits in the centre.
struct TimerDial: View {
    @Binding var minutes: Int

    /// The finger's angle at the last change; nil between drags (and while the finger is near the centre).
    @State private var previousAngle: Double?
    /// The unsnapped value the drag is carrying, so slow drags still add up to a step.
    @State private var raw: Double = 0

    static let size: CGFloat = 288
    private static let outerRadius: CGFloat = 132
    private static let innerRadius: CGFloat = 108
    private static let handleSize: CGFloat = 22
    /// Touches this close to the centre would spin wildly, so they are ignored.
    private static let deadZone: CGFloat = 60

    private var seconds: TimeInterval { TimeInterval(minutes * 60) }

    var body: some View {
        ZStack {
            ticks
            handle
            // Fraunces at `.numberDisplay`'s 48 pt, in fixed digit slots so the length doesn't shift as it ticks;
            // smaller sizes for the longest lengths ("1 h 55 min") so it stays inside the inner ring.
            ViewThatFits(in: .horizontal) {
                FixedDigitText(text: TimeFormat.length(seconds), size: 48)
                FixedDigitText(text: TimeFormat.length(seconds), size: 40)
                FixedDigitText(text: TimeFormat.length(seconds), size: 34)
                FixedDigitText(text: TimeFormat.length(seconds), size: 28)
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: 2 * (Self.innerRadius - 16))
        }
        .frame(width: Self.size, height: Self.size)
        .contentShape(Circle())
        .gesture(drag)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duration")
        .accessibilityValue(TimeFormat.spokenLength(seconds))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(DialMath.maximum, minutes + DialMath.step)
            case .decrement: minutes = max(DialMath.minimum, minutes - DialMath.step)
            @unknown default: break
            }
        }
    }

    // MARK: - Drawing

    /// Drawn straight from `minutes`, with no implicit animation, so the ticks snap (Reduce Motion safe).
    private var ticks: some View {
        let lit = DialMath.litTicks(minutes: minutes)
        return Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            for (radius, litCount) in [(Self.outerRadius, lit.outer), (Self.innerRadius, lit.inner)] {
                for index in 0..<60 {
                    let major = index % 5 == 0
                    let length: CGFloat = major ? 12 : 7
                    let radians = Double(index) * 6 * .pi / 180
                    let dx = CGFloat(sin(radians)), dy = CGFloat(-cos(radians))
                    var path = Path()
                    path.move(to: CGPoint(x: centre.x + dx * (radius - length / 2),
                                          y: centre.y + dy * (radius - length / 2)))
                    path.addLine(to: CGPoint(x: centre.x + dx * (radius + length / 2),
                                             y: centre.y + dy * (radius + length / 2)))
                    context.stroke(path, with: .color(index < litCount ? Color.emberLine : Color.track),
                                   style: StrokeStyle(lineWidth: major ? 2.4 : 1.6, lineCap: .round))
                }
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }

    private var handle: some View {
        let position = DialMath.handle(minutes: minutes)
        let radius = position.lap == 0 ? Self.outerRadius : Self.innerRadius
        let radians = position.angle * .pi / 180
        return Circle()
            .fill(Color.ember)
            .overlay(Circle().strokeBorder(Color.surface1, lineWidth: 3))
            .frame(width: Self.handleSize, height: Self.handleSize)
            .offset(x: CGFloat(sin(radians)) * radius, y: CGFloat(-cos(radians)) * radius)
            .accessibilityHidden(true)
    }

    // MARK: - Gesture

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let dx = Double(value.location.x - Self.size / 2)
                let dy = Double(value.location.y - Self.size / 2)
                guard (dx * dx + dy * dy).squareRoot() >= Double(Self.deadZone) else {
                    // Near the centre: drop the reference so leaving the dead zone starts afresh.
                    previousAngle = nil
                    return
                }
                let angle = DialMath.angle(dx: dx, dy: dy)
                guard let previous = previousAngle else {
                    previousAngle = angle
                    raw = Double(minutes)
                    return
                }
                raw = DialMath.dragged(minutes: raw, from: previous, to: angle)
                previousAngle = angle
                let snapped = DialMath.snapped(raw, holding: minutes)
                if snapped != minutes {
                    minutes = snapped
                    HapticEngine.shared.play(.detent)
                }
            }
            .onEnded { _ in previousAngle = nil }
    }
}

#if DEBUG
private struct DialPreview: View {
    @State var minutes: Int
    var body: some View {
        TimerDial(minutes: $minutes)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surface1)
    }
}

#Preview("Dial 45 · dark") { DialPreview(minutes: 45).preferredColorScheme(.dark) }
#Preview("Dial 85 · light") { DialPreview(minutes: 85).preferredColorScheme(.light) }
#endif
