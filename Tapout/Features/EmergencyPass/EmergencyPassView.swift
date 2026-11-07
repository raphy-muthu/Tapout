import SwiftUI

/// Hold for 10 seconds to spend one of five lifetime passes, per design/screens/EmergencyPass.dc.html.
/// Letting go resets the hold.
struct EmergencyPassView: View {
    /// Returns whether a pass was actually spent.
    let onUse: () -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The count when the screen opened, so spending the last pass doesn't flip the screen into "none left" mid-dismiss.
    @State private var passesAtOpen: Int
    @State private var countdown = HoldCountdown()
    @State private var holdTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?
    @State private var confirmingAccessibleUse = false
    /// Resets on its own when the touch ends or is cancelled by the system.
    @GestureState private var isPressed = false

    init(passesLeft: Int, onUse: @escaping () -> Bool) {
        _passesAtOpen = State(initialValue: passesLeft)
        self.onUse = onUse
    }

    private var canUse: Bool { passesAtOpen > 0 && !countdown.isDone }
    private var passesShown: Int { countdown.isDone ? passesAtOpen - 1 : passesAtOpen }

    var body: some View {
        VStack(spacing: 0) {
            header
            pips.padding(.top, 40)
            Spacer(minLength: 0)
            VStack(spacing: 28) {
                holdButton
                VStack(spacing: Space.xxs) {
                    Text(passesAtOpen > 0 ? countdown.title : "No passes left.")
                        .font(.tTitle)
                        .foregroundStyle(Color.ink)
                    Text("Apps open for \(Int(MockLockController.emergencyDuration / 60)) min, then relock.")
                        .font(.tSubhead)
                        .foregroundStyle(Color.inkSecondary)
                }
                .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.lg)
        .background(Color.bg.ignoresSafeArea())
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopHolding() }
        }
        .onDisappear {
            holdTask?.cancel()
            dismissTask?.cancel()
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("Emergency pass").font(.tHeadline).foregroundStyle(Color.ink)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var pips: some View {
        VStack(spacing: Space.sm) {
            PassPips(left: passesShown, width: 40, height: 12)
            (Text("\(passesShown)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                + Text(" of \(SharedStore.totalPasses) left. Passes never refill.").foregroundStyle(Color.inkSecondary))
                .font(.tSubhead)
        }
    }

    private var holdButton: some View {
        ZStack {
            Circle()
                .fill(Color.ember)
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .opacity(0.08 + countdown.progress * 0.35)
            Circle()
                .stroke(Color.track, lineWidth: 8)
                .frame(width: 236, height: 236)
            Circle()
                .trim(from: 0, to: countdown.progress)
                .stroke(Color.emberLine, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 236, height: 236)
            VStack(spacing: Space.xxs) {
                FixedDigitText(text: "\(countdown.secondsLeft)", size: 72)
                    .foregroundStyle(Color.ink)
                Text(countdown.label)
                    .font(.tFootnote)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(width: 204, height: 204)
            .background(Color.surface1, in: Circle())
            .cardShadow()
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in state = true }
            )
            .onChange(of: isPressed) { _, pressed in
                if pressed { startHolding() } else { stopHolding() }
            }
        }
        .frame(width: 248, height: 248)
        .opacity(passesAtOpen > 0 ? 1 : 0.45)
        .allowsHitTesting(canUse)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold for 10 seconds to use a pass")
        .accessibilityValue(
            countdown.isDone ? "Pass used" : passesAtOpen > 0 ? "\(countdown.secondsLeft) seconds" : "No passes left")
        // A 10-second hold is hard with assistive tech, so VoiceOver gets an action with a confirmation instead.
        .accessibilityActions {
            if canUse { Button("Use a pass") { confirmingAccessibleUse = true } }
        }
        .confirmationDialog("Use an emergency pass?", isPresented: $confirmingAccessibleUse, titleVisibility: .visible) {
            Button("Use a pass") { if !countdown.isDone { complete() } }
        }
    }

    private func startHolding() {
        guard holdTask == nil, canUse, scenePhase == .active else { return }
        holdTask = Task { @MainActor in
            var last = ContinuousClock.now
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                let now = ContinuousClock.now
                let elapsed = last.duration(to: now)
                last = now
                let before = countdown.secondsLeft
                countdown.advance(by: Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18)
                if countdown.isDone {
                    complete()
                    return
                }
                if countdown.secondsLeft != before { Haptics.select() }
            }
        }
    }

    private func stopHolding() {
        holdTask?.cancel()
        holdTask = nil
        guard !countdown.isDone else { return }
        withAnimation(reduceMotion ? Motion.reveal : Motion.ui) { countdown.progress = 0 }
    }

    private func complete() {
        guard passesAtOpen > 0, dismissTask == nil else { return }
        holdTask?.cancel()
        holdTask = nil
        guard onUse() else {
            countdown.progress = 0
            dismiss()
            return
        }
        countdown.progress = 1
        Haptics.unlock()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }
}

#Preview("Emergency pass · dark") {
    EmergencyPassView(passesLeft: 3) { true }.preferredColorScheme(.dark)
}

#Preview("Emergency pass · light") {
    EmergencyPassView(passesLeft: 3) { true }.preferredColorScheme(.light)
}
