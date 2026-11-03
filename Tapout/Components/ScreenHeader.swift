import SwiftUI

/// A tab's large title with its add button. Adding is off while locked.
struct ScreenHeader: View {
    let title: String
    let addLabel: String
    let onAdd: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        HStack {
            Text(title)
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            CircleIconButton(systemImage: "plus", label: addLabel, tint: .ink, action: onAdd)
                .disabled(isLocked)
        }
    }
}
