import FamilyControls
import SwiftUI

/// Settings, pushed from Home's gear. Read-only while locked, per design/screens/Settings.dc.html.
struct SettingsView: View {
    let model: AppModel
    let passesLeft: Int
    let onOpenTab: (AppTab) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @AppStorage(AppSettings.hapticsKey) private var haptics = true
    @AppStorage(AppSettings.liveActivityKey) private var liveActivity = true
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @State private var pickingAllowed = false
    #if DEBUG
    @State private var showingLab = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: Space.md) {
                header
                if isLocked { LockedBanner() }
                passesCard
                linksCard
                preferencesCard
                footer
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
        }
        .scrollIndicators(.hidden)
        .background(Color.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .familyActivityPicker(
            isPresented: $pickingAllowed,
            selection: Binding(get: { model.alwaysAllowed }, set: { if !isLocked { model.updateAlwaysAllowed($0) } })
        )
        .onChange(of: isLocked) { _, locked in
            if locked { pickingAllowed = false }
        }
        #if DEBUG
        .sheet(isPresented: $showingLab) { LabView() }
        #endif
    }

    private var header: some View {
        ZStack {
            Text("Settings")
                .font(.tHeadline)
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                CircleIconButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                Spacer()
            }
        }
        .frame(height: 44)
    }

    private var passesCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Emergency passes").font(.tHeadline).foregroundStyle(Color.ink)
                PassPips(left: passesLeft)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(passesLeft)").font(.numberMedium).foregroundStyle(Color.ink)
                Text("/\(SharedStore.totalPasses)")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.inkTertiary)
            }
            .accessibilityHidden(true)
        }
        .card(padding: 20)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "Places", value: "\(model.places.count)") { onOpenTab(.places) }
            SettingsRow(title: "Modes", value: "\(model.modes.count)") { onOpenTab(.modes) }
            SettingsRow(title: "Always allowed", value: Copy.count(allowedCount, "app", "apps")) { pickingAllowed = true }
        }
        .disabled(isLocked)
        .padding(.horizontal, 20)
        .padding(.vertical, Space.xxs)
        .card(padding: 0)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            toggleRow("Haptics", isOn: $haptics)
            toggleRow("Live Activity", isOn: $liveActivity)
            HStack {
                Text("Appearance").font(.tBody).foregroundStyle(Color.ink)
                Spacer()
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Color.inkSecondary)
                .opacity(isLocked ? 0.45 : 1)
            }
            .frame(minHeight: 56)
        }
        .disabled(isLocked)
        .padding(.horizontal, 20)
        .padding(.vertical, Space.xxs)
        .card(padding: 0)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.tBody).foregroundStyle(Color.ink)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Color.slate)
                .opacity(isLocked ? 0.45 : 1)
        }
        .frame(minHeight: 56)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Text("Tapout \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
            #if DEBUG
            Button("Developer Lab") { showingLab = true }
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
                .frame(minHeight: 44)
            #endif
        }
        .padding(.top, Space.lg)
    }

    private var allowedCount: Int {
        model.alwaysAllowed.applicationTokens.count + model.alwaysAllowed.categoryTokens.count
    }
}

/// A 56pt row: title, value, then a chevron, or a lock glyph while locked.
private struct SettingsRow: View {
    let title: String
    let value: String
    let action: () -> Void

    @Environment(\.isLocked) private var isLocked

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.tBody).foregroundStyle(Color.ink)
                Spacer()
                Text(value).font(.tBody).foregroundStyle(Color.inkSecondary)
                Image(systemName: isLocked ? "lock" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .accessibilityLabel("Locked")
                    .accessibilityHidden(!isLocked)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Unlocked · dark") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .preferredColorScheme(.dark)
}

#Preview("Locked · dark") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .environment(\.isLocked, true)
    .preferredColorScheme(.dark)
}

#Preview("Unlocked · light") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .preferredColorScheme(.light)
}

#Preview("Locked · light") {
    NavigationStack {
        SettingsView(model: DemoData.previewModel(), passesLeft: 3) { _ in }
    }
    .environment(\.isLocked, true)
    .preferredColorScheme(.light)
}
