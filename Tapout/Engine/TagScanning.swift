import Foundation

/// Reads one tag's UID. The real reader needs NFC hardware; the simulator gets a stand-in.
protocol TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID
}

enum TagScanPrompt {
    static let pair = "Hold your tag near the top of your iPhone."
}

extension TagReader: TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await readUID(prompt: prompt)
    }
}

enum TagScanners {
    /// The NFC reader, or in DEBUG builds without NFC (the simulator) a stand-in.
    @MainActor static func live() -> any TagScanning {
        #if DEBUG
        if !TagReader.isAvailable { return MockTagScanner() }
        #endif
        return TagReader()
    }
}

#if DEBUG
/// Simulator stand-in: finds a new random tag after a second.
struct MockTagScanner: TagScanning {
    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await Task.sleep(for: .seconds(1))
        return TagUID(data: Data((0..<7).map { _ in UInt8.random(in: .min ... .max) }))
    }
}
#endif
