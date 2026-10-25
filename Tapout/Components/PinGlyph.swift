import SwiftUI

/// The spec's place pin (Places tab, place pill): a teardrop outline with a dot,
/// drawn from the 24×24 SVG path in design/screens/TabBar.dc.html.
struct PinGlyph: View {
    var size: CGFloat = 24
    var lineWidth: CGFloat = 1.6

    var body: some View {
        PinShape()
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}

private struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        path.move(to: point(12, 21))
        path.addCurve(to: point(5.5, 10), control1: point(12, 21), control2: point(5.5, 15.4))
        path.addArc(center: point(12, 10), radius: 6.5 * scale,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addCurve(to: point(12, 21), control1: point(18.5, 15.4), control2: point(12, 21))
        path.closeSubpath()
        path.addEllipse(in: CGRect(origin: point(9.7, 7.7), size: CGSize(width: 4.6 * scale, height: 4.6 * scale)))
        return path
    }
}
