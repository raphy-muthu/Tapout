#if DEBUG
import Observation
import UIKit

/// Takes a battery-and-heat reading a minute while a run is on, whichever screen is up. It lives outside the
/// Lab, so leaving the Lab doesn't stop it, and it keeps the display awake so a screen can be left open.
@MainActor @Observable
final class PowerMeter {
    static let shared = PowerMeter()
    static let key = "lab.powerRuns"
    /// How many finished runs are kept.
    static let kept = 10

    private(set) var current: PowerRun?
    /// Newest first, including the one being taken.
    private(set) var runs: [PowerRun]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let read: @MainActor () -> PowerSample
    @ObservationIgnored private let keepAwake: @MainActor (Bool) -> Void
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(defaults: UserDefaults = .standard,
         read: @escaping @MainActor () -> PowerSample = PowerMeter.deviceReading,
         keepAwake: @escaping @MainActor (Bool) -> Void = PowerMeter.keepDeviceAwake) {
        self.defaults = defaults
        self.read = read
        self.keepAwake = keepAwake
        runs = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([PowerRun].self, from: $0) } ?? []
    }

    func start(label: String) {
        guard current == nil else { return }
        let name = label.trimmingCharacters(in: .whitespacesAndNewlines)
        current = PowerRun(label: name.isEmpty ? "Run" : name)
        keepAwake(true)
        sample()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(PowerRun.interval))
                guard !Task.isCancelled else { return }
                self?.sample()
            }
        }
    }

    /// Adds a reading to the run and saves it, so a run survives Tapout being closed.
    func sample() {
        guard var run = current else { return }
        run.samples.append(read())
        current = run
        runs = Array(([run] + runs.filter { $0.id != run.id }).prefix(Self.kept))
        save()
    }

    func stop() {
        guard current != nil else { return }
        loop?.cancel()
        loop = nil
        sample()
        current = nil
        keepAwake(false)
    }

    func clear() {
        guard current == nil else { return }
        runs = []
        save()
    }

    /// Every saved run's report, newest first.
    var report: String {
        runs.map(\.report).joined(separator: "\n\n")
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(runs), forKey: Self.key)
    }

    static func deviceReading() -> PowerSample {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = Double(device.batteryLevel) // -1 when unknown
        return PowerSample(
            date: .now,
            battery: level < 0 ? nil : level,
            charging: device.batteryState == .charging || device.batteryState == .full,
            heat: PowerHeat(ProcessInfo.processInfo.thermalState),
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
            glass: UserDefaults.standard.bool(forKey: AppSettings.livingGlassKey))
    }

    static func keepDeviceAwake(_ awake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = awake
    }
}
#endif
