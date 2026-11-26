#if DEBUG
import SwiftUI

/// The Lab's battery-and-heat page. Start a run, close the Lab, leave a screen open, come back and stop.
/// Not a designed screen; plain system list styling.
struct PowerMeterView: View {
    private let meter = PowerMeter.shared
    @State private var label = ""
    @State private var copied = false

    var body: some View {
        List {
            Section {
                if let run = meter.current {
                    Text(run.report).font(.footnote.monospaced())
                    Button("Stop") { meter.stop() }
                } else {
                    TextField("What are you testing? e.g. Home, switch on", text: $label)
                    Button("Start") {
                        meter.start(label: label)
                        copied = false
                    }
                }
            } header: {
                Text(meter.current == nil ? "New run" : "Running")
            } footer: {
                Text("Unplug, set the brightness you will use for every run, then Start, close the Lab and leave the screen open for about an hour. The display stays awake. Only time with Tapout on screen is read.")
            }
            if meter.current == nil && !meter.runs.isEmpty {
                Section("Saved") {
                    ForEach(meter.runs) { run in
                        Text(run.report).font(.footnote.monospaced())
                    }
                    Button(copied ? "Copied" : "Copy report") {
                        UIPasteboard.general.string = meter.report
                        copied = true
                    }
                    Button("Clear", role: .destructive) { meter.clear() }
                }
            }
        }
        .navigationTitle("Battery and heat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PowerMeterView() }
}
#endif
