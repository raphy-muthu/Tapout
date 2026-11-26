import SwiftUI
import UIKit

/// Tap and sideways drag over a chart. These are UIKit recognizers because a SwiftUI `DragGesture` here,
/// even a simultaneous one, stops the page scrolling when a swipe starts on the chart. This pan refuses to
/// begin unless it starts out sideways, which leaves every other swipe to the scroll view.
private struct ScrubSurface: UIViewRepresentable {
    let onTap: (CGPoint) -> Void
    let onScrub: (_ start: CGPoint, _ location: CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onScrub = onScrub
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (CGPoint) -> Void = { _ in }
        var onScrub: (CGPoint, CGPoint) -> Void = { _, _ in }
        /// Where the finger went down for the drag in progress.
        private var start = CGPoint.zero

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            onTap(recognizer.location(in: recognizer.view))
        }

        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .began || recognizer.state == .changed else { return }
            let location = recognizer.location(in: recognizer.view)
            if recognizer.state == .began {
                let moved = recognizer.translation(in: recognizer.view)
                start = CGPoint(x: location.x - moved.x, y: location.y - moved.y)
            }
            onScrub(start, location)
        }

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return ChartScrub.isSideways(dx: velocity.x, dy: velocity.y)
        }
    }
}

extension View {
    /// Points are in this view's own coordinates.
    func scrubbable(onTap: @escaping (CGPoint) -> Void,
                    onScrub: @escaping (_ start: CGPoint, _ location: CGPoint) -> Void) -> some View {
        overlay { ScrubSurface(onTap: onTap, onScrub: onScrub).accessibilityHidden(true) }
    }
}
