import FamilyControls
import Foundation
import os

/// One line in the Lab log. The monitor extension writes here too, so the Lab can show
/// when DeviceActivity callbacks really fired.
struct LogEntry: Codable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case app, monitor
    }

    var id = UUID()
    let date: Date
    let source: Source
    let message: String
}

/// Lock state shared by the app and its extensions through the App Group container.
/// Every read goes to UserDefaults, so a value the extension wrote is seen on the next read.
final class SharedStore {
    static let appGroupID = "group.com.raphymuthu.tapout"
    /// Five passes total, ever. They never refill.
    static let totalPasses = 5
    static let logLimit = 200

    /// False when the App Group isn't provisioned for this process. `UserDefaults(suiteName:)` then
    /// hands back a private store, so the app and the extension would silently stop sharing state.
    static var isAppGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil
    }

    static func appGroup() -> SharedStore {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            preconditionFailure("App Group \(appGroupID) is missing from the entitlements")
        }
        if !isAppGroupAvailable {
            logger.error("App Group \(appGroupID, privacy: .public) has no container; app and extension will not share state")
        }
        return SharedStore(defaults: defaults)
    }

    private static let logger = Logger(subsystem: "com.raphymuthu.tapout", category: "store")

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var session: LockSession {
        get { read(.session, absent: .unlocked, corrupt: .unlocked) }
        set { write(newValue, .session) }
    }

    /// The apps, categories and sites to shield. Opaque tokens; never leaves the device.
    var selection: FamilyActivitySelection {
        get { read(.selection, absent: FamilyActivitySelection(), corrupt: FamilyActivitySelection()) }
        set { write(newValue, .selection) }
    }

    var pairedTags: [PairedTag] {
        get { read(.pairedTags, absent: [], corrupt: []) }
        set { write(newValue, .pairedTags) }
    }

    var passesLeft: Int {
        get { read(.passesLeft, absent: Self.totalPasses, corrupt: 0) }
        set { write(newValue, .passesLeft) }
    }

    var relockStrategy: RelockStrategy {
        get { read(.relockStrategy, absent: .warning, corrupt: .warning) }
        set { write(newValue, .relockStrategy) }
    }

    var log: [LogEntry] {
        read(.log, absent: [], corrupt: [])
    }

    func appendLog(_ message: String, source: LogEntry.Source, at date: Date = .now) {
        var entries = log
        entries.append(LogEntry(date: date, source: source, message: message))
        write(Array(entries.suffix(Self.logLimit)), .log)
    }

    func clearLog() {
        defaults.removeObject(forKey: Key.log.rawValue)
    }

    private enum Key: String {
        case session, selection, pairedTags, passesLeft, relockStrategy, log
    }

    /// `absent` when nothing was ever stored. `corrupt` when data is there but won't decode;
    /// pick the safe side for each value, so damage never refills passes or drops a lock.
    private func read<Value: Decodable>(_ key: Key, absent: Value, corrupt: Value) -> Value {
        guard let data = defaults.data(forKey: key.rawValue) else { return absent }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            Self.logger.error("Unreadable \(key.rawValue, privacy: .public): \(error)")
            return corrupt
        }
    }

    /// A failed encode leaves the stored value as it was.
    private func write<Value: Encodable>(_ value: Value, _ key: Key) {
        do {
            defaults.set(try encoder.encode(value), forKey: key.rawValue)
        } catch {
            Self.logger.error("Could not save \(key.rawValue, privacy: .public): \(error)")
        }
    }
}
