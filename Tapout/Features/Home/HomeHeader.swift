import SwiftUI

/// The mode pill and the settings button. While unlocked the pill opens a mode picker.
struct HomeHeader: View {
    let modes: [Mode]
    let activeMode: Mode
    /// The lock glyph shows only in the locked state, not during an emergency pass.
    let showsLockGlyph: Bool
    let onSelectMode: (UUID) -> Void
    let onOpenSettings: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        HStack {
            if isLocked {
                pill
            } else {
                Menu {
                    Picker("Mode", selection: Binding(get: { activeMode.id }, set: { id in
                        Haptics.select()
                        onSelectMode(id)
                    })) {
                        ForEach(modes) { mode in Text(mode.name).tag(mode.id) }
                    }
                } label: {
                    pill
                }
                .accessibilityHint("Choose a mode")
            }

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

    private var pill: some View {
        HStack(spacing: 6) {
            if showsLockGlyph {
                Image(systemName: "lock").font(.system(size: 14, weight: .semibold))
            }
            Text(activeMode.name).font(.tSubhead.weight(.semibold))
            if !isLocked {
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(showsLockGlyph ? Color.emberInk : Color.ink)
        .padding(.leading, 14)
        .padding(.trailing, Space.md)
        .frame(height: 44)
        .background(Color.surface1, in: Capsule(style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode: \(activeMode.name)")
    }
}
