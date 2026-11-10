#if DEBUG
import FamilyControls
import SwiftUI

/// DEBUG-only status page for device runs: Screen Time access, the App Group, the lock, passes,
/// the relock strategy, and the log shared with the monitor extension.
/// Not a designed screen; it uses plain system list styling.
struct LabView: View {
    @State private var engine = LockEngine.live()
    @ObservedObject private var center = AuthorizationCenter.shared

    var body: some View {
        NavigationStack {
            List {
                accessSection
                sessionSection
                logSection
            }
            .navigationTitle("Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await refresh() }
    }

    // MARK: Sections

    private var accessSection: some View {
        Section("Screen Time") {
            LabeledContent("Access", value: accessText)
            LabeledContent("App Group", value: SharedStore.isAppGroupAvailable ? "OK" : "Missing")
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

    /// The app's own engine runs the lock; this one only reads the store.
    private func refresh() async {
        while !Task.isCancelled {
            engine.reload()
            try? await Task.sleep(for: .seconds(1))
        }
    }

    // MARK: Text

    private var accessText: String {
        switch center.authorizationStatus {
        case .approved: return "Approved"
        case .denied: return "Denied"
        case .notDetermined: return "Not asked"
        default:
            if #available(iOS 26.4, *), center.authorizationStatus == .approvedWithDataAccess { return "Approved" }
            return "Unknown"
        }
    }

    private func stateText(at date: Date) -> String {
        switch engine.session {
        case .unlocked: "Unlocked"
        case .locked: "Locked \(TimeFormat.clock(engine.session.elapsed(at: date)))"
        case .emergency: "Open, relocks in \(TimeFormat.clock(engine.session.remaining(at: date)))"
        }
    }
}
#endif
