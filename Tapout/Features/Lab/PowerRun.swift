#if DEBUG
import Foundation

/// How hot the phone says it is, worst last.
enum PowerHeat: Int, Codable, Comparable {
    case nominal, fair, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        self = switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .critical
        }
    }

    var name: String {
        switch self {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        }
    }

    static func < (a: PowerHeat, b: PowerHeat) -> Bool { a.rawValue < b.rawValue }
}

/// One reading while a battery run is on.
struct PowerSample: Codable, Equatable {
    var date: Date
    /// 0...1, or nil where iOS can't say (as on the simulator).
    var battery: Double?
    var charging: Bool
    var heat: PowerHeat
    var lowPower: Bool
    /// The Living glass switch.
    var glass: Bool
}

/// A battery-and-heat run: what was being tested, and a reading a minute. The report says what it can and
/// what spoiled it.
struct PowerRun: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String
    var samples: [PowerSample] = []

    /// The expected time between readings.
    static let interval: TimeInterval = 60

    var duration: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return last.date.timeIntervalSince(first.date)
    }

    /// Time Tapout wasn't reading: it only reads while it is on screen.
    var timeAway: TimeInterval {
        zip(samples, samples.dropFirst()).reduce(0) { total, pair in
            let gap = pair.1.date.timeIntervalSince(pair.0.date)
            return gap > Self.interval * 1.5 ? total + gap - Self.interval : total
        }
    }

    var worstHeat: PowerHeat { samples.map(\.heat).max() ?? .nominal }

    /// The share of the battery used per hour. iOS may report the level in coarse steps, so this is measured from
    /// the first step down to the last, and needs two of them. nil when charging spoiled it or it was too short.
    var drainPerHour: Double? {
        guard !samples.contains(where: \.charging) else { return nil }
        let steps = zip(samples, samples.dropFirst()).compactMap { before, after -> (date: Date, level: Double)? in
            guard let was = before.battery, let now = after.battery, now < was - 0.001 else { return nil }
            return (after.date, now)
        }
        guard let first = steps.first, let last = steps.last, last.date > first.date else { return nil }
        return (first.level - last.level) / last.date.timeIntervalSince(first.date) * 3600
    }

    /// What makes this run hard to compare with another.
    var problems: [String] {
        var found: [String] = []
        if samples.contains(where: \.charging) { found.append("Charging during the run.") }
        if samples.contains(where: \.lowPower) { found.append("Low Power Mode was on.") }
        if Set(samples.map(\.glass)).count > 1 { found.append("The switch changed during the run.") }
        if timeAway >= Self.interval { found.append("Away from Tapout for \(Self.minutes(timeAway)) min.") }
        if !samples.isEmpty && samples.allSatisfy({ $0.battery == nil }) { found.append("iOS gave no battery level.") }
        return found
    }

    var report: String {
        let glass = samples.first.map { $0.glass ? "switch on" : "switch off" } ?? "no readings"
        var lines = ["\(label) · \(glass)"]
        var battery = "\(Self.minutes(duration)) min"
        if let from = samples.first?.battery, let to = samples.last?.battery {
            battery += " · battery \(Self.percent(from)) → \(Self.percent(to))"
        }
        lines.append(battery)
        if let drain = drainPerHour {
            lines.append(String(format: "Drain: %.1f%% an hour", drain * 100))
        } else if samples.contains(where: \.charging) {
            lines.append("Drain: not measured while charging")
        } else {
            lines.append("Drain: too short to tell. It needs two battery steps; run for about an hour.")
        }
        lines.append("Heat: worst \(worstHeat.name)")
        lines += problems.map { "! \($0)" }
        return lines.joined(separator: "\n")
    }

    private static func minutes(_ seconds: TimeInterval) -> Int { Int((seconds / 60).rounded()) }
    private static func percent(_ level: Double) -> String { "\(Int((level * 100).rounded()))%" }
}
#endif
