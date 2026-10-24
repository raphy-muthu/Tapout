import SwiftUI

/// Stand-in for screens that arrive in Phase 3.
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
            Text("Coming in Phase 3")
                .font(.tSubhead)
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Space.lg)
        .background(Color.bg.ignoresSafeArea())
    }
}
