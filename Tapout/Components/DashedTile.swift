import SwiftUI

/// The dashed "add" tile at the end of a grid.
struct DashedTile: View {
    let title: String
    /// Modes stacks the icon above the title; Places puts them side by side.
    var vertical = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            Group {
                if vertical {
                    VStack(spacing: Space.xs) { icon; Text(title) }
                } else {
                    HStack(spacing: Space.xs) { icon; Text(title) }
                }
            }
            .font(.tSubhead.weight(.medium))
            .foregroundStyle(Color.inkSecondary)
            // Keeps wrapped large text centred and off the dashed line.
            .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
            .padding(typeSize.isAccessibilitySize ? Space.sm : 0)
            .frame(maxWidth: .infinity, minHeight: 84)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var icon: some View {
        Image(systemName: "plus").font(.system(size: 20, weight: .medium))
    }
}

extension GridItem {
    /// The Modes and Places tile grids: two columns, or one at accessibility sizes so names don't break mid-word.
    static func tiles(_ typeSize: DynamicTypeSize) -> [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: Space.sm), GridItem(.flexible())]
    }
}
