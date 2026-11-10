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
    /// The NFC reader, or in the simulator a stand-in that finds `known`, or a new tag when `known` is nil.
    /// Simulator only: a Debug build on an iPhone never unlocks without a real tag.
    @MainActor static func live(known: TagUID? = nil) -> any TagScanning {
        #if targetEnvironment(simulator)
        return MockTagScanner(known: known)
        #else
        return TagReader()
        #endif
    }
}

#if targetEnvironment(simulator)
/// Simulator stand-in. Finds `known` after a second, or a new random tag when `known` is nil
/// or the app was launched with `-mockUnknownTag`.
struct MockTagScanner: TagScanning {
    var known: TagUID?

    @MainActor func scan(prompt: String) async throws -> TagUID {
        try await Task.sleep(for: .seconds(1))
        if let known, !ProcessInfo.processInfo.arguments.contains("-mockUnknownTag") { return known }
        return TagUID(data: Data((0..<7).map { _ in UInt8.random(in: .min ... .max) }))
    }
}
#endif
