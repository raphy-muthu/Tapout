import SwiftUI

/// Mode pill (picker arrives with Modes in Phase 3) and the settings button.
struct HomeHeader: View {
    let modeName: String
    let isLocked: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                if isLocked {
                    Image(systemName: "lock").font(.system(size: 14, weight: .semibold))
                }
                Text(modeName).font(.tSubhead.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isLocked ? Color.emberInk : Color.ink)
            .padding(.leading, 14)
            .padding(.trailing, Space.md)
            .frame(height: 44)
            .background(Color.surface1, in: Capsule(style: .continuous))
            .cardShadow()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Mode: \(modeName)")

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.surface1, in: Circle())
                    .cardShadow()
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Settings")
        }
        .frame(height: 44)
    }
}
