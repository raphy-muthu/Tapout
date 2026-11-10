import Foundation
import Testing
@testable import Tapout

struct PassVaultTests {
    @Test func keychainStartsAtZeroAndKeepsTheCount() {
        let vault = KeychainPassVault(service: "com.raphymuthu.tapout.tests.\(UUID().uuidString)")
        defer { vault.delete() }
        #expect(vault.used() == 0)
        vault.setUsed(2)
        #expect(vault.used() == 2)
        vault.setUsed(3)
        #expect(KeychainPassVault(service: vault.service).used() == 3)
    }

    @Test func keychainNeverGoesDown() {
        let vault = KeychainPassVault(service: "com.raphymuthu.tapout.tests.\(UUID().uuidString)")
        defer { vault.delete() }
        vault.setUsed(3)
        vault.setUsed(1)
        #expect(vault.used() == 3)
    }
}
