import SwiftUI
import UIKit

/// Locks the active mode's apps for a set time, no tag needed. Opened from Home's Timer button.
/// The duration, a countdown wheel, preset chips, the intention and Start.
struct TimerSheet: View {
    let modeName: String
    let hasApps: Bool
    let hasTags: Bool
    @Binding var intention: String
    let recent: [String]
    /// Starts the timer lock. Returns false when it couldn't (the sheet then says so and stays open).
    let onStart: (TimeInterval) -> Bool

    /// 15 min, 30 min, 45 min, 1 h, 2 h.
    nonisolated static let presets: [TimeInterval] = [15 * 60, 30 * 60, 45 * 60, 3600, 2 * 3600]
    nonisolated static let initialDuration: TimeInterval = 45 * 60

    /// A wheel value rounded to the minute and kept within `TimerLock.minimum...maximum`.
    nonisolated static func snapped(_ duration: TimeInterval) -> TimeInterval {
        TimerLock.clamped((duration / 60).rounded() * 60)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLocked) private var isLocked
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var duration = TimerSheet.initialDuration
    @State private var failed = false
    /// Start went through; further taps while the sheet slides away are ignored.
    @State private var started = false
    @State private var detent = PresentationDetent.large

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.xs) {
                    Text(TimeFormat.length(duration))
                        .font(.numberDisplay)
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(TimeFormat.spokenLength(duration))
                        .contentTransition(.numericText())
                    CountdownWheel(duration: $duration)
                        .frame(height: 216)
                        .accessibilityLabel("Duration")
                }
                FlowLayout {
                    ForEach(Self.presets, id: \.self) { preset in
                        ChoiceChip(title: TimeFormat.length(preset), isOn: duration == preset) {
                            duration = preset
                            failed = false
                        }
                    }
                }
                IntentionField(text: $intention, recent: recent, fill: .surface2)
                notes
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.md)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryButton(title: "Start", action: start)
                .disabled(!hasApps)
                .opacity(hasApps ? 1 : 0.45)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.lg)
                .background(Color.surface1)
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(Color.surface1)
        // A schedule can lock while the sheet is open; the timer has nothing left to start.
        .onChange(of: isLocked) { _, locked in
            if locked { dismiss() }
        }
        .onChange(of: duration) { _, _ in failed = false }
    }

    private var notes: some View {
        VStack(spacing: Space.xs) {
            Text(hasApps ? "Locks \(modeName)'s apps" : "Choose apps in Modes first")
                .font(.tFootnote)
                .foregroundStyle(Color.inkSecondary)
            if !hasTags {
                Text("No tag is paired. Only the timer or an emergency pass will open your apps.")
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkTertiary)
            }
            if failed {
                Text("Couldn't start the timer. Try again.")
                    .font(.tFootnote.weight(.medium))
                    .foregroundStyle(Color.emberInk)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    private func start() {
        guard hasApps, !started else { return }
        if onStart(Self.snapped(duration)) {
            started = true
            dismiss()
        } else {
            Haptics.mismatch()
            failed = true
        }
    }
}

/// UIKit's countdown wheel (hours and minutes), which SwiftUI's `DatePicker` doesn't offer.
/// Values snap to `TimerSheet.snapped`, so the wheel never rests below 5 min or above 12 h.
private struct CountdownWheel: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.minuteInterval = 1
        picker.countDownDuration = duration
        picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        // UIKit drops the first spin's value-changed event unless the duration is set again after layout.
        let start = duration
        DispatchQueue.main.async { picker.countDownDuration = start }
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        context.coordinator.duration = $duration
        if abs(picker.countDownDuration - duration) >= 1 { picker.countDownDuration = duration }
    }

    func makeCoordinator() -> Coordinator { Coordinator(duration: $duration) }

    @MainActor
    final class Coordinator: NSObject {
        var duration: Binding<TimeInterval>

        init(duration: Binding<TimeInterval>) { self.duration = duration }

        @objc func changed(_ picker: UIDatePicker) {
            let value = TimerSheet.snapped(picker.countDownDuration)
            if value != picker.countDownDuration { picker.countDownDuration = value }
            // The wheel ticks with its own system haptic.
            duration.wrappedValue = value
        }
    }
}

#if DEBUG
@MainActor
private func timerPreview(apps: Bool, tags: Bool, _ scheme: ColorScheme) -> some View {
    Color.bg
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            TimerSheet(modeName: "Deep work", hasApps: apps, hasTags: tags, intention: .constant(""),
                       recent: ["Essay outline", "Reading"]) { _ in true }
        }
        .preferredColorScheme(scheme)
}

#Preview("Timer · dark") { timerPreview(apps: true, tags: true, .dark) }
#Preview("Timer · light") { timerPreview(apps: true, tags: true, .light) }
#Preview("No apps, no tag · dark") { timerPreview(apps: false, tags: false, .dark) }
#endif
