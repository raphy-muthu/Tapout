import FamilyControls
import SwiftUI

/// One mode with the Living glass switch on: a glass card that opens like a drawer onto its apps, days,
/// numbers and actions.
struct ModeDrawerCard: View {
    let mode: Mode
    let isActive: Bool
    let isOpen: Bool
    let unlockNames: [String]
    let lockedThisWeek: TimeInterval
    let onToggle: () -> Void
    let onUse: () -> Void
    let onEdit: () -> Void

    @Environment(\.isLocked) private var isLocked
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) { header }
                .buttonStyle(PressScaleStyle())
                .accessibilityValue(isOpen ? "Open" : "Closed")
            if isOpen {
                drawer
                    .padding(.top, Space.md)
                    .transition(.opacity)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(shape) // the drawer is revealed as the card grows
        .controlSurface(.surface1, in: shape)
    }

    private var header: some View {
        Group {
            // At accessibility sizes the words get the full width, under the gem and the chevron.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Space.sm) {
                    HStack {
                        gem
                        Spacer(minLength: Space.sm)
                        chevron
                    }
                    titles
                }
            } else {
                HStack(spacing: Space.md) {
                    gem
                    titles
                    chevron
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var titles: some View {
        let large = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 2) {
            if isActive {
                Text(isLocked ? "Active now" : "Selected")
                    .font(.tCaption)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundStyle(Color.emberInk)
            }
            Text(mode.name).font(.tTitle).foregroundStyle(Color.ink)
                .lineLimit(large ? nil : 1).minimumScaleFactor(0.8)
            Text(ModeText.subtitle(mode)).font(.tSubhead).foregroundStyle(Color.inkSecondary)
                .lineLimit(large ? nil : 1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.tSubhead.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
            .rotationEffect(.degrees(isOpen ? 180 : 0))
            .accessibilityHidden(true)
    }

    /// Ember for the active mode, slate for the rest; ringed while it is locked.
    private var gem: some View {
        OrbView(tone: isActive ? .ember : .slate, ring: isActive && isLocked ? 1 : 0, size: 46)
            .accessibilityHidden(true)
    }

    private var drawer: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            let icons = Array(mode.selection.applicationTokens.prefix(6))
            if !icons.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 6), spacing: Space.xs) {
                    ForEach(icons, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.ink.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                }
            }
            days
            ModeStatTiles(mode: mode, unlockNames: unlockNames, lockedThisWeek: lockedThisWeek)
            actions
        }
    }

    /// The scheduled days, lit. Smaller than the editor's day chips, because these only show.
    private var days: some View {
        let scheduled = mode.schedule?.days ?? []
        return HStack(spacing: 0) {
            ForEach(ModeSchedule.displayOrder, id: \.self) { day in
                let lit = scheduled.contains(day)
                Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                    .font(.tCaption)
                    .foregroundStyle(lit ? Color.bg : Color.inkSecondary)
                    .frame(width: 32, height: 32)
                    .background(lit ? Color.ink : Color.ink.opacity(0.07), in: Circle())
                    .frame(maxWidth: .infinity)
            }
        }
        // As large as the circles have room for.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locks on")
        .accessibilityValue(mode.schedule.map { ScheduleFormat.days($0.days) } ?? "no days, manual")
    }

    private var actions: some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: Space.xs))
                                      : AnyLayout(HStackLayout(spacing: Space.xs))) {
            if !isActive {
                Button(action: onUse) {
                    actionLabel("Use this mode", color: .bg)
                        .background(Color.ink, in: Capsule(style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(isLocked)
                .opacity(isLocked ? 0.45 : 1)
            }
            Button(action: onEdit) {
                actionLabel(isLocked ? "View" : "Edit", color: .ink)
                    .controlSurface(.surface2, in: Capsule(style: .continuous), shadowed: false)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("\(isLocked ? "View" : "Edit") \(mode.name)")
        }
    }

    private func actionLabel(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.tSubhead.weight(.semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Capsule(style: .continuous))
    }
}

extension View {
    /// On iOS 18 and later, the editor zooms out of the view marked with the same id.
    @ViewBuilder
    func zoomSource(_ id: UUID, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(_ id: UUID, in namespace: Namespace.ID, isOn: Bool) -> some View {
        if #available(iOS 18.0, *), isOn {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

#if DEBUG
private struct DrawerPreview: View {
    var body: some View {
        let model = DemoData.previewModel()
        VStack(spacing: Space.sm) {
            ModeDrawerCard(mode: model.activeMode, isActive: true, isOpen: true, unlockNames: ["Kitchen"],
                           lockedThisWeek: 5 * 3600, onToggle: {}, onUse: {}, onEdit: {})
            ModeDrawerCard(mode: model.otherModes[0], isActive: false, isOpen: false, unlockNames: [],
                           lockedThisWeek: 0, onToggle: {}, onUse: {}, onEdit: {})
        }
        .environment(\.glassControls, true)
        .padding(Space.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}

#Preview("Drawers · dark") { DrawerPreview().preferredColorScheme(.dark) }
#Preview("Drawers · light") { DrawerPreview().preferredColorScheme(.light) }
#endif
