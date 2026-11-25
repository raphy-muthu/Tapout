#if DEBUG
import SwiftUI

/// DEBUG-only page for the Phase 9 effects: the flag, the motion budget's inputs, the glass orb beside
/// the classic one, live tilt and the haptic patterns. Not a designed screen; plain system list styling.
struct EffectsGallery: View {
    @AppStorage(AppSettings.livingGlassKey) private var flag = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// The slider's value. The orbs show `shownTone`, which follows it with `Motion.tone` once the drag ends.
    @State private var tone = 0.0
    @State private var shownTone = 0.0
    @State private var ring = 0.0
    @State private var ripples = OrbRipples()

    private let environment = MotionEnvironment.shared
    private let motion = MotionSource.shared

    var body: some View {
        List {
            flagSection
            motionSection
            orbSection
            tiltSection
            hapticsSection
        }
        .navigationTitle("Effects")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { motion.acquire() }
        .onDisappear { motion.release() }
    }

    // MARK: Sections

    private var flagSection: some View {
        Section("Flag") {
            Toggle("Living glass in the app", isOn: $flag)
        }
    }

    private var motionSection: some View {
        Section("Motion") {
            LabeledContent("Reduce Motion", value: reduceMotion ? "On" : "Off")
            LabeledContent("Low Power Mode", value: environment.lowPowerMode ? "On" : "Off")
            LabeledContent("Thermal state", value: thermalText)
            LabeledContent("Scene phase", value: scenePhaseText)
            LabeledContent("Motion level", value: level == .full ? "Full" : "Still")
            LabeledContent("Glass shader", value: GlassOrbShader.isAvailable ? "In this build" : "Missing")
        }
    }

    private var orbSection: some View {
        Section("Orb") {
            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    glassOrb
                    Text("Glass").font(.tCaption).foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 8) {
                    OrbView(tone: shownTone < 0.5 ? .slate : .ember, ring: ring, size: 160)
                    Text("Classic").font(.tCaption).foregroundStyle(Color.inkSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 24)
            .listRowBackground(Color.bg)

            VStack(alignment: .leading) {
                Text("Tone").font(.tCaption).foregroundStyle(Color.inkSecondary)
                Slider(value: $tone, in: 0...1) { editing in
                    if !editing { withAnimation(Motion.tone) { shownTone = tone } }
                }
            }
            VStack(alignment: .leading) {
                Text("Ring").font(.tCaption).foregroundStyle(Color.inkSecondary)
                Slider(value: $ring, in: 0...1)
            }
        }
    }

    /// The glass orb when the shader is in the library; otherwise a note in its place.
    @ViewBuilder private var glassOrb: some View {
        if GlassOrbShader.isAvailable {
            // The orb's own timeline pulls the tilt each frame.
            GlassOrbView(tone: shownTone, ring: ring, size: 220, tilt: { MotionSource.shared.tilt }, ripples: ripples)
                .frame(width: 220, height: 220)
                .contentShape(Circle())
                .onTapGesture { ripples.add(at: Date.timeIntervalSinceReferenceDate) }
        } else {
            Text("The glass shader is not in this build.")
                .font(.tFootnote)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(width: 160, height: 220)
        }
    }

    private var tiltSection: some View {
        Section("Tilt") {
            // `tilt` is not observed, so the readout samples it on its own timeline.
            TimelineView(.animation(minimumInterval: MotionBudget.frameInterval)) { _ in
                let tilt = motion.tilt
                VStack {
                    LabeledContent("x") { Text(tilt.x, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                    LabeledContent("y") { Text(tilt.y, format: .number.precision(.fractionLength(2))).monospacedDigit() }
                }
            }
        }
    }

    private var hapticsSection: some View {
        Section("Haptics") {
            ForEach(HapticPattern.allCases, id: \.self) { pattern in
                Button(String(describing: pattern)) { HapticEngine.shared.play(pattern) }
            }
        }
    }

    // MARK: Text

    private var level: MotionLevel {
        MotionBudget.level(reduceMotion: reduceMotion, lowPowerMode: environment.lowPowerMode,
                           thermalState: environment.thermalState, sceneActive: scenePhase == .active)
    }

    private var thermalText: String {
        switch environment.thermalState {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }

    private var scenePhaseText: String {
        switch scenePhase {
        case .active: "Active"
        case .inactive: "Inactive"
        case .background: "Background"
        @unknown default: "Unknown"
        }
    }
}
#endif
