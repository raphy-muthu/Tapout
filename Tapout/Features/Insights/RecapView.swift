import SwiftUI
import UniformTypeIdentifiers

/// The weekly recap story from design/screens/Recap.dc.html, laid out at 360 × 640 points and
/// rendered at 3× into a 1080 × 1920 image for sharing (Instagram Stories' size).
/// Every size is the design's pixel value divided by three, and fixed, so Dynamic Type can't change the image.
struct RecapView: View {
    let weekStart: Date
    let total: TimeInterval
    let days: [Insights.Day]
    let comparison: Comparison?

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 3) {
                Text("Tapout")
                    .font(Font.recapWordmark)
                    .foregroundStyle(Color.ink)
                Text("Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
            }
            OrbView(tone: .ember, ring: 1, size: 187).padding(.top, 19)
            VStack(spacing: 1) {
                Text(TimeFormat.short(total))
                    .font(Font.recapTotal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Color.ink)
                Text("phone-free").font(.system(size: 16)).foregroundStyle(Color.inkSecondary)
            }
            .padding(.top, 11)
            if let comparison {
                HStack(spacing: 13) {
                    Image(systemName: comparison.symbol)
                        .font(.system(size: 21))
                        .foregroundStyle(Color.emberInk)
                        .frame(width: 40, height: 40)
                        .background(Color.emberGlow, in: Circle())
                    Text(comparison.asLongAs(total))
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 19)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(Color.surface1, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .cardShadow()
                .padding(.top, 19)
            }
            Spacer(minLength: 0)
            bars
            // The design's 80pt bottom inset, which gives way when the comparison card wraps.
            Spacer(minLength: 0).frame(maxHeight: 80)
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color.bg)
    }

    private var bars: some View {
        let peak = max(days.map(\.lockedTime).max() ?? 0, 1)
        return VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.start) { day in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(day.isToday ? Color.ember : Color.surface2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 8 + 45 * day.lockedTime / peak)
                }
            }
            .frame(height: 53, alignment: .bottom)
            HStack(spacing: 8) {
                ForEach(days, id: \.start) { day in
                    Text(day.letter)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

enum RecapImage {
    /// The recap at `scale`x (3x is the shared 1080 x 1920 image; 1x is the share sheet thumbnail).
    @MainActor static func render(_ view: RecapView, colorScheme: ColorScheme, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, colorScheme))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(RecapView.size)
        return renderer.uiImage
    }
}

/// The shared recap. The full image is rendered only when the share sheet asks for it.
struct RecapShare: Transferable, Sendable {
    let weekStart: Date
    let total: TimeInterval
    let days: [Insights.Day]
    let comparison: Comparison?
    let colorScheme: ColorScheme

    func pngData() async -> Data? {
        await MainActor.run {
            let view = RecapView(weekStart: weekStart, total: total, days: days, comparison: comparison)
            return RecapImage.render(view, colorScheme: colorScheme)?.pngData()
        }
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { share in
            guard let data = await share.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
    }
}

#Preview("Recap · dark") {
    let sample = LockSnapshot.sample(.unlocked)
    return RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                     comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        .preferredColorScheme(.dark)
}

#Preview("Recap · light") {
    let sample = LockSnapshot.sample(.unlocked)
    return RecapView(weekStart: .now, total: sample.weekTotal, days: sample.days,
                     comparison: Comparison.best(for: sample.weekTotal, interests: [.sports]))
        .preferredColorScheme(.light)
}
