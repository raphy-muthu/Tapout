import Foundation
import Security

/// A second count of spent passes, beside the App Group. The Keychain outlives deleting the app,
/// so reinstalling doesn't refill passes. The item is this-device-only, so a new iPhone starts fresh.
protocol PassCounting {
    /// Passes spent so far, ever. Zero when nothing is stored.
    func used() -> Int
    /// Returns true when the count was saved.
    @discardableResult
    func setUsed(_ count: Int) -> Bool
}

struct KeychainPassVault: PassCounting {
    var service = "com.raphymuthu.tapout.passes"
    private let account = "used"

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func used() -> Int {
        read() ?? 0
    }

    /// The stored count, 0 when there is no item yet, or nil when the Keychain couldn't be read.
    private func read() -> Int? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return 0 }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return Int(String(decoding: data, as: UTF8.self))
    }

    /// Never lowers the stored count: it writes the larger of `count` and what is already there,
    /// and writes nothing when the current count can't be read.
    @discardableResult
    func setUsed(_ count: Int) -> Bool {
        guard let stored = read() else { return false }
        let data = Data(String(max(count, stored)).utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    #if DEBUG
    func delete() {
        SecItemDelete(query as CFDictionary)
    }
    #endif
}

/// In memory, for previews and tests.
final class MemoryPassVault: PassCounting {
    private var count: Int

    init(used: Int = 0) {
        count = used
    }

    func used() -> Int { count }
    @discardableResult
    func setUsed(_ count: Int) -> Bool {
        self.count = count
        return true
    }
}
