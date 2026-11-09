import SwiftUI

/// Pairs a tag as a named place: scan, then name it. Matches the pair sheet in Places.dc.html.
/// Only reachable while unlocked.
struct PairPlaceSheet: View {
    let model: AppModel

    enum Phase: Equatable {
        case scanning
        case found(TagUID)
        case failed(String)
    }

    static let suggestions = ["Kitchen", "Desk", "Bedroom", "Front door"]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLocked) private var isLocked
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var scanner: any TagScanning
    @State private var phase = Phase.scanning
    @State private var name = ""
    @State private var pulsing = false
    @State private var attempt = 0

    init(model: AppModel, scanner: any TagScanning = TagScanners.live()) {
        self.model = model
        _scanner = State(initialValue: scanner)
    }

    var body: some View {
        Group {
            // At accessibility sizes everything above the action scrolls, so nothing gets squeezed or truncated.
            if typeSize.isAccessibilitySize {
                VStack(spacing: Space.lg) {
                    ScrollView {
                        VStack(spacing: Space.lg) { content }
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    actions
                }
            } else {
                VStack(spacing: Space.lg) {
                    content
                    Spacer(minLength: 0)
                    actions
                }
            }
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.lg)
        // Full height at accessibility sizes, so the field, suggestions and Save all fit.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(664)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
        .task(id: attempt) { await scan() }
        .onChange(of: isLocked) { _, locked in
            if locked { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        status
        if case .found = phase {
            nameField
            FlowLayout {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    ChoiceChip(title: suggestion, isOn: name == suggestion) { name = suggestion }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var status: some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .strokeBorder(Color.slateLine, lineWidth: 2)
                    .frame(width: 156, height: 156)
                    .opacity(phase == .scanning && pulsing ? 0.35 : 1)
                Circle().fill(Color.surface2).frame(width: 124, height: 124)
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.slateInk)
                    .accessibilityHidden(true)
            }
            .frame(width: 160, height: 160)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Motion.readyPulse) { pulsing = true }
            }
            Text(statusText)
                .font(.tHeadline)
                .foregroundStyle(statusColor)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionLabel(text: "Name this place")
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .font(.tTitle)
                .foregroundStyle(Color.ink)
                .submitLabel(.done)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs) // grows with large text; the 56pt minimum holds at default sizes
                .frame(minHeight: 56)
                .background(Color.surface2, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch phase {
        case .scanning:
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.tBody)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
        case .found(let uid):
            PrimaryButton(title: "Save place") { save(uid) }
                .disabled(trimmedName.isEmpty)
                .opacity(trimmedName.isEmpty ? 0.45 : 1)
        case .failed:
            PrimaryButton(title: "Try again") { attempt += 1 }
        }
    }

    private var symbol: String {
        switch phase {
        case .scanning: "wave.3.right"
        case .found: "checkmark"
        case .failed: "exclamationmark"
        }
    }

    private var statusText: String {
        switch phase {
        case .scanning: "Ready to scan"
        case .found: "Tag found"
        case .failed(let message): message
        }
    }

    private var statusColor: Color {
        if case .failed = phase { .inkSecondary } else { .slateInk }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scan() async {
        phase = .scanning
        do {
            let uid = try await scanner.scan(prompt: TagScanPrompt.pair)
            guard !Task.isCancelled else { return }
            if let existing = model.places.first(where: { $0.uid == uid }) {
                Haptics.mismatch()
                phase = .failed("Already paired as \(existing.name).")
            } else {
                Haptics.select()
                name = Self.suggestions.first { suggestion in !model.places.contains { $0.name == suggestion } } ?? ""
                phase = .found(uid)
            }
        } catch is CancellationError {
            return
        } catch TagReader.ReadError.cancelled {
            dismiss()
        } catch TagReader.ReadError.timedOut {
            phase = .failed("No tag found.")
        } catch {
            phase = .failed("Couldn't read that tag.")
        }
    }

    private func save(_ uid: TagUID) {
        guard !isLocked else { return }
        if case .alreadyPaired(let existing) = model.pair(uid, name: trimmedName) {
            phase = .failed("Already paired as \(existing).")
            return
        }
        Haptics.select()
        dismiss()
    }
}

#if DEBUG
/// Preview stand-in for the NFC reader; `Behavior` picks what the scan does.
private struct PreviewScanner: TagScanning {
    enum Behavior { case wait, newTag, known, timeout }
    let behavior: Behavior

    init(_ behavior: Behavior) { self.behavior = behavior }

    @MainActor func scan(prompt: String) async throws -> TagUID {
        switch behavior {
        case .wait:
            try await Task.sleep(for: .seconds(3600))
            throw TagReader.ReadError.timedOut
        case .newTag: return TagUID(hex: "04FFEE")
        case .known: return DemoData.kitchen
        case .timeout: throw TagReader.ReadError.timedOut
        }
    }
}

@MainActor
private func pairPreview(_ behavior: PreviewScanner.Behavior, _ scheme: ColorScheme) -> some View {
    Color.bg
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PairPlaceSheet(model: DemoData.previewModel(), scanner: PreviewScanner(behavior))
        }
        .preferredColorScheme(scheme)
}

#Preview("Scanning · dark") { pairPreview(.wait, .dark) }
#Preview("Tag found · dark") { pairPreview(.newTag, .dark) }
#Preview("Tag found · light") { pairPreview(.newTag, .light) }
#Preview("Already paired · dark") { pairPreview(.known, .dark) }
#Preview("No tag found · dark") { pairPreview(.timeout, .dark) }
#endif
