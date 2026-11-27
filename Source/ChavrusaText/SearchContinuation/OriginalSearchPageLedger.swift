import Foundation

/// Bounded, passive facts from the original page owners. This is not a result
/// store or a provider: failed observation must never prevent provider work.
@MainActor
final class OriginalSearchPageLedger {
    struct Request: Equatable, Sendable {
        let bytes: Data
        let configuration: Data
        let offset: Int
        let limit: Int

        /// Both values are the original typed request. The configuration copy
        /// differs only in its offset, which the owner sets to zero.
        @MainActor
        static func encode<Value: Encodable>(
            _ request: Value,
            configuration: Value,
            offset: Int,
            limit: Int
        ) -> Self? {
            guard offset >= 0, limit > 0,
                  let bytes = OriginalSearchPageLedger.encodeEvidence(request),
                  let configuration = OriginalSearchPageLedger.encodeEvidence(configuration) else { return nil }
            return Self(bytes: bytes, configuration: configuration, offset: offset, limit: limit)
        }
    }

    struct Attempt: Equatable, Sendable {
        let id: UUID
        let ownerID: UUID
        let generation: UInt64
        let request: Request
        let replacing: Bool
        let consumedBefore: Int
        let cursorBefore: Int?
    }

    struct Commit: Equatable, Sendable {
        let attempt: Attempt
        let pageRevision: UInt64
        let rawCount: Int
        /// Converted page rows before the original display deduplication.
        let mappedCount: Int
        let consumedAfter: Int
        let cursorAfter: Int?
        let hasMore: Bool
        /// Verbatim advertised/computed cursor, before exhaustion or loop guards.
        let rawNextOffset: Int?
        let sourceEvidence: Data?
    }

    enum Terminal: Equatable, Sendable {
        case accepted(Commit)
        case failed(Attempt)
        case cancelled(Attempt)

        var attempt: Attempt {
            switch self {
            case .accepted(let commit): return commit.attempt
            case .failed(let attempt), .cancelled(let attempt): return attempt
            }
        }
    }

    /// A claimed operation may retain its actual effect after current source
    /// authority is revoked. This object never grants authority to continue.
    @MainActor
    final class TerminalCapture {
        let attempt: Attempt
        private(set) var terminal: Terminal?
        private(set) var isClosed = false

        fileprivate init(attempt: Attempt) { self.attempt = attempt }

        fileprivate func close(with terminal: Terminal?) {
            guard !isClosed else { return }
            if let terminal, terminal.attempt == attempt { self.terminal = terminal }
            isClosed = true
        }
    }

    struct Snapshot: Equatable, Sendable {
        let ownerID: UUID
        let generation: UInt64
        /// Nil revokes observation authority; it is never a reusable lease.
        let revision: UInt64?
        let pageRevision: UInt64?
        let active: Attempt?
        let lastTerminal: Terminal?
        let lastCommitted: Commit?
    }

    let ownerID = UUID()
    private(set) var generation: UInt64 = 0
    private var revisionValue: UInt64 = 0
    private var pageRevisionValue: UInt64 = 0
    private var available = true
    private var overflowed = false
    private var active: Attempt?
    private var lastTerminal: Terminal?
    private var lastCommitted: Commit?
    private var terminalCapture: TerminalCapture?

    var snapshot: Snapshot {
        Snapshot(
            ownerID: ownerID,
            generation: generation,
            revision: available ? revisionValue : nil,
            pageRevision: available ? pageRevisionValue : nil,
            active: active,
            lastTerminal: lastTerminal,
            lastCommitted: lastCommitted
        )
    }

    /// Repeated invalidation in the same source generation is still a new
    /// lifecycle. A prior attempt cannot become current again after an ABA.
    func invalidate(generation: UInt64) {
        self.generation = generation
        clearFacts()
        available = advanceRevision()
    }

    /// Encoding/bounds failures revoke only the observational epoch. The next
    /// real source invalidation may rearm it, unless a counter has overflowed.
    func observationFailed(generation: UInt64) {
        guard self.generation == generation else { return }
        _ = advanceRevision()
        clearFacts()
        available = false
    }

