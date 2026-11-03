import SwiftUI

/// Rename a place, make it the default or remove it. Read-only while locked.
struct PlaceSheet: View {
    let model: AppModel
    let place: PairedTag

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @State private var name: String
    @State private var confirmingRemove = false

    init(model: AppModel, place: PairedTag) {
        self.model = model
        self.place = place
        _name = State(initialValue: place.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            HStack {
                Button(isLocked ? "Close" : "Cancel") { dismiss() }
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                if !isLocked {
                    Button("Save") {
                        guard !isLocked else { return }
                        model.renamePlace(place.uid, to: name)
                        dismiss()
                    }
                    .font(.tHeadline)
                    .foregroundStyle(Color.ink)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.45 : 1)
                }
            }
            .frame(minHeight: 44)

            if isLocked { LockedBanner() }

            VStack(alignment: .leading, spacing: Space.xxs) {
                SectionLabel(text: "Name")
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.tLargeTitle)
                    .foregroundStyle(Color.ink)
                    .submitLabel(.done)
                    .disabled(isLocked)
                Text("\(Copy.count(model.lockCount(at: place.uid), "lock", "locks")) · paired \(place.pairedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.tSubhead)
                    .foregroundStyle(Color.inkSecondary)
            }

            if !isDefault && !isLocked {
                Button {
                    guard !isLocked else { return }
                    model.makeDefault(place.uid)
                    Haptics.select()
                    dismiss()
                } label: {
                    Text("Make default")
                        .font(.tBody)
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .padding(.horizontal, 20)
                        .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
            }

            Spacer(minLength: 0)

            if !isLocked {
                Button("Remove place", role: .destructive) { confirmingRemove = true }
                    .font(.tBody)
                    .foregroundStyle(Color.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.md)
        .presentationDetents([.medium])
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
        .confirmationDialog("Remove \(place.name)?", isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                guard !isLocked else { return }
                model.removePlace(place.uid)
                dismiss()
            }
        } message: {
            Text("Modes that unlock only here will unlock at any place.")
        }
        .onChange(of: isLocked) { _, locked in
            if locked { confirmingRemove = false }
        }
    }

    private var isDefault: Bool {
        model.defaultPlace?.uid == place.uid
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#if DEBUG
#Preview("Place · dark") {
    let model = DemoData.previewModel()
    return Color.bg.sheet(isPresented: .constant(true)) { PlaceSheet(model: model, place: model.places[0]) }
        .preferredColorScheme(.dark)
}

#Preview("Place · light") {
    let model = DemoData.previewModel()
    return Color.bg.sheet(isPresented: .constant(true)) { PlaceSheet(model: model, place: model.places[0]) }
        .preferredColorScheme(.light)
}

#Preview("Place · locked") {
    let model = DemoData.previewModel()
    return Color.bg.sheet(isPresented: .constant(true)) { PlaceSheet(model: model, place: model.places[0]) }
        .environment(\.isLocked, true)
        .preferredColorScheme(.dark)
}
#endif
