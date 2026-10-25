@preconcurrency import CoreNFC

/// Reads a tag's hardware UID through one system NFC sheet. Nothing is written to the tag.
/// Callbacks arrive on the main queue, which is the only place this class's state is touched
/// (each delegate method asserts it). A callback from a session that is no longer current is ignored.
final class TagReader: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
    enum ReadError: Error, Equatable {
        case unavailable, busy, unsupportedTag, cancelled, timedOut
        case failed(String)
    }

    static var isAvailable: Bool { NFCTagReaderSession.readingAvailable }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<TagUID, any Error>?

    @MainActor
    func readUID(prompt: String) async throws -> TagUID {
        guard Self.isAvailable else { throw ReadError.unavailable }
        // `session` outlives `continuation` until the system reports the invalidation, so check it too.
        guard session == nil, continuation == nil else { throw ReadError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            guard let session = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693], delegate: self, queue: .main) else {
                continuation.resume(throwing: ReadError.unavailable)
                return
            }
            self.continuation = continuation
            self.session = session
            session.alertMessage = prompt
            session.begin()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: any Error) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard session === self.session else { return }
        let code = (error as? NFCReaderError)?.code
        let failure: ReadError = switch code {
        case .readerSessionInvalidationErrorUserCanceled: .cancelled
        case .readerSessionInvalidationErrorSessionTimeout: .timedOut
        default: .failed(error.localizedDescription)
        }
        finish(.failure(failure))
        self.session = nil
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard session === self.session else { return }
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "Hold one tag at a time."
            session.restartPolling()
            return
        }
        // NFCTagReaderSession and NFCTag aren't Sendable; the completion arrives on the session's queue (main).
        nonisolated(unsafe) let session = session
        nonisolated(unsafe) let detected = tag
        session.connect(to: tag) { [self] error in
            dispatchPrecondition(condition: .onQueue(.main))
            guard session === self.session else { return }
            if let error {
                session.invalidate(errorMessage: "Try again.")
                finish(.failure(.failed(error.localizedDescription)))
                return
            }
            guard let uid = Self.identifier(of: detected) else {
                session.invalidate(errorMessage: "This tag isn't supported.")
                finish(.failure(.unsupportedTag))
                return
            }
            session.alertMessage = "Done."
            session.invalidate()
            finish(.success(TagUID(data: uid)))
        }
    }

    private static func identifier(of tag: NFCTag) -> Data? {
        switch tag {
        case .miFare(let tag): tag.identifier
        case .iso15693(let tag): tag.identifier
        case .iso7816(let tag): tag.identifier
        case .feliCa: nil
        @unknown default: nil
        }
    }

    /// Resumes the waiting read once. Later callbacks (the invalidation after a success) are ignored.
    private func finish(_ result: Result<TagUID, ReadError>) {
        continuation?.resume(with: result.mapError { $0 as any Error })
        continuation = nil
    }
}
