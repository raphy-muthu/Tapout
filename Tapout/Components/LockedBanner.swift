import SwiftUI

/// Shown on editable screens while locked.
struct LockedBanner: View {
    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "lock").font(.system(size: 20, weight: .semibold))
            VStack(alignment: .leading, spacing: 0) {
                Text("View only while locked").font(.tHeadline)
                Text("Tap a tag to make changes.").font(.tFootnote).foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.emberInk)
        .padding(.vertical, Space.md)
        .padding(.horizontal, 20)
        .background(Color.emberGlow, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
