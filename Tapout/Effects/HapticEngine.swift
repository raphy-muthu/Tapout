import CoreHaptics
import Foundation

/// Plays `HapticPattern`s through Core Haptics. Falls back to the plain `Haptics` generators
/// where the hardware has no Taptic Engine support, or when anything goes wrong.
@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private var engine: CHHapticEngine?

    private init() {}

    func play(_ pattern: HapticPattern) {
        guard AppSettings.hapticsEnabled() else { return }
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            fallBack(pattern)
            return
        }
        do {
            let engine = try readyEngine()
            let player = try engine.makeAdvancedPlayer(with: try Self.corePattern(for: pattern))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallBack(pattern)
        }
    }

    // MARK: - Engine lifecycle

    private func readyEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let made = try CHHapticEngine()
        // Core Haptics calls these handlers on its own internal queue. They must be `@Sendable`
        // (not main-actor isolated, which would trap on that queue in Swift 6), and hop back to
        // the main actor themselves.
        made.resetHandler = { @Sendable [weak self] in
            Task { @MainActor in self?.restart() }
        }
        // iOS stops the engine when it has been idle a while, so it doesn't keep running (and using power) between
        // haptics; the next player starts it again. Only a real stop drops it.
        made.isAutoShutdownEnabled = true
        made.stoppedHandler = { @Sendable [weak self] reason in
            guard reason != .idleTimeout else { return }
            Task { @MainActor in self?.engine = nil }
        }
        try made.start()
        engine = made
        return made
    }

    private func restart() {
        do { try engine?.start() } catch { engine = nil }
    }

    // MARK: - Pattern conversion

    private static func corePattern(for pattern: HapticPattern) throws -> CHHapticPattern {
        let events = pattern.events.map { event in
            CHHapticEvent(
                eventType: event.kind == .transient ? .hapticTransient : .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: event.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: event.sharpness),
                ],
                relativeTime: event.time,
                duration: event.kind == .continuous ? event.duration : 0
            )
        }
        return try CHHapticPattern(events: events, parameters: [])
    }

    private func fallBack(_ pattern: HapticPattern) {
        switch pattern.fallback {
        case .lock: Haptics.lock()
        case .unlock: Haptics.unlock()
        case .select: Haptics.select()
        }
    }
}