    /// Register synchronously after the real owner's begin and before yielding.
    /// There is at most one attached capture. A late registration is accepted
    /// only for the exact terminal still held by the current source epoch.
    func captureTerminal(for attempt: Attempt) -> TerminalCapture? {
        guard available, attempt.ownerID == ownerID, attempt.generation == generation else { return nil }
        if active == attempt {
            if let terminalCapture { return terminalCapture.attempt == attempt ? terminalCapture : nil }
            let capture = TerminalCapture(attempt: attempt)
            terminalCapture = capture
            return capture
        }
        guard let lastTerminal, lastTerminal.attempt == attempt else { return nil }
        let capture = TerminalCapture(attempt: attempt)
        capture.close(with: lastTerminal)
        return capture
    }

    func begin(
        generation: UInt64,
        request: Request?,
        replacing: Bool,
        consumedBefore: Int,
        cursorBefore: Int?
    ) -> Attempt? {
        guard self.generation == generation, available, active == nil else { return nil }
        guard let request,
              request.offset >= 0, request.limit > 0,
              !request.bytes.isEmpty, request.bytes.count <= Self.maximumEncodedBytes,
              !request.configuration.isEmpty, request.configuration.count <= Self.maximumEncodedBytes,
              consumedBefore >= 0,
              cursorBefore.map({ $0 >= 0 }) ?? true else {
            observationFailed(generation: generation)
            return nil
        }
        guard advanceRevision() else { return nil }
        let attempt = Attempt(
            id: UUID(), ownerID: ownerID, generation: generation,
            request: request, replacing: replacing,
            consumedBefore: consumedBefore, cursorBefore: cursorBefore
        )
        active = attempt
        lastTerminal = nil
        return attempt
    }

    /// Call only after the original owner has passed its cancellation/source
    /// guards and actually committed its original store/cursor. Empty terminal
    /// pages and pages wholly removed by display dedup remain accepted pages.
    func accept(
        _ attempt: Attempt?,
        rawCount: Int,
        mappedCount: Int,
        consumedAfter: Int,
        cursorAfter: Int?,
        hasMore: Bool,
        rawNextOffset: Int?,
        sourceEvidence: Data?
    ) {
        guard let attempt, isCurrent(attempt) else { return }
        guard rawCount >= 0, mappedCount >= 0, mappedCount <= rawCount,
              consumedAfter >= 0,
              attempt.replacing || consumedAfter >= attempt.consumedBefore,
              cursorAfter.map({ $0 >= 0 }) ?? true,
              sourceEvidence.map({ $0.count <= Self.maximumEncodedBytes }) ?? true else {
            observationFailed(generation: attempt.generation)
            return
        }
        let nextPageRevision = pageRevisionValue.addingReportingOverflow(1)
        guard !nextPageRevision.overflow else {
            disableForOverflow()
            return
        }
        guard advanceRevision() else { return }
        pageRevisionValue = nextPageRevision.partialValue
        let commit = Commit(
            attempt: attempt, pageRevision: pageRevisionValue,
            rawCount: rawCount, mappedCount: mappedCount,
            consumedAfter: consumedAfter, cursorAfter: cursorAfter,
            hasMore: hasMore, rawNextOffset: rawNextOffset,
            sourceEvidence: sourceEvidence
        )
        active = nil
        lastCommitted = commit
        lastTerminal = .accepted(commit)
        closeCapture(with: lastTerminal)
    }

    func fail(_ attempt: Attempt?, cancelled: Bool) {
        guard let attempt, isCurrent(attempt), advanceRevision() else { return }
        active = nil
        lastTerminal = cancelled ? .cancelled(attempt) : .failed(attempt)
        closeCapture(with: lastTerminal)
        // A paging failure leaves the original prior page available for retry.
    }

    static func encodeEvidence<Value: Encodable>(_ value: Value) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value), data.count <= maximumEncodedBytes else { return nil }
        return data
    }

    private static let maximumEncodedBytes = 256 * 1024

    private func isCurrent(_ attempt: Attempt) -> Bool {
        available && attempt.ownerID == ownerID && attempt.generation == generation && active == attempt
    }

    private func clearFacts() {
        closeCapture(with: nil)
        active = nil
        lastTerminal = nil
        lastCommitted = nil
    }

    private func closeCapture(with terminal: Terminal?) {
        let capture = terminalCapture
        terminalCapture = nil
        capture?.close(with: terminal)
    }

    private func advanceRevision() -> Bool {
        guard !overflowed else { return false }
        let next = revisionValue.addingReportingOverflow(1)
        guard !next.overflow else {
            disableForOverflow()
            return false
        }
        revisionValue = next.partialValue
        return true
    }

    private func disableForOverflow() {
        overflowed = true
        available = false
        clearFacts()
    }
}
