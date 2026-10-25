#if DEBUG
import FamilyControls
import SwiftUI

/// DEBUG-only test bench for the Phase 2 device spike: Screen Time access, app picking, tag
/// pairing and reads, emergency relock, and a log shared with the monitor extension.
/// Not a designed screen; it uses plain system list styling.
struct LabView: View {
    @State private var engine = LockEngine.live()
    @State private var reader = TagReader()
    @ObservedObject private var center = AuthorizationCenter.shared
    @State private var picking = false
    @State private var message: String?
    @Environment(\.scenePhase) private var scenePhase

    private let prompt = "Hold your tag near the top of your iPhone."

    var body: some View {
        NavigationStack {
            List {
                accessSection
                appsSection
                tagsSection
                sessionSection
                logSection
            }
            .navigationTitle("Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
        .familyActivityPicker(
            isPresented: $picking,
            selection: Binding(get: { engine.selection }, set: { engine.updateSelection($0) })
        )
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {}
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { engine.reload() }
        }
        .task { await runClock() }
    }

    // MARK: Sections

    private var accessSection: some View {
        Section("Screen Time") {
            LabeledContent("Access", value: accessText)
            LabeledContent("App Group", value: SharedStore.isAppGroupAvailable ? "OK" : "Missing")
            if !isApproved {
                Button("Allow Screen Time access") {
                    Task {
                        do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
                        catch { message = "Access failed: \(error.localizedDescription)" }
                    }
                }
            }
        }
    }

    private var appsSection: some View {
        Section("Blocked apps") {
            ForEach(Array(engine.selection.applicationTokens), id: \.self) { token in
                Label(token)
            }
            if !engine.selection.categoryTokens.isEmpty {
                LabeledContent("Categories", value: "\(engine.selection.categoryTokens.count)")
            }
            Button("Choose apps") { picking = true }
                .disabled(!isApproved)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            ForEach(engine.pairedTags) { tag in
                LabeledContent(tag.name, value: tag.uid.display)
                    .swipeActions {
                        Button("Unpair", role: .destructive) { engine.unpair(tag) }
                    }
            }
            Button("Pair a tag") { Task { await pair() } }
            Button("Scan") { Task { await scan() } }
                .disabled(engine.pairedTags.isEmpty)
            if !TagReader.isAvailable {
                Text("NFC isn't available on this device.")
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LabeledContent("State", value: stateText(at: context.date))
            }
            LabeledContent("Passes left", value: "\(engine.passesLeft) of \(SharedStore.totalPasses)")
            Picker("Relock via", selection: Binding(get: { engine.relockStrategy }, set: { engine.setRelockStrategy($0) })) {
                Text("Warning").tag(RelockStrategy.warning)
                Text("Past start").tag(RelockStrategy.pastStart)
            }
            Button("Emergency pass") {
                do {
                    try engine.useEmergencyPass()
                    Haptics.unlock()
                } catch {
                    message = passMessage(error)
                }
            }
            .disabled(!isLocked)
            Button("Relock now") {
                engine.relockNow()
                Haptics.lock()
            }
            .disabled(!isEmergency)
            Button("Reset passes") { engine.resetPasses() }
        }
    }

    private var logSection: some View {
        Section {
            ForEach(engine.log.reversed()) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.date.formatted(date: .omitted, time: .standard)) · \(entry.source.rawValue)")
                        .font(.tCaption.monospacedDigit())
                        .foregroundStyle(Color.inkSecondary)
                    Text(entry.message)
                        .font(.tFootnote)
                }
            }
        } header: {
            HStack {
                Text("Log")
                Spacer()
                Button("Clear") { engine.clearLog() }
            }
        }
    }

    // MARK: Actions

    private func pair() async {
        do {
            let uid = try await reader.readUID(prompt: prompt)
            if engine.pair(uid, name: "Tag \(engine.pairedTags.count + 1)") {
                Haptics.select()
            } else {
                message = "That tag is already paired."
            }
        } catch TagReader.ReadError.cancelled {
        } catch TagReader.ReadError.timedOut {
            message = "No tag found."
        } catch {
            message = "Read failed: \(error)"
        }
    }

    private func scan() async {
        Haptics.prepare()
        do {
            let uid = try await reader.readUID(prompt: prompt)
            switch engine.handleTag(uid) {
            case .locked: Haptics.lock()
            case .unlocked: Haptics.unlock()
            case .rejected:
                Haptics.mismatch()
                message = "Not a paired tag."
            }
        } catch TagReader.ReadError.cancelled {
        } catch TagReader.ReadError.timedOut {
            message = "No tag found."
        } catch {
            message = "Read failed: \(error)"
        }
    }

    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if engine.tick() { Haptics.lock() }
        }
    }

    // MARK: Text

    private var isApproved: Bool {
        if center.authorizationStatus == .approved { return true }
        if #available(iOS 26.4, *) { return center.authorizationStatus == .approvedWithDataAccess }
        return false
    }

    private var accessText: String {
        if isApproved { return "Approved" }
        switch center.authorizationStatus {
        case .denied: return "Denied"
        case .notDetermined: return "Not asked"
        default: return "Unknown"
        }
    }

    private var isLocked: Bool {
        if case .locked = engine.session { true } else { false }
    }

    private var isEmergency: Bool {
        if case .emergency = engine.session { true } else { false }
    }

    private func stateText(at date: Date) -> String {
        switch engine.session {
        case .unlocked: "Unlocked"
        case .locked: "Locked \(TimeFormat.clock(engine.session.elapsed(at: date)))"
        case .emergency: "Open, relocks in \(TimeFormat.clock(engine.session.remaining(at: date)))"
        }
    }

    private func passMessage(_ error: any Error) -> String {
        switch error as? LockEngine.PassError {
        case .notLocked: "Lock first."
        case .noPassesLeft: "No passes left."
        case .couldNotSchedule(let reason): "Couldn't schedule the relock: \(reason)"
        case nil: error.localizedDescription
        }
    }
}
#endif
