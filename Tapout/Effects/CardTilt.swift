import SwiftUI
import UIKit

/// Pure numbers for a card leaning under a resting finger.
enum CardTilt {
    /// The most the card turns about each axis, in degrees.
    static let maxX = 4.0
    static let maxY = 5.0
    /// How far a finger may drift before the card lets go: past this it is a scroll, not a touch.
    static let slop: CGFloat = 12

    /// Degrees about the x and y axes that push the touched side of the card back.
    static func angles(at point: CGPoint, in size: CGSize) -> (x: Double, y: Double) {
        guard size.width > 0, size.height > 0 else { return (0, 0) }
        let across = min(max(point.x / size.width, 0), 1)
        let down = min(max(point.y / size.height, 0), 1)
        return ((0.5 - down) * 2 * maxX, (across - 0.5) * 2 * maxY)
    }

    static func letsGo(from start: CGPoint, to point: CGPoint) -> Bool {
        hypot(point.x - start.x, point.y - start.y) > slop
    }
}

/// Reports a resting finger without taking the touch from anything else: it begins at once, runs alongside
/// every other recognizer and cancels nothing, so buttons still tap and the page still scrolls.
@available(iOS 18.0, *)
private struct TouchTracker: UIGestureRecognizerRepresentable {
    /// The finger's position in the view, or nil once it has lifted or moved away.
    let onChange: (CGPoint?) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.08 // long enough that a quick flick never tilts
        recognizer.allowableMovement = .greatestFiniteMagnitude
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let point = context.converter.localLocation
        switch recognizer.state {
        case .began:
            context.coordinator.start = recognizer.location(in: nil)
            onChange(point)
        case .changed:
            // Window coordinates: the card itself moves when the page scrolls under the finger.
            if let start = context.coordinator.start, !CardTilt.letsGo(from: start, to: recognizer.location(in: nil)) {
                onChange(point)
            } else {
                context.coordinator.start = nil
                onChange(nil)
            }
        default:
            context.coordinator.start = nil
            onChange(nil)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var start: CGPoint?

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private struct FingerTilt: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var size = CGSize.zero
    @State private var touch: CGPoint?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            let angles = touch.map { CardTilt.angles(at: $0, in: size) } ?? (x: 0, y: 0)
            content
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { size = proxy.size }
                            .onChange(of: proxy.size) { _, new in size = new }
                    }
                }
                .gesture(TouchTracker { touch = $0 })
                .rotation3DEffect(.degrees(angles.x), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                .rotation3DEffect(.degrees(angles.y), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .animation(Motion.scrub, value: touch)
        } else {
            content
        }
    }
}

extension View {
    /// The card leans under a resting finger (iOS 18 and later, not with Reduce Motion).
    /// `false` leaves the view untouched.
    @ViewBuilder
    func fingerTilt(_ isOn: Bool = true) -> some View {
        if isOn { modifier(FingerTilt()) } else { self }
    }
}
