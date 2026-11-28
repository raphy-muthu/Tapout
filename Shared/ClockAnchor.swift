import Darwin
import Foundation

/// A reading of the phone's monotonic clock: it keeps counting through sleep and ignores any change to the
/// date, time or time zone in Settings. Two readings from the same boot measure the real time between them,
/// so a timer or pass can't be ended (or stretched) by moving the clock. After a restart the readings can't be
/// compared, and callers fall back to the wall clock.
///
/// Uses the system boot time APIs for elapsed time only (privacy reason 35F9.1).
struct ClockAnchor: Codable, Equatable, Sendable {
    /// This boot's identifier (`kern.bootsessionuuid`).
    let boot: String
    /// Seconds on `CLOCK_MONOTONIC` since boot, sleep included.
    let seconds: TimeInterval

    /// Now, or nil when the boot can't be identified (then only the wall clock is used).
    static func current() -> ClockAnchor? {
        guard let boot = bootSession() else { return nil }
        return ClockAnchor(boot: boot, seconds: Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000)
    }

    /// Real seconds from this reading to `later`, or nil when either is missing or the phone restarted in between.
    func elapsed(until later: ClockAnchor?) -> TimeInterval? {
        guard let later, later.boot == boot else { return nil }
        return max(0, later.seconds - seconds)
    }

    private static func bootSession() -> String? {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &buffer, &size, nil, 0) == 0 else { return nil }
        let value = String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return value.isEmpty ? nil : value
    }
}
