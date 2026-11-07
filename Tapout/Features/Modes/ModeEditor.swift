import FamilyControls
import SwiftUI

/// Create or edit a mode, per the edit view in design/screens/Modes.dc.html. Read-only while locked.
struct ModeEditor: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @State private var draft: Mode
    @State private var days: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var picking = false
    @State private var confirmingDelete = false

    init(model: AppModel, mode: Mode) {
        self.model = model
        _draft = State(initialValue: mode)
        _days = State(initialValue: mode.schedule?.days ?? [])
        _start = State(initialValue: ClockMinutes.date(mode.schedule?.start ?? 9 * 60))
        _end = State(initialValue: ClockMinutes.date(mode.schedule?.end ?? 17 * 60))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.sm) {
                header
                if isLocked { LockedBanner() }
                nameField.padding(.vertical, Space.md)
                Group {
                    blockCard
                    whenCard
                    unlockCard
                }
                .disabled(isLocked)
                if model.isSaved(draft) && !isLocked { deleteButton }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color.bg.ignoresSafeArea())
        .familyActivityPicker(isPresented: $picking, selection: $draft.selection)
        .confirmationDialog("Delete \(storedName)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                guard !isLocked else { return }
                if model.deleteMode(id: draft.id) { dismiss() }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.sheet)
        .onChange(of: isLocked) { _, locked in
            if locked {
                confirmingDelete = false
                picking = false
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
            OrbView(tone: .slate, size: 44)
            Spacer()
            Button(action: save) {
                Text("Save")
                    .font(.tHeadline)
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            SectionLabel(text: "Name")
            TextField("Name", text: $draft.name, prompt: Text("Mode name").foregroundStyle(Color.inkTertiary))
                .textInputAutocapitalization(.words)
                .font(.tLargeTitle)
                .foregroundStyle(Color.ink)
                .submitLabel(.done)
                .disabled(isLocked)
        }
    }

    private var blockCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("Block").font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                Button { picking = true } label: {
                    Text("\(ModeText.apps(draft)) ›")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            let icons = Array(draft.selection.applicationTokens.prefix(6))
            if !icons.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 6), spacing: Space.xs) {
                    ForEach(icons, id: \.self) { token in
                        Label(token)
                            .labelStyle(.iconOnly)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("When").font(.tHeadline).foregroundStyle(Color.ink)
                Spacer()
                if days.isEmpty {
                    Text("Manual").font(.numberSmall).foregroundStyle(Color.inkSecondary)
                } else {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                    Text("–").foregroundStyle(Color.inkSecondary)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
                }
            }
            .frame(minHeight: 44)
            DayChips(days: $days)
            Text(whenFootnote)
                .font(.tFootnote)
                .foregroundStyle(Color.inkTertiary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var whenFootnote: String {
        if days.isEmpty { return "Pick days to lock on a schedule." }
        if schedule?.isRunnable == false { return "At least \(ModeSchedule.minimumDuration) minutes." }
        return "Locks at the start, unlocks at the end."
    }

    private var unlockCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Unlock at").font(.tHeadline).foregroundStyle(Color.ink)
            if model.places.isEmpty {
                Text("Pair a place to choose where this mode unlocks.")
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkTertiary)
            } else {
                FlowLayout {
                    ForEach(model.places) { place in
                        ChoiceChip(title: place.name, isOn: draft.unlockPlaces.contains(place.uid)) {
                            if draft.unlockPlaces.contains(place.uid) {
                                draft.unlockPlaces.remove(place.uid)
                            } else {
                                draft.unlockPlaces.insert(place.uid)
                            }
                        }
                    }
                }
                Text(draft.unlockPlaces.isEmpty ? "Any of your places unlocks this mode." : "Only these places unlock this mode.")
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, Space.lg)
        .card(padding: 0)
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmingDelete = true } label: {
            Text("Delete mode")
                .font(.tBody)
                .foregroundStyle(Color.danger)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(model.modes.count <= 1)
        .opacity(model.modes.count <= 1 ? 0.45 : 1)
        .padding(.top, Space.md)
    }

    /// The saved name, so a blanked draft name doesn't read "Delete ?".
    private var storedName: String {
        model.modes.first { $0.id == draft.id }?.name ?? draft.name
    }

    private var schedule: ModeSchedule? {
        ModeSchedule.make(days: days, start: ClockMinutes.minutes(of: start), end: ClockMinutes.minutes(of: end))
    }

    private var canSave: Bool {
        let named = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return !isLocked && named && (schedule?.isRunnable ?? true)
    }

    private func save() {
        guard !isLocked else { return }
        var mode = draft
        mode.schedule = schedule
        model.save(mode)
        Haptics.select()
        dismiss()
    }
}

#if DEBUG
#Preview("Editor · dark") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.activeMode).preferredColorScheme(.dark)
}

#Preview("Editor · light") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.activeMode).preferredColorScheme(.light)
}

#Preview("Editor · new") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.newMode()).preferredColorScheme(.dark)
}

#Preview("Editor · locked") {
    let model = DemoData.previewModel()
    return ModeEditor(model: model, mode: model.activeMode)
        .environment(\.isLocked, true)
        .preferredColorScheme(.dark)
}
#endif
